import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_session.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service class for handling API requests to Algeria Telecom and MyIdoom.
class ApiService {
  // Base URLs for the APIs.
  static const String myIdoomBaseUrl = 'https://myidoom.at.dz';
  static const String atBaseUrl = 'https://paiement.algerietelecom.dz/AndroidApp';

  // API key for the Gemini OCR service.
  final String geminiApiKey = dotenv.env['GEMINI_API_KEY']!;

  // Headers for MyIdoom API requests.
  Map<String, String> get _myIdoomHeaders => {
    'Authorization': 'Basic dXNyLW15aWRvb206TmVpZEshMTc5NA==',
    'User-Agent': 'Dart/3.0 (dart:io)',
    'Content-Type': 'application/json',
  };

  // Headers for Algeria Telecom API requests.
  Map<String, String> get _atHeaders => {
    'Authorization': 'Basic VEdkNzJyOTozUjcjd2FiRHNfSGpDNzg3IQ==',
    'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 10; vivo X21A Build/QD4A.200805.003)',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  };

  /// Logs in a user to MyIdoom.
  ///
  /// Returns a map containing the success status, token, and user data.
  Future<Map<String, dynamic>> myIdoomLogin(String phone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$myIdoomBaseUrl/api/checkHeader/login'),
        headers: _myIdoomHeaders,
        body: jsonEncode({
          'nd': phone,
          'password': password,
          'lang': 'fr',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 0) {
          return {
            'success': true,
            'token': data['data']['authorisation']['token'],
            'user': UserData.fromJson(data['data']),
          };
        } else {
          return {
            'success': false,
            'error': data.containsKey('message') ? data['message'] : 'Login failed',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Gets the account details for the currently logged in user.
  ///
  /// Returns an [AccountDetails] object or `null` if the request fails.
  Future<AccountDetails?> getAccountDetails(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$myIdoomBaseUrl/api/compte'),
        headers: {
          ..._myIdoomHeaders,
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AccountDetails.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Gets the service info for a given phone number.
  ///
  /// This method first checks for ADSL service, then for 4G LTE service.
  /// Returns a [ServiceInfo] object or `null` if the request fails.
  Future<ServiceInfo?> getServiceInfo(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$atBaseUrl/internet_recharge.php'),
        headers: _atHeaders,
        body: {
          'validerADSLco20': 'Confirmer',
          'ndco20': phone,
        },
      );

      final cleanResponse = _cleanResponse(response.body);
      final data = jsonDecode(cleanResponse);

      if (data['succes'] == "1") {
        return ServiceInfo.fromJson({
          'found': true,
          'type': data['type'],
          'ncli': data['ncli'],
          'offer': data['offre'] ?? 'Standard',
        });
      }

      // Try 4G LTE
      return await _getServiceInfo4G(phone);
    } catch (e) {
      return null;
    }
  }

  /// Gets the service info for a given 4G LTE phone number.
  ///
  /// Returns a [ServiceInfo] object or `null` if the request fails.
  Future<ServiceInfo?> _getServiceInfo4G(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$atBaseUrl/voucher_internet.php'),
        headers: _atHeaders,
        body: {
          'dahabiaco20': 'Confirmer',
          'nd_4gco20': phone,
        },
      );

      final cleanResponse = _cleanResponse(response.body);
      final data = jsonDecode(cleanResponse);

      if (data['succes'] == "1") {
        return ServiceInfo.fromJson({
          'found': true,
          'type': data['type'],
          'ncli': data['ncli'],
          'offer': data['offre'] ?? '4G LTE',
        });
      }

      return ServiceInfo(found: false, type: '', ncli: '', offer: '');
    } catch (e) {
      return null;
    }
  }

  /// Checks the debt for a given phone number.
  ///
  /// Returns a string indicating the debt status.
  Future<String> checkDebt(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('$atBaseUrl/dette_paiement.php'),
        headers: _atHeaders,
        body: {
          'ndco20': phone,
          'validerco20': 'Confirmer',
          'nfactco20': '',
        },
      );

      final cleanResponse = _cleanResponse(response.body);
      final data = jsonDecode(cleanResponse);

      if (data['succes'] != null) {
        if (data['succes'] == "0") {
          return "✅ No Debt";
        } else {
          return "⚠️ Debt Found";
        }
      }
      return "❌ Unavailable";
    } catch (e) {
      return "❌ Unavailable";
    }
  }

  /// Recharges a phone number with a voucher.
  ///
  /// Returns a [RechargeResult] object.
  Future<RechargeResult> recharge(String phone, String voucher) async {
    try {
      // Get service info first
      final serviceInfo = await getServiceInfo(phone);
      if (serviceInfo == null || !serviceInfo.found) {
        return RechargeResult(
          success: false,
          message: "❌ Number not found.",
          response: {},
        );
      }

      final response = await http.post(
        Uri.parse('$atBaseUrl/voucher_internet_suite.php'),
        headers: _atHeaders,
        body: {
          'rechargeco20': 'Recharger',
          'typeco20': serviceInfo.type,
          'ndco20': phone,
          'nclico20': serviceInfo.ncli,
          'voucherco20': voucher,
        },
      );

      final cleanResponse = _cleanResponse(response.body);
      final data = jsonDecode(cleanResponse);

      final isSuccess = (data['num_trans'] != null && data['num_trans'].toString().isNotEmpty) ||
          (data['succes'] != null && data['succes'] == "1");

      return RechargeResult(
        success: isSuccess,
        message: isSuccess ? "✅ RECHARGE SUCCESSFUL! 🚀" : data['erreur'] ?? "❌ RECHARGE FAILED ⚠️",
        response: data,
      );
    } catch (e) {
      return RechargeResult(
        success: false,
        message: "❌ Network error: ${e.toString()}",
        response: {},
      );
    }
  }

  /// Extracts a voucher code from an image using the Gemini OCR service.
  ///
  /// Returns the voucher code as a string, or an error message if the request fails.
  Future<String> extractVoucherCode(String imagePath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final payload = {
        "contents": [{
          "parts": [
            {"text": "Extract the 16-digit voucher code. Return ONLY the digits."},
            {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}
          ]
        }]
      };

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] ?? '';
        final code = text.replaceAll(RegExp(r'[^0-9]'), '');
        
        if (code.length == 16) {
          return code;
        } else {
          return "Error: AI found '$code' (Length: ${code.length})";
        }
      } else {
        return "Error: OCR service unavailable";
      }
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }

  /// Cleans the response from BOM characters.
  String _cleanResponse(String response) {
    return response.replaceAll(RegExp(r'^[\xEF\xBB\xBF]+'), '').trim();
  }
}
