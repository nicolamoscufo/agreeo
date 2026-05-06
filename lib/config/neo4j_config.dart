import 'dart:convert';

class Neo4jConfig {
  const Neo4jConfig({
    required this.uri,
    required this.username,
    required this.password,
    this.database = 'neo4j',
  });

  final String uri;
  final String username;
  final String password;
  final String database;

  factory Neo4jConfig.fromEnv() {
    return const Neo4jConfig(
      uri: 'http://localhost:7475',
      username: 'neo4j',
      password: 'password',
    );
  }

  Map<String, String> get authHeader {
    final credentials = '$username:$password';
    final encoded = base64Encode(utf8.encode(credentials));
    return {'Authorization': 'Basic $encoded'};
  }
}
