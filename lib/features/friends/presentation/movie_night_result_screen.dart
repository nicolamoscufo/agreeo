import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MovieNightResultScreen extends ConsumerStatefulWidget {
  const MovieNightResultScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<MovieNightResultScreen> createState() =>
      _MovieNightResultScreenState();
}

class _MovieNightResultScreenState
    extends ConsumerState<MovieNightResultScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(friendsMovieNightControllerProvider);
    final event = socialState.eventById(widget.eventId);
    final winner = event?.winnerCandidate;

    if (event == null || winner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('Result not ready yet')),
      );
    }

    final movie = winner.movie;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
                InfoBadge(label: _statusLabel(event.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tonight\'s pick is...',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x6638BDF8),
                      blurRadius: 34,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1F2937),
                        child: const Icon(
                          Icons.movie_creation_outlined,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              movie.title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '${movie.releaseYear} • ${movie.runtimeLabel} • ${movie.genres.take(3).join(', ')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Why it won',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: winner.explanationTags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AgreeoMovieDetailsScreen(movieId: movie.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('Open details'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final message = await ref
                        .read(agreeoAppControllerProvider.notifier)
                        .markAsWatched(movie.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  },
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Mark as Watched'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Movie Night saved.')),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save event'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  icon: const Icon(Icons.people_outline_rounded),
                  label: const Text('Back to Friends'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(MovieNightStatus status) {
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
