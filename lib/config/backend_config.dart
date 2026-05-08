class BackendConfig {
  const BackendConfig({required this.baseUrl});

  final String baseUrl;

  factory BackendConfig.fromEnv() {
    // Dev: local Node.js server
    return const BackendConfig(baseUrl: 'http://localhost:3000');
  }

  String get registerUrl => '$baseUrl/auth/register';
  String get loginUrl => '$baseUrl/auth/login';
  String get refreshUrl => '$baseUrl/auth/refresh';
  String get meUrl => '$baseUrl/me';
}
