import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import 'api_service.dart';

/// Service class for handling user authentication and session management.
class AuthService extends ChangeNotifier {
  final ApiService _apiService;
  UserSession? _currentSession;
  bool _isLoading = false;
  String? _error;

  AuthService(this._apiService);

  /// The current user session.
  UserSession? get currentSession => _currentSession;

  /// Whether the service is currently busy.
  bool get isLoading => _isLoading;

  /// The last error that occurred.
  String? get error => _error;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => _currentSession != null && !_currentSession!.isExpired;

  /// Logs in a user with the given phone number and password.
  ///
  /// Returns `true` if the login was successful, `false` otherwise.
  Future<bool> login(String phone, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final result = await _apiService.myIdoomLogin(phone, password);
      
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

  /// Logs out the current user.
  Future<void> logout() async {
    _currentSession = null;
    _setError(null);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    
    notifyListeners();
  }

  /// Restores the user session from the given token and user data.
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

  /// Gets the account details for the currently logged in user.
  ///
  /// Returns an [AccountDetails] object or `null` if the request fails.
  Future<AccountDetails?> getAccountDetails() async {
    if (_currentSession == null || _currentSession!.isExpired) {
      return null;
    }

    try {
      return await _apiService.getAccountDetails(_currentSession!.token);
    } catch (e) {
      _setError('Failed to fetch account details: ${e.toString()}');
      return null;
    }
  }

  /// Saves the user session to shared preferences.
  Future<void> _saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', session.token);
    await prefs.setString('user_data', jsonEncode(session.user.toJson()));
  }

  /// Sets the loading state.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Sets the error message.
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clears the error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
