import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/models/social_models.dart';

class ShortlistService {
  const ShortlistService();

  List<ShortlistCandidate> generateShortlist({
    required MovieNightConstraints eventConstraints,
    required List<MovieNightParticipant> participants,
    required List<Movie> movies,
    required Map<String, Map<String, UserMovieState>> userMovieStates,
    int limit = 5,
  }) {
    if (eventConstraints.hasGenreConflict) {
      return const <ShortlistCandidate>[];
    }

    final joinedParticipants = participants
        .where((participant) => participant.joined)
        .toList(growable: false);
    final candidates = <ShortlistCandidate>[];

    for (final movie in movies) {
      if (!eventConstraints.matches(movie)) {
        continue;
      }
      candidates.add(
        calculateMovieCompatibility(
          movie: movie,
          participants: joinedParticipants,
          userMovieStates: userMovieStates,
          constraints: eventConstraints,
        ),
      );
    }

    candidates.sort(_compareCandidates);
    return candidates.take(limit).toList(growable: false);
  }

  ShortlistCandidate calculateMovieCompatibility({
    required Movie movie,
    required List<MovieNightParticipant> participants,
    required Map<String, Map<String, UserMovieState>> userMovieStates,
    required MovieNightConstraints constraints,
  }) {
    var score = 0.0;
    var watchlistSaves = 0;
    var likes = 0;
    var dislikes = 0;
    var watched = 0;
    var positiveRatings = 0;

    for (final participant in participants) {
      final state =
          userMovieStates[participant.userId]?[movie.id] ??
          UserMovieState.initial(movie.id);

      if (state.inWatchlist) {
        watchlistSaves += 1;
        score += 4;
      }
      if (state.preference == MoviePreference.liked) {
        likes += 1;
        score += 3;
      }
      if ((state.rating ?? 0) >= 4) {
        positiveRatings += 1;
        score += 1;
      }
      if (state.preference == MoviePreference.disliked) {
        dislikes += 1;
        score -= 4;
      }
      if (state.watched) {
        watched += 1;
        score -= 1;
      }
    }

    final includedGenreMatches = movie.genres
        .where(constraints.includedGenres.contains)
        .length;
    var groupBonus = 0.0;
    var groupPenalty = 0.0;
    final groupSize = participants.isEmpty ? 1 : participants.length;
    final halfGroup = (groupSize / 2).ceil();

    if (includedGenreMatches > 0) {
      groupBonus += includedGenreMatches >= 2 ? 2 : 1;
    }
    if (watched < halfGroup) {
      groupBonus += 1;
    }
    if (movie.rating >= 7.5) {
      groupBonus += 1;
    }
    if (watched >= halfGroup) {
      groupPenalty -= 3;
    }
    if (dislikes >= halfGroup) {
      groupPenalty -= 5;
    }

    final total = score + groupBonus + groupPenalty;
    final breakdown = ScoreBreakdown(
      watchlistSaves: watchlistSaves,
      likes: likes,
      dislikes: dislikes,
      watched: watched,
      positiveRatings: positiveRatings,
      includedGenreMatches: includedGenreMatches,
      groupBonus: groupBonus,
      groupPenalty: groupPenalty,
      total: total,
    );

    return ShortlistCandidate(
      movie: movie,
      compatibilityScore: total,
      explanationTags: explainCandidate(
        movie: movie,
        scoreBreakdown: breakdown,
        participants: participants,
        constraints: constraints,
      ),
      scoreBreakdown: breakdown,
    );
  }

  List<String> explainCandidate({
    required Movie movie,
    required ScoreBreakdown scoreBreakdown,
    required List<MovieNightParticipant> participants,
    required MovieNightConstraints constraints,
  }) {
    final tags = <String>[];
    final groupSize = participants.isEmpty ? 1 : participants.length;
    final halfGroup = (groupSize / 2).ceil();

    if (scoreBreakdown.watchlistSaves > 0) {
      tags.add(
        'Saved by ${scoreBreakdown.watchlistSaves} ${_friendLabel(scoreBreakdown.watchlistSaves)}',
      );
    }
    if (scoreBreakdown.likes >= halfGroup && scoreBreakdown.likes > 0) {
      tags.add('Liked by most participants');
    }
    if (constraints.includedGenres.isNotEmpty &&
        scoreBreakdown.includedGenreMatches > 0) {
      tags.add('Matches selected genres');
    }
    if (scoreBreakdown.watched < halfGroup) {
      tags.add('Mostly unwatched');
    }
    if (movie.rating >= 7.5) {
      tags.add('High rating');
    }

    if (tags.isEmpty) {
      tags.add('Balanced group fit');
    }
    return tags.toList(growable: false);
  }

  bool hasEveryoneVoted(MovieNightEvent event) {
    final joinedIds = event.joinedParticipants
        .map((participant) => participant.userId)
        .toSet();
    if (joinedIds.isEmpty || event.shortlist.isEmpty) {
      return false;
    }

    for (final candidate in event.shortlist) {
      final votedIds = event.votes
          .where((vote) => vote.movieId == candidate.movie.id)
          .map((vote) => vote.userId)
          .toSet();
      if (!joinedIds.every(votedIds.contains)) {
        return false;
      }
    }
    return true;
  }

  ShortlistCandidate? selectWinner({
    required List<ShortlistCandidate> shortlist,
    required List<MovieNightVote> votes,
  }) {
    if (shortlist.isEmpty) {
      return null;
    }

    final scored = shortlist
        .map((candidate) {
          final movieVotes = votes
              .where((vote) => vote.movieId == candidate.movie.id)
              .toList(growable: false);
          final voteScore = movieVotes.fold<double>(0, (sum, vote) {
            return sum + _voteScore(vote.vote);
          });
          final likes = movieVotes
              .where((vote) => vote.vote == MovieNightVoteValue.like)
              .length;
          final dislikes = movieVotes
              .where((vote) => vote.vote == MovieNightVoteValue.dislike)
              .length;
          return _WinnerScore(
            candidate: candidate,
            finalScore: candidate.compatibilityScore + voteScore,
            likes: likes,
            dislikes: dislikes,
          );
        })
        .toList(growable: false);

    scored.sort((left, right) {
      final scoreCompare = right.finalScore.compareTo(left.finalScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final likeCompare = right.likes.compareTo(left.likes);
      if (likeCompare != 0) {
        return likeCompare;
      }
      final dislikeCompare = left.dislikes.compareTo(right.dislikes);
      if (dislikeCompare != 0) {
        return dislikeCompare;
      }
      final originalScoreCompare = right.candidate.compatibilityScore.compareTo(
        left.candidate.compatibilityScore,
      );
      if (originalScoreCompare != 0) {
        return originalScoreCompare;
      }
      final ratingCompare = right.candidate.movie.rating.compareTo(
        left.candidate.movie.rating,
      );
      if (ratingCompare != 0) {
        return ratingCompare;
      }
      return left.candidate.movie.title.compareTo(right.candidate.movie.title);
    });

    return scored.first.candidate;
  }

  int _compareCandidates(ShortlistCandidate left, ShortlistCandidate right) {
    final scoreCompare = right.compatibilityScore.compareTo(
      left.compatibilityScore,
    );
    if (scoreCompare != 0) {
      return scoreCompare;
    }
    final watchlistCompare = right.scoreBreakdown.watchlistSaves.compareTo(
      left.scoreBreakdown.watchlistSaves,
    );
    if (watchlistCompare != 0) {
      return watchlistCompare;
    }
    final likesCompare = right.scoreBreakdown.likes.compareTo(
      left.scoreBreakdown.likes,
    );
    if (likesCompare != 0) {
      return likesCompare;
    }
    final ratingCompare = right.movie.rating.compareTo(left.movie.rating);
    if (ratingCompare != 0) {
      return ratingCompare;
    }
    final yearCompare = right.movie.releaseYear.compareTo(
      left.movie.releaseYear,
    );
    if (yearCompare != 0) {
      return yearCompare;
    }
    return left.movie.title.compareTo(right.movie.title);
  }

  double _voteScore(MovieNightVoteValue vote) {
    switch (vote) {
      case MovieNightVoteValue.like:
        return 3;
      case MovieNightVoteValue.neutral:
        return 1;
      case MovieNightVoteValue.alreadySeen:
        return -1;
      case MovieNightVoteValue.dislike:
        return -4;
    }
  }

  String _friendLabel(int count) => count == 1 ? 'friend' : 'friends';
}

class _WinnerScore {
  const _WinnerScore({
    required this.candidate,
    required this.finalScore,
    required this.likes,
    required this.dislikes,
  });

  final ShortlistCandidate candidate;
  final double finalScore;
  final int likes;
  final int dislikes;
}
