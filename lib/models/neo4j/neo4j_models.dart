import 'package:agreeo/models/app_models.dart';

class Neo4jMovie {
  Neo4jMovie({
    required this.tmdbId,
    required this.title,
    required this.overview,
    required this.posterUrl,
    required this.releaseYear,
    required this.runtimeMinutes,
    required this.genres,
    required this.streamingServices,
    required this.mediaType,
    required this.trailerUrl,
    required this.score,
  });

  final String tmdbId;
  final String title;
  final String overview;
  final String posterUrl;
  final int releaseYear;
  final int runtimeMinutes;
  final List<String> genres;
  final List<String> streamingServices;
  final String mediaType;
  final String trailerUrl;
  final double score;

  Map<String, dynamic> toProperties() => {
        'tmdbId': tmdbId,
        'title': title,
        'overview': overview,
        'posterUrl': posterUrl,
        'releaseYear': releaseYear,
        'runtimeMinutes': runtimeMinutes,
        'genres': genres,
        'streamingServices': streamingServices,
        'mediaType': mediaType,
        'trailerUrl': trailerUrl,
        'score': score,
      };

  static Neo4jMovie fromMovie(Movie movie) {
    return Neo4jMovie(
      tmdbId: movie.id,
      title: movie.title,
      overview: movie.overview,
      posterUrl: movie.posterUrl,
      releaseYear: movie.releaseYear,
      runtimeMinutes: movie.runtimeMinutes,
      genres: movie.genres,
      streamingServices: movie.streamingServices,
      mediaType: movie.mediaType.name,
      trailerUrl: movie.trailerUrl,
      score: movie.score,
    );
  }

  Movie toMovie() {
    return Movie(
      id: tmdbId,
      title: title,
      overview: overview,
      posterUrl: posterUrl,
      releaseYear: releaseYear,
      runtimeMinutes: runtimeMinutes,
      genres: genres,
      streamingServices: streamingServices,
      mediaType: mediaType == 'series'
          ? MediaType.series
          : MediaType.movie,
      trailerUrl: trailerUrl,
      score: score,
    );
  }
}

class Neo4jUser {
  Neo4jUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.isGuest,
    required this.createdAt,
    this.passwordHash,
  });

  final String uid;
  final String displayName;
  final String email;
  final bool isGuest;
  final String createdAt;
  final String? passwordHash;

  Map<String, dynamic> toProperties() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'isGuest': isGuest,
        'createdAt': createdAt,
        if (passwordHash != null) 'passwordHash': passwordHash,
      };

  static Neo4jUser fromAppSession(AppSession session) {
    return Neo4jUser(
      uid: session.uid,
      displayName: session.displayName,
      email: session.email,
      isGuest: session.isGuest,
      createdAt: session.createdAt.toIso8601String(),
    );
  }
}

class Neo4jUserPreferences {
  Neo4jUserPreferences({
    required this.uid,
    required this.favoriteGenres,
    required this.streamingServices,
    required this.dailyRecommendationsEnabled,
    required this.onboardingComplete,
    required this.darkModeEnabled,
  });

  final String uid;
  final List<String> favoriteGenres;
  final List<String> streamingServices;
  final bool dailyRecommendationsEnabled;
  final bool onboardingComplete;
  final bool darkModeEnabled;

  Map<String, dynamic> toProperties() => {
        'uid': uid,
        'favoriteGenres': favoriteGenres,
        'streamingServices': streamingServices,
        'dailyRecommendationsEnabled': dailyRecommendationsEnabled,
        'onboardingComplete': onboardingComplete,
        'darkModeEnabled': darkModeEnabled,
      };

  static Neo4jUserPreferences fromPreferences(
      String uid, UserPreferences prefs) {
    return Neo4jUserPreferences(
      uid: uid,
      favoriteGenres: prefs.favoriteGenres,
      streamingServices: prefs.streamingServices,
      dailyRecommendationsEnabled: prefs.dailyRecommendationsEnabled,
      onboardingComplete: prefs.onboardingComplete,
      darkModeEnabled: prefs.darkModeEnabled,
    );
  }
}

class Neo4jGroup {
  Neo4jGroup({
    required this.groupId,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.createdAt,
  });

  final String groupId;
  final String name;
  final String inviteCode;
  final String ownerId;
  final String createdAt;

  Map<String, dynamic> toProperties() => {
        'groupId': groupId,
        'name': name,
        'inviteCode': inviteCode,
        'ownerId': ownerId,
        'createdAt': createdAt,
      };

  static Neo4jGroup fromGroup(MovieGroup group) {
    return Neo4jGroup(
      groupId: group.id,
      name: group.name,
      inviteCode: group.inviteCode,
      ownerId: group.ownerId,
      createdAt: group.createdAt.toIso8601String(),
    );
  }
}

class Neo4jEvent {
  Neo4jEvent({
    required this.eventId,
    required this.groupId,
    required this.groupName,
    required this.creatorId,
    required this.format,
    required this.includeGenres,
    required this.excludeGenres,
    required this.maxDurationMinutes,
    required this.createdAt,
    required this.resolvedMovieId,
  });

  final String eventId;
  final String groupId;
  final String groupName;
  final String creatorId;
  final String format;
  final List<String> includeGenres;
  final List<String> excludeGenres;
  final int maxDurationMinutes;
  final String createdAt;
  final String? resolvedMovieId;

  Map<String, dynamic> toProperties() => {
        'eventId': eventId,
        'groupId': groupId,
        'groupName': groupName,
        'creatorId': creatorId,
        'format': format,
        'includeGenres': includeGenres,
        'excludeGenres': excludeGenres,
        'maxDurationMinutes': maxDurationMinutes,
        'createdAt': createdAt,
        'resolvedMovieId': resolvedMovieId,
      };

  static Neo4jEvent fromEvent(MovieEvent event) {
    return Neo4jEvent(
      eventId: event.id,
      groupId: event.groupId,
      groupName: event.groupName,
      creatorId: event.creatorId,
      format: event.constraints.format.name,
      includeGenres: event.constraints.includeGenres,
      excludeGenres: event.constraints.excludeGenres,
      maxDurationMinutes: event.constraints.maxDurationMinutes,
      createdAt: event.createdAt.toIso8601String(),
      resolvedMovieId: event.resolvedMovieId,
    );
  }
}

class Neo4jVote {
  Neo4jVote({
    required this.voteId,
    required this.eventId,
    required this.movieId,
    required this.userId,
    required this.choice,
    required this.createdAt,
  });

  final String voteId;
  final String eventId;
  final String movieId;
  final String userId;
  final String choice;
  final String createdAt;

  Map<String, dynamic> toProperties() => {
        'voteId': voteId,
        'eventId': eventId,
        'movieId': movieId,
        'userId': userId,
        'choice': choice,
        'createdAt': createdAt,
      };

  static Neo4jVote fromVote(EventVote vote) {
    return Neo4jVote(
      voteId: vote.id,
      eventId: vote.eventId,
      movieId: vote.movieId,
      userId: vote.userId,
      choice: vote.choice.name,
      createdAt: vote.createdAt.toIso8601String(),
    );
  }
}
