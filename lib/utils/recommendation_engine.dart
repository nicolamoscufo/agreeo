import 'dart:math';

import 'package:agreeo/models/app_models.dart';

/// Recommendation Engine for Agreeo
///
/// Implements the algorithm as specified in the Agreeo UDSE Project Document:
/// - Section 4.5.2: FINAL SYSTEM FUNCTIONALITIES
/// - Section 5: DESIGN AND IMPLEMENTATION (State Transition Networks)
///
/// Two core recommendation scenarios:
/// 1. Daily Movie Evaluation (STN 5.1): Individual daily suggestions
/// 2. Organize a Movie Night (STN 5.2): Group consensus building
class RecommendationEngine {
  const RecommendationEngine();

  /// Builds daily personalized movie queue for individual user
  ///
  /// Implements STN 5.1 (Daily Movie Evaluation) flow:
  /// - Delivers proactive, lightweight daily suggestions
  /// - Reduces decision fatigue through consistent, minimal interactions
  /// - Distributes decision-making over time (core value proposition)
  ///
  /// Scoring: Genre Match + Rating + Exploration
  List<Movie> buildDailyQueue({
    required List<Movie> catalog,
    required UserPreferences preferences,
    required Iterable<MovieFeedbackRecord> feedback,
    DateTime? today,
    int limit = 7,
  }) {
    // Exclude already-evaluated content (seen or explicitly disliked)
    final excludedIds = feedback
        .where(
          (record) =>
              record.action == FeedbackAction.seen ||
              record.action == FeedbackAction.dislike,
        )
        .map((record) => record.movieId)
        .toSet();

    // Deterministic seeding by date ensures same queue shown to user throughout the day
    final seedDate = today ?? DateTime.now();
    final seed = seedDate.year * 10000 + seedDate.month * 100 + seedDate.day;
    final random = Random(seed);

    final scoredMovies = catalog
        .where((movie) => !excludedIds.contains(movie.id))
        .map((movie) {
          final genreMatches = movie.genres
              .where(preferences.favoriteGenres.contains)
              .length;

          final genreScore = genreMatches * 4.5;
          final ratingScore = movie.score;

          // Exploration bonus: probabilistic discovery of content outside usual preferences
          final explorationBonus = random.nextDouble();

          final score = genreScore + ratingScore + explorationBonus;

          return movie.copyWith(score: score);
        })
        .toList();

    // Sort by score descending, then alphabetically for determinism
    scoredMovies.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return left.title.compareTo(right.title);
    });

    return scoredMovies.take(limit).toList(growable: false);
  }

  /// Builds group shortlist for shared movie night decision
  ///
  /// Implements STN 5.2 (Organize a Movie Night) flow:
  /// - Applies group constraints (format, genres, duration)
  /// - Combines individual feedback to surface fair group consensus options
  /// - Supports voting mechanism for final selection
  ///
  /// Scoring: Rating + Member Likes/Dislikes + Vote Tally + Availability
  List<Movie> buildShortlist({
    required List<Movie> catalog,
    required List<MovieFeedbackRecord> feedback,
    required List<EventVote> votes,
    required List<String> memberIds,
    required EventConstraints constraints,
    DateTime? today,
    int limit = 6,
  }) {
    // Step 1: Build vote tally for consensus tracking
    final voteByMovie = <String, _VoteTally>{};
    for (final vote in votes) {
      voteByMovie
          .putIfAbsent(vote.movieId, _VoteTally.new)
          .register(vote.choice);
    }

    // Step 2: Index feedback by member for group-wide scoring
    final memberFeedback = feedback
        .where((record) => memberIds.contains(record.userId))
        .toList(growable: false);

    final scoredMovies = <Movie>[];

    for (final movie in catalog) {
      // Apply Constraints Setup (from STN 5.2: Constraints_Setup_Active)

      // Constraint 1: Format (movie vs series)
      if (!_matchesFormat(movie, constraints.format)) {
        continue;
      }

      // Constraint 2: Duration limit
      if (movie.runtimeMinutes > constraints.maxDurationMinutes) {
        continue;
      }

      // Constraint 3: Genre inclusions (if specified)
      if (constraints.includeGenres.isNotEmpty &&
          !movie.genres.any(constraints.includeGenres.contains)) {
        continue;
      }

      // Constraint 4: Genre exclusions
      if (movie.genres.any(constraints.excludeGenres.contains)) {
        continue;
      }

      // Step 3: Score based on group feedback and consensus signals

      // Count positive signals from group members
      final likes = memberFeedback
          .where(
            (record) =>
                record.movieId == movie.id &&
                record.action == FeedbackAction.like,
          )
          .length;

      // Count negative signals from group members
      final dislikes = memberFeedback
          .where(
            (record) =>
                record.movieId == movie.id &&
                record.action == FeedbackAction.dislike,
          )
          .length;

      // Penalize content already seen by group members
      // Reduces repeat viewings and maintains discovery excitement
      final seenPenalty = memberFeedback
          .where(
            (record) =>
                record.movieId == movie.id &&
                record.action == FeedbackAction.seen,
          )
          .length;

      final voteTally = voteByMovie[movie.id];

      // Consensus scoring formula:
      // Base rating + Member engagement signals + Voting signals
      final score =
          movie.score + // Base TMDB/platform rating
          (likes * 3.0) - // Strong positive signal
          (dislikes *
              2.5) - // Negative signal (weighted less to allow minority preferences)
          (seenPenalty * 2.0) + // Penalize repeats
          (voteTally?.likeCount ?? 0) * 2.0 - // Active voting support
          (voteTally?.dislikeCount ?? 0) * 1.5; // Active voting opposition

      scoredMovies.add(movie.copyWith(score: score));
    }

    // Final sort: highest consensus score first
    scoredMovies.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return left.title.compareTo(right.title);
    });

    return scoredMovies.take(limit).toList(growable: false);
  }

  /// Resolves final consensus when majority agreement is reached
  ///
  /// Implements voting majority rule: requires >50% of eligible voters to like a movie
  /// This triggers STN 5.2 transition: Voting_Session_Active → Final_Decision_Displayed
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
