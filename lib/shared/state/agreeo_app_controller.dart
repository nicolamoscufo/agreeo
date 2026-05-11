import 'dart:async';
import 'dart:convert';

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
      dailySuggestionIds:
          (json['dailySuggestionIds'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class AgreeoAppController extends StateNotifier<AgreeoAppState> {
  AgreeoAppController(
    this._movieService,
    this._authService,
    this._userMovieStateService,
  ) : super(AgreeoAppState.initial()) {
    Future.microtask(_bootstrap);
  }

  static const String _storageKey = 'agreeo.prototype.state.v1';

  final MovieService _movieService;
  final MockAuthService _authService;
  final UserMovieStateService _userMovieStateService;

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
        state.dailySuggestionIds.isEmpty) {
      await _refreshDailySuggestions();
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
      dailySuggestionIds: <String>[],
    );
    await _persist();
  }

  Future<void> logOut() async {
    await _authService.logOut();
    state = AgreeoAppState.initial().copyWith(
      hydrated: true,
      catalog: state.catalog,
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
    state = state.copyWith(
      onboarding: state.onboarding.copyWith(completed: true),
    );
    await _refreshDailySuggestions();
    await _persist();
  }

  Future<void> refreshMovieSuggestions() async {
    await _refreshDailySuggestions();
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
      refreshSuggestions: false,
    );
  }

  Future<void> _refreshDailySuggestions() async {
    if (!state.isAuthenticated || !state.onboardingComplete) {
      state = state.copyWith(dailySuggestionIds: <String>[]);
      return;
    }

    final suggestions = await _movieService.getDailySuggestions(
      favoriteGenres: state.onboarding.favoriteGenres,
      favoriteMovieIds: state.onboarding.favoriteMovieIds,
    );

    // Add any suggestions to catalog if they are not already there
    final currentCatalog = List<Movie>.of(state.catalog);
    for (final movie in suggestions) {
      if (!currentCatalog.any((m) => m.id == movie.id)) {
        currentCatalog.add(movie);
      }
    }

    state = state.copyWith(
      catalog: currentCatalog,
      dailySuggestionIds: suggestions
          .map((movie) => movie.id)
          .toList(growable: false),
    );
  }

  Future<String> _applyMutation(
    UserMovieStateMutation mutation, {
    bool refreshSuggestions = true,
  }) async {
    state = state.copyWith(
      movieStates: mutation.states,
      undoStack: mutation.undoStack,
    );
    if (refreshSuggestions && state.onboardingComplete) {
      await _refreshDailySuggestions();
    }
    await _persist();
    return mutation.message;
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

final agreeoAppControllerProvider =
    StateNotifierProvider<AgreeoAppController, AgreeoAppState>((ref) {
      return AgreeoAppController(
        ref.watch(movieServiceProvider),
        ref.watch(mockAuthServiceProvider),
        ref.watch(userMovieStateServiceProvider),
      );
    });
