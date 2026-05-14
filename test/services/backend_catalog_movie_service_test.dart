import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/backend_catalog_movie_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendMovieService extends BackendMovieService {
  _FakeBackendMovieService({
    this.failRecommendations = false,
    this.popularMovies = const <Movie>[],
  }) : super(config: null);

  final bool failRecommendations;
  final List<Movie> popularMovies;

  @override
  Future<List<Movie>> getRecommendations() async {
    if (failRecommendations) {
      throw StateError('backend recommendations failed');
    }
    return const <Movie>[];
  }

  @override
  Future<List<Movie>> getPopularMovies() async {
    return popularMovies;
  }
}

Movie _movie(String id) {
  return Movie(
    id: id,
    tmdbId: int.tryParse(id.replaceAll(RegExp(r'\D'), '')),
    title: id,
    originalTitle: id,
    overview: 'Overview for $id',
    posterUrl: 'https://example.com/$id.jpg',
    backdropUrl: 'https://example.com/$id-bg.jpg',
    releaseYear: 2026,
    runtime: 120,
    genres: <String>['Drama'],
    director: 'Director',
    cast: <String>['Actor'],
    rating: 8.0,
    mediaType: CatalogMediaType.movie,
    trailerUrl: 'https://example.com/$id-trailer',
  );
}

void main() {
  test(
    'falls back to popular movies when backend recommendations are empty',
    () async {
      final service = BackendCatalogMovieService(
        backendMovieService: _FakeBackendMovieService(
          popularMovies: <Movie>[_movie('tmdb-popular')],
        ),
      );

      final suggestions = await service.getDailySuggestions(
        favoriteGenres: <String>['Drama'],
        favoriteMovieIds: <String>['tmdb-1'],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.id, 'tmdb-popular');
    },
  );

  test(
    'returns empty when backend recommendations and popular fallback are empty',
    () async {
      final service = BackendCatalogMovieService(
        backendMovieService: _FakeBackendMovieService(),
      );

      final suggestions = await service.getDailySuggestions(
        favoriteGenres: <String>['Drama'],
        favoriteMovieIds: <String>['tmdb-1'],
      );

      expect(suggestions, isEmpty);
    },
  );

  test('returns popular movies when backend recommendations fail', () async {
    final service = BackendCatalogMovieService(
      backendMovieService: _FakeBackendMovieService(
        failRecommendations: true,
        popularMovies: <Movie>[_movie('tmdb-emergency')],
      ),
    );

    final suggestions = await service.getDailySuggestions(
      favoriteGenres: <String>['Drama'],
      favoriteMovieIds: <String>['tmdb-1'],
    );

    expect(suggestions, hasLength(1));
    expect(suggestions.single.id, 'tmdb-emergency');
  });
}
