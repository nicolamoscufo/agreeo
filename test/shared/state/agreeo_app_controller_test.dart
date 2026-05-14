import 'dart:convert';

import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/mock_auth_service.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:agreeo/shared/services/user_movie_state_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMovieService implements MovieService {
  _FakeMovieService(this.catalog, this.suggestions);

  final List<Movie> catalog;
  final List<Movie> suggestions;

  @override
  Future<List<Movie>> getCatalog() async => catalog;

  @override
  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
  }) async {
    return suggestions;
  }

  @override
  Future<Movie?> getMovieDetails(String movieId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getTrendingMovies() {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getMoviesByGenre(String genre) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getMockShortMovies() {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> searchMovies(String query, MovieSearchFilters filters) {
    throw UnimplementedError();
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bootstrap refreshes when persisted queue has no visible cards',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final staleMovie = _movie('tmdb-100');
      final freshMovie = _movie('tmdb-200');

      final initialState = AgreeoAppState.initial().copyWith(
        session: AgreeoUserSession(
          id: 'user-1',
          displayName: 'User',
          email: 'user@example.com',
          bio: 'Bio',
          joinedAt: DateTime(2026, 4, 11),
        ),
        onboarding: const OnboardingState(
          favoriteGenres: <String>['Drama'],
          favoriteMovieIds: <String>['tmdb-100'],
          completed: true,
        ),
        dailySuggestionIds: <String>[staleMovie.id],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'agreeo.prototype.state.v1',
        jsonEncode(initialState.toJson()),
      );

      final controller = AgreeoAppController(
        _FakeMovieService(const <Movie>[], <Movie>[freshMovie]),
        MockAuthService(),
        LocalUserMovieStateService(),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.remainingDailySuggestions, hasLength(1));
      expect(
        controller.state.remainingDailySuggestions.single.id,
        freshMovie.id,
      );
    },
  );
}
