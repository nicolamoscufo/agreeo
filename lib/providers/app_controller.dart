import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/services/backend_service.dart';
import 'package:agreeo/services/notification_service.dart';
import 'package:agreeo/utils/recommendation_engine.dart';
import 'package:agreeo/utils/sample_catalog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AppState {
  const AppState({
    required this.hydrated,
    required this.session,
    required this.preferences,
    required this.dailyQueue,
    required this.feedback,
    required this.savedWatchlist,
    required this.groups,
    required this.events,
    required this.votes,
    required this.activeGroupId,
    required this.activeEventId,
  });

  factory AppState.initial() {
    return AppState(
      hydrated: false,
      session: null,
      preferences: UserPreferences.initial(),
      dailyQueue: const <Movie>[],
      feedback: const <MovieFeedbackRecord>[],
      savedWatchlist: const <Movie>[],
      groups: const <MovieGroup>[],
      events: const <MovieEvent>[],
      votes: const <EventVote>[],
      activeGroupId: null,
      activeEventId: null,
    );
  }

  final bool hydrated;
  final AppSession? session;
  final UserPreferences preferences;
  final List<Movie> dailyQueue;
  final List<MovieFeedbackRecord> feedback;
  final List<Movie> savedWatchlist;
  final List<MovieGroup> groups;
  final List<MovieEvent> events;
  final List<EventVote> votes;
  final String? activeGroupId;
  final String? activeEventId;

  bool get hasSession => session != null;
  bool get onboardingComplete => preferences.onboardingComplete;

  Movie? get movieOfTheDay {
    if (!preferences.dailyRecommendationsEnabled || dailyQueue.isEmpty) {
      return null;
    }
    return dailyQueue.first;
  }

  MovieGroup? get activeGroup {
    if (activeGroupId == null) {
      return null;
    }
    for (final group in groups) {
      if (group.id == activeGroupId) {
        return group;
      }
    }
    return null;
  }

  MovieEvent? get activeEvent {
    if (activeEventId == null) {
      return null;
    }
    for (final event in events) {
      if (event.id == activeEventId) {
        return event;
      }
    }
    return null;
  }

  List<Movie> remainingQueueForUser(String? userId) {
    if (userId == null || userId.isEmpty) {
      return dailyQueue;
    }
    final processedIds = feedback
        .where((record) => record.userId == userId)
        .map((record) => record.movieId)
        .toSet();
    return dailyQueue
        .where((movie) => !processedIds.contains(movie.id))
        .toList(growable: false);
  }

  AppState copyWith({
    bool? hydrated,
    AppSession? session,
    UserPreferences? preferences,
    List<Movie>? dailyQueue,
    List<MovieFeedbackRecord>? feedback,
    List<Movie>? savedWatchlist,
    List<MovieGroup>? groups,
    List<MovieEvent>? events,
    List<EventVote>? votes,
    String? activeGroupId,
    bool clearActiveGroupId = false,
    String? activeEventId,
    bool clearActiveEventId = false,
  }) {
    return AppState(
      hydrated: hydrated ?? this.hydrated,
      session: session ?? this.session,
      preferences: preferences ?? this.preferences,
      dailyQueue: dailyQueue ?? this.dailyQueue,
      feedback: feedback ?? this.feedback,
      savedWatchlist: savedWatchlist ?? this.savedWatchlist,
      groups: groups ?? this.groups,
      events: events ?? this.events,
      votes: votes ?? this.votes,
      activeGroupId: clearActiveGroupId
          ? null
          : activeGroupId ?? this.activeGroupId,
      activeEventId: clearActiveEventId
          ? null
          : activeEventId ?? this.activeEventId,
    );
  }
}

class AppController extends StateNotifier<AppState> {
  AppController(this._ref) : super(AppState.initial()) {
    Future.microtask(_bootstrap);
  }

  static const String _sessionKey = 'agreeo.session';
  static const String _preferencesKey = 'agreeo.preferences';
  static const String _dailyQueueKey = 'agreeo.dailyQueue';
  static const String _feedbackKey = 'agreeo.feedback';
  static const String _savedWatchlistKey = 'agreeo.savedWatchlist';
  static const String _groupsKey = 'agreeo.groups';
  static const String _eventsKey = 'agreeo.events';
  static const String _votesKey = 'agreeo.votes';
  static const String _activeGroupKey = 'agreeo.activeGroupId';
  static const String _activeEventKey = 'agreeo.activeEventId';

  final Ref _ref;
  final BackendService _backendService = BackendService();
  final RecommendationEngine _recommendationEngine =
      const RecommendationEngine();
  final Uuid _uuid = const Uuid();

  Future<void> _bootstrap() async {
    await NotificationService.instance.initialize();
    final prefs = await SharedPreferences.getInstance();
    final session = _readSession(prefs);
    final preferences = _readPreferences(prefs);
    final queue = _readMovies(prefs, _dailyQueueKey);
    final feedback = _readFeedback(prefs, _feedbackKey);
    final savedWatchlist = _readMovies(prefs, _savedWatchlistKey);
    final groups = _readGroups(prefs, _groupsKey);
    final events = _readEvents(prefs, _eventsKey);
    final votes = _readVotes(prefs, _votesKey);
    final activeGroupId = prefs.getString(_activeGroupKey);
    final activeEventId = prefs.getString(_activeEventKey);

    state = state.copyWith(
      hydrated: true,
      session: session,
      preferences: preferences,
      dailyQueue: queue,
      feedback: feedback,
      savedWatchlist: savedWatchlist,
      groups: groups,
      events: events,
      votes: votes,
      activeGroupId: activeGroupId,
      activeEventId: activeEventId,
    );

    if (state.hasSession &&
        state.onboardingComplete &&
        state.dailyQueue.isEmpty) {
      await regenerateDailyQueue();
    }
  }

  Future<void> createOrUpdateSession({
    required String displayName,
    required String email,
    bool isGuest = false,
  }) async {
    final currentSession = state.session;
    final session = AppSession(
      uid: currentSession?.uid ?? _uuid.v4(),
      displayName: displayName.trim().isEmpty
          ? 'Agreeo user'
          : displayName.trim(),
      email: email.trim(),
      isGuest: isGuest,
      createdAt: currentSession?.createdAt ?? DateTime.now(),
    );

    state = state.copyWith(session: session);
    await _persistState();

    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
    } catch (_) {
      // Local demo mode does not require Firebase Auth.
    }
  }

  Future<void> signOut() async {
    state = AppState.initial().copyWith(hydrated: true);
    await _persistState();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Ignore when Firebase Auth is not configured.
    }
  }

  Future<void> completeOnboarding({
    required List<String> favoriteGenres,
    required List<String> streamingServices,
    bool dailyRecommendationsEnabled = true,
  }) async {
    final nextPreferences = state.preferences.copyWith(
      favoriteGenres: favoriteGenres,
      streamingServices: streamingServices,
      dailyRecommendationsEnabled: dailyRecommendationsEnabled,
      onboardingComplete: true,
    );

    state = state.copyWith(preferences: nextPreferences);
    await _persistState();
    await _backendSyncPreferences();
    await regenerateDailyQueue();
  }

  Future<void> setDailyRecommendationsEnabled(bool enabled) async {
    state = state.copyWith(
      preferences: state.preferences.copyWith(
        dailyRecommendationsEnabled: enabled,
      ),
    );
    await _persistState();
    await _backendSyncPreferences();
    if (enabled) {
      await regenerateDailyQueue();
    }
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    state = state.copyWith(
      preferences: state.preferences.copyWith(darkModeEnabled: enabled),
    );
    await _persistState();
    await _backendSyncPreferences();
  }

  Future<void> regenerateDailyQueue() async {
    final session = state.session;
    if (session == null || !state.preferences.onboardingComplete) {
      return;
    }

    final queue = await _backendService.generateDailyQueue(
      session: session,
      preferences: state.preferences,
      feedback: state.feedback,
    );

    state = state.copyWith(dailyQueue: queue);
    await _persistState();
    await _backendService.persistDailyQueue(session.uid, queue);
    if (queue.isNotEmpty) {
      await NotificationService.instance.showDailyReminder(
        'Movie of the day',
        'Your fresh queue is ready for tonight.',
      );
    }
  }

  Future<void> recordFeedback(Movie movie, FeedbackAction action) async {
    final session = state.session;
    if (session == null) {
      return;
    }

    final feedback = MovieFeedbackRecord(
      userId: session.uid,
      movieId: movie.id,
      action: action,
      createdAt: DateTime.now(),
    );

    final updatedFeedback = <MovieFeedbackRecord>[
      ...state.feedback.where(
        (record) =>
            !(record.userId == session.uid && record.movieId == movie.id),
      ),
      feedback,
    ];

    final updatedSavedWatchlist = List<Movie>.from(state.savedWatchlist);
    if (action == FeedbackAction.later &&
        updatedSavedWatchlist.every((entry) => entry.id != movie.id)) {
      updatedSavedWatchlist.add(movie);
    }

    state = state.copyWith(
      feedback: updatedFeedback,
      savedWatchlist: updatedSavedWatchlist,
    );

    await _persistState();
    await _backendService.persistFeedback(session.uid, feedback);
  }

  Future<void> toggleSavedWatchlist(Movie movie, {bool add = true}) async {
    final updatedSavedWatchlist = List<Movie>.from(state.savedWatchlist);
    updatedSavedWatchlist.removeWhere((entry) => entry.id == movie.id);
    if (add) {
      updatedSavedWatchlist.add(movie);
    }
    state = state.copyWith(savedWatchlist: updatedSavedWatchlist);
    await _persistState();
  }

  Future<MovieGroup> createGroup(String name) async {
    final session = state.session;
    if (session == null) {
      throw StateError('A session is required to create a group.');
    }

    final group = MovieGroup(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Movie Night Crew' : name.trim(),
      inviteCode: _generateInviteCode(),
      ownerId: session.uid,
      memberIds: <String>[session.uid],
      memberServices: <String, List<String>>{
        session.uid: state.preferences.streamingServices,
      },
      sharedWatchlist: <Movie>[],
      createdAt: DateTime.now(),
    );

    final updatedGroups = <MovieGroup>[...state.groups, group];
    state = state.copyWith(groups: updatedGroups, activeGroupId: group.id);
    await _persistState();
    await _backendService.persistGroup(group);
    await NotificationService.instance.showEventCreated(
      'Group created',
      'Invite code ${group.inviteCode} is ready for your friends.',
    );
    return group;
  }

  Future<MovieGroup?> joinGroupByCode(String code) async {
    final session = state.session;
    if (session == null) {
      return null;
    }

    final index = state.groups.indexWhere(
      (group) => group.inviteCode.toUpperCase() == code.trim().toUpperCase(),
    );
    if (index == -1) {
      return null;
    }

    final group = state.groups[index];
    final memberIds = <String>{
      ...group.memberIds,
      session.uid,
    }.toList(growable: false);
    final memberServices = Map<String, List<String>>.from(group.memberServices);
    memberServices[session.uid] = state.preferences.streamingServices;
    final updatedGroup = group.copyWith(
      memberIds: memberIds,
      memberServices: memberServices,
    );

    final updatedGroups = [...state.groups];
    updatedGroups[index] = updatedGroup;
    state = state.copyWith(
      groups: updatedGroups,
      activeGroupId: updatedGroup.id,
    );
    await _persistState();
    await _backendService.persistGroup(updatedGroup);
    return updatedGroup;
  }

  Future<void> addMovieToGroupWatchlist(String groupId, Movie movie) async {
    final index = state.groups.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      return;
    }

    final group = state.groups[index];
    final updatedWatchlist = <Movie>[...group.sharedWatchlist];
    updatedWatchlist.removeWhere((entry) => entry.id == movie.id);
    updatedWatchlist.add(movie);

    final updatedGroup = group.copyWith(sharedWatchlist: updatedWatchlist);
    final updatedGroups = [...state.groups];
    updatedGroups[index] = updatedGroup;
    state = state.copyWith(
      groups: updatedGroups,
      activeGroupId: updatedGroup.id,
    );
    await _persistState();
    await _backendService.persistGroup(updatedGroup);
  }

  Future<MovieEvent?> createEvent(EventConstraints constraints) async {
    final session = state.session;
    final group = state.groups
        .where((entry) => entry.id == constraints.groupId)
        .toList();
    if (session == null || group.isEmpty) {
      return null;
    }

    final targetGroup = group.first;
    final eventId = _uuid.v4();
    final shortlist = await _backendService.generateShortlist(
      session: session,
      event: MovieEvent(
        id: eventId,
        groupId: targetGroup.id,
        groupName: targetGroup.name,
        creatorId: session.uid,
        constraints: constraints,
        shortlist: const <Movie>[],
        createdAt: DateTime.now(),
        resolvedMovieId: null,
      ),
      feedback: state.feedback,
      votes: state.votes,
      group: targetGroup,
    );

    final event = MovieEvent(
      id: eventId,
      groupId: targetGroup.id,
      groupName: targetGroup.name,
      creatorId: session.uid,
      constraints: constraints,
      shortlist: shortlist,
      createdAt: DateTime.now(),
      resolvedMovieId: null,
    );

    final updatedEvents = <MovieEvent>[...state.events, event];
    state = state.copyWith(
      events: updatedEvents,
      activeEventId: event.id,
      activeGroupId: targetGroup.id,
    );
    await _persistState();
    await _backendService.persistEvent(event);
    await NotificationService.instance.showEventCreated(
      'Movie night ready',
      'Your shortlist for ${targetGroup.name} is ready for voting.',
    );
    return event;
  }

  Future<MovieEvent?> voteOnEvent({
    required String eventId,
    required String movieId,
    required VoteChoice choice,
  }) async {
    final session = state.session;
    if (session == null) {
      return null;
    }

    final eventIndex = state.events.indexWhere((event) => event.id == eventId);
    if (eventIndex == -1) {
      return null;
    }

    final vote = EventVote(
      id: _uuid.v4(),
      eventId: eventId,
      movieId: movieId,
      userId: session.uid,
      choice: choice,
      createdAt: DateTime.now(),
    );

    final updatedVotes = <EventVote>[
      ...state.votes.where(
        (entry) =>
            !(entry.eventId == eventId &&
                entry.userId == session.uid &&
                entry.movieId == movieId),
      ),
      vote,
    ];

    final event = state.events[eventIndex];
    final group = state.groups
        .where((entry) => entry.id == event.groupId)
        .toList();
    final updatedGroup = group.isEmpty ? null : group.first;
    final resolvedMovie = updatedGroup == null
        ? null
        : _recommendationEngine.resolveConsensus(
            event: event,
            votes: updatedVotes,
            memberIds: updatedGroup.memberIds,
          );

    final updatedEvents = [...state.events];
    updatedEvents[eventIndex] = event.copyWith(
      resolvedMovieId: resolvedMovie?.id ?? event.resolvedMovieId,
    );

    state = state.copyWith(
      votes: updatedVotes,
      events: updatedEvents,
      activeEventId: eventId,
    );

    await _persistState();
    await _backendService.persistVote(vote);
    await _backendService.persistEvent(updatedEvents[eventIndex]);
    if (resolvedMovie != null) {
      await NotificationService.instance.showConsensusReached(
        'Match found!',
        '${resolvedMovie.title} has enough likes to win the night.',
      );
    }

    return updatedEvents[eventIndex];
  }

  Future<void> setActiveGroup(String? groupId) async {
    state = state.copyWith(
      activeGroupId: groupId,
      clearActiveGroupId: groupId == null,
    );
    await _persistState();
  }

  Future<void> setActiveEvent(String? eventId) async {
    state = state.copyWith(
      activeEventId: eventId,
      clearActiveEventId: eventId == null,
    );
    await _persistState();
  }

  Future<void> _backendSyncPreferences() async {
    final session = state.session;
    if (session == null) {
      return;
    }
    await _backendService.persistPreferences(session.uid, state.preferences);
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    final session = state.session;
    if (session == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    }

    await prefs.setString(
      _preferencesKey,
      jsonEncode(state.preferences.toJson()),
    );
    await prefs.setString(
      _dailyQueueKey,
      jsonEncode(state.dailyQueue.map((movie) => movie.toJson()).toList()),
    );
    await prefs.setString(
      _feedbackKey,
      jsonEncode(state.feedback.map((record) => record.toJson()).toList()),
    );
    await prefs.setString(
      _savedWatchlistKey,
      jsonEncode(state.savedWatchlist.map((movie) => movie.toJson()).toList()),
    );
    await prefs.setString(
      _groupsKey,
      jsonEncode(state.groups.map((group) => group.toJson()).toList()),
    );
    await prefs.setString(
      _eventsKey,
      jsonEncode(state.events.map((event) => event.toJson()).toList()),
    );
    await prefs.setString(
      _votesKey,
      jsonEncode(state.votes.map((vote) => vote.toJson()).toList()),
    );

    if (state.activeGroupId == null) {
      await prefs.remove(_activeGroupKey);
    } else {
      await prefs.setString(_activeGroupKey, state.activeGroupId!);
    }

    if (state.activeEventId == null) {
      await prefs.remove(_activeEventKey);
    } else {
      await prefs.setString(_activeEventKey, state.activeEventId!);
    }
  }

  AppSession? _readSession(SharedPreferences prefs) {
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AppSession.fromJson(jsonDecode(raw).cast<String, dynamic>());
  }

  UserPreferences _readPreferences(SharedPreferences prefs) {
    final raw = prefs.getString(_preferencesKey);
    if (raw == null || raw.isEmpty) {
      return UserPreferences.initial();
    }
    return UserPreferences.fromJson(jsonDecode(raw).cast<String, dynamic>());
  }

  List<Movie> _readMovies(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <Movie>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Movie>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => Movie.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  List<MovieFeedbackRecord> _readFeedback(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <MovieFeedbackRecord>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <MovieFeedbackRecord>[];
    }
    return decoded
        .whereType<Map>()
        .map(
          (entry) =>
              MovieFeedbackRecord.fromJson(entry.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  List<MovieGroup> _readGroups(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <MovieGroup>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <MovieGroup>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => MovieGroup.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  List<MovieEvent> _readEvents(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <MovieEvent>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <MovieEvent>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => MovieEvent.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  List<EventVote> _readVotes(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return <EventVote>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <EventVote>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => EventVote.fromJson(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  String _generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List<String>.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}

final appControllerProvider = StateNotifierProvider<AppController, AppState>((
  ref,
) {
  return AppController(ref);
});
