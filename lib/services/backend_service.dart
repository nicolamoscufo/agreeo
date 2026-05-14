import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/utils/recommendation_engine.dart';
import 'package:agreeo/services/tmdb_service.dart';

class BackendService {
  BackendService({
    RecommendationEngine? recommendationEngine,
    TmdbService? tmdbService,
  }) : _recommendationEngine =
           recommendationEngine ?? const RecommendationEngine(),
       _tmdbService = tmdbService ?? TmdbService();

  final RecommendationEngine _recommendationEngine;
  final TmdbService _tmdbService;

  Future<void> initialize() async {
    // Neo4j persistence is handled by backend auth only.
  }

  Future<void> saveUser(AppSession session) async {
    // User creation is performed during backend /auth/register.
  }

  Future<List<Movie>> generateDailyQueue({
    required AppSession session,
    required UserPreferences preferences,
    required Iterable<MovieFeedbackRecord> feedback,
  }) async {
    final remoteCatalog = await _tmdbService.discoverCatalog(
      mediaType: null,
      includeGenres: preferences.favoriteGenres,
      excludeGenres: const <String>[],
      limit: 20,
    );
    return _recommendationEngine.buildDailyQueue(
      catalog: remoteCatalog,
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
    final remoteCatalog = await _tmdbService.discoverCatalog(
      mediaType: event.constraints.format,
      includeGenres: event.constraints.includeGenres,
      excludeGenres: event.constraints.excludeGenres,
      limit: 20,
    );
    return _recommendationEngine.buildShortlist(
      catalog: remoteCatalog,
      feedback: feedback,
      votes: votes,
      memberIds: group.memberIds,
      constraints: event.constraints,
      limit: 6,
    );
  }

  Future<void> persistPreferences(
    String uid,
    UserPreferences preferences,
  ) async {}

  Future<void> persistFeedback(
    String uid,
    MovieFeedbackRecord feedback,
  ) async {}

  Future<void> persistDailyQueue(String uid, List<Movie> queue) async {}

  Future<void> persistGroup(MovieGroup group) async {}

  Future<void> persistEvent(MovieEvent event) async {}

  Future<void> persistVote(EventVote vote) async {}
}
