import 'dart:convert';

import 'package:agreeo/config/backend_config.dart';
import 'package:agreeo/services/auth_service.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/models/app_models.dart' show InAppNotification;
import 'package:http/http.dart' as http;

class SocialBackendSnapshot {
  const SocialBackendSnapshot({
    required this.friends,
    required this.incomingRequests,
    required this.movieNights,
  });

  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final List<MovieNightEvent> movieNights;
}

class FriendSearchResponse {
  const FriendSearchResponse({
    required this.results,
    required this.pendingIds,
    required this.incomingRequestIdsByUserId,
  });

  final List<Friend> results;
  final Set<String> pendingIds;
  final Map<String, String> incomingRequestIdsByUserId;
}

class FriendRequestMutationResult {
  const FriendRequestMutationResult({
    required this.accepted,
    required this.snapshot,
  });

  final bool accepted;
  final SocialBackendSnapshot? snapshot;
}

class BackendSocialService {
  BackendSocialService({
    BackendConfig? config,
    AuthService? authService,
    http.Client? client,
  }) : _config = config ?? BackendConfig.fromEnv(),
       _authService = authService ?? AuthService(config: config),
       _client = client ?? http.Client();

  final BackendConfig _config;
  final AuthService _authService;
  final http.Client _client;

  Future<SocialBackendSnapshot> loadSnapshot() async {
    final friendsBody = _decodeMap(
      (await _authorizedRequest('GET', '/friends')).body,
    );
    final eventsBody = _decodeMap(
      (await _authorizedRequest('GET', '/movie-nights')).body,
    );
    return SocialBackendSnapshot(
      friends: _decodeFriends(friendsBody['friends']),
      incomingRequests: _decodeFriendRequests(friendsBody['incomingRequests']),
      movieNights: _decodeMovieNightEvents(eventsBody['events']),
    );
  }

  Future<FriendSearchResponse> searchFriends(String query) async {
    final uri = Uri(
      path: '/friends/search',
      queryParameters: query.trim().isEmpty
          ? null
          : <String, String>{'q': query.trim()},
    ).toString();
    final body = _decodeMap((await _authorizedRequest('GET', uri)).body);
    final pendingIds = <String>{};
    final incomingRequestIdsByUserId = <String, String>{};
    final results = <Friend>[];
    final rawResults = body['results'];
    if (rawResults is List) {
      for (final item in rawResults.whereType<Map>()) {
        final json = item.cast<String, dynamic>();
        final friend = _decodeFriend(json);
        results.add(friend);
        if (json['pending'] == true) {
          pendingIds.add(friend.id);
        }
        if (json['incomingPending'] == true) {
          final requestId = _string(json['incomingRequestId']);
          if (requestId.isNotEmpty) {
            incomingRequestIdsByUserId[friend.id] = requestId;
          }
        }
      }
    }
    return FriendSearchResponse(
      results: results,
      pendingIds: pendingIds,
      incomingRequestIdsByUserId: incomingRequestIdsByUserId,
    );
  }

  Future<FriendRequestMutationResult> sendFriendRequest(String userId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/friends/requests',
        body: <String, dynamic>{'targetUserId': userId},
      )).body,
    );
    final accepted = body['accepted'] == true;
    return FriendRequestMutationResult(
      accepted: accepted,
      snapshot: accepted
          ? SocialBackendSnapshot(
              friends: _decodeFriends(body['friends']),
              incomingRequests: _decodeFriendRequests(body['incomingRequests']),
              movieNights: const <MovieNightEvent>[],
            )
          : null,
    );
  }

  Future<SocialBackendSnapshot> acceptFriendRequest(String requestId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/friends/requests/$requestId/accept',
      )).body,
    );
    return SocialBackendSnapshot(
      friends: _decodeFriends(body['friends']),
      incomingRequests: _decodeFriendRequests(body['incomingRequests']),
      movieNights: const <MovieNightEvent>[],
    );
  }

  Future<SocialBackendSnapshot> declineFriendRequest(String requestId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/friends/requests/$requestId/decline',
      )).body,
    );
    return SocialBackendSnapshot(
      friends: _decodeFriends(body['friends']),
      incomingRequests: _decodeFriendRequests(body['incomingRequests']),
      movieNights: const <MovieNightEvent>[],
    );
  }

  Future<SocialBackendSnapshot> removeFriend(String friendId) async {
    final body = _decodeMap(
      (await _authorizedRequest('DELETE', '/friends/$friendId')).body,
    );
    return SocialBackendSnapshot(
      friends: _decodeFriends(body['friends']),
      incomingRequests: _decodeFriendRequests(body['incomingRequests']),
      movieNights: const <MovieNightEvent>[],
    );
  }

  Future<SocialBackendSnapshot> blockFriend(String friendId) async {
    final body = _decodeMap(
      (await _authorizedRequest('POST', '/friends/$friendId/block')).body,
    );
    return SocialBackendSnapshot(
      friends: _decodeFriends(body['friends']),
      incomingRequests: _decodeFriendRequests(body['incomingRequests']),
      movieNights: const <MovieNightEvent>[],
    );
  }

  /// Cancels my pending outgoing friend request to [userId].
  Future<SocialBackendSnapshot> cancelFriendRequest(String userId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'DELETE',
        '/friends/requests/outgoing/$userId',
      )).body,
    );
    return SocialBackendSnapshot(
      friends: _decodeFriends(body['friends']),
      incomingRequests: _decodeFriendRequests(body['incomingRequests']),
      movieNights: const <MovieNightEvent>[],
    );
  }

  Future<List<Friend>> getBlockedUsers() async {
    final body = _decodeMap(
      (await _authorizedRequest('GET', '/friends/blocked')).body,
    );
    return _decodeFriends(body['blocked']);
  }

  /// Unblocks [userId]; returns the refreshed blocked list.
  Future<List<Friend>> unblockFriend(String userId) async {
    final body = _decodeMap(
      (await _authorizedRequest('DELETE', '/friends/$userId/block')).body,
    );
    return _decodeFriends(body['blocked']);
  }

  Future<FriendProfile> getFriendProfile(String friendId) async {
    final body = _decodeMap(
      (await _authorizedRequest('GET', '/friends/$friendId/profile')).body,
    );
    return _decodeFriendProfile(_castMap(body['profile']));
  }

  Future<MovieNightEvent> createMovieNight({
    required String name,
    required DateTime? dateTime,
    required MovieNightConstraints constraints,
    required List<String> invitedFriendIds,
  }) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/movie-nights',
        body: <String, dynamic>{
          'name': name,
          'dateTime': dateTime?.toIso8601String(),
          'constraints': _encodeConstraints(constraints),
          'invitedFriendIds': invitedFriendIds,
        },
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> getMovieNight(String eventId) async {
    final body = _decodeMap(
      (await _authorizedRequest('GET', '/movie-nights/$eventId')).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> updateMovieNight({
    required String eventId,
    MovieNightConstraints? constraints,
    MovieNightStatus? status,
  }) async {
    final payload = <String, dynamic>{};
    if (constraints != null) {
      payload['constraints'] = _encodeConstraints(constraints);
    }
    if (status != null) {
      payload['status'] = status.name;
    }
    final body = _decodeMap(
      (await _authorizedRequest(
        'PATCH',
        '/movie-nights/$eventId',
        body: payload,
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> refreshShortlist(String eventId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/movie-nights/$eventId/shortlist',
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> joinMovieNight(String eventId) async {
    final body = _decodeMap(
      (await _authorizedRequest('POST', '/movie-nights/$eventId/join')).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<bool> leaveMovieNight(String eventId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'DELETE',
        '/movie-nights/$eventId/participants/me',
      )).body,
    );
    return body['ok'] == true;
  }

  Future<MovieNightEvent> submitVote({
    required String eventId,
    required String movieId,
    required MovieNightVoteValue vote,
  }) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/movie-nights/$eventId/votes',
        body: <String, dynamic>{'movieId': movieId, 'vote': vote.name},
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> createInviteLink(String eventId) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/movie-nights/$eventId/invite-link',
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> inviteFriends({
    required String eventId,
    required List<String> friendIds,
  }) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'POST',
        '/movie-nights/$eventId/invite',
        body: <String, dynamic>{'friendIds': friendIds},
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  Future<MovieNightEvent> deleteVote({
    required String eventId,
    required String movieId,
  }) async {
    final body = _decodeMap(
      (await _authorizedRequest(
        'DELETE',
        '/movie-nights/$eventId/votes/$movieId',
      )).body,
    );
    return _decodeMovieNightEvent(_castMap(body['event']));
  }

  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _authService.readToken();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Missing access token for authenticated social request.',
      );
    }

    final encodedBody = body == null ? null : jsonEncode(body);

    var response = await _send(method, path, token, encodedBody);

    // Transparently recover from an expired access token: refresh once and retry.
    if (response.statusCode == 401) {
      final refreshed = await _authService.refreshAccessToken();
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await _send(method, path, refreshed, encodedBody);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Social backend request failed: ${response.statusCode} ${response.body}',
      );
    }
    return response;
  }

  Future<http.Response> _send(
    String method,
    String path,
    String token,
    String? encodedBody,
  ) {
    final uri = Uri.parse('${_config.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(_requestTimeout);
      case 'POST':
        return _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout);
      case 'PATCH':
        return _client
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout);
      case 'DELETE':
        return _client.delete(uri, headers: headers).timeout(_requestTimeout);
      default:
        throw UnsupportedError('Unsupported method $method');
    }
  }

  List<Friend> _decodeFriends(Object? value) {
    if (value is! List) return const <Friend>[];
    return value
        .whereType<Map>()
        .map((entry) => _decodeFriend(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Friend _decodeFriend(Map<String, dynamic> json) {
    return Friend(
      id: _string(json['id']),
      name: _string(json['name'], 'Agreeo user'),
      avatarUrl: _string(json['avatarUrl']),
      watchedCount: _int(json['watchedCount']),
      reviewsCount: _int(json['reviewsCount']),
      privacySettings: _decodePrivacy(_castMap(json['privacySettings'])),
      bio: _string(json['bio']),
    );
  }

  PrivacySettings _decodePrivacy(Map<String, dynamic> json) {
    return PrivacySettings(
      canShowWatched: json['canShowWatched'] != false,
      canShowReviews: json['canShowReviews'] != false,
      canShowWatchlist: json['canShowWatchlist'] == true,
    );
  }

  List<FriendRequest> _decodeFriendRequests(Object? value) {
    if (value is! List) return const <FriendRequest>[];
    return value
        .whereType<Map>()
        .map((entry) => _decodeFriendRequest(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  FriendRequest _decodeFriendRequest(Map<String, dynamic> json) {
    return FriendRequest(
      id: _string(json['id']),
      fromUser: _decodeFriend(_castMap(json['fromUser'])),
      toUserId: _string(json['toUserId']),
      status: _friendRequestStatus(json['status']),
      createdAt: _date(json['createdAt']),
    );
  }

  FriendProfile _decodeFriendProfile(Map<String, dynamic> json) {
    return FriendProfile(
      friend: _decodeFriend(_castMap(json['friend'])),
      watchedMovies: _decodeMovieList(json['watchedMovies']),
      reviews: _decodeReviews(json['reviews']),
      watchlist: _decodeMovieList(json['watchlist']),
    );
  }

  List<FriendMovieReview> _decodeReviews(Object? value) {
    if (value is! List) return const <FriendMovieReview>[];
    return value
        .whereType<Map>()
        .map((entry) {
          final json = entry.cast<String, dynamic>();
          return FriendMovieReview(
            movie: _decodeMovie(_castMap(json['movie'])),
            rating: _int(json['rating']),
            reviewPreview: _string(json['reviewPreview']),
            date: _date(json['date']),
          );
        })
        .toList(growable: false);
  }

  List<MovieNightEvent> _decodeMovieNightEvents(Object? value) {
    if (value is! List) return const <MovieNightEvent>[];
    return value
        .whereType<Map>()
        .map((entry) => _decodeMovieNightEvent(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  MovieNightEvent decodeMovieNightEvent(Map<String, dynamic> json) {
    return _decodeMovieNightEvent(json);
  }

  MovieNightEvent _decodeMovieNightEvent(Map<String, dynamic> json) {
    return MovieNightEvent(
      id: _string(json['id']),
      name: _string(json['name'], 'Movie Night'),
      hostUserId: _string(json['hostUserId']),
      dateTime: _nullableDate(json['dateTime']),
      constraints: _decodeConstraints(_castMap(json['constraints'])),
      participants: _decodeParticipants(json['participants']),
      inviteLink: _string(json['inviteLink']),
      status: _movieNightStatus(json['status']),
      shortlist: _decodeShortlist(json['shortlist']),
      winnerMovieId: _nullableString(json['winnerMovieId']),
      votes: _decodeVotes(json['votes']),
      createdAt: _date(json['createdAt']),
      updatedAt: _date(json['updatedAt']),
      votedUserIds: _stringList(json['votedUserIds']),
      round: _nullableInt(json['round']) ?? 1,
    );
  }

  MovieNightConstraints _decodeConstraints(Map<String, dynamic> json) {
    return MovieNightConstraints(
      includedGenres: _stringList(json['includedGenres']),
      excludedGenres: _stringList(json['excludedGenres']),
      maxDurationMinutes: _nullableInt(json['maxDurationMinutes']),
      minimumRating: _nullableDouble(json['minimumRating']),
      language: _nullableString(json['language']),
    );
  }

  Map<String, dynamic> _encodeConstraints(MovieNightConstraints constraints) {
    return <String, dynamic>{
      'includedGenres': constraints.includedGenres,
      'excludedGenres': constraints.excludedGenres,
      'maxDurationMinutes': constraints.maxDurationMinutes,
      'minimumRating': constraints.minimumRating,
      'language': constraints.language,
    };
  }

  List<MovieNightParticipant> _decodeParticipants(Object? value) {
    if (value is! List) return const <MovieNightParticipant>[];
    return value
        .whereType<Map>()
        .map((entry) {
          final json = entry.cast<String, dynamic>();
          return MovieNightParticipant(
            userId: _string(json['userId']),
            name: _string(json['name'], 'Agreeo user'),
            avatarUrl: _string(json['avatarUrl']),
            status: _participantStatus(json['status']),
            isHost: json['isHost'] == true,
          );
        })
        .toList(growable: false);
  }

  List<ShortlistCandidate> _decodeShortlist(Object? value) {
    if (value is! List) return const <ShortlistCandidate>[];
    return value
        .whereType<Map>()
        .map((entry) {
          final json = entry.cast<String, dynamic>();
          return ShortlistCandidate(
            movie: _decodeMovie(_castMap(json['movie'])),
            compatibilityScore: _double(json['compatibilityScore']),
            explanationTags: _stringList(json['explanationTags']),
            scoreBreakdown: _decodeScoreBreakdown(
              _castMap(json['scoreBreakdown']),
            ),
            voteScore: _nullableDouble(json['voteScore']),
            finalScore: _nullableDouble(json['finalScore']),
            likesCount: _nullableInt(json['likesCount']),
            dislikesCount: _nullableInt(json['dislikesCount']),
            eliminated: json['eliminated'] == true,
          );
        })
        .toList(growable: false);
  }

  ScoreBreakdown _decodeScoreBreakdown(Map<String, dynamic> json) {
    return ScoreBreakdown(
      watchlistSaves: _int(json['watchlistSaves']),
      likes: _int(json['likes']),
      dislikes: _int(json['dislikes']),
      watched: _int(json['watched']),
      positiveRatings: _int(json['positiveRatings']),
      includedGenreMatches: _int(json['includedGenreMatches']),
      groupBonus: _double(json['groupBonus']),
      groupPenalty: _double(json['groupPenalty']),
      total: _double(json['total']),
    );
  }

  List<MovieNightVote> _decodeVotes(Object? value) {
    if (value is! List) return const <MovieNightVote>[];
    return value
        .whereType<Map>()
        .map((entry) {
          final json = entry.cast<String, dynamic>();
          return MovieNightVote(
            eventId: _string(json['eventId']),
            userId: _string(json['userId']),
            movieId: _string(json['movieId']),
            vote: _voteValue(json['vote']),
            createdAt: _date(json['createdAt']),
          );
        })
        .toList(growable: false);
  }

  List<Movie> _decodeMovieList(Object? value) {
    if (value is! List) return const <Movie>[];
    return value
        .whereType<Map>()
        .map((entry) => _decodeMovie(entry.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Movie _decodeMovie(Map<String, dynamic> json) {
    final tmdbId = _nullableInt(json['tmdbId']);
    final releaseDate = _string(json['releaseDate']);
    final year =
        DateTime.tryParse(releaseDate)?.year ?? _int(json['releaseYear']);
    final movieLens = _castMap(json['movieLens']);
    final rating =
        _nullableDouble(json['voteAverage']) ??
        ((_nullableDouble(movieLens['avgRating']) ?? 0) * 2);
    var posterUrl = _string(json['posterUrl']);
    final posterPath = _nullableString(json['posterPath']);
    if (posterUrl.isEmpty && posterPath != null && posterPath.isNotEmpty) {
      posterUrl = 'https://image.tmdb.org/t/p/w780$posterPath';
    } else if (posterUrl.isNotEmpty && !posterUrl.startsWith('http')) {
      posterUrl = 'https://image.tmdb.org/t/p/w780$posterUrl';
    }

    var backdropUrl = _string(json['backdropUrl']);
    final backdropPath = _nullableString(json['backdropPath']);
    if (backdropUrl.isEmpty &&
        backdropPath != null &&
        backdropPath.isNotEmpty) {
      backdropUrl = 'https://image.tmdb.org/t/p/w1280$backdropPath';
    } else if (backdropUrl.isNotEmpty && !backdropUrl.startsWith('http')) {
      backdropUrl = 'https://image.tmdb.org/t/p/w1280$backdropUrl';
    }

    return Movie(
      id: tmdbId == null ? _string(json['id']) : 'tmdb-$tmdbId',
      tmdbId: tmdbId,
      title: _string(json['title']),
      originalTitle: _string(json['originalTitle'], _string(json['title'])),
      overview: _string(json['overview']),
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      releaseYear: year,
      runtime: _int(json['runtime']),
      genres: _stringList(json['genres']),
      director: _string(json['director']),
      cast: _stringList(json['cast']),
      rating: rating,
      mediaType: CatalogMediaType.movie,
      trailerUrl: _string(json['trailerUrl']),
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    return _castMap(jsonDecode(body));
  }

  Map<String, dynamic> _castMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  String _string(Object? value, [String fallback = '']) {
    final text = value?.toString() ?? fallback;
    return text.isEmpty ? fallback : text;
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  int _int(Object? value) => _nullableInt(value) ?? 0;

  int? _nullableInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double _double(Object? value) => _nullableDouble(value) ?? 0;

  double? _nullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  DateTime _date(Object? value) {
    return _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _nullableDate(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  FriendRequestStatus _friendRequestStatus(Object? value) {
    return FriendRequestStatus.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => FriendRequestStatus.pending,
    );
  }

  MovieNightStatus _movieNightStatus(Object? value) {
    return MovieNightStatus.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => MovieNightStatus.waiting,
    );
  }

  MovieNightParticipantStatus _participantStatus(Object? value) {
    return MovieNightParticipantStatus.values.firstWhere(
      (status) => status.name == value?.toString(),
      orElse: () => MovieNightParticipantStatus.pending,
    );
  }

  MovieNightVoteValue _voteValue(Object? value) {
    return MovieNightVoteValue.values.firstWhere(
      (vote) => vote.name == value?.toString(),
      orElse: () => MovieNightVoteValue.neutral,
    );
  }

  Future<List<InAppNotification>> loadNotifications() async {
    try {
      final response = await _authorizedRequest('GET', '/notifications');
      final body = _decodeMap(response.body);
      final list = body['notifications'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map(
              (item) =>
                  InAppNotification.fromJson(item.cast<String, dynamic>()),
            )
            .toList();
      }
    } catch (e) {
      // ignore
    }
    return const <InAppNotification>[];
  }

  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final response = await _authorizedRequest(
        'POST',
        '/notifications/$notificationId/read',
      );
      final body = _decodeMap(response.body);
      return body['ok'] == true;
    } catch (e) {
      return false;
    }
  }
}
