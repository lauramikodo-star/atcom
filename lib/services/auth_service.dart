import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  UserSession? _currentSession;
  bool _isLoading = false;
  String? _error;

  UserSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentSession != null && !_currentSession!.isExpired;

  Future<bool> login(String phone, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final apiService = ApiService();
      final result = await apiService.myIdoomLogin(phone, password);
      
      if (result['success']) {
        final session = UserSession(
          token: result['token'],
          user: result['user'],
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );
        
        await _saveSession(session);
        _currentSession = session;
        notifyListeners();
        _setLoading(false);
        return true;
      } else {
        _setError(result['error'] ?? 'Login failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _currentSession = null;
    _setError(null);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    
    notifyListeners();
  }

  Future<void> restoreSession(String token, String userData) async {
    try {
      final session = UserSession(
        token: token,
        user: UserData.fromJson(
          Map<String, dynamic>.from(jsonDecode(userData)),
        ),
        expiresAt: DateTime.now().add(Duration(hours: 1)),
      );
      
      _currentSession = session;
      notifyListeners();
    } catch (e) {
      await logout();
    }
  }

  Future<AccountDetails?> getAccountDetails() async {
    if (_currentSession == null || _currentSession!.isExpired) {
      return null;
    }

    try {
      final apiService = ApiService();
      return await apiService.getAccountDetails(_currentSession!.token);
    } catch (e) {
      _setError('Failed to fetch account details: ${e.toString()}');
      return null;
    }
  }

  Future<void> _saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', session.token);
    await prefs.setString('user_data', jsonEncode(session.user.toJson()));
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}