import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

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
    const configuredUri = String.fromEnvironment('NEO4J_HTTP_URI');
    const configuredUsername = String.fromEnvironment('NEO4J_USERNAME');
    const configuredPassword = String.fromEnvironment('NEO4J_PASSWORD');
    const configuredDatabase = String.fromEnvironment('NEO4J_DATABASE');

    String host = 'localhost';
    if (!kIsWeb && Platform.isAndroid) {
      host = '10.0.2.2';
    }

    return Neo4jConfig(
      uri: configuredUri.isNotEmpty ? configuredUri : 'http://$host:7474',
      username: configuredUsername.isNotEmpty ? configuredUsername : 'neo4j',
      password: configuredPassword.isNotEmpty
          ? configuredPassword
          : 'password123',
      database: configuredDatabase.isNotEmpty ? configuredDatabase : 'neo4j',
    );
  }

  Map<String, String> get authHeader {
    final credentials = '$username:$password';
    final encoded = base64Encode(utf8.encode(credentials));
    return {'Authorization': 'Basic $encoded'};
  }
}
