import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/models/neo4j/neo4j_models.dart';
import 'package:agreeo/services/neo4j_service.dart';
import 'package:agreeo/utils/recommendation_engine.dart';
import 'package:agreeo/utils/sample_catalog.dart';
import 'package:agreeo/services/tmdb_service.dart';
import 'package:agreeo/config/backend_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BackendService {
  BackendService({
    Neo4jService? neo4jService,
    RecommendationEngine? recommendationEngine,
    TmdbService? tmdbService,
    BackendConfig? config,
  }) : _neo4jService = neo4jService ?? Neo4jService(),
       _recommendationEngine =
           recommendationEngine ?? const RecommendationEngine(),
       _tmdbService = tmdbService ?? TmdbService(),
       _config = config ?? BackendConfig.fromEnv();

  final Neo4jService _neo4jService;
  final RecommendationEngine _recommendationEngine;
  final TmdbService _tmdbService;
  final BackendConfig _config;

  bool get isNeo4jReady => _neo4jService.isReady;

  Future<void> initialize() async {
    await _neo4jService.initialize();
  }

  // In lib/services/backend_service.dart
  Future<void> saveUser(AppSession session) async {
    print(
      '[BackendService] saveUser called, isReady: ${_neo4jService.isReady}',
    );
    if (!_neo4jService.isReady) {
      print('[BackendService] Neo4j not ready, skipping saveUser');
      return;
    }
    final user = Neo4jUser.fromAppSession(session);
    print('[BackendService] Saving user: $user');
    await _neo4jService.upsertUser(user);
    print('[BackendService] User saved successfully');
  }

  Future<List<Movie>> generateDailyQueue({
    required AppSession session,
    required UserPreferences preferences,
    required Iterable<MovieFeedbackRecord> feedback,
  }) async {
    if (_neo4jService.isReady) {
      final savedQueue = await _neo4jService.getDailyQueue(session.uid);
      if (savedQueue.isNotEmpty) {
        return savedQueue;
      }
    }

    final remoteCatalog = await _tmdbService.discoverCatalog(
      mediaType: null,
      includeGenres: preferences.favoriteGenres,
      excludeGenres: const <String>[],
      streamingServices: preferences.streamingServices,
      limit: 20,
    );
    final catalog = remoteCatalog.isNotEmpty ? remoteCatalog : demoMovieCatalog;

    return _recommendationEngine.buildDailyQueue(
      catalog: catalog,
      preferences: preferences,
      feedback: feedback,
      limit: 7,
    );
  }

  Future<List<Movie>> generateShortlist({
    required AppSession session,
    required MovieEvent event,
    required List<MovieFeedbackRecord> feedback,
    required List<EventVote> votes,
    required MovieGroup group,
  }) async {
    final sharedServices = _sharedServices(
      group.memberServices.values.toList(),
    );
    final remoteCatalog = await _tmdbService.discoverCatalog(
      mediaType: event.constraints.format,
      includeGenres: event.constraints.includeGenres,
      excludeGenres: event.constraints.excludeGenres,
      streamingServices: sharedServices,
      limit: 20,
    );
    final catalog = remoteCatalog.isNotEmpty ? remoteCatalog : demoMovieCatalog;

    return _recommendationEngine.buildShortlist(
      catalog: catalog,
      feedback: feedback,
      votes: votes,
      memberIds: group.memberIds,
      memberServices: group.memberServices,
      constraints: event.constraints,
      limit: 6,
    );
  }

  List<String> _sharedServices(List<List<String>> servicesByMember) {
    if (servicesByMember.isEmpty) {
      return const <String>[];
    }

    final nonEmpty = servicesByMember
        .where((services) => services.isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) {
      return const <String>[];
    }

    final shared = nonEmpty.first.toSet();
    for (final services in nonEmpty.skip(1)) {
      shared.retainAll(services);
    }

    if (shared.isNotEmpty) {
      return shared.toList(growable: false);
    }

    return nonEmpty
        .expand((services) => services)
        .toSet()
        .toList(growable: false);
  }

  Future<void> persistPreferences(
    String uid,
    UserPreferences preferences,
  ) async {
    print('[BackendService] persistPreferences called for uid: $uid');
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('auth_accessToken');

      if (accessToken == null) {
        print(
          '[BackendService] No access token available, skipping preferences sync',
        );
        return;
      }

      final url = _config.preferencesUrl(uid);
      final body = jsonEncode({
        'favoriteGenres': preferences.favoriteGenres,
        'streamingServices': preferences.streamingServices,
        'dailyRecommendationsEnabled': preferences.dailyRecommendationsEnabled,
      });

      print('[BackendService] Sending preferences to $url');
      print('[BackendService] Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: body,
      );

      print('[BackendService] Response status: ${response.statusCode}');
      print('[BackendService] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[BackendService] Preferences saved successfully');
      } else {
        print(
          '[BackendService] Error saving preferences: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[BackendService] Exception in persistPreferences: $e');
    }
  }

  Future<void> persistFeedback(String uid, MovieFeedbackRecord feedback) async {
    if (!_neo4jService.isReady) {
      return;
    }

    await _neo4jService.recordFeedback(
      uid,
      feedback.movieId,
      feedback.action.name,
    );
  }

  Future<void> persistDailyQueue(String uid, List<Movie> queue) async {
    if (!_neo4jService.isReady) {
      return;
    }

    await _neo4jService.saveDailyQueue(uid, queue);
  }

  Future<void> persistGroup(MovieGroup group) async {
    if (!_neo4jService.isReady) {
      return;
    }

    final neo4jGroup = Neo4jGroup.fromGroup(group);
    await _neo4jService.upsertGroup(
      neo4jGroup,
      group.memberIds,
      group.memberServices,
    );
  }

  Future<void> persistEvent(MovieEvent event) async {
    if (!_neo4jService.isReady) {
      return;
    }

    final neo4jEvent = Neo4jEvent.fromEvent(event);
    await _neo4jService.upsertEvent(neo4jEvent);
  }

  Future<void> persistVote(EventVote vote) async {
    if (!_neo4jService.isReady) {
      return;
    }

    final neo4jVote = Neo4jVote.fromVote(vote);
    await _neo4jService.recordVote(neo4jVote);
  }
}
