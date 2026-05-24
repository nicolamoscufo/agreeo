import 'package:agreeo/shared/models/social_models.dart';

class MovieNightCandidateRank {
  const MovieNightCandidateRank({
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

String movieNightStatusLabel(MovieNightStatus status) {
  switch (status) {
    case MovieNightStatus.draft:
      return 'Draft';
    case MovieNightStatus.waiting:
      return 'Waiting for friends';
    case MovieNightStatus.voting:
      return 'Voting';
    case MovieNightStatus.completed:
      return 'Completed';
  }
}

String movieNightDateLabel(DateTime? dateTime, {bool includeTime = false}) {
  if (dateTime == null) {
    return 'Date optional';
  }
  final date =
      '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  if (!includeTime) {
    return date;
  }
  final time =
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String movieNightConstraintsLabel(MovieNightConstraints constraints) {
  final parts = <String>[
    if (constraints.includedGenres.isNotEmpty)
      'Genres: ${constraints.includedGenres.join(', ')}',
    if (constraints.excludedGenres.isNotEmpty)
      'No ${constraints.excludedGenres.join(', ')}',
    if (constraints.maxDurationMinutes != null)
      'Max ${constraints.maxDurationMinutes}m',
    if (constraints.minimumRating != null)
      'Rating >= ${constraints.minimumRating!.toStringAsFixed(0)}',
    if (constraints.language != null) 'Language ${constraints.language}',
  ];
  return parts.isEmpty ? 'No constraints set' : parts.join(' • ');
}

List<String> movieNightCompletedVoterIds(MovieNightEvent event) {
  if (event.votedUserIds.isNotEmpty) {
    return event.votedUserIds;
  }
  final joinedIds = event.joinedParticipants
      .map((participant) => participant.userId)
      .toSet();
  if (joinedIds.isEmpty || event.shortlist.isEmpty) {
    return const <String>[];
  }
  return joinedIds
      .where((userId) {
        return event.shortlist.every((candidate) {
          return event.votes.any(
            (vote) =>
                vote.userId == userId && vote.movieId == candidate.movie.id,
          );
        });
      })
      .toList(growable: false);
}

int movieNightVoteScore(MovieNightVoteValue vote) {
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

List<MovieNightCandidateRank> movieNightRanking(MovieNightEvent event) {
  final ranked = event.shortlist
      .map((candidate) {
        final votes = event.votes
            .where((vote) => vote.movieId == candidate.movie.id)
            .toList(growable: false);
        final voteScore = votes.fold<double>(0, (sum, vote) {
          return sum + movieNightVoteScore(vote.vote);
        });
        return MovieNightCandidateRank(
          candidate: candidate,
          finalScore: voteScore,
          likes: votes
              .where((vote) => vote.vote == MovieNightVoteValue.like)
              .length,
          dislikes: votes
              .where((vote) => vote.vote == MovieNightVoteValue.dislike)
              .length,
        );
      })
      .toList(growable: false);

  ranked.sort((left, right) {
    if (left.candidate.eliminated != right.candidate.eliminated) {
      return left.candidate.eliminated ? 1 : -1;
    }
    final scoreCompare = right.finalScore.compareTo(left.finalScore);
    if (scoreCompare != 0) return scoreCompare;
    final likeCompare = right.likes.compareTo(left.likes);
    if (likeCompare != 0) return likeCompare;
    final dislikeCompare = left.dislikes.compareTo(right.dislikes);
    if (dislikeCompare != 0) return dislikeCompare;
    final originalScoreCompare = right.candidate.compatibilityScore.compareTo(
      left.candidate.compatibilityScore,
    );
    if (originalScoreCompare != 0) return originalScoreCompare;
    final ratingCompare = right.candidate.movie.rating.compareTo(
      left.candidate.movie.rating,
    );
    if (ratingCompare != 0) return ratingCompare;
    return left.candidate.movie.title.compareTo(right.candidate.movie.title);
  });
  return ranked;
}
