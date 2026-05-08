import 'dart:convert';
import 'package:agreeo/models/neo4j/neo4j_models.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:agreeo/config/neo4j_config.dart';

class Neo4jService {
  Neo4jService({Neo4jConfig? config})
    : _config = config ?? Neo4jConfig.fromEnv();

  final Neo4jConfig _config;
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> initialize() async {
    debugPrint('[Neo4jService] Initializing... URI: ${_config.uri}');
    try {
      final response = await http.get(
        Uri.parse('${_config.uri}/db/${_config.database}'),
        headers: _config.authHeader,
      );
      _isReady = response.statusCode == 200;
      debugPrint(
        '[Neo4jService] initialize response: ${response.statusCode}, isReady: $_isReady',
      );
      if (!_isReady) {
        debugPrint('Neo4j not ready: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      _isReady = false;
      debugPrint('Neo4j connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> _executeCypher(
    String cypher, {
    Map<String, dynamic>? parameters,
  }) async {
    debugPrint('[Neo4jService] _executeCypher: $cypher');
    debugPrint('[Neo4jService] parameters: $parameters');
    final body = jsonEncode({'query': cypher, 'parameters': parameters ?? {}});

    final response = await http.post(
      Uri.parse('${_config.uri}/db/${_config.database}/tx/commit'),
      headers: {..._config.authHeader, 'Content-Type': 'application/json'},
      body: body,
    );

    debugPrint('[Neo4jService] response status: ${response.statusCode}');
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    debugPrint('[Neo4jService] response body: $responseBody');

    if (response.statusCode != 200 || responseBody.containsKey('errors')) {
      final errors = responseBody['errors'] as List?;
      final message = errors?.isNotEmpty == true
          ? errors!.first['message']?.toString() ?? 'Unknown error'
          : 'Neo4j query failed: ${response.statusCode}';
      throw Exception('Neo4j: $message');
    }

    return responseBody;
  }

  Future<void> upsertUser(Neo4jUser user) async {
    debugPrint('[Neo4jService] upsertUser called with: $user');
    try {
      final result = await _executeCypher('''
        MERGE (u:User {uid: \$uid})
        SET u.displayName = \$displayName,
            u.email = \$email,
            u.isGuest = \$isGuest,
            u.createdAt = \$createdAt
        ''', parameters: user.toProperties());
      debugPrint('[Neo4jService] upsertUser result: $result');
    } catch (e) {
      debugPrint('[Neo4jService] upsertUser error: $e');
      rethrow;
    }
  }
}
