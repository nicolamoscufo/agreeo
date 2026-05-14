import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:flutter/foundation.dart';

class BackendCatalogMovieService implements MovieService {
  BackendCatalogMovieService({BackendMovieService? backendMovieService})
    : _backendMovieService = backendMovieService ?? BackendMovieService();

  final BackendMovieService _backendMovieService;

  @override
  Future<List<Movie>> getCatalog() async {
    try {
      final movies = await _backendMovieService.getPopularMovies();
      if (movies.isNotEmpty) {
        return movies;
      }
    } catch (_) {}

    return const <Movie>[];
  }

  @override
  Future<List<Movie>> getRecommendedForYou() async {
    try {
      final recommendations = await _backendMovieService.getRecommendedForYou();
      if (recommendations.isNotEmpty) {
        return recommendations;
      }
    } catch (error) {
      debugPrint('[BackendCatalogMovieService] for-you backend failed: $error');
    }

    return const <Movie>[];
  }

  @override
  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
    int? limit,
  }) async {
    try {
      final suggestions = await _backendMovieService.getDailySuggestions(
        limit: limit,
      );
      if (suggestions.isNotEmpty) {
        return suggestions;
      }
    } catch (error) {
      debugPrint(
        '[BackendCatalogMovieService] daily-suggestions backend failed: $error',
      );
    }

    try {
      final popular = await _backendMovieService.getPopularMovies();
      if (popular.isNotEmpty) {
        return popular;
      }
    } catch (error) {
      debugPrint(
        '[BackendCatalogMovieService] popular backend fallback failed: $error',
      );
    }

    return const <Movie>[];
  }

  @override
  Future<List<Movie>> searchMovies(
    String query,
    MovieSearchFilters filters,
  ) async {
    if (query.trim().isEmpty) {
      final catalog = await getCatalog();
      return catalog.where(filters.matches).toList(growable: false);
    }

    try {
      final results = await _backendMovieService.searchMovies(query);
      return results.where(filters.matches).toList(growable: false);
    } catch (_) {
      return const <Movie>[];
    }
  }

  @override
  Future<Movie?> getMovieDetails(String movieId) async {
    final tmdbId = _parseTmdbId(movieId);
    if (tmdbId == null) {
      return null;
    }

    try {
      final details = await _backendMovieService.getMovieDetails(tmdbId);
      return details.movie;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Movie>> getTrendingMovies() async {
    return getCatalog();
  }

  @override
  Future<List<Movie>> getMoviesByGenre(String genre) async {
    final catalog = await getCatalog();
    return catalog
        .where((movie) => movie.genres.contains(genre))
        .toList(growable: false);
  }

  @override
  Future<List<Movie>> getMockShortMovies() async {
    final catalog = await getCatalog();
    return catalog
        .where((movie) => movie.runtime <= 110)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> getRecommendationDebugStats() {
    return _backendMovieService.getRecommendationDebugStats();
  }

  int? _parseTmdbId(String movieId) {
    final rawId = movieId.startsWith('tmdb-') ? movieId.substring(5) : movieId;
    return int.tryParse(rawId);
  }
}
