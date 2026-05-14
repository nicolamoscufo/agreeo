enum CatalogMediaType { movie, tv }

extension CatalogMediaTypeX on CatalogMediaType {
  String get label => this == CatalogMediaType.movie ? 'Movie' : 'TV Series';

  static CatalogMediaType fromJson(Object? value) {
    return CatalogMediaType.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => CatalogMediaType.movie,
    );
  }
}

enum MoviePreference { liked, disliked, neutral }

extension MoviePreferenceX on MoviePreference {
  static MoviePreference fromJson(Object? value) {
    return MoviePreference.values.firstWhere(
      (item) => item.name == value?.toString(),
      orElse: () => MoviePreference.neutral,
    );
  }
}

enum LibrarySort { recent, title, rating, year }

extension LibrarySortX on LibrarySort {
  String get label {
    switch (this) {
      case LibrarySort.recent:
        return 'Recently added';
      case LibrarySort.title:
        return 'Title';
      case LibrarySort.rating:
        return 'Rating';
      case LibrarySort.year:
        return 'Year';
    }
  }
}

String _stringValue(Object? value, [String fallback = '']) {
  return value?.toString() ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const <String>[];
}

DateTime _dateValue(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class Movie {
  const Movie({
    required this.id,
    required this.tmdbId,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.posterUrl,
    required this.backdropUrl,
    required this.releaseYear,
    required this.runtime,
    required this.genres,
    required this.director,
    required this.cast,
    required this.rating,
    required this.mediaType,
    required this.trailerUrl,
  });

  final String id;
  final int? tmdbId;
  final String title;
  final String originalTitle;
  final String overview;
  final String posterUrl;
  final String backdropUrl;
  final int releaseYear;
  final int runtime;
  final List<String> genres;
  final String director;
  final List<String> cast;
  final double rating;
  final CatalogMediaType mediaType;
  final String trailerUrl;

  String get typeLabel => mediaType.label;
  String get runtimeLabel => '${runtime}m';
  String get yearLabel =>
      releaseYear > 0 ? releaseYear.toString() : 'Unknown year';

  String get subtitleLine => '$yearLabel • ${runtime}m • ${mediaType.label}';

  Movie copyWith({
    String? id,
    int? tmdbId,
    String? title,
    String? originalTitle,
    String? overview,
    String? posterUrl,
    String? backdropUrl,
    int? releaseYear,
    int? runtime,
    List<String>? genres,
    String? director,
    List<String>? cast,
    double? rating,
    CatalogMediaType? mediaType,
    String? trailerUrl,
  }) {
    return Movie(
      id: id ?? this.id,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      overview: overview ?? this.overview,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      releaseYear: releaseYear ?? this.releaseYear,
      runtime: runtime ?? this.runtime,
      genres: genres ?? this.genres,
      director: director ?? this.director,
      cast: cast ?? this.cast,
      rating: rating ?? this.rating,
      mediaType: mediaType ?? this.mediaType,
      trailerUrl: trailerUrl ?? this.trailerUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'tmdbId': tmdbId,
      'title': title,
      'originalTitle': originalTitle,
      'overview': overview,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'releaseYear': releaseYear,
      'runtime': runtime,
      'genres': genres,
      'director': director,
      'cast': cast,
      'rating': rating,
      'mediaType': mediaType.name,
      'trailerUrl': trailerUrl,
    };
  }

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: _stringValue(json['id']),
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      title: _stringValue(json['title']),
      originalTitle: _stringValue(json['originalTitle']),
      overview: _stringValue(json['overview']),
      posterUrl: _stringValue(json['posterUrl']),
      backdropUrl: _stringValue(json['backdropUrl']),
      releaseYear: (json['releaseYear'] as num?)?.toInt() ?? 2025,
      runtime: (json['runtime'] as num?)?.toInt() ?? 110,
      genres: _stringList(json['genres']),
      director: _stringValue(json['director']),
      cast: _stringList(json['cast']),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      mediaType: CatalogMediaTypeX.fromJson(json['mediaType']),
      trailerUrl: _stringValue(json['trailerUrl']),
    );
  }
}

class MovieSearchFilters {
  const MovieSearchFilters({
    this.mediaType,
    this.genre,
    this.maxRuntimeMinutes,
    this.minReleaseYear,
    this.minRating,
  });

  final CatalogMediaType? mediaType;
  final String? genre;
  final int? maxRuntimeMinutes;
  final int? minReleaseYear;
  final double? minRating;

  bool get hasActiveFilters {
    return mediaType != null ||
        genre != null ||
        maxRuntimeMinutes != null ||
        minReleaseYear != null ||
        minRating != null;
  }

  MovieSearchFilters copyWith({
    CatalogMediaType? mediaType,
    bool clearMediaType = false,
    String? genre,
    bool clearGenre = false,
    int? maxRuntimeMinutes,
    bool clearMaxRuntimeMinutes = false,
    int? minReleaseYear,
    bool clearMinReleaseYear = false,
    double? minRating,
    bool clearMinRating = false,
  }) {
    return MovieSearchFilters(
      mediaType: clearMediaType ? null : mediaType ?? this.mediaType,
      genre: clearGenre ? null : genre ?? this.genre,
      maxRuntimeMinutes: clearMaxRuntimeMinutes
          ? null
          : maxRuntimeMinutes ?? this.maxRuntimeMinutes,
      minReleaseYear: clearMinReleaseYear
          ? null
          : minReleaseYear ?? this.minReleaseYear,
      minRating: clearMinRating ? null : minRating ?? this.minRating,
    );
  }

  bool matches(Movie movie) {
    if (mediaType != null && movie.mediaType != mediaType) {
      return false;
    }
    if (genre != null && !movie.genres.contains(genre)) {
      return false;
    }
    if (maxRuntimeMinutes != null && movie.runtime > maxRuntimeMinutes!) {
      return false;
    }
    if (minReleaseYear != null && movie.releaseYear < minReleaseYear!) {
      return false;
    }
    if (minRating != null && movie.rating < minRating!) {
      return false;
    }
    return true;
  }
}

class AgreeoUserSession {
  const AgreeoUserSession({
    required this.id,
    required this.displayName,
    required this.email,
    required this.bio,
    required this.joinedAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String bio;
  final DateTime joinedAt;

  String get initials {
    final parts = displayName
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

  AgreeoUserSession copyWith({
    String? id,
    String? displayName,
    String? email,
    String? bio,
    DateTime? joinedAt,
  }) {
    return AgreeoUserSession(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory AgreeoUserSession.fromJson(Map<String, dynamic> json) {
    return AgreeoUserSession(
      id: _stringValue(json['id']),
      displayName: _stringValue(json['displayName'], 'Agreeo User'),
      email: _stringValue(json['email']),
      bio: _stringValue(json['bio']),
      joinedAt: _dateValue(json['joinedAt']),
    );
  }
}

class OnboardingState {
  const OnboardingState({
    required this.favoriteGenres,
    required this.favoriteMovieIds,
    required this.completed,
  });

  final List<String> favoriteGenres;
  final List<String> favoriteMovieIds;
  final bool completed;

  factory OnboardingState.initial() {
    return const OnboardingState(
      favoriteGenres: <String>[],
      favoriteMovieIds: <String>[],
      completed: false,
    );
  }

  OnboardingState copyWith({
    List<String>? favoriteGenres,
    List<String>? favoriteMovieIds,
    bool? completed,
  }) {
    return OnboardingState(
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      favoriteMovieIds: favoriteMovieIds ?? this.favoriteMovieIds,
      completed: completed ?? this.completed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'favoriteGenres': favoriteGenres,
      'favoriteMovieIds': favoriteMovieIds,
      'completed': completed,
    };
  }

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    return OnboardingState(
      favoriteGenres: _stringList(json['favoriteGenres']),
      favoriteMovieIds: _stringList(json['favoriteMovieIds']),
      completed: json['completed'] == true,
    );
  }
}

class ProfilePreferences {
  const ProfilePreferences({
    required this.showWatchedToFriends,
    required this.showLikedToFriends,
    required this.showWatchlistToFriends,
    required this.showReviewsToFriends,
    required this.dailySuggestionReminder,
    required this.movieNightInvites,
    required this.votingStarted,
    required this.finalDecisionReached,
  });

  final bool showWatchedToFriends;
  final bool showLikedToFriends;
  final bool showWatchlistToFriends;
  final bool showReviewsToFriends;
  final bool dailySuggestionReminder;
  final bool movieNightInvites;
  final bool votingStarted;
  final bool finalDecisionReached;

  factory ProfilePreferences.initial() {
    return const ProfilePreferences(
      showWatchedToFriends: true,
      showLikedToFriends: true,
      showWatchlistToFriends: false,
      showReviewsToFriends: true,
      dailySuggestionReminder: true,
      movieNightInvites: true,
      votingStarted: true,
      finalDecisionReached: true,
    );
  }

  ProfilePreferences copyWith({
    bool? showWatchedToFriends,
    bool? showLikedToFriends,
    bool? showWatchlistToFriends,
    bool? showReviewsToFriends,
    bool? dailySuggestionReminder,
    bool? movieNightInvites,
    bool? votingStarted,
    bool? finalDecisionReached,
  }) {
    return ProfilePreferences(
      showWatchedToFriends: showWatchedToFriends ?? this.showWatchedToFriends,
      showLikedToFriends: showLikedToFriends ?? this.showLikedToFriends,
      showWatchlistToFriends:
          showWatchlistToFriends ?? this.showWatchlistToFriends,
      showReviewsToFriends: showReviewsToFriends ?? this.showReviewsToFriends,
      dailySuggestionReminder:
          dailySuggestionReminder ?? this.dailySuggestionReminder,
      movieNightInvites: movieNightInvites ?? this.movieNightInvites,
      votingStarted: votingStarted ?? this.votingStarted,
      finalDecisionReached: finalDecisionReached ?? this.finalDecisionReached,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'showWatchedToFriends': showWatchedToFriends,
      'showLikedToFriends': showLikedToFriends,
      'showWatchlistToFriends': showWatchlistToFriends,
      'showReviewsToFriends': showReviewsToFriends,
      'dailySuggestionReminder': dailySuggestionReminder,
      'movieNightInvites': movieNightInvites,
      'votingStarted': votingStarted,
      'finalDecisionReached': finalDecisionReached,
    };
  }

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) {
    return ProfilePreferences(
      showWatchedToFriends: json['showWatchedToFriends'] != false,
      showLikedToFriends: json['showLikedToFriends'] != false,
      showWatchlistToFriends: json['showWatchlistToFriends'] == true,
      showReviewsToFriends: json['showReviewsToFriends'] != false,
      dailySuggestionReminder: json['dailySuggestionReminder'] != false,
      movieNightInvites: json['movieNightInvites'] != false,
      votingStarted: json['votingStarted'] != false,
      finalDecisionReached: json['finalDecisionReached'] != false,
    );
  }
}

class UserMovieState {
  const UserMovieState({
    required this.movieId,
    required this.preference,
    required this.inWatchlist,
    required this.watched,
    required this.rating,
    required this.review,
    required this.updatedAt,
  });

  final String movieId;
  final MoviePreference preference;
  final bool inWatchlist;
  final bool watched;
  final int? rating;
  final String? review;
  final DateTime updatedAt;

  factory UserMovieState.initial(String movieId) {
    return UserMovieState(
      movieId: movieId,
      preference: MoviePreference.neutral,
      inWatchlist: false,
      watched: false,
      rating: null,
      review: null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  bool get isUntouched {
    return preference == MoviePreference.neutral &&
        !inWatchlist &&
        !watched &&
        rating == null &&
        (review == null || review!.trim().isEmpty);
  }

  bool get hasReview => review != null && review!.trim().isNotEmpty;

  UserMovieState copyWith({
    MoviePreference? preference,
    bool? inWatchlist,
    bool? watched,
    int? rating,
    bool clearRating = false,
    String? review,
    bool clearReview = false,
    DateTime? updatedAt,
  }) {
    return UserMovieState(
      movieId: movieId,
      preference: preference ?? this.preference,
      inWatchlist: inWatchlist ?? this.inWatchlist,
      watched: watched ?? this.watched,
      rating: clearRating ? null : rating ?? this.rating,
      review: clearReview ? null : review ?? this.review,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'movieId': movieId,
      'preference': preference.name,
      'inWatchlist': inWatchlist,
      'watched': watched,
      'rating': rating,
      'review': review,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserMovieState.fromJson(Map<String, dynamic> json) {
    return UserMovieState(
      movieId: _stringValue(json['movieId']),
      preference: MoviePreferenceX.fromJson(json['preference']),
      inWatchlist: json['inWatchlist'] == true,
      watched: json['watched'] == true,
      rating: (json['rating'] as num?)?.toInt(),
      review: json['review']?.toString(),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }
}

class UndoEntry {
  const UndoEntry({
    required this.movieId,
    required this.previousState,
    required this.nextState,
    required this.message,
  });

  final String movieId;
  final UserMovieState previousState;
  final UserMovieState nextState;
  final String message;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'movieId': movieId,
      'previousState': previousState.toJson(),
      'nextState': nextState.toJson(),
      'message': message,
    };
  }

  factory UndoEntry.fromJson(Map<String, dynamic> json) {
    return UndoEntry(
      movieId: _stringValue(json['movieId']),
      previousState: UserMovieState.fromJson(
        (json['previousState'] as Map).cast<String, dynamic>(),
      ),
      nextState: UserMovieState.fromJson(
        (json['nextState'] as Map).cast<String, dynamic>(),
      ),
      message: _stringValue(json['message']),
    );
  }
}
