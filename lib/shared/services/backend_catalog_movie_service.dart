import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/mock_movie_service.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:flutter/foundation.dart';

class BackendCatalogMovieService implements MovieService {
  BackendCatalogMovieService({
    BackendMovieService? backendMovieService,
    MockMovieService? fallback,
  }) : _backendMovieService = backendMovieService ?? BackendMovieService(),
       _fallback = fallback ?? MockMovieService();

  final BackendMovieService _backendMovieService;
  final MockMovieService _fallback;

  @override
  Future<List<Movie>> getCatalog() async {
    try {
      final movies = await _backendMovieService.getPopularMovies();
      if (movies.isNotEmpty) {
        return movies;
      }
    } catch (_) {}

    return _fallback.getCatalog();
  }

  @override
  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
  }) async {
    try {
      // Normal path: let the backend own personalized + cold-start fallback.
      final recommendations = await _backendMovieService.getRecommendations();
      return recommendations;
    } catch (error) {
      // Emergency path only: backend request failed completely.
      // Keep the fallback explicit so normal cold-start users still go through Neo4j.
      debugPrint(
        '[BackendCatalogMovieService] recommendation backend failed: $error',
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

    return _fallback.getDailySuggestions(
      favoriteGenres: favoriteGenres,
      favoriteMovieIds: favoriteMovieIds,
    );
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
      return _fallback.searchMovies(query, filters);
    }
  }

  @override
  Future<Movie?> getMovieDetails(String movieId) async {
    final tmdbId = _parseTmdbId(movieId);
    if (tmdbId == null) {
      return _fallback.getMovieDetails(movieId);
    }

    try {
      final details = await _backendMovieService.getMovieDetails(tmdbId);
      return details.movie;
    } catch (_) {
      return _fallback.getMovieDetails(movieId);
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

  int? _parseTmdbId(String movieId) {
    final rawId = movieId.startsWith('tmdb-') ? movieId.substring(5) : movieId;
    return int.tryParse(rawId);
  }
}
