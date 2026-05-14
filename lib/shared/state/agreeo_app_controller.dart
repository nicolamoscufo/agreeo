import 'dart:async';
import 'dart:convert';

import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/backend_catalog_movie_service.dart';
import 'package:agreeo/shared/services/mock_auth_service.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:agreeo/shared/services/user_movie_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgreeoAppState {
  const AgreeoAppState({
    required this.hydrated,
    required this.session,
    required this.onboarding,
    required this.profilePreferences,
    required this.catalog,
    required this.movieStates,
    required this.undoStack,
    required this.recommendedIds,
    required this.dailySuggestionIds,
  });

  factory AgreeoAppState.initial() {
    return AgreeoAppState(
      hydrated: false,
      session: null,
      onboarding: OnboardingState.initial(),
      profilePreferences: ProfilePreferences.initial(),
      catalog: const <Movie>[],
      movieStates: const <String, UserMovieState>{},
      undoStack: const <UndoEntry>[],
      recommendedIds: const <String>[],
      dailySuggestionIds: const <String>[],
    );
  }

  final bool hydrated;
  final AgreeoUserSession? session;
  final OnboardingState onboarding;
  final ProfilePreferences profilePreferences;
  final List<Movie> catalog;
  final Map<String, UserMovieState> movieStates;
  final List<UndoEntry> undoStack;
  final List<String> recommendedIds;
  final List<String> dailySuggestionIds;

  bool get isAuthenticated => session != null;
  bool get onboardingComplete => onboarding.completed;

  Movie? movieById(String movieId) {
    for (final movie in catalog) {
      if (movie.id == movieId) {
        return movie;
      }
    }
    return null;
  }

  UserMovieState userMovieStateFor(String movieId) {
    return movieStates[movieId] ?? UserMovieState.initial(movieId);
  }

  List<Movie> moviesByIds(Iterable<String> ids) {
    final items = <Movie>[];
    for (final id in ids) {
      final movie = movieById(id);
      if (movie != null) {
        items.add(movie);
      }
    }
    return items;
  }

  List<Movie> get remainingDailySuggestions {
    return moviesByIds(dailySuggestionIds)
        .where((movie) => userMovieStateFor(movie.id).isUntouched)
        .toList(growable: false);
  }

  List<Movie> get recommendedForYou {
    return moviesByIds(recommendedIds)
        .where((movie) => userMovieStateFor(movie.id).isUntouched)
        .toList(growable: false);
  }

  int get watchlistCount =>
      movieStates.values.where((state) => state.inWatchlist).length;

  int get likedCount => movieStates.values
      .where((state) => state.preference == MoviePreference.liked)
      .length;

  int get watchedCount =>
      movieStates.values.where((state) => state.watched).length;

  int get hiddenCount => movieStates.values
      .where((state) => state.preference == MoviePreference.disliked)
      .length;

  int get reviewCount =>
      movieStates.values.where((state) => state.hasReview).length;

  AgreeoAppState copyWith({
    bool? hydrated,
    AgreeoUserSession? session,
    bool clearSession = false,
    OnboardingState? onboarding,
    ProfilePreferences? profilePreferences,
    List<Movie>? catalog,
    Map<String, UserMovieState>? movieStates,
    List<UndoEntry>? undoStack,
    List<String>? recommendedIds,
    List<String>? dailySuggestionIds,
  }) {
    return AgreeoAppState(
      hydrated: hydrated ?? this.hydrated,
      session: clearSession ? null : session ?? this.session,
      onboarding: onboarding ?? this.onboarding,
      profilePreferences: profilePreferences ?? this.profilePreferences,
      catalog: catalog ?? this.catalog,
      movieStates: movieStates ?? this.movieStates,
      undoStack: undoStack ?? this.undoStack,
      recommendedIds: recommendedIds ?? this.recommendedIds,
      dailySuggestionIds: dailySuggestionIds ?? this.dailySuggestionIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'session': session?.toJson(),
      'onboarding': onboarding.toJson(),
      'profilePreferences': profilePreferences.toJson(),
      'movieStates': movieStates.values
          .map((value) => value.toJson())
          .toList(growable: false),
      'undoStack': undoStack.map((value) => value.toJson()).toList(),
      'recommendedIds': recommendedIds,
      'dailySuggestionIds': dailySuggestionIds,
    };
  }

  factory AgreeoAppState.fromJson(Map<String, dynamic> json) {
    final movieStateItems = <String, UserMovieState>{};
    final rawMovieStates = json['movieStates'];
    if (rawMovieStates is List) {
      for (final item in rawMovieStates.whereType<Map>()) {
        final state = UserMovieState.fromJson(item.cast<String, dynamic>());
        movieStateItems[state.movieId] = state;
      }
    }

    final undoItems = <UndoEntry>[];
    final rawUndoStack = json['undoStack'];
    if (rawUndoStack is List) {
      for (final item in rawUndoStack.whereType<Map>()) {
        undoItems.add(UndoEntry.fromJson(item.cast<String, dynamic>()));
      }
    }

    return AgreeoAppState(
      hydrated: true,
      session: json['session'] is Map<String, dynamic>
          ? AgreeoUserSession.fromJson(json['session'] as Map<String, dynamic>)
          : json['session'] is Map
          ? AgreeoUserSession.fromJson(
              (json['session'] as Map).cast<String, dynamic>(),
            )
          : null,
      onboarding: json['onboarding'] is Map<String, dynamic>
          ? OnboardingState.fromJson(json['onboarding'] as Map<String, dynamic>)
          : json['onboarding'] is Map
          ? OnboardingState.fromJson(
              (json['onboarding'] as Map).cast<String, dynamic>(),
            )
          : OnboardingState.initial(),
      profilePreferences: json['profilePreferences'] is Map<String, dynamic>
          ? ProfilePreferences.fromJson(
              json['profilePreferences'] as Map<String, dynamic>,
            )
          : json['profilePreferences'] is Map
          ? ProfilePreferences.fromJson(
              (json['profilePreferences'] as Map).cast<String, dynamic>(),
            )
          : ProfilePreferences.initial(),
      catalog: const <Movie>[],
      movieStates: movieStateItems,
      undoStack: undoItems,
      recommendedIds:
          (json['recommendedIds'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
      dailySuggestionIds:
          (json['dailySuggestionIds'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class AgreeoAppController extends StateNotifier<AgreeoAppState> {
  static const int swipeQueueRefillThreshold = 8;
  static const int dailySuggestionBatchSize = 60;

  AgreeoAppController(
    this._movieService,
    this._authService,
    this._userMovieStateService,
    this._backendMovieService,
  ) : super(AgreeoAppState.initial()) {
    Future.microtask(_bootstrap);
  }

  static const String _storageKey = 'agreeo.prototype.state.v1';

  final MovieService _movieService;
  final MockAuthService _authService;
  final UserMovieStateService _userMovieStateService;
  final BackendMovieService _backendMovieService;
  bool _isRefillingDailySuggestions = false;

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    final catalog = await _movieService.getCatalog();

    if (stored == null || stored.isEmpty) {
      state = state.copyWith(hydrated: true, catalog: catalog);
      return;
    }

    try {
      final decoded = jsonDecode(stored);
      if (decoded is Map<String, dynamic>) {
        state = AgreeoAppState.fromJson(decoded).copyWith(catalog: catalog);
      } else if (decoded is Map) {
        state = AgreeoAppState.fromJson(
          decoded.cast<String, dynamic>(),
        ).copyWith(catalog: catalog);
      } else {
        state = state.copyWith(hydrated: true, catalog: catalog);
      }
    } catch (_) {
      state = state.copyWith(hydrated: true, catalog: catalog);
    }

    if (state.isAuthenticated &&
        state.onboardingComplete &&
        (state.remainingDailySuggestions.isEmpty ||
            state.recommendedForYou.isEmpty)) {
      await _refreshDiscoveryFeeds();
    }
  }

  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final session = await _authService.signUp(
      displayName: displayName,
      email: email,
      password: password,
    );
    state = state.copyWith(
      session: session,
      onboarding: OnboardingState.initial(),
      profilePreferences: ProfilePreferences.initial(),
      movieStates: <String, UserMovieState>{},
      undoStack: <UndoEntry>[],
      recommendedIds: <String>[],
      dailySuggestionIds: <String>[],
    );
    await _persist();
  }

  Future<void> logIn({required String email, required String password}) async {
    final session = await _authService.logIn(email: email, password: password);
    state = state.copyWith(
      session: session,
      onboarding: OnboardingState.initial(),
      profilePreferences: ProfilePreferences.initial(),
      movieStates: <String, UserMovieState>{},
      undoStack: <UndoEntry>[],
      recommendedIds: <String>[],
      dailySuggestionIds: <String>[],
    );
    await _persist();
  }

  Future<void> logOut() async {
    await _authService.logOut();
    state = AgreeoAppState.initial().copyWith(
      hydrated: true,
      catalog: state.catalog,
      recommendedIds: const <String>[],
      dailySuggestionIds: const <String>[],
    );
    await _persist();
  }

  Future<void> updateOnboardingGenres(List<String> genres) async {
    state = state.copyWith(
      onboarding: state.onboarding.copyWith(
        favoriteGenres: genres.toList(growable: false),
      ),
    );
    await _persist();
  }

  Future<void> toggleFavoriteMovieSelection(String movieId) async {
    final selected = state.onboarding.favoriteMovieIds.toSet();
    if (selected.contains(movieId)) {
      selected.remove(movieId);
    } else if (selected.length < 10) {
      selected.add(movieId);
    }

    state = state.copyWith(
      onboarding: state.onboarding.copyWith(
        favoriteMovieIds: selected.toList(growable: false),
      ),
    );
    await _persist();
  }

  Future<void> finishOnboarding() async {
    await _authService.markOnboardingCompleted(
      selectedFavoriteTmdbIds: _selectedFavoriteTmdbIds(),
      favoriteGenres: state.onboarding.favoriteGenres,
    );

    state = state.copyWith(
      onboarding: state.onboarding.copyWith(completed: true),
    );
    await _refreshDiscoveryFeeds();
    await _persist();
  }

  List<int> _selectedFavoriteTmdbIds() {
    final ids = <int>[];
    for (final movieId in state.onboarding.favoriteMovieIds) {
      final movie = state.movieById(movieId);
      final tmdbId = movie?.tmdbId ?? _parseTmdbId(movieId);
      if (tmdbId != null && tmdbId > 0) {
        ids.add(tmdbId);
      }
    }
    return ids.toList(growable: false);
  }

  int? _parseTmdbId(String movieId) {
    final rawId = movieId.startsWith('tmdb-') ? movieId.substring(5) : movieId;
    return int.tryParse(rawId);
  }

  Future<void> refreshMovieSuggestions() async {
    await _refreshDiscoveryFeeds();
    await _persist();
  }

  Future<void> ensureSwipeQueueFilled({bool force = false}) async {
    await _ensureDailySuggestionBuffer(force: force);
    await _persist();
  }

  Future<void> updateProfile({
    required String displayName,
    required String bio,
  }) async {
    final currentSession = state.session;
    if (currentSession == null) {
      return;
    }
    state = state.copyWith(
      session: currentSession.copyWith(
        displayName: displayName.trim().isEmpty
            ? currentSession.displayName
            : displayName.trim(),
        bio: bio.trim(),
      ),
    );
    await _persist();
  }

  Future<void> setPrivacyPreference({
    bool? showWatchedToFriends,
    bool? showLikedToFriends,
    bool? showWatchlistToFriends,
    bool? showReviewsToFriends,
  }) async {
    state = state.copyWith(
      profilePreferences: state.profilePreferences.copyWith(
        showWatchedToFriends:
            showWatchedToFriends ??
            state.profilePreferences.showWatchedToFriends,
        showLikedToFriends:
            showLikedToFriends ?? state.profilePreferences.showLikedToFriends,
        showWatchlistToFriends:
            showWatchlistToFriends ??
            state.profilePreferences.showWatchlistToFriends,
        showReviewsToFriends:
            showReviewsToFriends ??
            state.profilePreferences.showReviewsToFriends,
      ),
    );
    await _persist();
  }

  Future<void> setNotificationPreference({
    bool? dailySuggestionReminder,
    bool? movieNightInvites,
    bool? votingStarted,
    bool? finalDecisionReached,
  }) async {
    state = state.copyWith(
      profilePreferences: state.profilePreferences.copyWith(
        dailySuggestionReminder:
            dailySuggestionReminder ??
            state.profilePreferences.dailySuggestionReminder,
        movieNightInvites:
            movieNightInvites ?? state.profilePreferences.movieNightInvites,
        votingStarted: votingStarted ?? state.profilePreferences.votingStarted,
        finalDecisionReached:
            finalDecisionReached ??
            state.profilePreferences.finalDecisionReached,
      ),
    );
    await _persist();
  }

  Future<String> likeMovie(String movieId) async {
    return _applyMutation(
      _userMovieStateService.likeMovie(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> dislikeMovie(String movieId) async {
    return _applyMutation(
      _userMovieStateService.dislikeMovie(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> addToWatchlist(String movieId) async {
    return _applyMutation(
      _userMovieStateService.addToWatchlist(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> removeFromWatchlist(String movieId) async {
    return _applyMutation(
      _userMovieStateService.removeFromWatchlist(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> markAsWatched(String movieId) async {
    return _applyMutation(
      _userMovieStateService.markAsWatched(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> removeFromWatched(String movieId) async {
    return _applyMutation(
      _userMovieStateService.removeFromWatched(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> clearPreference(String movieId) async {
    return _applyMutation(
      _userMovieStateService.clearPreference(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> rateMovie(String movieId, int rating) async {
    return _applyMutation(
      _userMovieStateService.rateMovie(
        state.movieStates,
        state.undoStack,
        movieId,
        rating,
      ),
    );
  }

  Future<String> saveReview(String movieId, String review) async {
    return _applyMutation(
      _userMovieStateService.reviewMovie(
        state.movieStates,
        state.undoStack,
        movieId,
        review,
      ),
    );
  }

  Future<String> deleteReview(String movieId) async {
    return _applyMutation(
      _userMovieStateService.deleteReview(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
    );
  }

  Future<String> undoLastAction() async {
    return _applyMutation(
      _userMovieStateService.undoLastAction(state.movieStates, state.undoStack),
      refreshSuggestions: true,
    );
  }

  Future<void> _refreshDiscoveryFeeds() async {
    if (!state.isAuthenticated || !state.onboardingComplete) {
      state = state.copyWith(
        recommendedIds: <String>[],
        dailySuggestionIds: <String>[],
      );
      return;
    }

    final results = await Future.wait<List<Movie>>([
      _movieService.getRecommendedForYou(),
      _movieService.getDailySuggestions(
        favoriteGenres: state.onboarding.favoriteGenres,
        favoriteMovieIds: state.onboarding.favoriteMovieIds,
        limit: dailySuggestionBatchSize,
      ),
    ]);
    final recommended = results[0];
    final suggestions = results[1];

    final currentCatalog = _mergeCatalogMovies(state.catalog, [
      recommended,
      suggestions,
    ]);

    state = state.copyWith(
      catalog: currentCatalog,
      recommendedIds: recommended
          .map((movie) => movie.id)
          .toList(growable: false),
      dailySuggestionIds: _dedupeMovieIds(suggestions.map((movie) => movie.id)),
    );
  }

  Future<void> _ensureDailySuggestionBuffer({bool force = false}) async {
    if (!state.isAuthenticated ||
        !state.onboardingComplete ||
        _isRefillingDailySuggestions) {
      return;
    }

    final untouchedIds = state.dailySuggestionIds
        .where((movieId) {
          return state.userMovieStateFor(movieId).isUntouched;
        })
        .toList(growable: false);

    if (!force && untouchedIds.length >= swipeQueueRefillThreshold) {
      return;
    }

    _isRefillingDailySuggestions = true;
    try {
      final suggestions = await _movieService.getDailySuggestions(
        favoriteGenres: state.onboarding.favoriteGenres,
        favoriteMovieIds: state.onboarding.favoriteMovieIds,
        limit: dailySuggestionBatchSize,
      );
      if (suggestions.isEmpty) {
        state = state.copyWith(dailySuggestionIds: untouchedIds);
        return;
      }

      final currentCatalog = _mergeCatalogMovies(state.catalog, [suggestions]);
      final nextDailyIds = _appendUniqueMovieIds(
        untouchedIds,
        suggestions.map((movie) => movie.id),
      );

      state = state.copyWith(
        catalog: currentCatalog,
        dailySuggestionIds: nextDailyIds,
      );
    } finally {
      _isRefillingDailySuggestions = false;
    }
  }

  List<Movie> _mergeCatalogMovies(
    List<Movie> baseCatalog,
    List<List<Movie>> movieGroups,
  ) {
    final currentCatalog = List<Movie>.of(baseCatalog);
    for (final movies in movieGroups) {
      for (final movie in movies) {
        final index = currentCatalog.indexWhere(
          (entry) => entry.id == movie.id,
        );
        if (index >= 0) {
          currentCatalog[index] = movie;
        } else {
          currentCatalog.add(movie);
        }
      }
    }
    return currentCatalog;
  }

  List<String> _dedupeMovieIds(Iterable<String> ids) {
    final seen = <String>{};
    final items = <String>[];
    for (final id in ids) {
      if (seen.add(id)) {
        items.add(id);
      }
    }
    return items.toList(growable: false);
  }

  List<String> _appendUniqueMovieIds(
    Iterable<String> existingIds,
    Iterable<String> newIds,
  ) {
    return _dedupeMovieIds(<String>[...existingIds, ...newIds]);
  }

  Future<String> _applyMutation(
    UserMovieStateMutation mutation, {
    bool refreshSuggestions = true,
  }) async {
    await _syncBackendMovieState(
      mutation.movieId,
      mutation.previousState,
      mutation.nextState,
    );

    state = state.copyWith(
      movieStates: mutation.states,
      undoStack: mutation.undoStack,
    );
    if (refreshSuggestions && state.onboardingComplete) {
      await _refreshRecommendedForYou();
      await _ensureDailySuggestionBuffer();
    }
    await _persist();
    return mutation.message;
  }

  Future<void> _refreshRecommendedForYou() async {
    if (!state.isAuthenticated || !state.onboardingComplete) {
      return;
    }

    final recommended = await _movieService.getRecommendedForYou();
    final currentCatalog = _mergeCatalogMovies(state.catalog, [recommended]);
    state = state.copyWith(
      catalog: currentCatalog,
      recommendedIds: recommended
          .map((movie) => movie.id)
          .toList(growable: false),
    );
  }

  Future<void> _syncBackendMovieState(
    String movieId,
    UserMovieState previousState,
    UserMovieState nextState,
  ) async {
    if (!state.isAuthenticated || movieId.isEmpty) {
      return;
    }

    final movie = state.movieById(movieId);
    if (movie?.tmdbId == null) {
      return;
    }

    final tmdbId = movie!.tmdbId!;

    if (previousState.preference != MoviePreference.liked &&
        nextState.preference == MoviePreference.liked) {
      await _backendMovieService.likeMovie(movie);
    } else if (previousState.preference == MoviePreference.liked &&
        nextState.preference != MoviePreference.liked) {
      await _backendMovieService.removeLike(tmdbId);
    }

    if (previousState.preference != MoviePreference.disliked &&
        nextState.preference == MoviePreference.disliked) {
      await _backendMovieService.dislikeMovie(movie);
    } else if (previousState.preference == MoviePreference.disliked &&
        nextState.preference != MoviePreference.disliked) {
      await _backendMovieService.removeDislike(tmdbId);
    }

    if (!previousState.inWatchlist && nextState.inWatchlist) {
      await _backendMovieService.addToWatchlist(movie);
    } else if (previousState.inWatchlist && !nextState.inWatchlist) {
      await _backendMovieService.removeFromWatchlist(tmdbId);
    }

    if (!previousState.watched && nextState.watched) {
      await _backendMovieService.markAsSeen(movie);
    } else if (previousState.watched && !nextState.watched) {
      await _backendMovieService.removeSeen(tmdbId);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}

final movieServiceProvider = Provider<MovieService>((ref) {
  return BackendCatalogMovieService();
});

final mockAuthServiceProvider = Provider<MockAuthService>((ref) {
  return MockAuthService();
});

final userMovieStateServiceProvider = Provider<UserMovieStateService>((ref) {
  return LocalUserMovieStateService();
});

final backendMovieServiceProvider = Provider<BackendMovieService>((ref) {
  return BackendMovieService();
});

final agreeoAppControllerProvider =
    StateNotifierProvider<AgreeoAppController, AgreeoAppState>((ref) {
      return AgreeoAppController(
        ref.watch(movieServiceProvider),
        ref.watch(mockAuthServiceProvider),
        ref.watch(userMovieStateServiceProvider),
        ref.watch(backendMovieServiceProvider),
      );
    });
