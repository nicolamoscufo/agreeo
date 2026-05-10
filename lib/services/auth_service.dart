import 'dart:convert';

import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/models/neo4j/neo4j_models.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('[AuthService] Registering with backend: $email');

      final response = await http.post(
        Uri.parse(_config.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      debugPrint('[AuthService] Register response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = _decodeBody(response.body);

        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;

        if (accessToken == null || refreshToken == null) {
          debugPrint('[AuthService] Register failed: missing tokens');
          return false;
        }

        await _storeTokens(accessToken, refreshToken);

        final user = _buildNeo4jUser(
          email: email,
          accessToken: accessToken,
          responseData: data,
          isNewUser: true,
        );

        // Populate current user by calling backend /me (no direct Neo4j writes)
        await _fetchMe(accessToken);

        debugPrint('[AuthService] Registration successful');
        return true;
      }

      _logBackendError('Register', response.body);
      return false;
    } catch (e) {
      debugPrint('[AuthService] Register exception: $e');
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      debugPrint('[AuthService] Logging in with backend: $email');

      final response = await http.post(
        Uri.parse(_config.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      debugPrint('[AuthService] Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);

        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;

        if (accessToken == null || refreshToken == null) {
          debugPrint('[AuthService] Login failed: missing tokens');
          return null;
        }

        await _storeTokens(accessToken, refreshToken);

        final user = _buildNeo4jUser(
          email: email,
          accessToken: accessToken,
          responseData: data,
          isNewUser: false,
        );

        // Populate current user by calling backend /me (no direct Neo4j writes)
        await _fetchMe(accessToken);

        debugPrint('[AuthService] Login successful');
        return accessToken;
      }

      _logBackendError('Login', response.body);
      return null;
    } catch (e) {
      debugPrint('[AuthService] Login exception: $e');
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);

    debugPrint('[AuthService] Logged out, tokens cleared');
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

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<bool> isTokenValid() async {
    final token = await readToken();
    return token != null && token.isNotEmpty;
  }

  Future<Neo4jUser?> getCurrentNeo4jUser() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return null;

    try {
      final responseUser = await _fetchMe(token);
      if (responseUser == null) return null;

      final responseData = {'user': responseUser};

      return _buildNeo4jUser(
        email: (responseUser['email'] ?? '') as String,
        accessToken: token,
        responseData: responseData,
        isNewUser: false,
      );
    } catch (e) {
      debugPrint('[AuthService] getCurrentNeo4jUser failed: $e');
      return null;
    }
  }

  Future<bool> isOnboardingCompleted() async {
    final user = await getCurrentNeo4jUser();
    return user?.onboardingCompleted ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final token = await readToken();
    if (token == null || token.isEmpty) return;

    try {
      final resp = await http.patch(
        Uri.parse(_config.meUrl + '/onboarding'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'completed': true}),
      );

      if (resp.statusCode != 200) {
        debugPrint(
          '[AuthService] markOnboardingCompleted failed: ${resp.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[AuthService] markOnboardingCompleted exception: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchMe(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(_config.meUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200) return null;

      final decoded = _decodeBody(response.body);
      final userMap = decoded['user'];
      if (userMap is Map<String, dynamic>) return userMap;
      return null;
    } catch (e) {
      debugPrint('[AuthService] _fetchMe failed: $e');
      return null;
    }
  }

  Neo4jUser _buildNeo4jUser({
    required String email,
    required String accessToken,
    required Map<String, dynamic> responseData,
    required bool isNewUser,
  }) {
    final responseUser = responseData['user'];

    final userMap = responseUser is Map<String, dynamic>
        ? responseUser
        : <String, dynamic>{};

    final claims = _decodeJwtPayload(accessToken);

    final uid = _firstNonEmpty([
      userMap['uid'],
      userMap['id'],
      userMap['userId'],
      claims['uid'],
      claims['id'],
      claims['userId'],
      claims['sub'],
    ]);

    final resolvedEmail = _firstNonEmpty([
      userMap['email'],
      claims['email'],
      email,
    ]);

    final displayName = _firstNonEmpty([
      userMap['displayName'],
      userMap['name'],
      claims['displayName'],
      claims['name'],
      _displayNameFromEmail(resolvedEmail),
    ]);

    final createdAt = _firstNonEmpty([
      userMap['createdAt'],
      DateTime.now().toIso8601String(),
    ]);

    final onboardingCompletedValue = userMap['onboardingCompleted'];

    return Neo4jUser(
      uid: uid,
      displayName: displayName,
      email: resolvedEmail,
      createdAt: createdAt,
      onboardingCompleted: isNewUser ? false : onboardingCompletedValue == true,
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};

      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadBytes = base64Url.decode(normalizedPayload);
      final payloadString = utf8.decode(payloadBytes);

      final decoded = jsonDecode(payloadString);
      if (decoded is Map<String, dynamic>) return decoded;

      return {};
    } catch (e) {
      debugPrint('[AuthService] JWT decode failed: $e');
      return {};
    }
  }

  String _extractUid(Map<String, dynamic> claims) {
    return _firstNonEmpty([
      claims['uid'],
      claims['id'],
      claims['userId'],
      claims['sub'],
    ]);
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return '';
  }

  String _displayNameFromEmail(String email) {
    if (!email.contains('@')) return email;
    return email.split('@').first;
  }

  void _logBackendError(String operation, String body) {
    try {
      final error = jsonDecode(body);

      if (error is Map<String, dynamic>) {
        debugPrint('[AuthService] $operation error: ${error['error']}');
      } else {
        debugPrint('[AuthService] $operation error: $error');
      }
    } catch (_) {
      debugPrint('[AuthService] $operation error body: $body');
    }
  }
}
