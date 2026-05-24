import 'dart:math' as math;

import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/utils/movie_night_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static final Set<String> _shownConfettiIds = <String>{};
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (_shownConfettiIds.add(widget.eventId)) {
      _confettiController.forward();
    }
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
    final ranking = movieNightRanking(event);
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
                  'The group\'s pick is...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AgreeoMovieDetailsScreen(movieId: movie.id),
                      ),
                    );
                  },
                  child: Center(
                    child: Container(
                      width: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AgreeoColors.cinematicRed.withValues(alpha: 0.4),
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
                              color: AgreeoColors.darkSurface,
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
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            AgreeoMovieDetailsScreen(movieId: movie.id),
                      ),
                    );
                  },
                  child: Text(
                    movie.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
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
                if (event.round > 1) ...<Widget>[
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AgreeoColors.kernelGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AgreeoColors.kernelGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.flash_on_rounded,
                            color: AgreeoColors.kernelGold,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Decided after ${event.round} rounds',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (ranking.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  _FullLeaderboard(
                    ranking: ranking,
                    winnerMovieId: event.winnerMovieId,
                  ),
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
                    FilledButton.tonalIcon(
                      onPressed: () {
                        final text = '\u{1F3AC} Movie Night Result\n\n'
                            '\u{1F3C6} Winner: ${movie.title}\n'
                            '\u2B50 Score: ${(winner.finalScore ?? winner.compatibilityScore).toStringAsFixed(1)}\n'
                            '\u2764 ${winner.likesCount ?? 0} likes\n\n'
                            'Voted on Agreeo!';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Result copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Result'),
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

class _FullLeaderboard extends StatelessWidget {
  const _FullLeaderboard({required this.ranking, this.winnerMovieId});

  final List<MovieNightCandidateRank> ranking;
  final String? winnerMovieId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Full Ranking',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...ranking.asMap().entries.map((entry) {
              final index = entry.key;
              final rank = entry.value;
              final movie = rank.candidate.movie;
              final isWinner = movie.id == winnerMovieId;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: isWinner
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AgreeoColors.kernelGold.withValues(alpha: 0.08),
                        border: Border.all(
                          color: AgreeoColors.kernelGold.withValues(alpha: 0.3),
                        ),
                      )
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          _rankEmoji(index),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: movie.posterUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: movie.posterUrl,
                                width: 36,
                                height: 54,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  width: 36,
                                  height: 54,
                                  color: AgreeoColors.darkSurface,
                                  child: const Icon(
                                    Icons.movie_outlined,
                                    size: 18,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : Container(
                                width: 36,
                                height: 54,
                                color: AgreeoColors.darkSurface,
                                child: const Icon(
                                  Icons.movie_outlined,
                                  size: 18,
                                  color: Colors.white54,
                                ),
                              ),
                      ),
                    ],
                  ),
                  title: Text(
                    movie.title,
                    style: TextStyle(
                      fontWeight:
                          isWinner ? FontWeight.w800 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    rank.candidate.eliminated
                        ? '\u2764 ${rank.likes}  \u00b7  \u{1F44E} ${rank.dislikes}  \u00b7  Eliminated'
                        : '\u2764 ${rank.likes}  \u00b7  \u{1F44E} ${rank.dislikes}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isWinner
                          ? AgreeoColors.kernelGold.withValues(alpha: 0.2)
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rank.finalScore.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: isWinner
                            ? AgreeoColors.kernelGold
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _rankEmoji(int index) {
    return switch (index) {
      0 => '\u{1F947}',
      1 => '\u{1F948}',
      2 => '\u{1F949}',
      _ => '${index + 1}.',
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
      AgreeoColors.kernelGold,
      AgreeoColors.cinematicRed,
      AgreeoColors.popcornWhite,
      AgreeoColors.kernelGold,
      AgreeoColors.cinematicRed,
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


