import 'dart:convert';
import 'package:agreeo/models/neo4j/neo4j_models.dart';
import 'package:http/http.dart' as http;
import 'package:agreeo/config/neo4j_config.dart';
import 'package:agreeo/models/app_models.dart';

class Neo4jService {
  Neo4jService({Neo4jConfig? config})
    : _config = config ?? Neo4jConfig.fromEnv();

  final Neo4jConfig _config;
  bool _isReady = false;

  bool get isReady => _isReady;

  Future<void> initialize() async {
    print('[Neo4jService] Initializing... URI: ${_config.uri}');
    try {
      final response = await http.get(
        Uri.parse('${_config.uri}/db/${_config.database}'),
        headers: _config.authHeader,
      );
      _isReady = response.statusCode == 200;
      print('[Neo4jService] initialize response: ${response.statusCode}, isReady: $_isReady');
      if (!_isReady) {
        print('Neo4j not ready: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      _isReady = false;
      print('Neo4j connection failed: $e');
    }
  }

  Future<Map<String, dynamic>> _executeCypher(
    String cypher, {
    Map<String, dynamic>? parameters,
  }) async {
    print('[Neo4jService] _executeCypher: $cypher');
    print('[Neo4jService] parameters: $parameters');
    final body = jsonEncode({'query': cypher, 'parameters': parameters ?? {}});

    final response = await http.post(
      Uri.parse('${_config.uri}/db/${_config.database}/tx/commit'),
      headers: {..._config.authHeader, 'Content-Type': 'application/json'},
      body: body,
    );

    print('[Neo4jService] response status: ${response.statusCode}');
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    print('[Neo4jService] response body: $responseBody');

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
    print('[Neo4jService] upsertUser called with: $user');
    try {
      final result = await _executeCypher('''
        MERGE (u:User {uid: \$uid})
        SET u.displayName = \$displayName,
            u.email = \$email,
            u.isGuest = \$isGuest,
            u.createdAt = \$createdAt
        ''', parameters: user.toProperties());
      print('[Neo4jService] upsertUser result: $result');
    } catch (e) {
      print('[Neo4jService] upsertUser error: $e');
      rethrow;
    }
  }

  Future<Neo4jUser?> getUserByEmail(String email) async {
    final result = await _executeCypher('''
      MATCH (u:User {email: \$email})
      RETURN u.uid as uid,
             u.displayName as displayName,
             u.email as email,
             u.isGuest as isGuest,
             u.createdAt as createdAt
      ''', parameters: {'email': email});

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return null;

    final record = data.first as List?;
    if (record == null || record.isEmpty) return null;

    final values = record.first as Map<String, dynamic>?;
    if (values == null) return null;

    return Neo4jUser(
      uid: values['uid']?.toString() ?? '',
      displayName: values['displayName']?.toString() ?? '',
      email: values['email']?.toString() ?? '',
      isGuest: values['isGuest'] == true,
      createdAt: values['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Future<Neo4jUser?> getUserByUid(String uid) async {
    final result = await _executeCypher('''
      MATCH (u:User {uid: \$uid})
      RETURN u.uid as uid,
             u.displayName as displayName,
             u.email as email,
             u.isGuest as isGuest,
             u.createdAt as createdAt
      ''', parameters: {'uid': uid});

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return null;

    final record = data.first as List?;
    if (record == null || record.isEmpty) return null;

    final values = record.first as Map<String, dynamic>?;
    if (values == null) return null;

    return Neo4jUser(
      uid: values['uid']?.toString() ?? '',
      displayName: values['displayName']?.toString() ?? '',
      email: values['email']?.toString() ?? '',
      isGuest: values['isGuest'] == true,
      createdAt: values['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Future<void> upsertUserPreferences(
    String uid,
    Neo4jUserPreferences prefs,
  ) async {
    await _executeCypher('''
      MERGE (u:User {uid: \$uid})
      SET u.favoriteGenres = \$favoriteGenres,
          u.streamingServices = \$streamingServices,
          u.dailyRecommendationsEnabled = \$dailyRecommendationsEnabled,
          u.onboardingComplete = \$onboardingComplete,
          u.darkModeEnabled = \$darkModeEnabled
      ''', parameters: prefs.toProperties());
  }

  Future<UserPreferences?> getUserPreferences(String uid) async {
    final result = await _executeCypher(
      '''
      MATCH (u:User {uid: \$uid})
      RETURN u.favoriteGenres as favoriteGenres,
             u.streamingServices as streamingServices,
             u.dailyRecommendationsEnabled as dailyRecommendationsEnabled,
             u.onboardingComplete as onboardingComplete,
             u.darkModeEnabled as darkModeEnabled
      ''',
      parameters: {'uid': uid},
    );

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return null;

    final record = data.first as List?;
    if (record == null || record.isEmpty) return null;

    final values = record.first as Map<String, dynamic>?;
    if (values == null) return null;

    return UserPreferences(
      favoriteGenres: _decodeList(values['favoriteGenres']),
      streamingServices: _decodeList(values['streamingServices']),
      dailyRecommendationsEnabled:
          values['dailyRecommendationsEnabled'] != false,
      onboardingComplete: values['onboardingComplete'] == true,
      darkModeEnabled: values['darkModeEnabled'] == true,
    );
  }

  Future<void> recordFeedback(
    String userId,
    String movieId,
    String action,
  ) async {
    final timestamp = DateTime.now().toIso8601String();

    await _executeCypher(
      '''
      MATCH (u:User {uid: \$userId})
      MERGE (m:Movie {tmdbId: \$movieId})
      MERGE (u)-[r:FEEDBACK]->(m)
      SET r.action = \$action,
          r.createdAt = \$createdAt
      ''',
      parameters: {
        'userId': userId,
        'movieId': movieId,
        'action': action,
        'createdAt': timestamp,
      },
    );
  }

  Future<List<MovieFeedbackRecord>> getFeedback(String userId) async {
    final result = await _executeCypher(
      '''
      MATCH (u:User {uid: \$userId})-[r:FEEDBACK]->(m:Movie)
      RETURN m.tmdbId as movieId,
             r.action as action,
             r.createdAt as createdAt
      ''',
      parameters: {'userId': userId},
    );

    final data = result['data'] as List? ?? [];
    return data.map((record) {
      final values = (record as List).first as Map<String, dynamic>;
      return MovieFeedbackRecord(
        userId: userId,
        movieId: values['movieId']?.toString() ?? '',
        action: FeedbackActionX.fromJson(values['action']),
        createdAt:
            DateTime.tryParse(values['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<void> saveDailyQueue(String uid, List<Movie> queue) async {
    await _executeCypher(
      '''
      MATCH (u:User {uid: \$uid})
      SET u.dailyQueue = \$queue
      ''',
      parameters: {'uid': uid, 'queue': queue.map((m) => m.toJson()).toList()},
    );
  }

  Future<List<Movie>> getDailyQueue(String uid) async {
    final result = await _executeCypher(
      '''
      MATCH (u:User {uid: \$uid})
      RETURN u.dailyQueue as queue
      ''',
      parameters: {'uid': uid},
    );

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return [];

    final record = data.first as List?;
    if (record == null) return [];

    final queue = record.first as List?;
    if (queue == null) return [];

    return queue
        .map((item) => Movie.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertGroup(
    Neo4jGroup group,
    List<String> memberIds,
    Map<String, List<String>> memberServices,
  ) async {
    await _executeCypher('''
      MERGE (g:Group {groupId: \$groupId})
      SET g.name = \$name,
          g.inviteCode = \$inviteCode,
          g.ownerId = \$ownerId,
          g.createdAt = \$createdAt
      ''', parameters: group.toProperties());

    for (final memberId in memberIds) {
      await _executeCypher(
        '''
        MATCH (u:User {uid: \$memberId})
        MATCH (g:Group {groupId: \$groupId})
        MERGE (u)-[:MEMBER_OF]->(g)
        ''',
        parameters: {'memberId': memberId, 'groupId': group.groupId},
      );
    }
  }

  Future<MovieGroup?> getGroup(String groupId) async {
    final result = await _executeCypher(
      '''
      MATCH (g:Group {groupId: \$groupId})
      OPTIONAL MATCH (u:User)-[:MEMBER_OF]->(g)
      RETURN g.name as name,
             g.inviteCode as inviteCode,
             g.ownerId as ownerId,
             g.createdAt as createdAt,
             collect(u.uid) as memberIds
      ''',
      parameters: {'groupId': groupId},
    );

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return null;

    final record = data.first as List?;
    if (record == null) return null;

    final values = record.first as Map<String, dynamic>;
    if (values == null) return null;

    return MovieGroup(
      id: groupId,
      name: values['name']?.toString() ?? '',
      inviteCode: values['inviteCode']?.toString() ?? '',
      ownerId: values['ownerId']?.toString() ?? '',
      memberIds: _decodeList(values['memberIds']),
      memberServices: {},
      sharedWatchlist: [],
      createdAt:
          DateTime.tryParse(values['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> upsertEvent(Neo4jEvent event) async {
    await _executeCypher('''
      MERGE (e:Event {eventId: \$eventId})
      SET e.groupId = \$groupId,
          e.groupName = \$groupName,
          e.creatorId = \$creatorId,
          e.format = \$format,
          e.includeGenres = \$includeGenres,
          e.excludeGenres = \$excludeGenres,
          e.maxDurationMinutes = \$maxDurationMinutes,
          e.createdAt = \$createdAt,
          e.resolvedMovieId = \$resolvedMovieId
      ''', parameters: event.toProperties());
  }

  Future<MovieEvent?> getEvent(String eventId) async {
    final result = await _executeCypher(
      '''
      MATCH (e:Event {eventId: \$eventId})
      RETURN e.groupId as groupId,
             e.groupName as groupName,
             e.creatorId as creatorId,
             e.format as format,
             e.includeGenres as includeGenres,
             e.excludeGenres as excludeGenres,
             e.maxDurationMinutes as maxDurationMinutes,
             e.createdAt as createdAt,
             e.resolvedMovieId as resolvedMovieId
      ''',
      parameters: {'eventId': eventId},
    );

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return null;

    final record = data.first as List?;
    if (record == null) return null;

    final values = record.first as Map<String, dynamic>;
    return MovieEvent(
      id: eventId,
      groupId: values['groupId']?.toString() ?? '',
      groupName: values['groupName']?.toString() ?? '',
      creatorId: values['creatorId']?.toString() ?? '',
      constraints: EventConstraints(
        groupId: values['groupId']?.toString() ?? '',
        format: MediaTypeX.fromJson(values['format']),
        includeGenres: _decodeList(values['includeGenres']),
        excludeGenres: _decodeList(values['excludeGenres']),
        maxDurationMinutes:
            (values['maxDurationMinutes'] as num?)?.toInt() ?? 150,
      ),
      shortlist: [],
      createdAt:
          DateTime.tryParse(values['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      resolvedMovieId: values['resolvedMovieId']?.toString(),
    );
  }

  Future<void> recordVote(Neo4jVote vote) async {
    await _executeCypher('''
      MATCH (e:Event {eventId: \$eventId})
      MATCH (u:User {uid: \$userId})
      MERGE (u)-[r:VOTED]->(e)
      SET r.movieId = \$movieId,
          r.choice = \$choice,
          r.createdAt = \$createdAt
      ''', parameters: vote.toProperties());
  }

  Future<List<EventVote>> getVotes(String eventId) async {
    final result = await _executeCypher(
      '''
      MATCH (u:User)-[r:VOTED]->(e:Event {eventId: \$eventId})
      RETURN r.movieId as movieId,
             r.choice as choice,
             r.createdAt as createdAt
      ''',
      parameters: {'eventId': eventId},
    );

    final data = result['data'] as List? ?? [];
    return data.map((record) {
      final values = (record as List).first as Map<String, dynamic>;
      return EventVote(
        id: '',
        eventId: eventId,
        movieId: values['movieId']?.toString() ?? '',
        userId: '',
        choice: VoteChoiceX.fromJson(values['choice']),
        createdAt:
            DateTime.tryParse(values['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<List<String>> getSharedServices(String groupId) async {
    final result = await _executeCypher(
      '''
      MATCH (u:User)-[:MEMBER_OF]->(g:Group {groupId: \$groupId})
      RETURN u.streamingServices as services
      ''',
      parameters: {'groupId': groupId},
    );

    final data = result['data'] as List? ?? [];
    final allServices = <String>{};
    for (final record in data) {
      final services = (record as List).first;
      allServices.addAll(_decodeList(services));
    }
    return allServices.toList();
  }

  Future<List<Movie>> getSharedWatchlist(String groupId) async {
    final result = await _executeCypher(
      '''
      MATCH (g:Group {groupId: \$groupId})
      RETURN g.sharedWatchlist as watchlist
      ''',
      parameters: {'groupId': groupId},
    );

    final data = result['data'] as List?;
    if (data == null || data.isEmpty) return [];

    final record = data.first as List?;
    if (record == null) return [];

    final watchlist = record.first as List?;
    if (watchlist == null) return [];

    return watchlist
        .map((item) => Movie.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addToSharedWatchlist(String groupId, Movie movie) async {
    await _executeCypher(
      '''
      MATCH (g:Group {groupId: \$groupId})
      WITH g, COALESCE(g.sharedWatchlist, []) + [\$movie] as newWatchlist
      SET g.sharedWatchlist = newWatchlist
      ''',
      parameters: {'groupId': groupId, 'movie': movie.toJson()},
    );
  }
}

List<String> _decodeList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return [];
}
