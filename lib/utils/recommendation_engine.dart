import 'dart:math';

import 'package:agreeo/models/app_models.dart';

class RecommendationEngine {
  const RecommendationEngine();

  List<Movie> buildDailyQueue({
    required List<Movie> catalog,
    required UserPreferences preferences,
    required Iterable<MovieFeedbackRecord> feedback,
    DateTime? today,
    int limit = 7,
  }) {
    final excludedIds = feedback
        .where(
          (record) =>
              record.action == FeedbackAction.seen ||
              record.action == FeedbackAction.dislike,
        )
        .map((record) => record.movieId)
        .toSet();

    final seedDate = today ?? DateTime.now();
    final seed = seedDate.year * 10000 + seedDate.month * 100 + seedDate.day;
    final random = Random(seed);

    final scoredMovies = catalog
        .where((movie) => !excludedIds.contains(movie.id))
        .map((movie) {
          final genreMatches = movie.genres
              .where(preferences.favoriteGenres.contains)
              .length;
          final serviceMatches = movie.streamingServices
              .where(preferences.streamingServices.contains)
              .length;
          final genreScore = genreMatches * 4.5;
          final serviceScore = serviceMatches * 3.5;
          final ratingScore = movie.score;
          final recencyBoost = (movie.releaseYear >= seedDate.year - 1)
              ? 1.3
              : 0.0;
          final explorationBonus = random.nextDouble();
          final score =
              genreScore +
              serviceScore +
              ratingScore +
              recencyBoost +
              explorationBonus;
          return movie.copyWith(score: score);
        })
        .toList();

    scoredMovies.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return left.title.compareTo(right.title);
    });

    return scoredMovies.take(limit).toList(growable: false);
  }

  List<Movie> buildShortlist({
    required List<Movie> catalog,
    required List<MovieFeedbackRecord> feedback,
    required List<EventVote> votes,
    required List<String> memberIds,
    required Map<String, List<String>> memberServices,
    required EventConstraints constraints,
    DateTime? today,
    int limit = 6,
  }) {
    final sharedServices = _sharedServices(
      memberServices.values.toList(growable: false),
    );
    final voteByMovie = <String, _VoteTally>{};
    for (final vote in votes) {
      voteByMovie
          .putIfAbsent(vote.movieId, _VoteTally.new)
          .register(vote.choice);
    }

    final memberFeedback = feedback
        .where((record) => memberIds.contains(record.userId))
        .toList(growable: false);
    final scoredMovies = <Movie>[];
    for (final movie in catalog) {
      if (!_matchesFormat(movie, constraints.format)) {
        continue;
      }
      if (movie.runtimeMinutes > constraints.maxDurationMinutes) {
        continue;
      }
      if (constraints.includeGenres.isNotEmpty &&
          !movie.genres.any(constraints.includeGenres.contains)) {
        continue;
      }
      if (movie.genres.any(constraints.excludeGenres.contains)) {
        continue;
      }
      if (sharedServices.isNotEmpty &&
          !movie.streamingServices.any(sharedServices.contains)) {
        continue;
      }

      final likes = memberFeedback
          .where(
            (record) =>
                record.movieId == movie.id &&
                record.action == FeedbackAction.like,
          )
          .length;
      final dislikes = memberFeedback
          .where(
            (record) =>
                record.movieId == movie.id &&
                record.action == FeedbackAction.dislike,
          )
          .length;
      final seenPenalty = memberFeedback
          .where(
            (record) =>
                record.movieId == movie.id &&
                record.action == FeedbackAction.seen,
          )
          .length;
      final voteTally = voteByMovie[movie.id];

      final score =
          movie.score +
          (likes * 3.0) -
          (dislikes * 2.5) -
          (seenPenalty * 2.0) +
          (voteTally?.likeCount ?? 0) * 2.0 -
          (voteTally?.dislikeCount ?? 0) * 1.5;
      scoredMovies.add(movie.copyWith(score: score));
    }

    scoredMovies.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return left.title.compareTo(right.title);
    });

    return scoredMovies.take(limit).toList(growable: false);
  }

  Movie? resolveConsensus({
    required MovieEvent event,
    required List<EventVote> votes,
    required List<String> memberIds,
  }) {
    final totalEligibleVoters = memberIds.isEmpty ? 1 : memberIds.length;
    final requiredLikes = (totalEligibleVoters / 2).floor() + 1;

    for (final movie in event.shortlist) {
      final likes = votes
          .where(
            (vote) =>
                vote.eventId == event.id &&
                vote.movieId == movie.id &&
                vote.choice == VoteChoice.like,
          )
          .map((vote) => vote.userId)
          .toSet()
          .length;
      if (likes >= requiredLikes) {
        return movie;
      }
    }

    return null;
  }

  bool _matchesFormat(Movie movie, MediaType format) {
    switch (format) {
      case MediaType.movie:
        return movie.mediaType == MediaType.movie;
      case MediaType.series:
        return movie.mediaType == MediaType.series;
    }
  }

  List<String> _sharedServices(List<List<String>> servicesByMember) {
    if (servicesByMember.isEmpty) {
      return const <String>[];
    }

    final nonEmpty = servicesByMember
        .where((services) => services.isNotEmpty)
        .toList(growable: false);
    if (nonEmpty.isEmpty) {
      return const <String>[];
    }

    final shared = nonEmpty.first.toSet();
    for (final services in nonEmpty.skip(1)) {
      shared.retainAll(services);
    }

    if (shared.isNotEmpty) {
      return shared.toList(growable: false);
    }

    return nonEmpty
        .expand((services) => services)
        .toSet()
        .toList(growable: false);
  }
}

class _VoteTally {
  _VoteTally();

  int likeCount = 0;
  int dislikeCount = 0;

  void register(VoteChoice choice) {
    switch (choice) {
      case VoteChoice.like:
        likeCount += 1;
      case VoteChoice.dislike:
        dislikeCount += 1;
    }
  }
}
