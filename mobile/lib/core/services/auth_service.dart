import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class AuthService {
  static const String _userKey = 'catu_current_user_profile';
  static const String _isLoggedInKey = 'catu_is_logged_in';

  static Map<String, dynamic>? _currentUser;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _currentUser != null;

  /// Load session from SharedPreferences on app startup
  static Future<Map<String, dynamic>?> initSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userKey);
      final loggedIn = prefs.getBool(_isLoggedInKey);
      if (raw != null && raw.isNotEmpty && loggedIn != false) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            (decoded.containsKey('id') ||
                decoded.containsKey('userId') ||
                decoded.containsKey('user_id') ||
                decoded.containsKey('fullName') ||
                decoded.containsKey('full_name'))) {
          _currentUser = decoded;
          await prefs.setBool(_isLoggedInKey, true);
          NotificationService.setCurrentUser(decoded);

          final uid = decoded['id'] ?? decoded['userId'] ?? decoded['user_id'];
          if (uid != null) {
            final int? intUid = int.tryParse(uid.toString());
            if (intUid != null) {
              NotificationService.registerUserDevice(intUid);
              NotificationService.startPolling(intUid);
            }
          }
          debugPrint('AuthService: Auto-login session restored for user: $uid');
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
    }
    return null;
  }

  /// Save session after successful login
  static Future<void> saveSession(Map<String, dynamic> user) async {
    _currentUser = Map<String, dynamic>.from(user);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
      await prefs.setBool(_isLoggedInKey, true);
      NotificationService.setCurrentUser(user);
      final uid = user['id'] ?? user['userId'] ?? user['user_id'];
      if (uid != null) {
        final int? intUid = int.tryParse(uid.toString());
        if (intUid != null) {
          NotificationService.registerUserDevice(intUid);
          NotificationService.startPolling(intUid);
        }
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  /// Clear session when user explicitly logs out
  static Future<void> logout() async {
    _currentUser = null;
    NotificationService.stopPolling();
    NotificationService.currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.setBool(_isLoggedInKey, false);
    } catch (e) {
      debugPrint('Error clearing session: $e');
    }
  }
}
