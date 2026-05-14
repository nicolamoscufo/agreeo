import 'dart:convert';

import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/mock_auth_service.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:agreeo/shared/services/user_movie_state_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMovieService implements MovieService {
  _FakeMovieService(this.catalog, this.suggestionBatches);

  final List<Movie> catalog;
  final List<List<Movie>> suggestionBatches;
  int _dailySuggestionCallCount = 0;

  @override
  Future<List<Movie>> getCatalog() async => catalog;

  @override
  Future<List<Movie>> getRecommendedForYou() async =>
      suggestionBatches.isEmpty ? const <Movie>[] : suggestionBatches.first;

  @override
  Future<List<Movie>> getDailySuggestions({
    required List<String> favoriteGenres,
    required List<String> favoriteMovieIds,
    int? limit,
  }) async {
    if (suggestionBatches.isEmpty) {
      return const <Movie>[];
    }
    final index = _dailySuggestionCallCount < suggestionBatches.length
        ? _dailySuggestionCallCount
        : suggestionBatches.length - 1;
    _dailySuggestionCallCount += 1;
    return suggestionBatches[index];
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

  @override
  Future<Map<String, dynamic>> getRecommendationDebugStats() async {
    return <String, dynamic>{};
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
        _FakeMovieService(const <Movie>[], <List<Movie>>[
          <Movie>[freshMovie],
        ]),
        MockAuthService(),
        LocalUserMovieStateService(),
        BackendMovieService(),
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

  test('ensureSwipeQueueFilled appends new untouched suggestions', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final firstMovie = _movie('tmdb-200');
    final secondMovie = _movie('tmdb-300');

    final controller = AgreeoAppController(
      _FakeMovieService(const <Movie>[], <List<Movie>>[
        <Movie>[firstMovie],
        <Movie>[secondMovie],
      ]),
      MockAuthService(),
      LocalUserMovieStateService(),
      BackendMovieService(),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.state = controller.state.copyWith(
      hydrated: true,
      session: AgreeoUserSession(
        id: 'user-1',
        displayName: 'User',
        email: 'user@example.com',
        bio: 'Bio',
        joinedAt: DateTime(2026, 4, 11),
      ),
      onboarding: const OnboardingState(
        favoriteGenres: <String>['Drama'],
        favoriteMovieIds: <String>['tmdb-200'],
        completed: true,
      ),
      catalog: <Movie>[firstMovie],
      dailySuggestionIds: <String>[firstMovie.id],
    );

    await controller.ensureSwipeQueueFilled(force: true);
    await controller.ensureSwipeQueueFilled(force: true);

    expect(controller.state.dailySuggestionIds, contains(firstMovie.id));
    expect(controller.state.dailySuggestionIds, contains(secondMovie.id));
  });
}
