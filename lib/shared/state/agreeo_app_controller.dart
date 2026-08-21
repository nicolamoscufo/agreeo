import 'dart:async';
import 'dart:convert';

import 'package:agreeo/services/backend_movie_service.dart';
import 'package:agreeo/services/notification_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/services/backend_catalog_movie_service.dart';
import 'package:agreeo/shared/services/movie_service.dart';
import 'package:agreeo/shared/services/user_movie_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agreeo/services/real_time_service.dart';
import 'package:flutter/foundation.dart';

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
    required this.trendingIds,
    this.dailySuggestionsGeneratedAt,
    this.dailySuggestionBatchId,
    this.dailySuggestionContexts =
        const <String, RecommendationActionContext>{},
    this.dailySwipeLimitEnabled = false,
    this.dailySwipeLimit,
    this.dailySwipesUsedToday = 0,
    this.dailySwipesRemainingToday,
    this.dailySwipeResetAt,
    this.movieMutationInProgress = false,
    this.discoveryFeedFailed = false,
  });

  factory AgreeoAppState.initial() {
    return AgreeoAppState(
      hydrated: false,
      session: null,
      onboarding: OnboardingState.initial(),
      profilePreferences: ProfilePreferences.initial(),
      movieMutationInProgress: false,
      catalog: const <Movie>[],
      movieStates: const <String, UserMovieState>{},
      undoStack: const <UndoEntry>[],
      recommendedIds: const <String>[],
      dailySuggestionIds: const <String>[],
      trendingIds: const <String>[],
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
  final List<String> trendingIds;
  final DateTime? dailySuggestionsGeneratedAt;
  final String? dailySuggestionBatchId;
  final Map<String, RecommendationActionContext> dailySuggestionContexts;
  final bool dailySwipeLimitEnabled;
  final int? dailySwipeLimit;
  final int dailySwipesUsedToday;
  final int? dailySwipesRemainingToday;
  final DateTime? dailySwipeResetAt;
  final bool movieMutationInProgress;

  /// Transient (not persisted): the last discovery-feed refresh threw. Lets the
  /// Home rails show an error + retry instead of an indistinguishable "empty".
  final bool discoveryFeedFailed;

  bool get isAuthenticated => session != null;
  bool get onboardingComplete => onboarding.completed;
  bool get dailySwipeLimitReached {
    if (!dailySwipeLimitEnabled || dailySwipesRemainingToday == null) {
      return false;
    }
    final resetAt = dailySwipeResetAt;
    if (resetAt != null && !DateTime.now().isBefore(resetAt)) return false;
    return dailySwipesRemainingToday! <= 0;
  }

  bool get dailySuggestionQueueExpired {
    if (dailySuggestionIds.isEmpty) return false;
    if (dailySuggestionIds.any(
      (id) => !dailySuggestionContexts.containsKey(id),
    )) {
      return true;
    }
    if (dailySuggestionIds.any((id) {
      final expiresAt = dailySuggestionContexts[id]?.expiresAt;
      return expiresAt == null || !DateTime.now().isBefore(expiresAt);
    })) {
      return true;
    }
    final generatedAt = dailySuggestionsGeneratedAt;
    if (generatedAt == null) return true;
    return DateTime.now().difference(generatedAt) >= const Duration(hours: 24);
  }

  RecommendationActionContext? dailySuggestionContextFor(String movieId) {
    return dailySuggestionContexts[movieId];
  }

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
    if (dailySuggestionQueueExpired || dailySwipeLimitReached) {
      return const <Movie>[];
    }
    return moviesByIds(dailySuggestionIds)
        .where((movie) => userMovieStateFor(movie.id).isUntouched)
        .toList(growable: false);
  }

  List<Movie> get recommendedForYou {
    return moviesByIds(recommendedIds)
        .where((movie) => userMovieStateFor(movie.id).isUntouched)
        .toList(growable: false);
  }

  /// Movies for the Home "Made for you" rail. Personalized recommendations need
  /// some swipe/like history before the backend can return picks, so on a cold
  /// start (first launch, before the user swipes anything) [recommendedForYou]
  /// is empty. Fall back to the genre-shaped daily suggestions, then trending,
  /// so the rail is never empty on first launch.
  List<Movie> get recommendedHomeMovies {
    final personalized = recommendedForYou;
    if (personalized.isNotEmpty) return personalized;
    final daily = remainingDailySuggestions;
    if (daily.isNotEmpty) return daily;
    return trendingMovies;
  }

  List<Movie> get trendingMovies {
    return moviesByIds(trendingIds);
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
    List<String>? trendingIds,
    DateTime? dailySuggestionsGeneratedAt,
    bool clearDailySuggestionsGeneratedAt = false,
    String? dailySuggestionBatchId,
    bool clearDailySuggestionBatchId = false,
    Map<String, RecommendationActionContext>? dailySuggestionContexts,
    bool? dailySwipeLimitEnabled,
    int? dailySwipeLimit,
    bool clearDailySwipeLimit = false,
    int? dailySwipesUsedToday,
    int? dailySwipesRemainingToday,
    bool clearDailySwipesRemainingToday = false,
    DateTime? dailySwipeResetAt,
    bool clearDailySwipeResetAt = false,
    bool? movieMutationInProgress,
    bool? discoveryFeedFailed,
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
      trendingIds: trendingIds ?? this.trendingIds,
      dailySuggestionsGeneratedAt: clearDailySuggestionsGeneratedAt
          ? null
          : dailySuggestionsGeneratedAt ?? this.dailySuggestionsGeneratedAt,
      dailySuggestionBatchId: clearDailySuggestionBatchId
          ? null
          : dailySuggestionBatchId ?? this.dailySuggestionBatchId,
      dailySuggestionContexts:
          dailySuggestionContexts ?? this.dailySuggestionContexts,
      dailySwipeLimitEnabled:
          dailySwipeLimitEnabled ?? this.dailySwipeLimitEnabled,
      dailySwipeLimit: clearDailySwipeLimit
          ? null
          : dailySwipeLimit ?? this.dailySwipeLimit,
      dailySwipesUsedToday: dailySwipesUsedToday ?? this.dailySwipesUsedToday,
      dailySwipesRemainingToday: clearDailySwipesRemainingToday
          ? null
          : dailySwipesRemainingToday ?? this.dailySwipesRemainingToday,
      dailySwipeResetAt: clearDailySwipeResetAt
          ? null
          : dailySwipeResetAt ?? this.dailySwipeResetAt,
      movieMutationInProgress:
          movieMutationInProgress ?? this.movieMutationInProgress,
      discoveryFeedFailed: discoveryFeedFailed ?? this.discoveryFeedFailed,
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
      'dailySuggestionsGeneratedAt': dailySuggestionsGeneratedAt
          ?.toIso8601String(),
      'dailySuggestionBatchId': dailySuggestionBatchId,
      'dailySuggestionContexts': dailySuggestionContexts.map(
        (movieId, context) =>
            MapEntry<String, dynamic>(movieId, <String, dynamic>{
              'batchId': context.batchId,
              'position': context.position,
              'source': context.source,
              'expiresAt': context.expiresAt?.toIso8601String(),
            }),
      ),
      'dailySwipeLimitEnabled': dailySwipeLimitEnabled,
      'dailySwipeLimit': dailySwipeLimit,
      'dailySwipesUsedToday': dailySwipesUsedToday,
      'dailySwipesRemainingToday': dailySwipesRemainingToday,
      'dailySwipeResetAt': dailySwipeResetAt?.toIso8601String(),
      'trendingIds': trendingIds,
      'catalog': catalog.map((value) => value.toJson()).toList(),
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

    final catalogItems = <Movie>[];
    final rawCatalog = json['catalog'];
    if (rawCatalog is List) {
      for (final item in rawCatalog.whereType<Map>()) {
        catalogItems.add(Movie.fromJson(item.cast<String, dynamic>()));
      }
    }

    final dailySuggestionContexts = <String, RecommendationActionContext>{};
    final rawDailySuggestionContexts = json['dailySuggestionContexts'];
    if (rawDailySuggestionContexts is Map) {
      for (final entry in rawDailySuggestionContexts.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final values = value.cast<String, dynamic>();
        final batchId = values['batchId']?.toString() ?? '';
        final position = (values['position'] as num?)?.toInt();
        if (batchId.isEmpty || position == null || position < 0) continue;
        dailySuggestionContexts[entry.key
            .toString()] = RecommendationActionContext(
          batchId: batchId,
          position: position,
          source: values['source']?.toString() ?? 'daily-suggestion',
          expiresAt: DateTime.tryParse(values['expiresAt']?.toString() ?? ''),
        );
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
      catalog: catalogItems,
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
      dailySuggestionsGeneratedAt: DateTime.tryParse(
        json['dailySuggestionsGeneratedAt']?.toString() ?? '',
      ),
      dailySuggestionBatchId: json['dailySuggestionBatchId']?.toString(),
      dailySuggestionContexts: dailySuggestionContexts,
      dailySwipeLimitEnabled: json['dailySwipeLimitEnabled'] == true,
      dailySwipeLimit: (json['dailySwipeLimit'] as num?)?.toInt(),
      dailySwipesUsedToday:
          (json['dailySwipesUsedToday'] as num?)?.toInt() ?? 0,
      dailySwipesRemainingToday: (json['dailySwipesRemainingToday'] as num?)
          ?.toInt(),
      dailySwipeResetAt: DateTime.tryParse(
        json['dailySwipeResetAt']?.toString() ?? '',
      ),
      trendingIds:
          (json['trendingIds'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
    );
  }
}

class AgreeoAppController extends StateNotifier<AgreeoAppState> {
  static const int swipeQueueRefillThreshold = 8;
  static const int dailySuggestionBatchSize = 20;

  AgreeoAppController(
    this._ref,
    this._movieService,
    this._authService,
    this._userMovieStateService,
    this._backendMovieService,
  ) : super(AgreeoAppState.initial()) {
    Future.microtask(_bootstrap);
  }

  static const String _storageKey = 'agreeo.prototype.state.v1';

  final Ref _ref;
  final MovieService _movieService;
  final BackendAuthSessionService _authService;
  final UserMovieStateService _userMovieStateService;
  final BackendMovieService _backendMovieService;
  bool _isRefillingDailySuggestions = false;
  bool _hasExhaustedDailySuggestions = false;
  int _feedGeneration = 0;
  Completer<void>? _activeMutation;

  void _invalidateFeedRequests() {
    _feedGeneration += 1;
    _isRefillingDailySuggestions = false;
    _hasExhaustedDailySuggestions = false;
  }

  bool _isCurrentFeedRequest(int generation, String sessionId) {
    return mounted &&
        generation == _feedGeneration &&
        state.session?.id == sessionId;
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final stored = prefs.getString(_storageKey);

    List<Movie> catalog = const <Movie>[];
    try {
      catalog = await _movieService.getCatalog();
    } catch (e) {
      debugPrint(
        '[AgreeoAppController] Failed to fetch catalog from backend during bootstrap: $e',
      );
    }
    if (!mounted) return;

    if (stored == null || stored.isEmpty) {
      state = state.copyWith(hydrated: true, catalog: catalog);
      await _persist();
      if (!mounted) return;
    } else {
      try {
        final decoded = jsonDecode(stored);
        AgreeoAppState loadedState;
        if (decoded is Map<String, dynamic>) {
          loadedState = AgreeoAppState.fromJson(decoded);
        } else if (decoded is Map) {
          loadedState = AgreeoAppState.fromJson(
            decoded.cast<String, dynamic>(),
          );
        } else {
          loadedState = state;
        }

        final mergedCatalog = catalog.isEmpty
            ? loadedState.catalog
            : _mergeCatalogMovies(loadedState.catalog, [catalog]);

        state = loadedState.copyWith(catalog: mergedCatalog);
        await _persist();
      } catch (_) {
        if (!mounted) return;
        state = state.copyWith(hydrated: true, catalog: catalog);
        await _persist();
      }
    }

    if (!mounted) return;

    if (!state.isAuthenticated) {
      await _restoreStoredLogin();
      if (!mounted) return;
    }

    if (state.isAuthenticated &&
        state.onboardingComplete &&
        (state.remainingDailySuggestions.isEmpty ||
            state.recommendedForYou.isEmpty)) {
      try {
        await _refreshDiscoveryFeeds();
        await _persist();
      } catch (e) {
        debugPrint(
          '[AgreeoAppController] Failed to refresh discovery feeds: $e',
        );
      }
    }

    if (state.isAuthenticated) {
      _ref.read(realTimeServiceProvider).connect(state.session!.id);
      await _syncLibraryFromBackend();
    }

    unawaited(_syncDailyReminderSchedule());
  }

  /// Keeps the recurring 24h daily-picks reminder aligned with the session and
  /// the Settings toggle: scheduled while signed in with the toggle on,
  /// cancelled otherwise. Re-scheduling on every app open resets the window,
  /// so the reminder only fires after a full day away from the app.
  Future<void> _syncDailyReminderSchedule() async {
    if (state.isAuthenticated &&
        state.profilePreferences.dailySuggestionReminder) {
      await NotificationService.instance.scheduleDailySuggestionReminder(
        title: 'Your daily picks are in',
        body:
            "$dailySuggestionBatchSize fresh movies are waiting — swipe to find tonight's watch.",
      );
    } else {
      await NotificationService.instance.cancelDailySuggestionReminder();
    }
  }

  Future<void> _restoreStoredLogin() async {
    try {
      final session = await _authService.restoreSession();
      if (!mounted || session == null) return;

      final onboardingCompleted = await _authService.isOnboardingCompleted();
      if (!mounted) return;

      _invalidateFeedRequests();
      state = state.copyWith(
        session: session,
        onboarding: state.onboarding.copyWith(completed: onboardingCompleted),
      );
      await _persist();
    } catch (e) {
      debugPrint('[AgreeoAppController] Failed to restore stored login: $e');
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
    _invalidateFeedRequests();
    state = state.copyWith(
      session: session,
      onboarding: OnboardingState.initial(),
      profilePreferences: ProfilePreferences.initial(),
      movieMutationInProgress: false,
      movieStates: <String, UserMovieState>{},
      undoStack: <UndoEntry>[],
      recommendedIds: <String>[],
      dailySuggestionIds: <String>[],
      dailySuggestionContexts: const <String, RecommendationActionContext>{},
      clearDailySuggestionsGeneratedAt: true,
      clearDailySuggestionBatchId: true,
      dailySwipeLimitEnabled: false,
      clearDailySwipeLimit: true,
      dailySwipesUsedToday: 0,
      clearDailySwipesRemainingToday: true,
      clearDailySwipeResetAt: true,
      trendingIds: <String>[],
    );
    await _persist();
    _ref.read(realTimeServiceProvider).connect(session.id);
    await _syncLibraryFromBackend();
    unawaited(_syncDailyReminderSchedule());
  }

  Future<void> logIn({required String email, required String password}) async {
    final session = await _authService.logIn(email: email, password: password);
    _invalidateFeedRequests();
    final onboardingCompleted = await _authService.isOnboardingCompleted();

    List<Movie> recommended = const [];
    var dailyBatch = const DailySuggestionBatch(movies: <Movie>[]);
    List<Movie> trending = const [];

    if (onboardingCompleted) {
      try {
        final results = await Future.wait<Object>([
          _movieService.getRecommendedForYou(),
          _movieService.getDailySuggestions(
            favoriteGenres: const [],
            favoriteMovieIds: const [],
            limit: dailySuggestionBatchSize,
          ),
          _movieService.getTrendingMovies(),
        ]);
        recommended = results[0] as List<Movie>;
        dailyBatch = results[1] as DailySuggestionBatch;
        trending = results[2] as List<Movie>;
      } catch (e) {
        debugPrint('[AgreeoAppController] Pre-login feed fetch failed: $e');
      }
    }

    final suggestions = dailyBatch.movies;
    final mergedCatalog = _mergeCatalogMovies(state.catalog, [
      recommended,
      suggestions,
      trending,
    ]);

    state = state.copyWith(
      session: session,
      onboarding: OnboardingState.initial().copyWith(
        completed: onboardingCompleted,
      ),
      profilePreferences: ProfilePreferences.initial(),
      movieMutationInProgress: false,
      movieStates: <String, UserMovieState>{},
      undoStack: <UndoEntry>[],
      catalog: mergedCatalog,
      recommendedIds: recommended
          .map((movie) => movie.id)
          .toList(growable: false),
      dailySuggestionIds: suggestions
          .map((movie) => movie.id)
          .toList(growable: false),
      dailySuggestionsGeneratedAt: suggestions.isEmpty ? null : DateTime.now(),
      clearDailySuggestionsGeneratedAt: suggestions.isEmpty,
      dailySuggestionBatchId: dailyBatch.batchId,
      dailySuggestionContexts: _contextsForDailyBatch(dailyBatch),
      clearDailySuggestionBatchId: dailyBatch.batchId == null,
      dailySwipeLimitEnabled: dailyBatch.swipeLimitEnabled,
      dailySwipeLimit: dailyBatch.swipeLimit,
      clearDailySwipeLimit: dailyBatch.swipeLimit == null,
      dailySwipesUsedToday: dailyBatch.usedToday,
      dailySwipesRemainingToday: dailyBatch.remainingToday,
      clearDailySwipesRemainingToday: dailyBatch.remainingToday == null,
      dailySwipeResetAt: dailyBatch.resetAt,
      clearDailySwipeResetAt: dailyBatch.resetAt == null,
      trendingIds: trending.map((movie) => movie.id).toList(growable: false),
    );
    await _persist();
    _ref.read(realTimeServiceProvider).connect(session.id);
    await _syncLibraryFromBackend();
    unawaited(_syncDailyReminderSchedule());
  }

  Future<void> logOut() async {
    _invalidateFeedRequests();
    _ref.read(realTimeServiceProvider).disconnect();
    await _authService.logOut();
    state = AgreeoAppState.initial().copyWith(
      hydrated: true,
      catalog: state.catalog,
      recommendedIds: const <String>[],
      dailySuggestionIds: const <String>[],
      trendingIds: const <String>[],
    );
    await _persist();
    unawaited(_syncDailyReminderSchedule());
  }

  Future<void> _syncLibraryFromBackend() async {
    if (!state.isAuthenticated) return;
    try {
      var library = await _backendMovieService.getLibrary();
      final pushedMissingStates = await _pushMissingLocalStatesToBackend(
        library,
      );
      if (pushedMissingStates) {
        library = await _backendMovieService.getLibrary();
      }

      final newStates = Map<String, UserMovieState>.from(state.movieStates);
      final libraryMovies = <Movie>[
        ...library.liked,
        ...library.disliked,
        ...library.watchlist,
        ...library.alreadySeen,
      ].where((movie) => movie.id.isNotEmpty).toList(growable: false);

      for (final movie in library.liked) {
        if (movie.id.isNotEmpty) {
          final current =
              newStates[movie.id] ?? UserMovieState.initial(movie.id);
          newStates[movie.id] = current.copyWith(
            preference: MoviePreference.liked,
          );
        }
      }

      for (final movie in library.disliked) {
        if (movie.id.isNotEmpty) {
          final current =
              newStates[movie.id] ?? UserMovieState.initial(movie.id);
          newStates[movie.id] = current.copyWith(
            preference: MoviePreference.disliked,
          );
        }
      }

      for (final movie in library.watchlist) {
        if (movie.id.isNotEmpty) {
          final current =
              newStates[movie.id] ?? UserMovieState.initial(movie.id);
          newStates[movie.id] = current.copyWith(inWatchlist: true);
        }
      }

      for (final movie in library.alreadySeen) {
        if (movie.id.isNotEmpty) {
          final current =
              newStates[movie.id] ?? UserMovieState.initial(movie.id);
          newStates[movie.id] = current.copyWith(watched: true);
        }
      }

      state = state.copyWith(
        catalog: _mergeCatalogMovies(state.catalog, [libraryMovies]),
        movieStates: newStates,
      );
      await _persist();
    } catch (e) {
      debugPrint(
        '[AgreeoAppController] Failed to sync library from backend: $e',
      );
    }
  }

  Future<bool> _pushMissingLocalStatesToBackend(UserLibrary library) async {
    if (!state.isAuthenticated || state.movieStates.isEmpty) return false;

    final backendLikedIds = library.liked.map((movie) => movie.id).toSet();
    final backendDislikedIds = library.disliked
        .map((movie) => movie.id)
        .toSet();
    final backendWatchlistIds = library.watchlist
        .map((movie) => movie.id)
        .toSet();
    final backendSeenIds = library.alreadySeen.map((movie) => movie.id).toSet();
    var pushedAny = false;

    for (final userMovieState in state.movieStates.values) {
      final movie = state.movieById(userMovieState.movieId);
      if (movie?.tmdbId == null) {
        continue;
      }

      try {
        if (userMovieState.preference == MoviePreference.liked &&
            !backendLikedIds.contains(userMovieState.movieId)) {
          await _backendMovieService.likeMovie(movie!);
          pushedAny = true;
        } else if (userMovieState.preference == MoviePreference.disliked &&
            !backendDislikedIds.contains(userMovieState.movieId)) {
          await _backendMovieService.dislikeMovie(movie!);
          pushedAny = true;
        }

        if (userMovieState.inWatchlist &&
            !backendWatchlistIds.contains(userMovieState.movieId)) {
          await _backendMovieService.addToWatchlist(movie!);
          pushedAny = true;
        }

        if (userMovieState.watched &&
            !backendSeenIds.contains(userMovieState.movieId)) {
          await _backendMovieService.markAsSeen(movie!);
          pushedAny = true;
        }
      } catch (e) {
        debugPrint(
          '[AgreeoAppController] Failed to push local movie state ${userMovieState.movieId}: $e',
        );
      }
    }

    return pushedAny;
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

  /// Persists profile fields on the backend, then mirrors the saved values
  /// into the local session. Pass [avatarUrl] as '' to remove the photo.
  /// Throws [BackendAuthException] when the backend rejects the update.
  Future<void> updateProfile({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    final currentSession = state.session;
    if (currentSession == null) {
      return;
    }

    final resolvedDisplayName = displayName.trim().isEmpty
        ? currentSession.displayName
        : displayName.trim();

    final updated = await _authService.updateProfile(
      displayName: resolvedDisplayName,
      bio: bio.trim(),
      avatarUrl: avatarUrl,
    );

    state = state.copyWith(
      session: currentSession.copyWith(
        displayName: updated.displayName,
        bio: updated.bio,
        avatarUrl: updated.avatarUrl,
      ),
    );
    await _persist();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Deletes the account on the backend (which detaches every relationship in
  /// Neo4j), then resets the app to the signed-out state.
  Future<void> deleteAccount({required String password}) async {
    await _authService.deleteAccount(password: password);
    _ref.read(realTimeServiceProvider).disconnect();
    state = AgreeoAppState.initial().copyWith(
      hydrated: true,
      catalog: state.catalog,
    );
    await _persist();
    unawaited(_syncDailyReminderSchedule());
  }

  /// Updates the favorite genres from the profile (post-onboarding) and
  /// refreshes the discovery feeds, which are shaped by these preferences.
  Future<void> updateFavoriteGenres(List<String> genres) async {
    final normalized = genres.toList(growable: false);
    await _authService.updateFavoriteGenres(normalized);
    state = state.copyWith(
      onboarding: state.onboarding.copyWith(favoriteGenres: normalized),
    );
    await _persist();
    unawaited(_refreshDiscoveryFeeds());
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

    // Local-first toggle; mirror the flags the social layer actually enforces
    // onto the AppUser node in the background (liked has no friend-facing
    // surface, so it stays local).
    if (showWatchedToFriends != null ||
        showReviewsToFriends != null ||
        showWatchlistToFriends != null) {
      unawaited(
        _authService
            .updatePrivacy(
              canShowWatched: showWatchedToFriends,
              canShowReviews: showReviewsToFriends,
              canShowWatchlist: showWatchlistToFriends,
            )
            .catchError((Object e) {
              debugPrint(
                '[AgreeoAppController] Privacy backend sync failed: $e',
              );
            }),
      );
    }
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

    if (dailySuggestionReminder != null) {
      unawaited(_syncDailyReminderSchedule());
    }
  }

  RecommendationActionContext? _dailyRecommendationContext(String movieId) {
    return state.dailySuggestionContextFor(movieId);
  }

  Future<void> recordDailySuggestionImpression(
    String movieId, {
    RecommendationActionContext? context,
  }) async {
    final resolvedContext = context ?? _dailyRecommendationContext(movieId);
    final movie = state.movieById(movieId);
    if (resolvedContext == null || movie?.tmdbId == null) return;
    await _backendMovieService.recordRecommendationImpression(
      batchId: resolvedContext.batchId,
      tmdbId: movie!.tmdbId!,
      position: resolvedContext.position,
    );
  }

  Future<String> likeMovie(
    String movieId, {
    bool fromDailySuggestions = false,
  }) async {
    return _applyMutation(
      _userMovieStateService.likeMovie(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
      recommendationContext: fromDailySuggestions
          ? _dailyRecommendationContext(movieId)
          : null,
    );
  }

  Future<String> dislikeMovie(
    String movieId, {
    bool fromDailySuggestions = false,
  }) async {
    return _applyMutation(
      _userMovieStateService.dislikeMovie(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
      recommendationContext: fromDailySuggestions
          ? _dailyRecommendationContext(movieId)
          : null,
    );
  }

  Future<String> addToWatchlist(
    String movieId, {
    bool fromDailySuggestions = false,
  }) async {
    return _applyMutation(
      _userMovieStateService.addToWatchlist(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
      recommendationContext: fromDailySuggestions
          ? _dailyRecommendationContext(movieId)
          : null,
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

  Future<String> markAsWatched(
    String movieId, {
    bool fromDailySuggestions = false,
  }) async {
    return _applyMutation(
      _userMovieStateService.markAsWatched(
        state.movieStates,
        state.undoStack,
        movieId,
      ),
      recommendationContext: fromDailySuggestions
          ? _dailyRecommendationContext(movieId)
          : null,
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

  Future<void> _refreshDiscoveryFeeds({int page = 1}) async {
    if (!state.isAuthenticated || !state.onboardingComplete) {
      state = state.copyWith(
        recommendedIds: <String>[],
        dailySuggestionIds: <String>[],
        dailySuggestionContexts: const <String, RecommendationActionContext>{},
        clearDailySuggestionBatchId: true,
      );
      return;
    }

    final requestGeneration = _feedGeneration;
    final sessionId = state.session!.id;

    try {
      final results = await Future.wait<Object>([
        page > 1
            ? Future<Object>.value(const <Movie>[])
            : _movieService.getRecommendedForYou(),
        page > 1
            ? Future<Object>.value(
                const DailySuggestionBatch(movies: <Movie>[]),
              )
            : _movieService.getDailySuggestions(
                favoriteGenres: state.onboarding.favoriteGenres,
                favoriteMovieIds: state.onboarding.favoriteMovieIds,
                limit: dailySuggestionBatchSize,
              ),
        page > 1
            ? Future<Object>.value(const <Movie>[])
            : _movieService.getTrendingMovies(),
      ]);
      final recommended = results[0] as List<Movie>;
      final dailyBatch = results[1] as DailySuggestionBatch;
      final suggestions = dailyBatch.movies;
      final trending = results[2] as List<Movie>;

      if (!_isCurrentFeedRequest(requestGeneration, sessionId)) return;

      if (page == 1) {
        _hasExhaustedDailySuggestions = suggestions.isEmpty;
      }

      if (recommended.isEmpty && suggestions.isEmpty && trending.isEmpty) {
        final limitReached =
            dailyBatch.swipeLimitEnabled &&
            dailyBatch.remainingToday != null &&
            dailyBatch.remainingToday! <= 0;
        state = state.copyWith(
          dailySuggestionIds: limitReached
              ? const <String>[]
              : state.dailySuggestionIds,
          dailySuggestionContexts: limitReached
              ? const <String, RecommendationActionContext>{}
              : state.dailySuggestionContexts,
          clearDailySuggestionBatchId: limitReached,
          dailySwipeLimitEnabled: dailyBatch.swipeLimitEnabled,
          dailySwipeLimit: dailyBatch.swipeLimit,
          clearDailySwipeLimit: dailyBatch.swipeLimit == null,
          dailySwipesUsedToday: dailyBatch.usedToday,
          dailySwipesRemainingToday: dailyBatch.remainingToday,
          clearDailySwipesRemainingToday: dailyBatch.remainingToday == null,
          dailySwipeResetAt: dailyBatch.resetAt,
          clearDailySwipeResetAt: dailyBatch.resetAt == null,
          discoveryFeedFailed: false,
        );
        await _persist();
        return;
      }

      final currentCatalog = page > 1
          ? <Movie>[...recommended, ...suggestions, ...trending]
          : _mergeCatalogMovies(state.catalog, [
              recommended,
              suggestions,
              trending,
            ]);

      state = state.copyWith(
        catalog: currentCatalog,
        recommendedIds: recommended.isEmpty && state.recommendedIds.isNotEmpty
            ? state.recommendedIds
            : recommended.map((movie) => movie.id).toList(growable: false),
        dailySuggestionIds:
            suggestions.isEmpty && state.dailySuggestionIds.isNotEmpty
            ? state.dailySuggestionIds
            : _dedupeMovieIds(suggestions.map((movie) => movie.id)),
        dailySuggestionsGeneratedAt: page == 1 && suggestions.isNotEmpty
            ? DateTime.now()
            : null,
        dailySuggestionBatchId: page == 1 ? dailyBatch.batchId : null,
        dailySuggestionContexts: page == 1
            ? _contextsForDailyBatch(dailyBatch)
            : null,
        clearDailySuggestionBatchId: page == 1 && dailyBatch.batchId == null,
        dailySwipeLimitEnabled: page == 1 ? dailyBatch.swipeLimitEnabled : null,
        dailySwipeLimit: page == 1 ? dailyBatch.swipeLimit : null,
        clearDailySwipeLimit: page == 1 && dailyBatch.swipeLimit == null,
        dailySwipesUsedToday: page == 1 ? dailyBatch.usedToday : null,
        dailySwipesRemainingToday: page == 1 ? dailyBatch.remainingToday : null,
        clearDailySwipesRemainingToday:
            page == 1 && dailyBatch.remainingToday == null,
        dailySwipeResetAt: page == 1 ? dailyBatch.resetAt : null,
        clearDailySwipeResetAt: page == 1 && dailyBatch.resetAt == null,
        trendingIds: trending.isEmpty && state.trendingIds.isNotEmpty
            ? state.trendingIds
            : trending.map((movie) => movie.id).toList(growable: false),
        discoveryFeedFailed: false,
      );
      await _persist();
    } catch (e) {
      debugPrint('[AgreeoAppController] Failed to refresh discovery feeds: $e');
      if (_isCurrentFeedRequest(requestGeneration, sessionId)) {
        state = state.copyWith(discoveryFeedFailed: true);
      }
    }
  }

  Future<void> refreshHomeFeed({int page = 1}) async {
    await _refreshDiscoveryFeeds(page: page);
  }

  Future<void> syncLibrary() async {
    await _syncLibraryFromBackend();
  }

  Future<void> _ensureDailySuggestionBuffer({bool force = false}) async {
    final queueExpired = state.dailySuggestionQueueExpired;
    if (!state.isAuthenticated ||
        !state.onboardingComplete ||
        state.dailySwipeLimitReached ||
        _isRefillingDailySuggestions ||
        (!force && _hasExhaustedDailySuggestions && !queueExpired)) {
      return;
    }

    final untouchedIds = queueExpired
        ? const <String>[]
        : state.dailySuggestionIds
              .where((movieId) => state.userMovieStateFor(movieId).isUntouched)
              .toList(growable: false);

    if (!force && untouchedIds.length >= swipeQueueRefillThreshold) {
      return;
    }

    _isRefillingDailySuggestions = true;
    final requestGeneration = _feedGeneration;
    final sessionId = state.session!.id;
    try {
      final dailyBatch = await _movieService.getDailySuggestions(
        favoriteGenres: state.onboarding.favoriteGenres,
        favoriteMovieIds: state.onboarding.favoriteMovieIds,
        limit: dailySuggestionBatchSize,
      );
      final suggestions = dailyBatch.movies;

      if (!_isCurrentFeedRequest(requestGeneration, sessionId)) return;

      if (suggestions.isEmpty) {
        _hasExhaustedDailySuggestions = true;
        final limitReached =
            dailyBatch.swipeLimitEnabled &&
            dailyBatch.remainingToday != null &&
            dailyBatch.remainingToday! <= 0;
        state = state.copyWith(
          dailySuggestionIds: limitReached
              ? const <String>[]
              : state.dailySuggestionIds,
          dailySuggestionContexts: limitReached
              ? const <String, RecommendationActionContext>{}
              : state.dailySuggestionContexts,
          clearDailySuggestionBatchId: limitReached,
          dailySwipeLimitEnabled: dailyBatch.swipeLimitEnabled,
          dailySwipeLimit: dailyBatch.swipeLimit,
          clearDailySwipeLimit: dailyBatch.swipeLimit == null,
          dailySwipesUsedToday: dailyBatch.usedToday,
          dailySwipesRemainingToday: dailyBatch.remainingToday,
          clearDailySwipesRemainingToday: dailyBatch.remainingToday == null,
          dailySwipeResetAt: dailyBatch.resetAt,
          clearDailySwipeResetAt: dailyBatch.resetAt == null,
        );
        await _persist();
        return;
      }

      _hasExhaustedDailySuggestions = false;

      final currentCatalog = _mergeCatalogMovies(state.catalog, [suggestions]);
      final nextDailyIds = _dedupeMovieIds(<String>[
        if (!queueExpired) ...untouchedIds,
        ...suggestions.map((movie) => movie.id),
      ]);
      final batchContexts = _contextsForDailyBatch(dailyBatch);
      final nextContexts = <String, RecommendationActionContext>{
        if (!queueExpired)
          for (final id in untouchedIds) id: ?state.dailySuggestionContexts[id],
        ...batchContexts,
      };

      state = state.copyWith(
        catalog: currentCatalog,
        dailySuggestionIds: nextDailyIds,
        dailySuggestionsGeneratedAt: DateTime.now(),
        dailySuggestionBatchId: dailyBatch.batchId,
        dailySuggestionContexts: nextContexts,
        clearDailySuggestionBatchId: dailyBatch.batchId == null,
        dailySwipeLimitEnabled: dailyBatch.swipeLimitEnabled,
        dailySwipeLimit: dailyBatch.swipeLimit,
        clearDailySwipeLimit: dailyBatch.swipeLimit == null,
        dailySwipesUsedToday: dailyBatch.usedToday,
        dailySwipesRemainingToday: dailyBatch.remainingToday,
        clearDailySwipesRemainingToday: dailyBatch.remainingToday == null,
        dailySwipeResetAt: dailyBatch.resetAt,
        clearDailySwipeResetAt: dailyBatch.resetAt == null,
      );
      await _persist();
    } catch (e) {
      debugPrint('[AgreeoAppController] Failed to refill suggestions: $e');
    } finally {
      if (requestGeneration == _feedGeneration) {
        _isRefillingDailySuggestions = false;
      }
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

  Map<String, RecommendationActionContext> _contextsForDailyBatch(
    DailySuggestionBatch batch,
  ) {
    final batchId = batch.batchId;
    if (batchId == null || batchId.isEmpty) {
      return const <String, RecommendationActionContext>{};
    }
    return <String, RecommendationActionContext>{
      for (var index = 0; index < batch.movies.length; index += 1)
        batch.movies[index].id: RecommendationActionContext(
          batchId: batchId,
          position: index,
          expiresAt: batch.batchExpiresAt,
        ),
    };
  }

  Future<String> _applyMutation(
    UserMovieStateMutation mutation, {
    bool refreshSuggestions = true,
    RecommendationActionContext? recommendationContext,
  }) async {
    while (_activeMutation != null) {
      await _activeMutation!.future;
    }
    final completion = Completer<void>();
    _activeMutation = completion;
    final requestGeneration = _feedGeneration;
    final sessionId = state.session?.id;
    try {
      state = state.copyWith(
        movieStates: mutation.states,
        undoStack: mutation.undoStack,
        movieMutationInProgress: true,
      );
      final usage = await _syncBackendMovieState(
        mutation.movieId,
        mutation.previousState,
        mutation.nextState,
        recommendationContext: recommendationContext,
      );
      final sameSession =
          requestGeneration == _feedGeneration &&
          state.session?.id == sessionId;
      if (!sameSession) return mutation.message;
      if (usage != null) {
        state = state.copyWith(
          dailySwipeLimitEnabled: usage.limit != null,
          dailySwipeLimit: usage.limit,
          clearDailySwipeLimit: usage.limit == null,
          dailySwipesUsedToday: usage.usedToday,
          dailySwipesRemainingToday: usage.remainingToday,
          clearDailySwipesRemainingToday: usage.remainingToday == null,
          dailySwipeResetAt: usage.resetAt,
          clearDailySwipeResetAt: usage.resetAt == null,
        );
      }
      state = state.copyWith(movieMutationInProgress: false);
      await _persist();
      if (refreshSuggestions && state.onboardingComplete) {
        _asyncRefreshSuggestionsAndBuffer();
      }
      return mutation.message;
    } catch (error) {
      final sameSession =
          requestGeneration == _feedGeneration &&
          state.session?.id == sessionId;
      if (sameSession) {
        final usage = error is MovieBackendRequestException
            ? error.dailyUsage
            : null;
        state = state.copyWith(
          movieStates: mutation.previousStates,
          undoStack: mutation.previousUndoStack,
          movieMutationInProgress: false,
          dailySwipeLimitEnabled: usage?.limit != null
              ? true
              : state.dailySwipeLimitEnabled,
          dailySwipeLimit: usage?.limit,
          dailySwipesUsedToday: usage?.usedToday,
          dailySwipesRemainingToday: usage?.remainingToday,
          dailySwipeResetAt: usage?.resetAt,
        );
        await _persist();
      }
      rethrow;
    } finally {
      if (identical(_activeMutation, completion)) {
        _activeMutation = null;
      }
      if (!completion.isCompleted) completion.complete();
    }
  }

  Future<void> _asyncRefreshSuggestionsAndBuffer() async {
    try {
      await _refreshRecommendedForYou();
      await _ensureDailySuggestionBuffer();
      await _persist();
    } catch (e) {
      debugPrint('[AgreeoAppController] Async suggestions refresh failed: $e');
    }
  }

  Future<void> _refreshRecommendedForYou() async {
    if (!state.isAuthenticated || !state.onboardingComplete) {
      return;
    }

    final requestGeneration = _feedGeneration;
    final sessionId = state.session!.id;

    try {
      final recommended = await _movieService.getRecommendedForYou();
      if (!_isCurrentFeedRequest(requestGeneration, sessionId)) return;
      if (recommended.isEmpty) return;
      final currentCatalog = _mergeCatalogMovies(state.catalog, [recommended]);
      state = state.copyWith(
        catalog: currentCatalog,
        recommendedIds: recommended
            .map((movie) => movie.id)
            .toList(growable: false),
      );
      await _persist();
    } catch (e) {
      debugPrint(
        '[AgreeoAppController] Failed to refresh recommended for you: $e',
      );
    }
  }

  Future<DailySwipeUsage?> _syncBackendMovieState(
    String movieId,
    UserMovieState previousState,
    UserMovieState nextState, {
    RecommendationActionContext? recommendationContext,
  }) async {
    if (!state.isAuthenticated || movieId.isEmpty) {
      return null;
    }

    final movie = state.movieById(movieId);
    if (movie?.tmdbId == null) {
      return null;
    }

    final tmdbId = movie!.tmdbId!;

    if (previousState.preference != MoviePreference.liked &&
        nextState.preference == MoviePreference.liked) {
      return _backendMovieService.likeMovie(
        movie,
        recommendationContext: recommendationContext,
      );
    }

    if (previousState.preference != MoviePreference.disliked &&
        nextState.preference == MoviePreference.disliked) {
      return _backendMovieService.dislikeMovie(
        movie,
        recommendationContext: recommendationContext,
      );
    }

    if (!previousState.inWatchlist && nextState.inWatchlist) {
      return _backendMovieService.addToWatchlist(
        movie,
        recommendationContext: recommendationContext,
      );
    }

    if (!previousState.watched && nextState.watched) {
      return _backendMovieService.markAsSeen(
        movie,
        recommendationContext: recommendationContext,
      );
    }

    if (previousState.preference == MoviePreference.liked &&
        nextState.preference != MoviePreference.liked) {
      await _backendMovieService.removeLike(tmdbId);
    }
    if (previousState.preference == MoviePreference.disliked &&
        nextState.preference != MoviePreference.disliked) {
      await _backendMovieService.removeDislike(tmdbId);
    }
    if (previousState.inWatchlist && !nextState.inWatchlist) {
      await _backendMovieService.removeFromWatchlist(tmdbId);
    }
    if (previousState.watched && !nextState.watched) {
      await _backendMovieService.removeSeen(tmdbId);
    }
    return null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> handleSocketMovieStateChanged({
    required String tmdbId,
    required String stateName,
    required bool value,
  }) async {
    final movieId = 'tmdb-$tmdbId';
    final currentState =
        state.movieStates[movieId] ?? UserMovieState.initial(movieId);

    UserMovieState nextState = currentState;
    if (stateName == 'liked') {
      nextState = currentState.copyWith(
        preference: value ? MoviePreference.liked : MoviePreference.neutral,
      );
    } else if (stateName == 'disliked') {
      nextState = currentState.copyWith(
        preference: value ? MoviePreference.disliked : MoviePreference.neutral,
      );
    } else if (stateName == 'watchlist') {
      nextState = currentState.copyWith(inWatchlist: value);
    } else if (stateName == 'seen') {
      nextState = currentState.copyWith(watched: value);
    }

    final newStates = Map<String, UserMovieState>.from(state.movieStates);
    newStates[movieId] = nextState;

    state = state.copyWith(movieStates: newStates);
    await _persist();
  }
}

final movieServiceProvider = Provider<MovieService>((ref) {
  return BackendCatalogMovieService();
});

final backendAuthSessionServiceProvider = Provider<BackendAuthSessionService>((
  ref,
) {
  return BackendAuthSessionService();
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
        ref,
        ref.watch(movieServiceProvider),
        ref.watch(backendAuthSessionServiceProvider),
        ref.watch(userMovieStateServiceProvider),
        ref.watch(backendMovieServiceProvider),
      );
    });
