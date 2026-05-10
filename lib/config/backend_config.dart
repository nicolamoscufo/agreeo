import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class BackendConfig {
  const BackendConfig({required this.baseUrl});

  final String baseUrl;

  factory BackendConfig.fromEnv() {
    const configuredBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return const BackendConfig(baseUrl: configuredBaseUrl);
    }

    // Dev: local Node.js server (use 10.0.2.2 for Android Emulator, otherwise localhost)
    String host = 'localhost';
    if (!kIsWeb && Platform.isAndroid) {
      host = '10.0.2.2';
    }
    return BackendConfig(baseUrl: 'http://$host:3000');
  }

  String get registerUrl => '$baseUrl/auth/register';
  String get loginUrl => '$baseUrl/auth/login';
  String get refreshUrl => '$baseUrl/auth/refresh';
  String get meUrl => '$baseUrl/me';
}
