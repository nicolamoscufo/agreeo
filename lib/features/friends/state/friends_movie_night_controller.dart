import 'package:agreeo/shared/mock_data/mock_movies.dart';
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
    required this.profiles,
    required this.friendMovieStates,
    required this.movieNights,
  });

  factory FriendsMovieNightState.initial() {
    return const FriendsMovieNightState(
      friends: <Friend>[],
      incomingRequests: <FriendRequest>[],
      discoverableUsers: <Friend>[],
      searchResults: <Friend>[],
      outgoingPendingIds: <String>{},
      profiles: <String, FriendProfile>{},
      friendMovieStates: <String, Map<String, UserMovieState>>{},
      movieNights: <MovieNightEvent>[],
    );
  }

  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final List<Friend> discoverableUsers;
  final List<Friend> searchResults;
  final Set<String> outgoingPendingIds;
  final Map<String, FriendProfile> profiles;
  final Map<String, Map<String, UserMovieState>> friendMovieStates;
  final List<MovieNightEvent> movieNights;

  bool isFriend(String userId) {
    return friends.any((friend) => friend.id == userId);
  }

  bool isPending(String userId) => outgoingPendingIds.contains(userId);

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
    Map<String, FriendProfile>? profiles,
    Map<String, Map<String, UserMovieState>>? friendMovieStates,
    List<MovieNightEvent>? movieNights,
  }) {
    return FriendsMovieNightState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      discoverableUsers: discoverableUsers ?? this.discoverableUsers,
      searchResults: searchResults ?? this.searchResults,
      outgoingPendingIds: outgoingPendingIds ?? this.outgoingPendingIds,
      profiles: profiles ?? this.profiles,
      friendMovieStates: friendMovieStates ?? this.friendMovieStates,
      movieNights: movieNights ?? this.movieNights,
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

  final Ref _ref;
  final ShortlistService _shortlistService;
  final BackendSocialService _backendSocialService;
  final Uuid _uuid = const Uuid();
  bool _usingBackend = false;
  String _latestSearchKey = '';

  Future<void> _hydrateSocialLayer() async {
    _seedLocalSocialLayer();
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
        profiles: const <String, FriendProfile>{},
        friendMovieStates: const <String, Map<String, UserMovieState>>{},
        movieNights: snapshot.movieNights,
      );
    } catch (e, stackTrace) {
      debugPrint('Error hydrating backend social layer: $e');
      debugPrint(stackTrace.toString());
      _usingBackend = false;
    }
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
    final request = _firstOrNull(
      state.incomingRequests.where((entry) => entry.id == requestId),
    );
    if (request == null) {
      return;
    }

    final catalog = _catalogMovies();
    final profiles = Map<String, FriendProfile>.from(state.profiles);
    final movieStates = Map<String, Map<String, UserMovieState>>.from(
      state.friendMovieStates,
    );
    profiles[request.fromUser.id] = _buildProfile(request.fromUser, catalog, 7);
    movieStates[request.fromUser.id] = _buildMovieStates(
      request.fromUser.id,
      catalog,
    );

    state = state.copyWith(
      friends: <Friend>[...state.friends, request.fromUser],
      incomingRequests: state.incomingRequests
          .where((entry) => entry.id != requestId)
          .toList(growable: false),
      profiles: profiles,
      friendMovieStates: movieStates,
    );
    if (_usingBackend) {
      Future<void>.microtask(() => _acceptFriendRequestBackend(requestId));
    }
  }

  void declineFriendRequest(String requestId) {
    state = state.copyWith(
      incomingRequests: state.incomingRequests
          .where((entry) => entry.id != requestId)
          .toList(growable: false),
    );
    if (_usingBackend) {
      Future<void>.microtask(() => _declineFriendRequestBackend(requestId));
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
      );
    } catch (_) {}
  }

  Future<void> _sendFriendRequestBackend(
    String userId,
    FriendsMovieNightState previous,
  ) async {
    try {
      await _backendSocialService.sendFriendRequest(userId);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> _acceptFriendRequestBackend(String requestId) async {
    try {
      final snapshot = await _backendSocialService.acceptFriendRequest(
        requestId,
      );
      state = state.copyWith(
        friends: snapshot.friends,
        incomingRequests: snapshot.incomingRequests,
      );
    } catch (_) {}
  }

  Future<void> _declineFriendRequestBackend(String requestId) async {
    try {
      final snapshot = await _backendSocialService.declineFriendRequest(
        requestId,
      );
      state = state.copyWith(
        friends: snapshot.friends,
        incomingRequests: snapshot.incomingRequests,
      );
    } catch (_) {}
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
      } catch (_) {}
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

    final shortlist = _generateShortlist(
      participants: participants,
      constraints: constraints,
    );
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
      } catch (_) {}
    }
    final event = state.eventById(eventId);
    if (event == null) {
      return null;
    }
    final shortlist = _generateShortlist(
      participants: event.participants,
      constraints: constraints,
    );
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
      } catch (_) {}
    }
    final event = state.eventById(eventId);
    if (event == null) {
      return null;
    }
    final updated = event.copyWith(
      shortlist: _generateShortlist(
        participants: event.participants,
        constraints: event.constraints,
      ),
      votes: const <MovieNightVote>[],
      clearWinnerMovieId: true,
      updatedAt: DateTime.now(),
    );
    _replaceEvent(updated);
    return updated;
  }

  Future<MovieNightEvent?> startVoting(String eventId) async {
    if (_usingBackend) {
      try {
        final event = await _backendSocialService.updateMovieNight(
          eventId: eventId,
          status: MovieNightStatus.voting,
        );
        _upsertEvent(event);
        return event;
      } catch (_) {}
    }
    final event = state.eventById(eventId);
    if (event == null || event.shortlist.isEmpty) {
      return event;
    }
    final updated = event.copyWith(
      status: MovieNightStatus.voting,
      updatedAt: DateTime.now(),
    );
    _replaceEvent(updated);
    return updated;
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
      } catch (_) {}
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

    for (final participant in event.joinedParticipants) {
      if (participant.userId == currentUserId) {
        continue;
      }
      final alreadyVoted = nextVotes.any(
        (entry) =>
            entry.userId == participant.userId && entry.movieId == movieId,
      );
      if (alreadyVoted) {
        continue;
      }
      nextVotes.add(
        MovieNightVote(
          eventId: eventId,
          userId: participant.userId,
          movieId: movieId,
          vote: _voteFromParticipantPreference(participant.userId, movieId),
          createdAt: now,
        ),
      );
    }

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

  void _seedLocalSocialLayer() {
    final catalog = _catalogMovies();
    final friends = <Friend>[
      Friend(
        id: 'friend-carla',
        name: 'Carla Rossi',
        avatarUrl: '',
        watchedCount: 38,
        reviewsCount: 12,
        privacySettings: PrivacySettings.open(),
      ),
      const Friend(
        id: 'friend-marco',
        name: 'Marco Bianchi',
        avatarUrl: '',
        watchedCount: 21,
        reviewsCount: 7,
        privacySettings: PrivacySettings(
          canShowWatched: true,
          canShowReviews: true,
          canShowWatchlist: false,
        ),
      ),
      Friend(
        id: 'friend-lina',
        name: 'Lina Costa',
        avatarUrl: '',
        watchedCount: 44,
        reviewsCount: 19,
        privacySettings: PrivacySettings.open(),
      ),
    ];
    final discoverable = <Friend>[
      const Friend(
        id: 'friend-giulia',
        name: 'Giulia Moretti',
        avatarUrl: '',
        watchedCount: 16,
        reviewsCount: 4,
        privacySettings: PrivacySettings(
          canShowWatched: true,
          canShowReviews: false,
          canShowWatchlist: false,
        ),
      ),
      Friend(
        id: 'friend-leo',
        name: 'Leo Martin',
        avatarUrl: '',
        watchedCount: 29,
        reviewsCount: 9,
        privacySettings: PrivacySettings.open(),
      ),
      const Friend(
        id: 'friend-nina',
        name: 'Nina Ahmed',
        avatarUrl: '',
        watchedCount: 11,
        reviewsCount: 2,
        privacySettings: PrivacySettings(
          canShowWatched: false,
          canShowReviews: true,
          canShowWatchlist: false,
        ),
      ),
    ];
    const requester = Friend(
      id: 'friend-omar',
      name: 'Omar Silva',
      avatarUrl: '',
      watchedCount: 18,
      reviewsCount: 5,
      privacySettings: PrivacySettings(
        canShowWatched: true,
        canShowReviews: true,
        canShowWatchlist: false,
      ),
    );

    final profiles = <String, FriendProfile>{};
    final movieStates = <String, Map<String, UserMovieState>>{};
    for (var index = 0; index < friends.length; index++) {
      final friend = friends[index];
      profiles[friend.id] = _buildProfile(friend, catalog, index);
      movieStates[friend.id] = _buildMovieStates(friend.id, catalog);
    }
    profiles[requester.id] = _buildProfile(requester, catalog, 5);
    movieStates[requester.id] = _buildMovieStates(requester.id, catalog);

    state = state.copyWith(
      friends: friends,
      incomingRequests: <FriendRequest>[
        FriendRequest(
          id: 'request-omar',
          fromUser: requester,
          toUserId:
              _ref.read(agreeoAppControllerProvider).session?.id ??
              'local-host',
          status: FriendRequestStatus.pending,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ],
      discoverableUsers: discoverable,
      searchResults: discoverable,
      profiles: profiles,
      friendMovieStates: movieStates,
    );
  }

  List<ShortlistCandidate> _generateShortlist({
    required List<MovieNightParticipant> participants,
    required MovieNightConstraints constraints,
  }) {
    return _shortlistService.generateShortlist(
      eventConstraints: constraints,
      participants: participants,
      movies: _catalogMovies(),
      userMovieStates: _allUserMovieStates(),
      limit: 5,
    );
  }

  Map<String, Map<String, UserMovieState>> _allUserMovieStates() {
    final appState = _ref.read(agreeoAppControllerProvider);
    final currentUserId = appState.session?.id ?? 'local-host';
    return <String, Map<String, UserMovieState>>{
      ...state.friendMovieStates,
      currentUserId: appState.movieStates,
    };
  }

  MovieNightVoteValue _voteFromParticipantPreference(
    String userId,
    String movieId,
  ) {
    final movieState =
        _allUserMovieStates()[userId]?[movieId] ??
        UserMovieState.initial(movieId);
    if (movieState.preference == MoviePreference.disliked) {
      return MovieNightVoteValue.dislike;
    }
    if (movieState.preference == MoviePreference.liked ||
        movieState.inWatchlist ||
        (movieState.rating ?? 0) >= 4) {
      return MovieNightVoteValue.like;
    }
    if (movieState.watched) {
      return MovieNightVoteValue.alreadySeen;
    }
    return MovieNightVoteValue.neutral;
  }

  List<Movie> _catalogMovies() {
    final currentCatalog = _ref
        .read(agreeoAppControllerProvider)
        .catalog
        .where((movie) => movie.mediaType == CatalogMediaType.movie)
        .toList(growable: false);
    final moviesById = <String, Movie>{
      for (final movie in mockMovieCatalog.where(
        (movie) => movie.mediaType == CatalogMediaType.movie,
      ))
        movie.id: movie,
      for (final movie in currentCatalog) movie.id: movie,
    };
    return moviesById.values.toList(growable: false);
  }

  FriendProfile _buildProfile(Friend friend, List<Movie> catalog, int offset) {
    final states = _buildMovieStates(friend.id, catalog);
    final watched = catalog
        .where((movie) => states[movie.id]?.watched == true)
        .take(6)
        .toList(growable: false);
    final watchlist = catalog
        .where((movie) => states[movie.id]?.inWatchlist == true)
        .take(6)
        .toList(growable: false);
    final fallbackWatched = watched.isEmpty
        ? catalog.skip(offset).take(4).toList(growable: false)
        : watched;
    final reviews = fallbackWatched
        .take(3)
        .map((movie) {
          final rating = states[movie.id]?.rating ?? 4;
          return FriendMovieReview(
            movie: movie,
            rating: rating,
            reviewPreview:
                '${movie.title} kept the whole room talking after credits.',
            date: DateTime.now().subtract(Duration(days: 8 + offset)),
          );
        })
        .toList(growable: false);

    return FriendProfile(
      friend: friend.copyWith(
        watchedCount: friend.watchedCount,
        reviewsCount: reviews.length + friend.reviewsCount,
      ),
      watchedMovies: fallbackWatched,
      reviews: reviews,
      watchlist: watchlist.isEmpty
          ? catalog.reversed.take(4).toList(growable: false)
          : watchlist,
    );
  }

  Map<String, UserMovieState> _buildMovieStates(
    String userId,
    List<Movie> catalog,
  ) {
    final seed = _stableSeed(userId);
    final states = <String, UserMovieState>{};
    for (var index = 0; index < catalog.length; index++) {
      final movie = catalog[index];
      final signal = seed + index * 17;
      final disliked = signal % 11 == 0;
      final liked = !disliked && signal % 4 == 0;
      final inWatchlist = !disliked && signal % 5 == 0;
      final watched = signal % 6 == 0;
      final rating = watched || liked ? 3 + (signal % 3) : null;
      states[movie.id] = UserMovieState.initial(movie.id).copyWith(
        preference: disliked
            ? MoviePreference.disliked
            : liked
            ? MoviePreference.liked
            : MoviePreference.neutral,
        inWatchlist: inWatchlist,
        watched: watched,
        rating: rating,
        review: watched && signal % 2 == 0
            ? 'Strong group-night candidate with a memorable final act.'
            : null,
        updatedAt: DateTime.now().subtract(Duration(days: index + 1)),
      );
    }
    return states;
  }

  int _stableSeed(String value) {
    var seed = 0;
    for (final unit in value.codeUnits) {
      seed = (seed * 31 + unit) % 100000;
    }
    return seed;
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
