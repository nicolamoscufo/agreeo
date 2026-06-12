import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/services/shortlist_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/services/backend_social_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class FriendsMovieNightState {
  const FriendsMovieNightState({
    required this.friends,
    required this.incomingRequests,
    required this.discoverableUsers,
    required this.searchResults,
    required this.outgoingPendingIds,
    required this.incomingRequestIdsByUserId,
    required this.profiles,
    required this.friendMovieStates,
    required this.movieNights,
    required this.inflightEventIds,
  });

  factory FriendsMovieNightState.initial() {
    return const FriendsMovieNightState(
      friends: <Friend>[],
      incomingRequests: <FriendRequest>[],
      discoverableUsers: <Friend>[],
      searchResults: <Friend>[],
      outgoingPendingIds: <String>{},
      incomingRequestIdsByUserId: <String, String>{},
      profiles: <String, FriendProfile>{},
      friendMovieStates: <String, Map<String, UserMovieState>>{},
      movieNights: <MovieNightEvent>[],
      inflightEventIds: <String>{},
    );
  }

  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final List<Friend> discoverableUsers;
  final List<Friend> searchResults;
  final Set<String> outgoingPendingIds;
  final Map<String, String> incomingRequestIdsByUserId;
  final Map<String, FriendProfile> profiles;
  final Map<String, Map<String, UserMovieState>> friendMovieStates;
  final List<MovieNightEvent> movieNights;
  final Set<String> inflightEventIds;

  bool isFriend(String userId) {
    return friends.any((friend) => friend.id == userId);
  }

  bool isPending(String userId) => outgoingPendingIds.contains(userId);

  String? incomingRequestIdFor(String userId) {
    return incomingRequestIdsByUserId[userId];
  }

  FriendProfile? profileFor(String userId) => profiles[userId];

  MovieNightEvent? eventById(String eventId) {
    for (final event in movieNights) {
      if (event.id == eventId) {
        return event;
      }
    }
    return null;
  }

  FriendsMovieNightState copyWith({
    List<Friend>? friends,
    List<FriendRequest>? incomingRequests,
    List<Friend>? discoverableUsers,
    List<Friend>? searchResults,
    Set<String>? outgoingPendingIds,
    Map<String, String>? incomingRequestIdsByUserId,
    Map<String, FriendProfile>? profiles,
    Map<String, Map<String, UserMovieState>>? friendMovieStates,
    List<MovieNightEvent>? movieNights,
    Set<String>? inflightEventIds,
  }) {
    return FriendsMovieNightState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      discoverableUsers: discoverableUsers ?? this.discoverableUsers,
      searchResults: searchResults ?? this.searchResults,
      outgoingPendingIds: outgoingPendingIds ?? this.outgoingPendingIds,
      incomingRequestIdsByUserId:
          incomingRequestIdsByUserId ?? this.incomingRequestIdsByUserId,
      profiles: profiles ?? this.profiles,
      friendMovieStates: friendMovieStates ?? this.friendMovieStates,
      movieNights: movieNights ?? this.movieNights,
      inflightEventIds: inflightEventIds ?? this.inflightEventIds,
    );
  }
}

class FriendsMovieNightController
    extends StateNotifier<FriendsMovieNightState> {
  FriendsMovieNightController(
    this._ref,
    this._shortlistService,
    this._backendSocialService,
  ) : super(FriendsMovieNightState.initial()) {
    Future<void>.microtask(_hydrateSocialLayer);
  }

  void _markEventInFlight(String eventId) {
    state = state.copyWith(
      inflightEventIds: {...state.inflightEventIds, eventId},
    );
  }

  void _clearEventInFlight(String eventId) {
    final copy = Set<String>.from(state.inflightEventIds)..remove(eventId);
    state = state.copyWith(inflightEventIds: copy);
  }

  Future<void> refreshSocialLayer() async {
    await _hydrateSocialLayer();
  }

  final Ref _ref;
  final ShortlistService _shortlistService;
  final BackendSocialService _backendSocialService;
  final Uuid _uuid = const Uuid();
  bool _usingBackend = false;
  String _latestSearchKey = '';

  bool get _allowLocalDevFallbacks => const bool.fromEnvironment(
    'ALLOW_LOCAL_DEV_FALLBACKS',
    defaultValue: false,
  );

  Future<void> _hydrateSocialLayer() async {
    try {
      final snapshot = await _backendSocialService.loadSnapshot();
      final search = await _backendSocialService.searchFriends('');
      _usingBackend = true;
      state = state.copyWith(
        friends: snapshot.friends,
        incomingRequests: snapshot.incomingRequests,
        discoverableUsers: search.results,
        searchResults: search.results,
        outgoingPendingIds: search.pendingIds,
        incomingRequestIdsByUserId: <String, String>{
          ..._incomingRequestIds(snapshot.incomingRequests),
          ...search.incomingRequestIdsByUserId,
        },
        profiles: const <String, FriendProfile>{},
        friendMovieStates: const <String, Map<String, UserMovieState>>{},
        movieNights: snapshot.movieNights,
      );
    } catch (e) {
      debugPrint('Backend social layer unavailable: $e');
      if (_allowLocalDevFallbacks) {
        _usingBackend = false;
        _hydrateLocalFallback();
        return;
      }

      _usingBackend = true;
      state = state.copyWith(
        friends: const <Friend>[],
        incomingRequests: const <FriendRequest>[],
        discoverableUsers: const <Friend>[],
        searchResults: const <Friend>[],
        outgoingPendingIds: const <String>{},
        incomingRequestIdsByUserId: const <String, String>{},
        profiles: const <String, FriendProfile>{},
        friendMovieStates: const <String, Map<String, UserMovieState>>{},
        movieNights: const <MovieNightEvent>[],
      );
    }
  }

  void _hydrateLocalFallback() {
    final localFriends = _localFriendSeed();
    final incomingRequests = state.incomingRequests.isEmpty
        ? _localIncomingRequestSeed()
        : state.incomingRequests;
    final discoverableUsers = state.discoverableUsers.isEmpty
        ? localFriends
        : state.discoverableUsers;
    state = state.copyWith(
      friends: state.friends.isEmpty ? localFriends : state.friends,
      incomingRequests: incomingRequests,
      discoverableUsers: discoverableUsers,
      searchResults: state.searchResults.isEmpty
          ? discoverableUsers
          : state.searchResults,
      incomingRequestIdsByUserId: <String, String>{
        ...state.incomingRequestIdsByUserId,
        ..._incomingRequestIds(incomingRequests),
      },
    );
  }

  void searchFriends(String query, {bool syncBackend = true}) {
    final tokens = _searchTokens(query);
    _latestSearchKey = tokens.join(' ');
    final regex = _friendSearchRegex(tokens);
    final results = tokens.isEmpty
        ? state.discoverableUsers
        : _rankedFriendSearchResults(state.discoverableUsers, tokens, regex);
    state = state.copyWith(searchResults: results);
    if (_usingBackend && syncBackend) {
      Future<void>.microtask(() => _searchFriendsBackend(query));
    }
  }

  void sendFriendRequest(String userId) {
    final incomingRequestId = state.incomingRequestIdFor(userId);
    if (incomingRequestId != null) {
      acceptFriendRequest(incomingRequestId);
      return;
    }
    if (state.isFriend(userId) || state.isPending(userId)) {
      return;
    }
    final previous = state;
    state = state.copyWith(
      outgoingPendingIds: <String>{...state.outgoingPendingIds, userId},
    );
    if (_usingBackend) {
      Future<void>.microtask(() => _sendFriendRequestBackend(userId, previous));
    }
  }

  void acceptFriendRequest(String requestId) {
    final previous = state;
    final request = _firstOrNull(
      state.incomingRequests.where((entry) => entry.id == requestId),
    );
    if (request == null) {
      if (_usingBackend) {
        Future<void>.microtask(
          () => _acceptFriendRequestBackend(requestId, previous),
        );
      }
      return;
    }

    state = state.copyWith(
      friends: state.isFriend(request.fromUser.id)
          ? state.friends
          : <Friend>[...state.friends, request.fromUser],
      incomingRequests: state.incomingRequests
          .where((entry) => entry.id != requestId)
          .toList(growable: false),
      incomingRequestIdsByUserId: _withoutIncomingRequest(
        state.incomingRequestIdsByUserId,
        requestId: requestId,
        userId: request.fromUser.id,
      ),
    );
    if (_usingBackend) {
      Future<void>.microtask(
        () => _acceptFriendRequestBackend(requestId, previous),
      );
    }
  }

  void declineFriendRequest(String requestId) {
    final previous = state;
    final request = _firstOrNull(
      state.incomingRequests.where((entry) => entry.id == requestId),
    );
    state = state.copyWith(
      incomingRequests: state.incomingRequests
          .where((entry) => entry.id != requestId)
          .toList(growable: false),
      incomingRequestIdsByUserId: _withoutIncomingRequest(
        state.incomingRequestIdsByUserId,
        requestId: requestId,
        userId: request?.fromUser.id,
      ),
    );
    if (_usingBackend) {
      Future<void>.microtask(
        () => _declineFriendRequestBackend(requestId, previous),
      );
    }
  }

  /// Cancels my pending outgoing friend request to [userId] (optimistic:
  /// the "Pending" badge clears immediately, rolled back on failure).
  void cancelFriendRequest(String userId) {
    if (!state.isPending(userId)) return;
    final previous = state;
    state = state.copyWith(
      outgoingPendingIds: <String>{...state.outgoingPendingIds}..remove(userId),
    );
    if (_usingBackend) {
      Future<void>.microtask(
        () => _cancelFriendRequestBackend(userId, previous),
      );
    }
  }

  void removeFriend(String friendId) {
    final previous = state;
    state = _stateWithoutUser(friendId);
    if (_usingBackend) {
      Future<void>.microtask(() => _removeFriendBackend(friendId, previous));
    }
  }

  void blockFriend(String friendId) {
    final previous = state;
    state = _stateWithoutUser(friendId);
    if (_usingBackend) {
      Future<void>.microtask(() => _blockFriendBackend(friendId, previous));
    }
  }

  /// Files an abuse report against [friendId]. Returns true when accepted.
  /// Reporting does not remove the friendship — the caller can offer to block
  /// separately. [context] tags what was reported (e.g. 'profile', 'review').
  Future<bool> reportFriend(
    String friendId, {
    required String reason,
    String context = 'profile',
    String? contentId,
  }) async {
    if (!_usingBackend) return true;
    try {
      await _backendSocialService.reportUser(
        friendId,
        reason: reason,
        context: context,
        contentId: contentId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _searchFriendsBackend(String query) async {
    final searchKey = _searchTokens(query).join(' ');
    try {
      final search = await _backendSocialService.searchFriends(query);
      if (searchKey != _latestSearchKey) {
        return;
      }
      state = state.copyWith(
        discoverableUsers: query.trim().isEmpty
            ? search.results
            : state.discoverableUsers,
        searchResults: search.results,
        outgoingPendingIds: <String>{
          ...state.outgoingPendingIds,
          ...search.pendingIds,
        },
        incomingRequestIdsByUserId: <String, String>{
          ...state.incomingRequestIdsByUserId,
          ...search.incomingRequestIdsByUserId,
        },
      );
    } catch (_) {}
  }

  Future<void> _sendFriendRequestBackend(
    String userId,
    FriendsMovieNightState previous,
  ) async {
    try {
      final result = await _backendSocialService.sendFriendRequest(userId);
      final snapshot = result.snapshot;
      if (result.accepted && snapshot != null) {
        state = state.copyWith(
          friends: snapshot.friends,
          incomingRequests: snapshot.incomingRequests,
          outgoingPendingIds: <String>{...state.outgoingPendingIds}
            ..remove(userId),
          incomingRequestIdsByUserId: _incomingRequestIds(
            snapshot.incomingRequests,
          ),
        );
      }
    } catch (_) {
      state = previous;
    }
  }

  Future<void> _acceptFriendRequestBackend(
    String requestId,
    FriendsMovieNightState previous,
  ) async {
    try {
      final snapshot = await _backendSocialService.acceptFriendRequest(
        requestId,
      );
      if (!mounted) return;
      state = state.copyWith(
        friends: snapshot.friends,
        incomingRequests: snapshot.incomingRequests,
        incomingRequestIdsByUserId: _incomingRequestIds(
          snapshot.incomingRequests,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = previous;
    }
  }

  Future<void> _declineFriendRequestBackend(
    String requestId,
    FriendsMovieNightState previous,
  ) async {
    try {
      final snapshot = await _backendSocialService.declineFriendRequest(
        requestId,
      );
      state = state.copyWith(
        friends: snapshot.friends,
        incomingRequests: snapshot.incomingRequests,
        incomingRequestIdsByUserId: _incomingRequestIds(
          snapshot.incomingRequests,
        ),
      );
    } catch (_) {
      state = previous;
    }
  }

  Future<void> _cancelFriendRequestBackend(
    String userId,
    FriendsMovieNightState previous,
  ) async {
    try {
      final snapshot = await _backendSocialService.cancelFriendRequest(userId);
      if (!mounted) return;
      _applySocialSnapshot(snapshot);
    } catch (_) {
      if (!mounted) return;
      state = previous;
    }
  }

  Future<void> _removeFriendBackend(
    String friendId,
    FriendsMovieNightState previous,
  ) async {
    try {
      final snapshot = await _backendSocialService.removeFriend(friendId);
      if (!mounted) return;
      _applySocialSnapshot(snapshot);
    } catch (_) {
      if (!mounted) return;
      state = previous;
    }
  }

  Future<void> _blockFriendBackend(
    String friendId,
    FriendsMovieNightState previous,
  ) async {
    try {
      final snapshot = await _backendSocialService.blockFriend(friendId);
      _applySocialSnapshot(snapshot);
      state = _stateWithoutUser(friendId);
    } catch (_) {
      state = previous;
    }
  }

  Future<FriendProfile?> loadFriendProfile(String userId) async {
    final existing = state.profileFor(userId);
    if (existing != null) {
      return existing;
    }
    if (!_usingBackend) {
      return null;
    }
    try {
      final profile = await _backendSocialService.getFriendProfile(userId);
      state = state.copyWith(
        profiles: <String, FriendProfile>{...state.profiles, userId: profile},
      );
      return profile;
    } catch (_) {
      return null;
    }
  }

  Future<MovieNightEvent> createMovieNight({
    required String name,
    required DateTime? dateTime,
    required MovieNightConstraints constraints,
    required List<String> invitedFriendIds,
  }) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.createMovieNight(
          name: name,
          dateTime: dateTime,
          constraints: constraints,
          invitedFriendIds: invitedFriendIds,
        );
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error creating backend Movie Night: $error');
        rethrow;
      }
    }
    return _createLocalMovieNight(
      name: name,
      dateTime: dateTime,
      constraints: constraints,
      invitedFriendIds: invitedFriendIds,
    );
  }

  MovieNightEvent _createLocalMovieNight({
    required String name,
    required DateTime? dateTime,
    required MovieNightConstraints constraints,
    required List<String> invitedFriendIds,
  }) {
    final appState = _ref.read(agreeoAppControllerProvider);
    final session = appState.session;
    final now = DateTime.now();
    final eventId = _uuid.v4();
    final hostId = session?.id ?? 'local-host';
    final participants = <MovieNightParticipant>[
      MovieNightParticipant(
        userId: hostId,
        name: session?.displayName ?? 'You',
        avatarUrl: '',
        status: MovieNightParticipantStatus.joined,
        isHost: true,
      ),
    ];

    for (var index = 0; index < invitedFriendIds.length; index++) {
      final friend = _firstOrNull(
        state.friends.where((entry) => entry.id == invitedFriendIds[index]),
      );
      if (friend == null) {
        continue;
      }
      participants.add(
        MovieNightParticipant(
          userId: friend.id,
          name: friend.name,
          avatarUrl: friend.avatarUrl,
          status: index == 0 || index.isEven
              ? MovieNightParticipantStatus.joined
              : MovieNightParticipantStatus.pending,
          isHost: false,
        ),
      );
    }

    final shortlist = _fallbackShortlist();
    final event = MovieNightEvent(
      id: eventId,
      name: name.trim().isEmpty ? 'Movie Night' : name.trim(),
      hostUserId: hostId,
      dateTime: dateTime,
      constraints: constraints,
      participants: participants,
      inviteLink: 'agreeo://invite/$eventId',
      status: MovieNightStatus.waiting,
      shortlist: shortlist,
      winnerMovieId: null,
      votes: const <MovieNightVote>[],
      createdAt: now,
      updatedAt: now,
    );

    state = state.copyWith(
      movieNights: <MovieNightEvent>[event, ...state.movieNights],
    );
    return event;
  }

  List<ShortlistCandidate> _fallbackShortlist() {
    const fallbackBreakdown = ScoreBreakdown(
      watchlistSaves: 1,
      likes: 2,
      dislikes: 0,
      watched: 0,
      positiveRatings: 1,
      includedGenreMatches: 2,
      groupBonus: 0.05,
      groupPenalty: 0.0,
      total: 0.95,
    );
    return <ShortlistCandidate>[
      ShortlistCandidate(
        movie: Movie(
          id: '550',
          tmdbId: 550,
          title: 'Fight Club',
          originalTitle: 'Fight Club',
          overview:
              'An insomniac office worker and a soapmaker form an underground fight club.',
          posterUrl:
              'https://image.tmdb.org/t/p/w500/pB8BM7pv12mEaaA8v17fSSJbxr9.jpg',
          backdropUrl: '',
          releaseYear: 1999,
          runtime: 139,
          genres: const ['Drama', 'Thriller'],
          director: 'David Fincher',
          cast: const ['Brad Pitt', 'Edward Norton'],
          rating: 8.4,
          mediaType: CatalogMediaType.movie,
          trailerUrl: '',
        ),
        compatibilityScore: 0.95,
        explanationTags: const ['Highly compatible'],
        scoreBreakdown: fallbackBreakdown,
      ),
      ShortlistCandidate(
        movie: Movie(
          id: '27205',
          tmdbId: 27205,
          title: 'Inception',
          originalTitle: 'Inception',
          overview:
              'A thief who steals corporate secrets through dream-sharing technology.',
          posterUrl:
              'https://image.tmdb.org/t/p/w500/oYu2QhxWgVnsD2yc76eia2tIYpq.jpg',
          backdropUrl: '',
          releaseYear: 2010,
          runtime: 148,
          genres: const ['Action', 'Sci-Fi'],
          director: 'Christopher Nolan',
          cast: const ['Leonardo DiCaprio'],
          rating: 8.3,
          mediaType: CatalogMediaType.movie,
          trailerUrl: '',
        ),
        compatibilityScore: 0.88,
        explanationTags: const ['Highly compatible'],
        scoreBreakdown: fallbackBreakdown,
      ),
    ];
  }

  Future<MovieNightEvent?> updateEventConstraints({
    required String eventId,
    required MovieNightConstraints constraints,
  }) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.updateMovieNight(
          eventId: eventId,
          constraints: constraints,
        );
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error updating backend Movie Night: $error');
        return null;
      }
    }
    final event = state.eventById(eventId);
    if (event == null) {
      return null;
    }
    final shortlist = const <ShortlistCandidate>[];
    final updated = event.copyWith(
      constraints: constraints,
      shortlist: shortlist,
      votes: const <MovieNightVote>[],
      status: MovieNightStatus.waiting,
      clearWinnerMovieId: true,
      updatedAt: DateTime.now(),
    );
    _replaceEvent(updated);
    return updated;
  }

  Future<MovieNightEvent?> refreshShortlist(String eventId) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.refreshShortlist(eventId);
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error refreshing backend Movie Night shortlist: $error');
        return null;
      }
    }
    final event = state.eventById(eventId);
    if (event == null) {
      return null;
    }
    final updated = event.copyWith(
      shortlist: const <ShortlistCandidate>[],
      votes: const <MovieNightVote>[],
      clearWinnerMovieId: true,
      updatedAt: DateTime.now(),
    );
    _replaceEvent(updated);
    return updated;
  }

  Future<MovieNightEvent?> refreshMovieNight(String eventId) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.getMovieNight(eventId);
        _upsertEvent(event);
        return event;
      } catch (_) {
        return state.eventById(eventId);
      }
    }
    return state.eventById(eventId);
  }

  Future<MovieNightEvent?> resolveMovieNightInvite(String eventId) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.joinMovieNight(eventId);
        _upsertEvent(event);
        return event;
      } catch (_) {
        return refreshMovieNight(eventId);
      }
    }

    final event = state.eventById(eventId);
    if (event == null || event.status != MovieNightStatus.waiting) {
      return event;
    }
    return joinMovieNight(eventId);
  }

  Future<MovieNightEvent?> joinMovieNight(String eventId) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.joinMovieNight(eventId);
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error joining backend Movie Night: $error');
        return null;
      }
    }

    final event = state.eventById(eventId);
    if (event == null) {
      return null;
    }
    final appState = _ref.read(agreeoAppControllerProvider);
    final currentUserId = appState.session?.id ?? 'local-host';
    final currentName = appState.session?.displayName ?? 'You';
    var foundCurrentUser = false;
    final participants = event.participants
        .map((participant) {
          if (participant.userId != currentUserId) {
            return participant;
          }
          foundCurrentUser = true;
          return MovieNightParticipant(
            userId: participant.userId,
            name: participant.name,
            avatarUrl: participant.avatarUrl,
            status: MovieNightParticipantStatus.joined,
            isHost: participant.isHost,
          );
        })
        .toList(growable: true);
    if (!foundCurrentUser) {
      participants.add(
        MovieNightParticipant(
          userId: currentUserId,
          name: currentName,
          avatarUrl: '',
          status: MovieNightParticipantStatus.joined,
          isHost: false,
        ),
      );
    }

    final updated = event.copyWith(
      participants: participants,
      shortlist: const <ShortlistCandidate>[],
      votes: const <MovieNightVote>[],
      status: MovieNightStatus.waiting,
      clearWinnerMovieId: true,
      updatedAt: DateTime.now(),
    );
    _replaceEvent(updated);
    return updated;
  }

  Future<bool> leaveMovieNight(String eventId) async {
    final previous = state;
    state = state.copyWith(
      movieNights: state.movieNights
          .where((event) => event.id != eventId)
          .toList(growable: false),
    );
    if (_usingBackend) {
      try {
        final left = await _backendSocialService.leaveMovieNight(eventId);
        if (!left) {
          state = previous;
        }
        return left;
      } catch (error) {
        debugPrint('Error leaving backend Movie Night: $error');
        state = previous;
        return false;
      }
    }
    return true;
  }

  Future<MovieNightEvent?> startVoting(String eventId) async {
    // Idempotency guard: avoid duplicate transitions for the same event
    if (state.inflightEventIds.contains(eventId)) {
      return null;
    }
    _markEventInFlight(eventId);
    try {
      final event = state.eventById(eventId);
      if (event == null) return null;

      // Only allow transition if current status is waiting
      if (event.status != MovieNightStatus.waiting) {
        return event;
      }

      if (_usingBackend) {
        try {
          final updatedEvent = await _backendSocialService.updateMovieNight(
            eventId: eventId,
            status: MovieNightStatus.voting,
          );
          _upsertEvent(updatedEvent);
          return updatedEvent;
        } catch (error) {
          debugPrint('Error starting backend Movie Night voting: $error');
          return null;
        }
      }

      // Local dev fallback: generate a shortlist if explicitly enabled.
      var shortlist = event.shortlist;
      if (shortlist.isEmpty) {
        const fallbackBreakdown = ScoreBreakdown(
          watchlistSaves: 1,
          likes: 2,
          dislikes: 0,
          watched: 0,
          positiveRatings: 1,
          includedGenreMatches: 2,
          groupBonus: 0.05,
          groupPenalty: 0.0,
          total: 0.95,
        );
        shortlist = [
          ShortlistCandidate(
            movie: Movie(
              id: '550',
              tmdbId: 550,
              title: 'Fight Club',
              originalTitle: 'Fight Club',
              overview:
                  'An insomniac office worker and a soapmaker form an underground fight club.',
              posterUrl:
                  'https://image.tmdb.org/t/p/w500/pB8BM7pv12mEaaA8v17fSSJbxr9.jpg',
              backdropUrl: '',
              releaseYear: 1999,
              runtime: 139,
              genres: const ['Drama', 'Thriller'],
              director: 'David Fincher',
              cast: const ['Brad Pitt', 'Edward Norton'],
              rating: 8.4,
              mediaType: CatalogMediaType.movie,
              trailerUrl: '',
            ),
            compatibilityScore: 0.95,
            explanationTags: const ['Highly compatible'],
            scoreBreakdown: fallbackBreakdown,
          ),
          ShortlistCandidate(
            movie: Movie(
              id: '27205',
              tmdbId: 27205,
              title: 'Inception',
              originalTitle: 'Inception',
              overview:
                  'A thief who steals corporate secrets through the use of dream-sharing technology.',
              posterUrl:
                  'https://image.tmdb.org/t/p/w500/oYu2QhxWgVnsD2yc76eia2tIYpq.jpg',
              backdropUrl: '',
              releaseYear: 2010,
              runtime: 148,
              genres: const ['Action', 'Sci-Fi'],
              director: 'Christopher Nolan',
              cast: const ['Leonardo DiCaprio'],
              rating: 8.3,
              mediaType: CatalogMediaType.movie,
              trailerUrl: '',
            ),
            compatibilityScore: 0.88,
            explanationTags: const ['Highly compatible'],
            scoreBreakdown: fallbackBreakdown,
          ),
        ];
      }
      final updated = event.copyWith(
        status: MovieNightStatus.voting,
        shortlist: shortlist,
        updatedAt: DateTime.now(),
      );
      _replaceEvent(updated);
      return updated;
    } finally {
      _clearEventInFlight(eventId);
    }
  }

  Future<MovieNightEvent?> submitVote({
    required String eventId,
    required String movieId,
    required MovieNightVoteValue vote,
  }) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.submitVote(
          eventId: eventId,
          movieId: movieId,
          vote: vote,
        );
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error submitting backend Movie Night vote: $error');
        return null;
      }
    }
    final event = state.eventById(eventId);
    if (event == null) {
      return null;
    }
    final appState = _ref.read(agreeoAppControllerProvider);
    final currentUserId = appState.session?.id ?? 'local-host';
    final now = DateTime.now();
    final nextVotes = <MovieNightVote>[
      ...event.votes.where(
        (entry) => !(entry.userId == currentUserId && entry.movieId == movieId),
      ),
      MovieNightVote(
        eventId: eventId,
        userId: currentUserId,
        movieId: movieId,
        vote: vote,
        createdAt: now,
      ),
    ];

    var updated = event.copyWith(
      status: MovieNightStatus.voting,
      votes: nextVotes,
      updatedAt: now,
    );

    if (_shortlistService.hasEveryoneVoted(updated)) {
      final winner = _shortlistService.selectWinner(
        shortlist: updated.shortlist,
        votes: updated.votes,
      );
      updated = updated.copyWith(
        status: MovieNightStatus.completed,
        winnerMovieId: winner?.movie.id,
        updatedAt: DateTime.now(),
      );
    }

    _replaceEvent(updated);
    return updated;
  }

  Future<MovieNightEvent?> createInviteLink(String eventId) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.createInviteLink(eventId);
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error creating invite link on backend: $error');
        return null;
      }
    }
    final event = state.eventById(eventId);
    if (event == null) return null;
    final updated = event.copyWith(inviteLink: 'agreeo://invite/$eventId');
    _replaceEvent(updated);
    return updated;
  }

  Future<MovieNightEvent?> inviteFriends({
    required String eventId,
    required List<String> friendIds,
  }) async {
    if (state.inflightEventIds.contains(eventId)) {
      return null;
    }
    _markEventInFlight(eventId);
    try {
      if (_usingBackend) {
        final event = await _backendSocialService.inviteFriends(
          eventId: eventId,
          friendIds: friendIds,
        );
        _upsertEvent(event);
        return event;
      }

      // Local dev fallback.
      final event = state.eventById(eventId);
      if (event == null) return null;

      final updatedParticipants = List<MovieNightParticipant>.from(
        event.participants,
      );
      for (final friendId in friendIds) {
        if (!updatedParticipants.any((p) => p.userId == friendId)) {
          final friendIndex = state.friends.indexWhere((f) => f.id == friendId);
          if (friendIndex != -1) {
            final friend = state.friends[friendIndex];
            updatedParticipants.add(
              MovieNightParticipant(
                userId: friendId,
                name: friend.name,
                avatarUrl: friend.avatarUrl,
                status: MovieNightParticipantStatus.pending,
                isHost: false,
              ),
            );
          }
        }
      }
      final updated = event.copyWith(
        participants: updatedParticipants,
        updatedAt: DateTime.now(),
      );
      _replaceEvent(updated);
      return updated;
    } catch (error) {
      debugPrint('Error inviting friends: $error');
      return null;
    } finally {
      _clearEventInFlight(eventId);
    }
  }

  Future<MovieNightEvent?> deleteVote({
    required String eventId,
    required String movieId,
  }) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.deleteVote(
          eventId: eventId,
          movieId: movieId,
        );
        _upsertEvent(event);
        return event;
      } catch (error) {
        debugPrint('Error deleting backend Movie Night vote: $error');
        return null;
      }
    }
    final event = state.eventById(eventId);
    if (event == null) return null;
    final appState = _ref.read(agreeoAppControllerProvider);
    final currentUserId = appState.session?.id ?? 'local-host';
    final nextVotes = event.votes
        .where(
          (entry) =>
              !(entry.userId == currentUserId && entry.movieId == movieId),
        )
        .toList();
    final updated = event.copyWith(votes: nextVotes, updatedAt: DateTime.now());
    _replaceEvent(updated);
    return updated;
  }

  MovieNightVote? currentUserVoteFor(String eventId, String movieId) {
    final appState = _ref.read(agreeoAppControllerProvider);
    final currentUserId = appState.session?.id ?? 'local-host';
    return _firstOrNull(
      state
              .eventById(eventId)
              ?.votes
              .where(
                (vote) =>
                    vote.userId == currentUserId && vote.movieId == movieId,
              ) ??
          const <MovieNightVote>[],
    );
  }

  void _applySocialSnapshot(SocialBackendSnapshot snapshot) {
    state = state.copyWith(
      friends: snapshot.friends,
      incomingRequests: snapshot.incomingRequests,
      incomingRequestIdsByUserId: _incomingRequestIds(
        snapshot.incomingRequests,
      ),
    );
  }

  FriendsMovieNightState _stateWithoutUser(String userId) {
    // Profiles and movie states are managed by backend; no local mutation needed here.
    final incomingRequestIds = Map<String, String>.from(
      state.incomingRequestIdsByUserId,
    )..remove(userId);

    return state.copyWith(
      friends: state.friends
          .where((friend) => friend.id != userId)
          .toList(growable: false),
      incomingRequests: state.incomingRequests
          .where((request) => request.fromUser.id != userId)
          .toList(growable: false),
      discoverableUsers: state.discoverableUsers
          .where((friend) => friend.id != userId)
          .toList(growable: false),
      searchResults: state.searchResults
          .where((friend) => friend.id != userId)
          .toList(growable: false),
      outgoingPendingIds: <String>{...state.outgoingPendingIds}..remove(userId),
      incomingRequestIdsByUserId: incomingRequestIds,
    );
  }

  Map<String, String> _incomingRequestIds(List<FriendRequest> requests) {
    return <String, String>{
      for (final request in requests) request.fromUser.id: request.id,
    };
  }

  Map<String, String> _withoutIncomingRequest(
    Map<String, String> requestIds, {
    required String requestId,
    String? userId,
  }) {
    return <String, String>{
      for (final entry in requestIds.entries)
        if (entry.value != requestId && entry.key != userId)
          entry.key: entry.value,
    };
  }

  void _replaceEvent(MovieNightEvent event) {
    state = state.copyWith(
      movieNights: state.movieNights
          .map((entry) => entry.id == event.id ? event : entry)
          .toList(growable: false),
    );
  }

  void _upsertEvent(MovieNightEvent event) {
    final exists = state.movieNights.any((entry) => entry.id == event.id);
    state = state.copyWith(
      movieNights: exists
          ? state.movieNights
                .map((entry) => entry.id == event.id ? event : entry)
                .toList(growable: false)
          : <MovieNightEvent>[event, ...state.movieNights],
    );
  }

  void handleSocketMovieNightUpdated(MovieNightEvent event) {
    if (state.inflightEventIds.contains(event.id)) {
      return;
    }
    final local = state.eventById(event.id);
    if (local != null && local.updatedAt.isAfter(event.updatedAt)) {
      return;
    }
    _upsertEvent(event);
  }
}

final shortlistServiceProvider = Provider<ShortlistService>((ref) {
  return const ShortlistService();
});

final backendSocialServiceProvider = Provider<BackendSocialService>((ref) {
  return BackendSocialService();
});

final friendsMovieNightControllerProvider =
    StateNotifierProvider<FriendsMovieNightController, FriendsMovieNightState>((
      ref,
    ) {
      return FriendsMovieNightController(
        ref,
        ref.watch(shortlistServiceProvider),
        ref.watch(backendSocialServiceProvider),
      );
    });

List<Friend> _localFriendSeed() {
  final privacy = PrivacySettings.open();
  return <Friend>[
    Friend(
      id: 'friend-giulia',
      name: 'Giulia Moretti',
      avatarUrl: '',
      watchedCount: 42,
      reviewsCount: 8,
      privacySettings: privacy,
      bio: 'Amante del cinema d\'autore e dei pop-corn salati.',
    ),
    Friend(
      id: 'friend-nina',
      name: 'Nina Ahmed',
      avatarUrl: '',
      watchedCount: 37,
      reviewsCount: 6,
      privacySettings: privacy,
      bio: 'Fantascienza e thriller psicologici sono la mia vita.',
    ),
    Friend(
      id: 'friend-leo',
      name: 'Leo Martin',
      avatarUrl: '',
      watchedCount: 29,
      reviewsCount: 4,
      privacySettings: privacy,
      bio: 'Guardo film per rilassarmi nel weekend.',
    ),
  ];
}

List<FriendRequest> _localIncomingRequestSeed() {
  return <FriendRequest>[
    FriendRequest(
      id: 'request-sofia',
      fromUser: Friend(
        id: 'friend-sofia',
        name: 'Sofia Russo',
        avatarUrl: '',
        watchedCount: 18,
        reviewsCount: 3,
        privacySettings: PrivacySettings.open(),
        bio: 'Ciao! Sono nuova su Agreeo!',
      ),
      toUserId: 'local-host',
      status: FriendRequestStatus.pending,
      createdAt: DateTime(2026),
    ),
  ];
}

List<Friend> _rankedFriendSearchResults(
  List<Friend> friends,
  List<String> tokens,
  RegExp regex,
) {
  final scored = <({Friend friend, int index, int score})>[];
  for (var index = 0; index < friends.length; index++) {
    final friend = friends[index];
    final name = _normalizeSearchText(friend.name);
    final id = _normalizeSearchText(friend.id);
    final haystack = '$name $id';
    if (!regex.hasMatch(haystack)) {
      continue;
    }
    scored.add((
      friend: friend,
      index: index,
      score: _friendSearchScore(name, id, tokens),
    ));
  }
  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    return a.index.compareTo(b.index);
  });
  return scored.map((entry) => entry.friend).toList(growable: false);
}

int _friendSearchScore(String name, String id, List<String> tokens) {
  var score = 0;
  final words = name.split(' ');
  for (final token in tokens) {
    if (name == token || id == token) {
      score += 80;
    } else if (name.startsWith(token)) {
      score += 48;
    } else if (words.any((word) => word.startsWith(token))) {
      score += 32;
    } else if (name.contains(token) || id.contains(token)) {
      score += 12;
    }
  }
  return score;
}

RegExp _friendSearchRegex(List<String> tokens) {
  final lookaheads = tokens
      .map((token) => '(?=.*(?:^| )${RegExp.escape(token)})')
      .join();
  return RegExp('^$lookaheads.*\$', caseSensitive: false);
}

List<String> _searchTokens(String query) {
  final normalized = _normalizeSearchText(query);
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized
      .split(' ')
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String _normalizeSearchText(String value) {
  final lower = value.toLowerCase();
  final folded = lower
      .replaceAll(RegExp('[àáâãäåāăą]'), 'a')
      .replaceAll(RegExp('[çćĉċč]'), 'c')
      .replaceAll(RegExp('[ďđ]'), 'd')
      .replaceAll(RegExp('[èéêëēĕėęě]'), 'e')
      .replaceAll(RegExp('[ĝğġģ]'), 'g')
      .replaceAll(RegExp('[ĥħ]'), 'h')
      .replaceAll(RegExp('[ìíîïĩīĭįı]'), 'i')
      .replaceAll(RegExp('[ĵ]'), 'j')
      .replaceAll(RegExp('[ķ]'), 'k')
      .replaceAll(RegExp('[ĺļľŀł]'), 'l')
      .replaceAll(RegExp('[ñńņňŉŋ]'), 'n')
      .replaceAll(RegExp('[òóôõöøōŏő]'), 'o')
      .replaceAll(RegExp('[ŕŗř]'), 'r')
      .replaceAll(RegExp('[śŝşš]'), 's')
      .replaceAll(RegExp('[ţťŧ]'), 't')
      .replaceAll(RegExp('[ùúûüũūŭůűų]'), 'u')
      .replaceAll(RegExp('[ŵ]'), 'w')
      .replaceAll(RegExp('[ýÿŷ]'), 'y')
      .replaceAll(RegExp('[źżž]'), 'z')
      .replaceAll('æ', 'ae')
      .replaceAll('œ', 'oe')
      .replaceAll('ß', 'ss');
  return folded.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

T? _firstOrNull<T>(Iterable<T> items) {
  for (final item in items) {
    return item;
  }
  return null;
}
