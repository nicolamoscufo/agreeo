import 'dart:convert';

import 'package:agreeo/config/neo4j_config.dart';
import 'package:agreeo/models/neo4j/neo4j_models.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Neo4jService {
  Neo4jService({Neo4jConfig? config})
    : _config = config ?? Neo4jConfig.fromEnv();

  final Neo4jConfig _config;
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> initialize() async {
    debugPrint('[Neo4jService] Initializing... URI: ${_config.uri}');

    try {
      final result = await _executeCypher('RETURN 1 AS ok', logResult: false);

      _isReady =
          result['errors'] == null ||
          (result['errors'] is List && (result['errors'] as List).isEmpty);

      if (_isReady) {
        await createUserConstraints();
      }

      debugPrint('[Neo4jService] isReady: $_isReady');
    } catch (e) {
      _isReady = false;
      debugPrint('[Neo4jService] connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> _executeCypher(
    String cypher, {
    Map<String, dynamic>? parameters,
    bool logResult = true,
  }) async {
    final normalizedCypher = cypher.replaceAll(RegExp(r'\s+'), ' ').trim();

    debugPrint('[Neo4jService] Cypher: $normalizedCypher');
    debugPrint('[Neo4jService] parameters: $parameters');

    final body = jsonEncode({
      'statements': [
        {'statement': normalizedCypher, 'parameters': parameters ?? {}},
      ],
    });

    final response = await http.post(
      Uri.parse('${_config.uri}/db/${_config.database}/tx/commit'),
      headers: {
        ..._config.authHeader,
        'Accept': 'application/json;charset=UTF-8',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    debugPrint('[Neo4jService] response status: ${response.statusCode}');
    if (logResult) {
      debugPrint('[Neo4jService] response body: $responseBody');
    }

    final errors = responseBody['errors'];
    final hasErrors = errors is List && errors.isNotEmpty;

    if (response.statusCode != 200 || hasErrors) {
      final message = hasErrors
          ? errors.first['message']?.toString() ?? 'Unknown Neo4j error'
          : 'Neo4j query failed: ${response.statusCode}';

      throw Exception('Neo4j: $message');
    }

    return responseBody;
  }

  Map<String, dynamic>? _firstRow(Map<String, dynamic> response) {
    final results = response['results'];
    if (results is! List || results.isEmpty) return null;

    final firstResult = results.first;
    if (firstResult is! Map<String, dynamic>) return null;

    final data = firstResult['data'];
    if (data is! List || data.isEmpty) return null;

    final firstData = data.first;
    if (firstData is! Map<String, dynamic>) return null;

    final row = firstData['row'];
    if (row is! List || row.isEmpty) return null;

    final firstValue = row.first;
    if (firstValue is Map<String, dynamic>) {
      return firstValue;
    }

    return {'value': firstValue};
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response) {
    final results = response['results'];
    if (results is! List || results.isEmpty) return [];

    final firstResult = results.first;
    if (firstResult is! Map<String, dynamic>) return [];

    final data = firstResult['data'];
    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map((entry) {
          final row = entry['row'];
          if (row is List &&
              row.isNotEmpty &&
              row.first is Map<String, dynamic>) {
            return row.first as Map<String, dynamic>;
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Neo4jUser _userFromProperties(Map<String, dynamic> properties) {
    return Neo4jUser(
      uid: properties['uid']?.toString() ?? '',
      displayName: properties['displayName']?.toString() ?? '',
      email: properties['email']?.toString() ?? '',
      createdAt: properties['createdAt']?.toString() ?? '',
      passwordHash: properties['passwordHash']?.toString(),
      onboardingCompleted: properties['onboardingCompleted'] == true,
    );
  }

  // ---------------------------------------------------------------------------
  // SCHEMA / CONSTRAINTS
  // ---------------------------------------------------------------------------

  Future<void> createUserConstraints() async {
    await _executeCypher('''
      CREATE CONSTRAINT app_user_uid IF NOT EXISTS
      FOR (u:AppUser)
      REQUIRE u.uid IS UNIQUE
    ''');

    await _executeCypher('''
      CREATE CONSTRAINT app_user_email IF NOT EXISTS
      FOR (u:AppUser)
      REQUIRE u.emailNormalized IS UNIQUE
    ''');
  }

  // ---------------------------------------------------------------------------
  // CREATE / UPSERT
  // ---------------------------------------------------------------------------

  Future<Neo4jUser> createUser(Neo4jUser user) async {
    final props = user.toProperties();

    final response = await _executeCypher(
      '''
      CREATE (u:AppUser)
      SET u = \$props
      RETURN u {.*} AS user
    ''',
      parameters: {'props': props},
    );

    final row = _firstRow(response);
    if (row == null) {
      throw Exception('Neo4j: createUser did not return a user');
    }

    return _userFromProperties(row);
  }

  Future<Neo4jUser> upsertUser(Neo4jUser user) async {
    final props = user.toProperties();

    final response = await _executeCypher(
      '''
      MERGE (u:AppUser {uid: \$uid})
      ON CREATE SET
        u.createdAt = \$createdAt,
        u.onboardingCompleted = coalesce(\$onboardingCompleted, false)
      SET
        u += \$props,
        u.emailNormalized = toLower(trim(\$email))
      RETURN u {.*} AS user
    ''',
      parameters: {...props, 'props': props},
    );

    final row = _firstRow(response);
    if (row == null) {
      throw Exception('Neo4j: upsertUser did not return a user');
    }

    return _userFromProperties(row);
  }

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------

  Future<Neo4jUser?> getUserByUid(String uid) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {uid: \$uid})
      RETURN u {.*} AS user
      LIMIT 1
    ''',
      parameters: {'uid': uid},
    );

    final row = _firstRow(response);
    if (row == null) return null;

    return _userFromProperties(row);
  }

  Future<Neo4jUser?> getUserByEmail(String email) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {emailNormalized: toLower(trim(\$email))})
      RETURN u {.*} AS user
      LIMIT 1
    ''',
      parameters: {'email': email},
    );

    final row = _firstRow(response);
    if (row == null) return null;

    return _userFromProperties(row);
  }

  Future<bool> userExistsByUid(String uid) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {uid: \$uid})
      RETURN count(u) > 0 AS exists
    ''',
      parameters: {'uid': uid},
    );

    final row = _firstRow(response);
    return row?['value'] == true;
  }

  Future<bool> userExistsByEmail(String email) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {emailNormalized: toLower(trim(\$email))})
      RETURN count(u) > 0 AS exists
    ''',
      parameters: {'email': email},
    );

    final row = _firstRow(response);
    return row?['value'] == true;
  }

  Future<List<Neo4jUser>> getAllUsers({int limit = 50}) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser)
      RETURN u {.*} AS user
      ORDER BY u.createdAt DESC
      LIMIT \$limit
    ''',
      parameters: {'limit': limit},
    );

    return _rows(response).map(_userFromProperties).toList();
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<Neo4jUser> updateUserProfile({
    required String uid,
    String? displayName,
    String? email,
  }) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {uid: \$uid})

      FOREACH (_ IN CASE WHEN \$displayName IS NULL THEN [] ELSE [1] END |
        SET u.displayName = \$displayName
      )

      FOREACH (_ IN CASE WHEN \$email IS NULL THEN [] ELSE [1] END |
        SET u.email = \$email,
            u.emailNormalized = toLower(trim(\$email))
      )

      RETURN u {.*} AS user
    ''',
      parameters: {'uid': uid, 'displayName': displayName, 'email': email},
    );

    final row = _firstRow(response);
    if (row == null) {
      throw Exception('Neo4j: user not found');
    }

    return _userFromProperties(row);
  }

  Future<Neo4jUser> setOnboardingCompleted({
    required String uid,
    required bool completed,
  }) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {uid: \$uid})
      SET u.onboardingCompleted = \$completed
      RETURN u {.*} AS user
    ''',
      parameters: {'uid': uid, 'completed': completed},
    );

    final row = _firstRow(response);
    if (row == null) {
      throw Exception('Neo4j: user not found');
    }

    return _userFromProperties(row);
  }

  Future<Neo4jUser> updatePasswordHash({
    required String uid,
    required String passwordHash,
  }) async {
    final response = await _executeCypher(
      '''
      MATCH (u:AppUser {uid: \$uid})
      SET u.passwordHash = \$passwordHash
      RETURN u {.*} AS user
    ''',
      parameters: {'uid': uid, 'passwordHash': passwordHash},
    );

    final row = _firstRow(response);
    if (row == null) {
      throw Exception('Neo4j: user not found');
    }

    return _userFromProperties(row);
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------

  Future<void> deleteUserByUid(String uid) async {
    await _executeCypher(
      '''
      MATCH (u:AppUser {uid: \$uid})
      DETACH DELETE u
    ''',
      parameters: {'uid': uid},
    );
  }

  Future<void> deleteAllAppUsers() async {
    await _executeCypher('''
      MATCH (u:AppUser)
      DETACH DELETE u
    ''');
  }
}
