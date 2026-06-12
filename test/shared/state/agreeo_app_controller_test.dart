import 'dart:convert';

import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/services/real_time_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:agreeo/shared/services/user_movie_state_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRealTimeService implements RealTimeService {
  @override
  void connect(String userId) {}

  @override
  void disconnect() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRef implements Ref {
  @override
  T read<T>(ProviderListenable<T> provider) {
    if (provider as dynamic == realTimeServiceProvider) {
      return _FakeRealTimeService() as T;
    }
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  Future<List<Movie>> getTrendingMovies() async {
    return const <Movie>[];
  }

  @override
  Future<List<Movie>> getMoviesByGenre(String genre) {
    throw UnimplementedError();
  }

  @override
  Future<List<Movie>> getShortMovies() {
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

  @override
  Future<Movie> getRandomMovie() async {
    return catalog.isNotEmpty ? catalog.first : _movie('tmdb-fake');
  }

  @override
  Future<List<Movie>> getMoviesByMood({
    required String feeling,
    required String wantToFeel,
  }) async {
    return const <Movie>[];
  }
}

class _StoredLoginAuthService extends BackendAuthSessionService {
  _StoredLoginAuthService({
    required this.session,
    required this.onboardingCompleted,
  });

  final AgreeoUserSession? session;
  final bool onboardingCompleted;

  @override
  Future<AgreeoUserSession?> restoreSession() async => session;

  @override
  Future<bool> isOnboardingCompleted() async => onboardingCompleted;
}

/// Records profile/account calls and answers them locally, so controller
/// tests never hit the network.
class _ProfileAuthService extends BackendAuthSessionService {
  String? updatedDisplayName;
  String? updatedBio;
  String? updatedAvatarUrl;
  List<String>? updatedGenres;
  String? deletedWithPassword;

  @override
  Future<AgreeoUserSession> updateProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    updatedDisplayName = displayName;
    updatedBio = bio;
    updatedAvatarUrl = avatarUrl;
    return AgreeoUserSession(
      id: 'user-1',
      displayName: displayName ?? 'User',
      email: 'user@example.com',
      bio: bio ?? '',
      joinedAt: DateTime(2026, 4, 11),
      avatarUrl: avatarUrl ?? '',
    );
  }

  @override
  Future<void> updateFavoriteGenres(List<String> favoriteGenres) async {
    updatedGenres = favoriteGenres;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    deletedWithPassword = password;
  }

  bool? pushedCanShowWatched;
  bool? pushedCanShowReviews;
  bool? pushedCanShowWatchlist;

  @override
  Future<void> updatePrivacy({
    bool? canShowWatched,
    bool? canShowReviews,
    bool? canShowWatchlist,
  }) async {
    pushedCanShowWatched = canShowWatched;
    pushedCanShowReviews = canShowReviews;
    pushedCanShowWatchlist = canShowWatchlist;
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
        _FakeRef(),
        _FakeMovieService(const <Movie>[], <List<Movie>>[
          <Movie>[freshMovie],
        ]),
        BackendAuthSessionService(),
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
      _FakeRef(),
      _FakeMovieService(const <Movie>[], <List<Movie>>[
        <Movie>[firstMovie],
        <Movie>[secondMovie],
      ]),
      BackendAuthSessionService(),
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

  test('bootstrap restores login from persisted auth tokens', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final restoredSession = AgreeoUserSession(
      id: 'user-1',
      displayName: 'Restored User',
      email: 'restored@example.com',
      bio: 'Bio',
      joinedAt: DateTime(2026, 4, 11),
    );

    final controller = AgreeoAppController(
      _FakeRef(),
      _FakeMovieService(const <Movie>[], const <List<Movie>>[]),
      _StoredLoginAuthService(
        session: restoredSession,
        onboardingCompleted: true,
      ),
      LocalUserMovieStateService(),
      BackendMovieService(),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.session?.id, restoredSession.id);
    expect(controller.state.onboardingComplete, isTrue);
  });

  test('updateProfile persists to the backend and mirrors the session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final authService = _ProfileAuthService();
    final controller = AgreeoAppController(
      _FakeRef(),
      _FakeMovieService(const <Movie>[], const <List<Movie>>[]),
      authService,
      LocalUserMovieStateService(),
      BackendMovieService(),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    controller.state = controller.state.copyWith(
      hydrated: true,
      session: AgreeoUserSession(
        id: 'user-1',
        displayName: 'Old Name',
        email: 'user@example.com',
        bio: 'Old bio',
        joinedAt: DateTime(2026, 4, 11),
      ),
    );

    await controller.updateProfile(
      displayName: 'New Name',
      bio: 'New bio',
      avatarUrl: 'data:image/jpeg;base64,AAAA',
    );

    expect(authService.updatedDisplayName, 'New Name');
    expect(authService.updatedBio, 'New bio');
    expect(authService.updatedAvatarUrl, 'data:image/jpeg;base64,AAAA');
    expect(controller.state.session?.displayName, 'New Name');
    expect(controller.state.session?.bio, 'New bio');
    expect(controller.state.session?.avatarUrl, 'data:image/jpeg;base64,AAAA');
  });

  test('updateFavoriteGenres persists and updates onboarding state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final authService = _ProfileAuthService();
    final controller = AgreeoAppController(
      _FakeRef(),
      _FakeMovieService(const <Movie>[], const <List<Movie>>[]),
      authService,
      LocalUserMovieStateService(),
      BackendMovieService(),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    await controller.updateFavoriteGenres(<String>['Drama', 'Sci-Fi', 'Crime']);

    expect(authService.updatedGenres, <String>['Drama', 'Sci-Fi', 'Crime']);
    expect(
      controller.state.onboarding.favoriteGenres,
      <String>['Drama', 'Sci-Fi', 'Crime'],
    );
  });

  test('deleteAccount clears the session and resets state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final authService = _ProfileAuthService();
    final controller = AgreeoAppController(
      _FakeRef(),
      _FakeMovieService(const <Movie>[], const <List<Movie>>[]),
      authService,
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
    );

    await controller.deleteAccount(password: 'secret123');

    expect(authService.deletedWithPassword, 'secret123');
    expect(controller.state.session, isNull);
    expect(controller.state.hydrated, isTrue);
  });

  test('setPrivacyPreference mirrors enforced flags to the backend', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final authService = _ProfileAuthService();
    final controller = AgreeoAppController(
      _FakeRef(),
      _FakeMovieService(const <Movie>[], const <List<Movie>>[]),
      authService,
      LocalUserMovieStateService(),
      BackendMovieService(),
    );

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    await controller.setPrivacyPreference(showWatchlistToFriends: true);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.profilePreferences.showWatchlistToFriends, isTrue);
    expect(authService.pushedCanShowWatchlist, isTrue);
    expect(authService.pushedCanShowWatched, isNull);
    expect(authService.pushedCanShowReviews, isNull);
  });
}
