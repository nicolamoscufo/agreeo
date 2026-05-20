import 'dart:math' as math;

import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/utils/movie_night_utils.dart';
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

class _MovieNightResultScreenState extends ConsumerState<MovieNightResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
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
    final ranking = movieNightRanking(event).take(3).toList(growable: false);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    InfoBadge(label: movieNightStatusLabel(event.status)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tonight\'s pick is...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
                    child: CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      imageBuilder: (context, imageProvider) => ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Image(image: imageProvider, fit: BoxFit.cover),
                        ),
                      ),
                      errorWidget: (context, url, error) => ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
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
                if (ranking.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  _RankingCard(ranking: ranking),
                ],
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
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      icon: const Icon(Icons.people_outline_rounded),
                      label: const Text('Back to Friends'),
                    ),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ConfettiPainter(_confettiController.value),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.ranking});

  final List<MovieNightCandidateRank> ranking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Top 3 movies',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...ranking.asMap().entries.map((entry) {
              final index = entry.key;
              final rank = entry.value;
              final movie = rank.candidate.movie;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _podiumColor(index),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                title: Text(movie.title),
                subtitle: Text('${rank.likes} likes • ${rank.dislikes} nopes'),
                trailing: Text(
                  rank.finalScore.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _podiumColor(int index) {
    return switch (index) {
      0 => const Color(0xFFFACC15),
      1 => const Color(0xFFE5E7EB),
      _ => const Color(0xFFF97316),
    };
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }
    const colors = <Color>[
      Color(0xFFFACC15),
      Color(0xFF22C55E),
      Color(0xFF38BDF8),
      Color(0xFFF472B6),
      Color(0xFFF97316),
    ];
    final fade = (1 - progress).clamp(0.0, 1.0).toDouble();
    for (var index = 0; index < 56; index++) {
      final random = math.Random(index * 41);
      final x = random.nextDouble() * size.width;
      final speed = 0.65 + random.nextDouble() * 0.8;
      final drift = (random.nextDouble() - 0.5) * 120 * progress;
      final y = -40 + (size.height + 160) * progress * speed;
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x + drift, y);
      canvas.rotate((progress * 6 + random.nextDouble()) * math.pi);
      final width = 6 + random.nextDouble() * 7;
      final height = 10 + random.nextDouble() * 12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
