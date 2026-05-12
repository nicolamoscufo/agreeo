import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/backend_catalog_movie_service.dart';
import 'package:agreeo/shared/services/mock_movie_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackendMovieService extends BackendMovieService {
  _FakeBackendMovieService({this.failRecommendations = false})
    : super(config: null);

  final bool failRecommendations;

  @override
  Future<List<Movie>> getRecommendations() async {
    if (failRecommendations) {
      throw StateError('backend recommendations failed');
    }
    return const <Movie>[];
  }

  @override
  Future<List<Movie>> getPopularMovies() async {
    return const <Movie>[];
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
  test('uses backend recommendations even when empty', () async {
    final service = BackendCatalogMovieService(
      backendMovieService: _FakeBackendMovieService(),
      fallback: _FakeMockMovieService(),
    );

    final suggestions = await service.getDailySuggestions(
      favoriteGenres: <String>['Drama'],
      favoriteMovieIds: <String>['tmdb-1'],
    );

    expect(suggestions, isEmpty);
  });

  test(
    'falls back to emergency catalog when backend recommendations fail',
    () async {
      final service = BackendCatalogMovieService(
        backendMovieService: _FakeBackendMovieService(
          failRecommendations: true,
        ),
        fallback: _FakeMockMovieService(),
      );

      final suggestions = await service.getDailySuggestions(
        favoriteGenres: <String>['Drama'],
        favoriteMovieIds: <String>['tmdb-1'],
      );

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.id, 'tmdb-emergency');
    },
  );
}

class _FakeMockMovieService extends MockMovieService {
  @override
  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
  }) async => <Movie>[_movie('tmdb-emergency')];
}
