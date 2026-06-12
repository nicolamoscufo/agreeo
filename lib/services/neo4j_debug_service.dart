import 'dart:convert';

import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:http/http.dart' as http;

class Neo4jServerInfo {
  const Neo4jServerInfo({
    required this.name,
    required this.version,
    required this.edition,
    required this.uri,
  });

  final String name;
  final String version;
  final String edition;
  final String uri;
}

class Neo4jLabelCount {
  const Neo4jLabelCount({required this.label, required this.count});

  final String label;
  final int count;
}

class Neo4jRelTypeCount {
  const Neo4jRelTypeCount({required this.type, required this.count});

  final String type;
  final int count;
}

class Neo4jOverview {
  const Neo4jOverview({
    required this.server,
    required this.nodeCount,
    required this.relationshipCount,
    required this.propertyKeyCount,
    required this.labels,
    required this.relationshipTypes,
  });

  final Neo4jServerInfo server;
  final int nodeCount;
  final int relationshipCount;
  final int propertyKeyCount;
  final List<Neo4jLabelCount> labels;
  final List<Neo4jRelTypeCount> relationshipTypes;
}

class Neo4jSchemaPattern {
  const Neo4jSchemaPattern({
    required this.from,
    required this.relType,
    required this.to,
    required this.count,
  });

  final List<String> from;
  final String relType;
  final List<String> to;
  final int count;
}

class Neo4jIndexInfo {
  const Neo4jIndexInfo({
    required this.name,
    required this.type,
    required this.entityType,
    required this.labelsOrTypes,
    required this.properties,
    required this.state,
    required this.populationPercent,
    required this.provider,
    required this.options,
  });

  final String name;
  final String type;
  final String entityType;
  final List<String> labelsOrTypes;
  final List<String> properties;
  final String state;
  final double populationPercent;
  final String provider;
  final Map<String, dynamic> options;
}

class Neo4jConstraintInfo {
  const Neo4jConstraintInfo({
    required this.name,
    required this.type,
    required this.entityType,
    required this.labelsOrTypes,
    required this.properties,
  });

  final String name;
  final String type;
  final String entityType;
  final List<String> labelsOrTypes;
  final List<String> properties;
}

class Neo4jIndexReport {
  const Neo4jIndexReport({required this.indexes, required this.constraints});

  final List<Neo4jIndexInfo> indexes;
  final List<Neo4jConstraintInfo> constraints;
}

class Neo4jQueryPlan {
  const Neo4jQueryPlan({
    required this.operatorType,
    required this.identifiers,
    required this.details,
    required this.estimatedRows,
    required this.rows,
    required this.dbHits,
    required this.children,
  });

  final String operatorType;
  final List<String> identifiers;
  final String? details;
  final num? estimatedRows;
  final num? rows;
  final num? dbHits;
  final List<Neo4jQueryPlan> children;
}

class Neo4jQueryResult {
  const Neo4jQueryResult({
    required this.columns,
    required this.rows,
    required this.truncated,
    required this.totalRows,
    required this.wallTimeMs,
    required this.resultAvailableAfterMs,
    required this.resultConsumedAfterMs,
    required this.queryType,
    required this.plan,
  });

  final List<String> columns;
  final List<List<dynamic>> rows;
  final bool truncated;
  final int totalRows;
  final int wallTimeMs;
  final int? resultAvailableAfterMs;
  final int? resultConsumedAfterMs;
  final String? queryType;
  final Neo4jQueryPlan? plan;
}

/// Raised when the backend rejects a Cypher query (syntax error, write attempt
/// in the read-only console, ...). Carries the driver message verbatim so the
/// console can show it like the Neo4j browser does.
class Neo4jQueryException implements Exception {
  const Neo4jQueryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Client for the read-only `/debug/neo4j/*` backend console endpoints.
class Neo4jDebugService {
  Neo4jDebugService({
    BackendConfig? config,
    AuthService? authService,
    http.Client? client,
  }) : _config = config ?? BackendConfig.fromEnv(),
       _authService = authService ?? AuthService(config: config),
       _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 30);

  final BackendConfig _config;
  final AuthService _authService;
  final http.Client _client;

  Future<Neo4jOverview> getOverview() async {
    final body = await _getJson('/debug/neo4j/overview');
    final server = body['server'] as Map<String, dynamic>? ?? const {};
    final totals = body['totals'] as Map<String, dynamic>? ?? const {};
    return Neo4jOverview(
      server: Neo4jServerInfo(
        name: server['name']?.toString() ?? 'Neo4j',
        version: server['version']?.toString() ?? '?',
        edition: server['edition']?.toString() ?? '?',
        uri: server['uri']?.toString() ?? '?',
      ),
      nodeCount: _asInt(totals['nodes']),
      relationshipCount: _asInt(totals['relationships']),
      propertyKeyCount: _asInt(totals['propertyKeys']),
      labels: [
        for (final entry in body['labels'] as List? ?? const [])
          Neo4jLabelCount(
            label: entry['label']?.toString() ?? '?',
            count: _asInt(entry['count']),
          ),
      ],
      relationshipTypes: [
        for (final entry in body['relationshipTypes'] as List? ?? const [])
          Neo4jRelTypeCount(
            type: entry['type']?.toString() ?? '?',
            count: _asInt(entry['count']),
          ),
      ],
    );
  }

  Future<List<Neo4jSchemaPattern>> getSchema() async {
    final body = await _getJson('/debug/neo4j/schema');
    return [
      for (final entry in body['patterns'] as List? ?? const [])
        Neo4jSchemaPattern(
          from: _asStringList(entry['from']),
          relType: entry['relType']?.toString() ?? '?',
          to: _asStringList(entry['to']),
          count: _asInt(entry['count']),
        ),
    ];
  }

  Future<Neo4jIndexReport> getIndexes() async {
    final body = await _getJson('/debug/neo4j/indexes');
    return Neo4jIndexReport(
      indexes: [
        for (final entry in body['indexes'] as List? ?? const [])
          Neo4jIndexInfo(
            name: entry['name']?.toString() ?? '?',
            type: entry['type']?.toString() ?? '?',
            entityType: entry['entityType']?.toString() ?? '?',
            labelsOrTypes: _asStringList(entry['labelsOrTypes']),
            properties: _asStringList(entry['properties']),
            state: entry['state']?.toString() ?? '?',
            populationPercent: (entry['populationPercent'] as num?)?.toDouble() ?? 0,
            provider: entry['provider']?.toString() ?? '?',
            options: entry['options'] as Map<String, dynamic>? ?? const {},
          ),
      ],
      constraints: [
        for (final entry in body['constraints'] as List? ?? const [])
          Neo4jConstraintInfo(
            name: entry['name']?.toString() ?? '?',
            type: entry['type']?.toString() ?? '?',
            entityType: entry['entityType']?.toString() ?? '?',
            labelsOrTypes: _asStringList(entry['labelsOrTypes']),
            properties: _asStringList(entry['properties']),
          ),
      ],
    );
  }

  /// Runs a read-only Cypher query. [mode] is `null`, `explain` or `profile`.
  Future<Neo4jQueryResult> runQuery(String query, {String? mode}) async {
    final body = await _postJson('/debug/neo4j/query', {
      'query': query,
      'mode': ?mode,
    });
    final summary = body['summary'] as Map<String, dynamic>? ?? const {};
    return Neo4jQueryResult(
      columns: _asStringList(body['columns']),
      rows: [
        for (final row in body['rows'] as List? ?? const []) row as List<dynamic>,
      ],
      truncated: body['truncated'] == true,
      totalRows: _asInt(body['totalRows']),
      wallTimeMs: _asInt(body['wallTimeMs']),
      resultAvailableAfterMs: (summary['resultAvailableAfterMs'] as num?)?.toInt(),
      resultConsumedAfterMs: (summary['resultConsumedAfterMs'] as num?)?.toInt(),
      queryType: summary['queryType']?.toString(),
      plan: _decodePlan(summary['plan']),
    );
  }

  Neo4jQueryPlan? _decodePlan(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return Neo4jQueryPlan(
      operatorType: raw['operatorType']?.toString() ?? '?',
      identifiers: _asStringList(raw['identifiers']),
      details: raw['details']?.toString(),
      estimatedRows: raw['estimatedRows'] as num?,
      rows: raw['rows'] as num?,
      dbHits: raw['dbHits'] as num?,
      children: [
        for (final child in raw['children'] as List? ?? const []) ?_decodePlan(child),
      ],
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _authorizedRequest('GET', path);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final response = await _authorizedRequest('POST', path, body: body);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.readToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token for Neo4j debug request.');
    }

    var response = await _send(method, path, token, body: body);

    // Transparently recover from an expired access token: refresh once and retry.
    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshAccessToken();
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await _send(method, path, refreshed, body: body);
      }
    }

    if (response.statusCode == 422 || response.statusCode == 400) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Neo4jQueryException(
        decoded['error']?.toString() ?? 'Query failed',
        code: decoded['code']?.toString(),
      );
    }
    if (response.statusCode == 404) {
      throw const Neo4jQueryException(
        'Console disabilitata: imposta ENABLE_NEO4J_DEBUG=true sul backend.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Neo4j debug request failed: ${response.statusCode} ${response.body}',
      );
    }

    return response;
  }

  Future<http.Response> _send(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) {
    final uri = Uri.parse('${_config.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (method) {
      case 'POST':
        return _client
            .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
            .timeout(_requestTimeout);
      case 'GET':
        return _client.get(uri, headers: headers).timeout(_requestTimeout);
      default:
        throw UnsupportedError('Unsupported method $method');
    }
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const [];
    return [for (final entry in value) entry.toString()];
  }
}
