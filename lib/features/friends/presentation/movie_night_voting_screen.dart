import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovieNightVotingScreen extends ConsumerWidget {
  const MovieNightVotingScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(friendsMovieNightControllerProvider.notifier);
    final event = socialState.eventById(eventId);
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voting')),
        body: const Center(child: Text('Movie Night not found')),
      );
    }

    if (event.status == MovieNightStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => MovieNightResultScreen(eventId: event.id),
            ),
          );
        }
      });
    }

    final currentVotes = event.shortlist.where((candidate) {
      final vote = controller.currentUserVoteFor(event.id, candidate.movie.id);
      return vote != null;
    }).length;
    final totalCandidates = event.shortlist.length;
    final waiting = totalCandidates - currentVotes;

    return Scaffold(
      appBar: AppBar(title: const Text('Voting')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: <Widget>[
            SectionHeader(
              title: event.name,
              subtitle: waiting <= 0
                  ? 'All votes collected. Result is being prepared.'
                  : '$currentVotes/$totalCandidates movies voted • Waiting for $waiting',
              trailing: InfoBadge(
                label:
                    '${event.joinedParticipants.length} friends voted per movie',
              ),
            ),
            const SizedBox(height: 18),
            if (event.shortlist.isEmpty)
              const EmptyState(
                icon: Icons.movie_filter_outlined,
                title: 'No movies matched this group',
                message: 'Go back and relax constraints before voting.',
              )
            else
              ...event.shortlist.map((candidate) {
                final vote = controller.currentUserVoteFor(
                  event.id,
                  candidate.movie.id,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _VotingCandidateCard(
                    candidate: candidate,
                    currentVote: vote?.vote,
                    votedCount: event.votesForMovieFromJoined(
                      candidate.movie.id,
                    ),
                    joinedCount: event.joinedParticipants.length,
                    onOpenDetails: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AgreeoMovieDetailsScreen(
                            movieId: candidate.movie.id,
                          ),
                        ),
                      );
                    },
                    onVote: (voteValue) {
                      final updated = controller.submitVote(
                        eventId: event.id,
                        movieId: candidate.movie.id,
                        vote: voteValue,
                      );
                      if (updated?.status == MovieNightStatus.completed &&
                          context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                MovieNightResultScreen(eventId: event.id),
                          ),
                        );
                      }
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _VotingCandidateCard extends StatelessWidget {
  const _VotingCandidateCard({
    required this.candidate,
    required this.currentVote,
    required this.votedCount,
    required this.joinedCount,
    required this.onOpenDetails,
    required this.onVote,
  });

  final ShortlistCandidate candidate;
  final MovieNightVoteValue? currentVote;
  final int votedCount;
  final int joinedCount;
  final VoidCallback onOpenDetails;
  final ValueChanged<MovieNightVoteValue> onVote;

  @override
  Widget build(BuildContext context) {
    final movie = candidate.movie;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 86,
                    height: 128,
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1F2937),
                        child: const Icon(Icons.movie_creation_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        movie.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(movie.subtitleLine),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: movie.genres
                            .take(3)
                            .map((genre) => GenreChip(label: genre))
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                      Text('$votedCount/$joinedCount friends voted'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidate.explanationTags
                  .map((tag) => Chip(label: Text(tag)))
                  .toList(growable: false),
            ),
            if (kDebugMode) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Compatibility ${candidate.compatibilityScore.toStringAsFixed(1)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Details'),
                ),
                _VoteButton(
                  label: 'Like',
                  icon: Icons.thumb_up_alt_outlined,
                  vote: MovieNightVoteValue.like,
                  currentVote: currentVote,
                  onVote: onVote,
                ),
                _VoteButton(
                  label: 'Dislike',
                  icon: Icons.thumb_down_alt_outlined,
                  vote: MovieNightVoteValue.dislike,
                  currentVote: currentVote,
                  onVote: onVote,
                ),
                _VoteButton(
                  label: 'Already Seen',
                  icon: Icons.visibility_outlined,
                  vote: MovieNightVoteValue.alreadySeen,
                  currentVote: currentVote,
                  onVote: onVote,
                ),
                _VoteButton(
                  label: 'Maybe',
                  icon: Icons.remove_circle_outline_rounded,
                  vote: MovieNightVoteValue.neutral,
                  currentVote: currentVote,
                  onVote: onVote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.icon,
    required this.vote,
    required this.currentVote,
    required this.onVote,
  });

  final String label;
  final IconData icon;
  final MovieNightVoteValue vote;
  final MovieNightVoteValue? currentVote;
  final ValueChanged<MovieNightVoteValue> onVote;

  @override
  Widget build(BuildContext context) {
    final selected = currentVote == vote;
    return FilterChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => onVote(vote),
    );
  }
}
