import 'package:agreeo/shared/models/agreeo_models.dart';

class DailySwipeUsage {
  const DailySwipeUsage({
    required this.usedToday,
    required this.remainingToday,
    required this.limit,
    required this.resetAt,
  });

  final int usedToday;
  final int? remainingToday;
  final int? limit;
  final DateTime? resetAt;
}

class DailySuggestionBatch {
  const DailySuggestionBatch({
    required this.movies,
    this.batchId,
    this.batchExpiresAt,
    this.swipeLimitEnabled = false,
    this.swipeLimit,
    this.usedToday = 0,
    this.remainingToday,
    this.resetAt,
  });

  final List<Movie> movies;
  final String? batchId;
  final DateTime? batchExpiresAt;
  final bool swipeLimitEnabled;
  final int? swipeLimit;
  final int usedToday;
  final int? remainingToday;
  final DateTime? resetAt;
}

class RecommendationActionContext {
  const RecommendationActionContext({
    required this.batchId,
    required this.position,
    this.source = 'daily-suggestion',
    this.expiresAt,
  });

  final String batchId;
  final int position;
  final String source;
  final DateTime? expiresAt;
}

abstract class MovieService {
  Future<List<Movie>> getCatalog();

  Future<List<Movie>> getRecommendedForYou();

  Future<DailySuggestionBatch> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
    int? limit,
  });

  Future<List<Movie>> searchMovies(String query, MovieSearchFilters filters);

  Future<Movie?> getMovieDetails(String movieId);

  Future<List<Movie>> getTrendingMovies();

  Future<List<Movie>> getMoviesByGenre(String genre);

  Future<List<Movie>> getShortMovies();

  Future<Map<String, dynamic>> getRecommendationDebugStats();

  Future<Movie> getRandomMovie();

  Future<List<Movie>> getMoviesByMood({
    required String feeling,
    required String wantToFeel,
  });
}
