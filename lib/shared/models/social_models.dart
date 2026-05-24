import 'package:agreeo/shared/models/agreeo_models.dart';

enum FriendRequestStatus { pending, accepted, declined }

enum MovieNightStatus { draft, waiting, voting, completed }

enum MovieNightParticipantStatus { joined, pending }

enum MovieNightVoteValue { like, dislike, alreadySeen, neutral }

class PrivacySettings {
  const PrivacySettings({
    required this.canShowWatched,
    required this.canShowReviews,
    required this.canShowWatchlist,
  });

  final bool canShowWatched;
  final bool canShowReviews;
  final bool canShowWatchlist;

  factory PrivacySettings.open() {
    return const PrivacySettings(
      canShowWatched: true,
      canShowReviews: true,
      canShowWatchlist: true,
    );
  }
}

class Friend {
  const Friend({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.watchedCount,
    required this.reviewsCount,
    required this.privacySettings,
    this.bio = '',
  });

  final String id;
  final String name;
  final String avatarUrl;
  final int watchedCount;
  final int reviewsCount;
  final PrivacySettings privacySettings;
  final String bio;

  String get initials {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'A';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Friend copyWith({
    int? watchedCount,
    int? reviewsCount,
    PrivacySettings? privacySettings,
    String? bio,
  }) {
    return Friend(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      watchedCount: watchedCount ?? this.watchedCount,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      privacySettings: privacySettings ?? this.privacySettings,
      bio: bio ?? this.bio,
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUser,
    required this.toUserId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final Friend fromUser;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime createdAt;
}

class FriendMovieReview {
  const FriendMovieReview({
    required this.movie,
    required this.rating,
    required this.reviewPreview,
    required this.date,
  });

  final Movie movie;
  final int rating;
  final String reviewPreview;
  final DateTime date;
}

class FriendProfile {
  const FriendProfile({
    required this.friend,
    required this.watchedMovies,
    required this.reviews,
    required this.watchlist,
  });

  final Friend friend;
  final List<Movie> watchedMovies;
  final List<FriendMovieReview> reviews;
  final List<Movie> watchlist;
}

class MovieNightConstraints {
  const MovieNightConstraints({
    required this.includedGenres,
    required this.excludedGenres,
    required this.maxDurationMinutes,
    required this.minimumRating,
    required this.language,
  });

  final List<String> includedGenres;
  final List<String> excludedGenres;
  final int? maxDurationMinutes;
  final double? minimumRating;
  final String? language;

  factory MovieNightConstraints.empty() {
    return const MovieNightConstraints(
      includedGenres: <String>[],
      excludedGenres: <String>[],
      maxDurationMinutes: 150,
      minimumRating: null,
      language: null,
    );
  }

  bool get hasGenreConflict {
    return includedGenres.any(excludedGenres.contains);
  }

  bool matches(Movie movie) {
    if (movie.mediaType != CatalogMediaType.movie) {
      return false;
    }
    if (includedGenres.isNotEmpty &&
        !movie.genres.any(includedGenres.contains)) {
      return false;
    }
    if (movie.genres.any(excludedGenres.contains)) {
      return false;
    }
    if (maxDurationMinutes != null &&
        maxDurationMinutes! > 0 &&
        movie.runtime > maxDurationMinutes!) {
      return false;
    }
    if (minimumRating != null && movie.rating < minimumRating!) {
      return false;
    }
    return true;
  }

  MovieNightConstraints copyWith({
    List<String>? includedGenres,
    List<String>? excludedGenres,
    int? maxDurationMinutes,
    bool clearMaxDurationMinutes = false,
    double? minimumRating,
    bool clearMinimumRating = false,
    String? language,
    bool clearLanguage = false,
  }) {
    return MovieNightConstraints(
      includedGenres: includedGenres ?? this.includedGenres,
      excludedGenres: excludedGenres ?? this.excludedGenres,
      maxDurationMinutes: clearMaxDurationMinutes
          ? null
          : maxDurationMinutes ?? this.maxDurationMinutes,
      minimumRating: clearMinimumRating
          ? null
          : minimumRating ?? this.minimumRating,
      language: clearLanguage ? null : language ?? this.language,
    );
  }
}

class MovieNightParticipant {
  const MovieNightParticipant({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.isHost,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final MovieNightParticipantStatus status;
  final bool isHost;

  bool get joined => status == MovieNightParticipantStatus.joined;

  String get initials {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'A';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.watchlistSaves,
    required this.likes,
    required this.dislikes,
    required this.watched,
    required this.positiveRatings,
    required this.includedGenreMatches,
    required this.groupBonus,
    required this.groupPenalty,
    required this.total,
  });

  final int watchlistSaves;
  final int likes;
  final int dislikes;
  final int watched;
  final int positiveRatings;
  final int includedGenreMatches;
  final double groupBonus;
  final double groupPenalty;
  final double total;
}

class ShortlistCandidate {
  const ShortlistCandidate({
    required this.movie,
    required this.compatibilityScore,
    required this.explanationTags,
    required this.scoreBreakdown,
    this.voteScore,
    this.finalScore,
    this.likesCount,
    this.dislikesCount,
    this.eliminated = false,
  });

  final Movie movie;
  final double compatibilityScore;
  final List<String> explanationTags;
  final ScoreBreakdown scoreBreakdown;
  final double? voteScore;
  final double? finalScore;
  final int? likesCount;
  final int? dislikesCount;
  final bool eliminated;
}

class MovieNightVote {
  const MovieNightVote({
    required this.eventId,
    required this.userId,
    required this.movieId,
    required this.vote,
    required this.createdAt,
  });

  final String eventId;
  final String userId;
  final String movieId;
  final MovieNightVoteValue vote;
  final DateTime createdAt;
}

class MovieNightEvent {
  const MovieNightEvent({
    required this.id,
    required this.name,
    required this.hostUserId,
    required this.dateTime,
    required this.constraints,
    required this.participants,
    required this.inviteLink,
    required this.status,
    required this.shortlist,
    required this.winnerMovieId,
    required this.votes,
    required this.createdAt,
    required this.updatedAt,
    this.votedUserIds = const <String>[],
    this.round = 1,
  });

  final String id;
  final String name;
  final String hostUserId;
  final DateTime? dateTime;
  final MovieNightConstraints constraints;
  final List<MovieNightParticipant> participants;
  final String inviteLink;
  final MovieNightStatus status;
  final List<ShortlistCandidate> shortlist;
  final String? winnerMovieId;
  final List<MovieNightVote> votes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> votedUserIds;
  final int round;

  String get contentTypeLabel => 'Movie';

  bool get isCompleted => status == MovieNightStatus.completed;

  List<MovieNightParticipant> get joinedParticipants {
    return participants.where((participant) => participant.joined).toList();
  }

  ShortlistCandidate? get winnerCandidate {
    final id = winnerMovieId;
    if (id == null) {
      return null;
    }
    for (final candidate in shortlist) {
      if (candidate.movie.id == id) {
        return candidate;
      }
    }
    return null;
  }

  int votesForMovieFromJoined(String movieId) {
    final joinedIds = joinedParticipants
        .map((participant) => participant.userId)
        .toSet();
    return votes
        .where(
          (vote) => vote.movieId == movieId && joinedIds.contains(vote.userId),
        )
        .map((vote) => vote.userId)
        .toSet()
        .length;
  }

  MovieNightEvent copyWith({
    String? name,
    DateTime? dateTime,
    bool clearDateTime = false,
    MovieNightConstraints? constraints,
    List<MovieNightParticipant>? participants,
    String? inviteLink,
    MovieNightStatus? status,
    List<ShortlistCandidate>? shortlist,
    String? winnerMovieId,
    bool clearWinnerMovieId = false,
    List<MovieNightVote>? votes,
    DateTime? updatedAt,
    List<String>? votedUserIds,
    int? round,
  }) {
    return MovieNightEvent(
      id: id,
      name: name ?? this.name,
      hostUserId: hostUserId,
      dateTime: clearDateTime ? null : dateTime ?? this.dateTime,
      constraints: constraints ?? this.constraints,
      participants: participants ?? this.participants,
      inviteLink: inviteLink ?? this.inviteLink,
      status: status ?? this.status,
      shortlist: shortlist ?? this.shortlist,
      winnerMovieId: clearWinnerMovieId
          ? null
          : winnerMovieId ?? this.winnerMovieId,
      votes: votes ?? this.votes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      votedUserIds: votedUserIds ?? this.votedUserIds,
      round: round ?? this.round,
    );
  }
}
