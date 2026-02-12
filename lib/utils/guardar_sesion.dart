import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageHelper {
  static const String _keyAccessToken = 'access_token';
  static const String _keyUserInfo = 'user_info';
  static const String _keyIsAuthenticated = 'is_authenticated';

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, token);
    print('Token guardado: ${token.substring(0, 20)}...');
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    print('Token recuperado: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
    return token;
  }

  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserInfo, jsonEncode(userInfo));
    print('UserInfo guardado');
  }

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString(_keyUserInfo);
    if (userInfoString != null) {
      print('UserInfo recuperado');
      return jsonDecode(userInfoString);
    }
    print('UserInfo no encontrado');
    return null;
  }

  static Future<void> saveAuthStatus(bool isAuthenticated) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsAuthenticated, isAuthenticated);
    print(' AuthStatus guardado: $isAuthenticated');
  }

  static Future<bool> getAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getBool(_keyIsAuthenticated) ?? false;
    print(' AuthStatus recuperado: $status');
    return status;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserInfo);
    await prefs.remove(_keyIsAuthenticated);
    print(' Almacenamiento limpiado completamente');
  }

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    final hasToken = prefs.containsKey(_keyAccessToken);
    final hasUserInfo = prefs.containsKey(_keyUserInfo);
    print('hasSession - Token: $hasToken, UserInfo: $hasUserInfo');
    return hasToken && hasUserInfo;
  }
}