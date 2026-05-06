import 'dart:convert';
import 'package:agreeo/config/backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _tokenKey = 'auth_accessToken';
  static const String _refreshTokenKey = 'auth_refreshToken';

  AuthService({BackendConfig? config})
    : _config = config ?? BackendConfig.fromEnv();

  final BackendConfig _config;

  Future<bool> register(String email, String password) async {
    try {
      print('[AuthService] Registering with backend: $email');
      final response = await http.post(
        Uri.parse(_config.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print('[AuthService] Register response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;

        if (accessToken != null && refreshToken != null) {
          await _storeTokens(accessToken, refreshToken);
          print('[AuthService] Registration successful, tokens stored');
          return true;
        }
      } else {
        final error = jsonDecode(response.body);
        print('[AuthService] Register error: ${error['error']}');
      }
      return false;
    } catch (e) {
      print('[AuthService] Register exception: $e');
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      print('[AuthService] Logging in with backend: $email');
      final response = await http.post(
        Uri.parse(_config.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print('[AuthService] Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;

        if (accessToken != null && refreshToken != null) {
          await _storeTokens(accessToken, refreshToken);
          print('[AuthService] Login successful, tokens stored');
          return accessToken;
        }
      } else {
        final error = jsonDecode(response.body);
        print('[AuthService] Login error: ${error['error']}');
      }
      return null;
    } catch (e) {
      print('[AuthService] Login exception: $e');
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    print('[AuthService] Logged out, tokens cleared');
  }

  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isTokenValid() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }
}
