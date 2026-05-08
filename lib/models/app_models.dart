import 'dart:convert';

List<String> _decodeList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList(growable: false);
    }
  }
  return const <String>[];
}

DateTime _decodeDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

String _encodeDateTime(DateTime value) => value.toIso8601String();

extension StringListNullSafe on Map<String, dynamic> {
  List<String> listOf(String key) => _decodeList(this[key]);
}

enum MediaType { movie, series }

enum FeedbackAction { like, dislike, seen, later }

enum VoteChoice { like, dislike }

extension MediaTypeX on MediaType {
  String get jsonValue => name;
  static MediaType fromJson(Object? value) {
    return MediaType.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => MediaType.movie,
    );
  }
}

extension FeedbackActionX on FeedbackAction {
  String get jsonValue => name;
  static FeedbackAction fromJson(Object? value) {
    return FeedbackAction.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => FeedbackAction.like,
    );
  }
}

extension VoteChoiceX on VoteChoice {
  String get jsonValue => name;
  static VoteChoice fromJson(Object? value) {
    return VoteChoice.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => VoteChoice.like,
    );
  }
}

class AppSession {
  const AppSession({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool isGuest;
  final DateTime createdAt;

  AppSession copyWith({
    String? uid,
    String? displayName,
    String? email,
    bool? isGuest,
    DateTime? createdAt,
  }) {
    return AppSession(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'isGuest': isGuest,
    'createdAt': _encodeDateTime(createdAt),
  };

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      uid: json['uid']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Agreeo user',
      email: json['email']?.toString() ?? '',
      isGuest: json['isGuest'] == true,
      createdAt: _decodeDateTime(json['createdAt']),
    );
  }
}

class UserPreferences {
  const UserPreferences({
    required this.favoriteGenres,
    required this.dailyRecommendationsEnabled,
    required this.onboardingComplete,
    required this.darkModeEnabled,
  });

  final List<String> favoriteGenres;
  final bool dailyRecommendationsEnabled;
  final bool onboardingComplete;
  final bool darkModeEnabled;

  factory UserPreferences.initial() {
    return const UserPreferences(
      favoriteGenres: <String>[],
      dailyRecommendationsEnabled: true,
      onboardingComplete: false,
      darkModeEnabled: false,
    );
  }

  UserPreferences copyWith({
    List<String>? favoriteGenres,
    bool? dailyRecommendationsEnabled,
    bool? onboardingComplete,
    bool? darkModeEnabled,
  }) {
    return UserPreferences(
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      dailyRecommendationsEnabled:
          dailyRecommendationsEnabled ?? this.dailyRecommendationsEnabled,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'favoriteGenres': favoriteGenres,
    'dailyRecommendationsEnabled': dailyRecommendationsEnabled,
    'onboardingComplete': onboardingComplete,
    'darkModeEnabled': darkModeEnabled,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      favoriteGenres: json.listOf('favoriteGenres'),
      dailyRecommendationsEnabled: json['dailyRecommendationsEnabled'] != false,
      onboardingComplete: json['onboardingComplete'] == true,
      darkModeEnabled: json['darkModeEnabled'] == true,
    );
  }
}

class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterUrl,
    required this.releaseYear,
    required this.runtimeMinutes,
    required this.genres,
    required this.mediaType,
    required this.trailerUrl,
    required this.score,
  });

  final String id;
  final String title;
  final String overview;
  final String posterUrl;
  final int releaseYear;
  final int runtimeMinutes;
  final List<String> genres;
  final MediaType mediaType;
  final String trailerUrl;
  final double score;

  bool get isSeries => mediaType == MediaType.series;
  String get typeLabel => isSeries ? 'Series' : 'Movie';

  Movie copyWith({
    String? id,
    String? title,
    String? overview,
    String? posterUrl,
    int? releaseYear,
    int? runtimeMinutes,
    List<String>? genres,
    MediaType? mediaType,
    String? trailerUrl,
    double? score,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      releaseYear: releaseYear ?? this.releaseYear,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      genres: genres ?? this.genres,
      mediaType: mediaType ?? this.mediaType,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'overview': overview,
    'posterUrl': posterUrl,
    'releaseYear': releaseYear,
    'runtimeMinutes': runtimeMinutes,
    'genres': genres,
    'mediaType': mediaType.name,
    'trailerUrl': trailerUrl,
    'score': score,
  };

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      posterUrl: json['posterUrl']?.toString() ?? '',
      releaseYear:
          (json['releaseYear'] as num?)?.toInt() ?? DateTime.now().year,
      runtimeMinutes: (json['runtimeMinutes'] as num?)?.toInt() ?? 0,
      genres: _decodeList(json['genres']),
      mediaType: MediaTypeX.fromJson(json['mediaType']),
      trailerUrl: json['trailerUrl']?.toString() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MovieFeedbackRecord {
  const MovieFeedbackRecord({
    required this.userId,
    required this.movieId,
    required this.action,
    required this.createdAt,
  });

  final String userId;
  final String movieId;
  final FeedbackAction action;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'movieId': movieId,
    'action': action.name,
    'createdAt': _encodeDateTime(createdAt),
  };

  factory MovieFeedbackRecord.fromJson(Map<String, dynamic> json) {
    return MovieFeedbackRecord(
      userId: json['userId']?.toString() ?? '',
      movieId: json['movieId']?.toString() ?? '',
      action: FeedbackActionX.fromJson(json['action']),
      createdAt: _decodeDateTime(json['createdAt']),
    );
  }
}

class MovieGroup {
  const MovieGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.memberIds,
    required this.sharedWatchlist,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final List<String> memberIds;
  final List<Movie> sharedWatchlist;
  final DateTime createdAt;

  MovieGroup copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? ownerId,
    List<String>? memberIds,
    List<Movie>? sharedWatchlist,
    DateTime? createdAt,
  }) {
    return MovieGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      sharedWatchlist: sharedWatchlist ?? this.sharedWatchlist,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'inviteCode': inviteCode,
    'ownerId': ownerId,
    'memberIds': memberIds,
    'sharedWatchlist': sharedWatchlist.map((movie) => movie.toJson()).toList(),
    'createdAt': _encodeDateTime(createdAt),
  };

  factory MovieGroup.fromJson(Map<String, dynamic> json) {
    final rawWatchlist = json['sharedWatchlist'];
    final watchlist = <Movie>[];
    if (rawWatchlist is List) {
      for (final item in rawWatchlist) {
        if (item is Map<String, dynamic>) {
          watchlist.add(Movie.fromJson(item));
        } else if (item is Map) {
          watchlist.add(Movie.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return MovieGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Group',
      inviteCode: json['inviteCode']?.toString() ?? '',
      ownerId: json['ownerId']?.toString() ?? '',
      memberIds: _decodeList(json['memberIds']),
      sharedWatchlist: watchlist,
      createdAt: _decodeDateTime(json['createdAt']),
    );
  }
}

class EventConstraints {
  const EventConstraints({
    required this.groupId,
    required this.format,
    required this.includeGenres,
    required this.excludeGenres,
    required this.maxDurationMinutes,
  });

  final String groupId;
  final MediaType format;
  final List<String> includeGenres;
  final List<String> excludeGenres;
  final int maxDurationMinutes;

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'format': format.name,
    'includeGenres': includeGenres,
    'excludeGenres': excludeGenres,
    'maxDurationMinutes': maxDurationMinutes,
  };

  factory EventConstraints.fromJson(Map<String, dynamic> json) {
    return EventConstraints(
      groupId: json['groupId']?.toString() ?? '',
      format: MediaTypeX.fromJson(json['format']),
      includeGenres: _decodeList(json['includeGenres']),
      excludeGenres: _decodeList(json['excludeGenres']),
      maxDurationMinutes: (json['maxDurationMinutes'] as num?)?.toInt() ?? 150,
    );
  }
}

class MovieEvent {
  const MovieEvent({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.creatorId,
    required this.constraints,
    required this.shortlist,
    required this.createdAt,
    required this.resolvedMovieId,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String creatorId;
  final EventConstraints constraints;
  final List<Movie> shortlist;
  final DateTime createdAt;
  final String? resolvedMovieId;

  bool get isResolved => resolvedMovieId != null;

  MovieEvent copyWith({
    String? id,
    String? groupId,
    String? groupName,
    String? creatorId,
    EventConstraints? constraints,
    List<Movie>? shortlist,
    DateTime? createdAt,
    String? resolvedMovieId,
  }) {
    return MovieEvent(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      creatorId: creatorId ?? this.creatorId,
      constraints: constraints ?? this.constraints,
      shortlist: shortlist ?? this.shortlist,
      createdAt: createdAt ?? this.createdAt,
      resolvedMovieId: resolvedMovieId ?? this.resolvedMovieId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'groupName': groupName,
    'creatorId': creatorId,
    'constraints': constraints.toJson(),
    'shortlist': shortlist.map((movie) => movie.toJson()).toList(),
    'createdAt': _encodeDateTime(createdAt),
    'resolvedMovieId': resolvedMovieId,
  };

  factory MovieEvent.fromJson(Map<String, dynamic> json) {
    final rawShortlist = json['shortlist'];
    final shortlist = <Movie>[];
    if (rawShortlist is List) {
      for (final item in rawShortlist) {
        if (item is Map<String, dynamic>) {
          shortlist.add(Movie.fromJson(item));
        } else if (item is Map) {
          shortlist.add(Movie.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    final constraints = json['constraints'] is Map<String, dynamic>
        ? EventConstraints.fromJson(json['constraints'] as Map<String, dynamic>)
        : EventConstraints(
            groupId: json['groupId']?.toString() ?? '',
            format: MediaType.movie,
            includeGenres: const <String>[],
            excludeGenres: const <String>[],
            maxDurationMinutes: 150,
          );

    return MovieEvent(
      id: json['id']?.toString() ?? '',
      groupId: json['groupId']?.toString() ?? '',
      groupName: json['groupName']?.toString() ?? 'Group',
      creatorId: json['creatorId']?.toString() ?? '',
      constraints: constraints,
      shortlist: shortlist,
      createdAt: _decodeDateTime(json['createdAt']),
      resolvedMovieId: json['resolvedMovieId']?.toString(),
    );
  }
}

class EventVote {
  const EventVote({
    required this.id,
    required this.eventId,
    required this.movieId,
    required this.userId,
    required this.choice,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String movieId;
  final String userId;
  final VoteChoice choice;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'movieId': movieId,
    'userId': userId,
    'choice': choice.name,
    'createdAt': _encodeDateTime(createdAt),
  };

  factory EventVote.fromJson(Map<String, dynamic> json) {
    return EventVote(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      movieId: json['movieId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      choice: VoteChoiceX.fromJson(json['choice']),
      createdAt: _decodeDateTime(json['createdAt']),
    );
  }
}
