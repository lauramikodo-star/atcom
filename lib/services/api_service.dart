import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user_session.dart';

class ApiService {
  static const String myIdoomBaseUrl = 'https://myidoom.at.dz';
  static const String atBaseUrl = 'https://paiement.algerietelecom.dz/AndroidApp';
  static const String geminiApiKey = 'AIzaSyAS6l7qi0RhVjzXR3u6sDdtNTHmESOQMzQ';

  // MyIdoom API Headers
  Map<String, String> get _myIdoomHeaders => {
    'Authorization': 'Basic dXNyLW15aWRvb206TmVpZEshMTc5NA==',
    'User-Agent': 'Dart/3.0 (dart:io)',
    'Content-Type': 'application/json',
  };

  Map<String, String> get _atHeaders => {
    'Authorization': 'Basic VEdkNzJyOTozUjcjd2FiRHNfSGpDNzg3IQ==',
    'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 10; vivo X21A Build/QD4A.200805.003)',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  };

  // MyIdoom Login
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
            'error': data['message'] ?? 'Login failed',
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

  // Get Account Details
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

  // Get Service Info (ADSL)
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

  // Get Service Info (4G LTE)
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

  // Check Debt
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

  // Recharge
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
        message: isSuccess ? "✅ RECHARGE SUCCESSFUL! 🚀" : "❌ RECHARGE FAILED ⚠️",
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

  // OCR with Gemini
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

  // Clean response from BOM characters
  String _cleanResponse(String response) {
    return response.replaceAll(RegExp(r'^[\xEF\xBB\xBF]+'), '').trim();
  }
}