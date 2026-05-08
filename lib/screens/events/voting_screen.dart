import 'package:agreeo/models/app_models.dart';
import 'package:agreeo/providers/app_controller.dart';
import 'package:agreeo/widgets/consensus_banner.dart';
import 'package:agreeo/widgets/empty_state.dart';
import 'package:agreeo/widgets/gradient_scaffold.dart';
import 'package:agreeo/widgets/movie_card.dart';
import 'package:agreeo/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VotingScreen extends ConsumerWidget {
  const VotingScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final event = state.events
        .where((entry) => entry.id == eventId)
        .cast<MovieEvent?>()
        .firstOrNull;
    final session = state.session;

    if (event == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Event not found',
          message: 'The shortlist is missing from this session.',
        ),
      );
    }

    final resolvedMovie = event.shortlist
        .where((movie) => movie.id == event.resolvedMovieId)
        .cast<Movie?>()
        .firstOrNull;

    return GradientScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: <Widget>[
          SectionHeader(
            title: 'Vote on the shortlist',
            subtitle: '${event.groupName} • ${event.shortlist.length} titles',
          ),
          const SizedBox(height: 12),
          if (event.isResolved)
            ConsensusBanner(
              title: 'Match found!',
              message: resolvedMovie == null
                  ? 'Your group reached consensus.'
                  : '${resolvedMovie.title} won the vote.',
            )
          else
            ConsensusBanner(
              title: 'Real-time voting',
              message: 'Votes update as soon as each member makes a choice.',
              icon: Icons.how_to_vote_rounded,
            ),
          const SizedBox(height: 16),
          ...event.shortlist.map(
            (movie) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _VoteCard(
                movie: movie,
                currentVote: _voteForMovie(
                  state.votes,
                  event.id,
                  session?.uid,
                  movie.id,
                ),
                onLike: () => ref
                    .read(appControllerProvider.notifier)
                    .voteOnEvent(
                      eventId: event.id,
                      movieId: movie.id,
                      choice: VoteChoice.like,
                    ),
                onDislike: () => ref
                    .read(appControllerProvider.notifier)
                    .voteOnEvent(
                      eventId: event.id,
                      movieId: movie.id,
                      choice: VoteChoice.dislike,
                    ),
              ),
            ),
          ),
          if (event.isResolved && resolvedMovie != null) ...<Widget>[
            const SizedBox(height: 8),
            MovieCard(movie: resolvedMovie, compact: true),
          ],
        ],
      ),
    );
  }

  VoteChoice? _voteForMovie(
    List<EventVote> votes,
    String eventId,
    String? userId,
    String movieId,
  ) {
    if (userId == null) {
      return null;
    }
    for (final vote in votes.reversed) {
      if (vote.eventId == eventId &&
          vote.userId == userId &&
          vote.movieId == movieId) {
        return vote.choice;
      }
    }
    return null;
  }
}

class _VoteCard extends StatelessWidget {
  const _VoteCard({
    required this.movie,
    required this.currentVote,
    required this.onLike,
    required this.onDislike,
  });

  final Movie movie;
  final VoteChoice? currentVote;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MovieCard(movie: movie, compact: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onLike,
                    icon: Icon(
                      currentVote == VoteChoice.like
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_up_outlined,
                    ),
                    label: const Text('Like'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDislike,
                    icon: Icon(
                      currentVote == VoteChoice.dislike
                          ? Icons.thumb_down_rounded
                          : Icons.thumb_down_outlined,
                    ),
                    label: const Text('Dislike'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = iteratored;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }

  Iterator<E> get iteratored => iterator;
}
