import 'dart:math' as math;

import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
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

  void _returnToTab(int index) {
    ref.read(navIndexProvider.notifier).state = index;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _run(Future<String> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await action();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final social = ref.watch(friendsMovieNightControllerProvider);
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final event = social.eventById(widget.eventId);
    final winner = event?.winnerCandidate;

    if (event == null || winner == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Text('Result not ready yet', style: TextStyle(color: t.sub)),
        ),
      );
    }

    final movie = winner.movie;
    final likers = event.joinedParticipants;
    final likes = winner.likesCount ?? likers.length;
    final unanimous = likes >= likers.length && likers.isNotEmpty;
    final meta = [
      if (movie.releaseYear > 0) '${movie.releaseYear}',
      if (movie.runtimeLabel.isNotEmpty) movie.runtimeLabel,
    ].join(' · ');

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: t.line),
                        ),
                        child: Icon(
                          AgIcons.chevronLeft,
                          size: 20,
                          color: t.text,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Column(
                        children: [
                          Text(
                            'IT\'S A MATCH',
                            style: AgText.overline.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: t.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tonight you're watching",
                            textAlign: TextAlign.center,
                            style: AgText.h1.copyWith(
                              letterSpacing: -0.6,
                              color: t.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Winner poster + badge
                      Center(
                        child: SizedBox(
                          width: 186,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AgPoster(
                                imageUrl: movie.posterUrl,
                                title: movie.title,
                                radius: 20,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AgreeoMovieDetailsScreen(
                                      movieId: movie.id,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -12,
                                right: -12,
                                child: Transform.rotate(
                                  angle: 0.1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: t.grad,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: t.purple.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 22,
                                          offset: const Offset(0, 10),
                                          spreadRadius: -6,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$likes/${likers.length} ',
                                          style: AgText.h4.copyWith(
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Icon(
                                          AgIcons.heartFilled,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        movie.title,
                        textAlign: TextAlign.center,
                        style: AgText.h2.copyWith(
                          letterSpacing: -0.5,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (meta.isNotEmpty || movie.rating > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (meta.isNotEmpty)
                              Text(
                                '$meta   ',
                                style: AgText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: t.sub,
                                ),
                              ),
                            if (movie.rating > 0)
                              AgStars(rating: movie.rating, size: 13),
                          ],
                        ),
                      const SizedBox(height: 20),
                      // Likers card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: t.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unanimous
                                  ? 'EVERYONE LOVED IT'
                                  : 'THE GROUP LIKED IT',
                              style: AgText.overline.copyWith(color: t.faint),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: Stack(
                                      children: [
                                        for (var i = 0;
                                            i < likers.length.clamp(0, 5);
                                            i++)
                                          Positioned(
                                            left: i * 26.0,
                                            child: AgAvatar(
                                              name: likers[i].name,
                                              imageUrl: likers[i].avatarUrl,
                                              size: 40,
                                              ring: true,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      AgIcons.heartFilled,
                                      size: 16,
                                      color: t.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      unanimous ? 'Unanimous' : '$likes likes',
                                      style: AgText.label.copyWith(
                                        color: t.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          AgButton.secondary(
                            label: 'Watchlist',
                            icon: AgIcons.bookmark,
                            expand: false,
                            height: 46,
                            onPressed: () =>
                                _run(() => controller.addToWatchlist(movie.id)),
                          ),
                          AgButton.secondary(
                            label: 'Watched',
                            icon: AgIcons.eye,
                            expand: false,
                            height: 46,
                            onPressed: () =>
                                _run(() => controller.markAsWatched(movie.id)),
                          ),
                          AgButton.secondary(
                            label: 'Share',
                            icon: AgIcons.share,
                            expand: false,
                            height: 46,
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '🎬 Movie Night winner: ${movie.title} — voted on Agreeo!',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Result copied to clipboard!'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Bottom CTAs
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    children: [
                      AgButton(
                        label: 'View details',
                        icon: AgIcons.play,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AgreeoMovieDetailsScreen(movieId: movie.id),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      AgButton.secondary(
                        label: 'Back to Friends',
                        icon: AgIcons.users,
                        onPressed: () => _returnToTab(AgNavTab.friends),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiController,
                  builder: (context, child) => CustomPaint(
                    painter: _ConfettiPainter(_confettiController.value, t),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.tokens);

  final double progress;
  final AgreeoTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final colors = <Color>[
      tokens.gold,
      tokens.red,
      tokens.purple,
      tokens.green,
      tokens.gold,
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
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
