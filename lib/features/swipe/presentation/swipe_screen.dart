import 'dart:async';

import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';

String _preferredSwipeImageUrl(Movie movie) {
  final raw = movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.backdropUrl;
  return raw.replaceFirst('/w500/', '/w780/');
}

String _runtimeLabel(int minutes) {
  if (minutes <= 0) return '';
  return '${minutes ~/ 60}h ${minutes % 60}m';
}

int _swipeImageCacheWidth(BuildContext context) {
  return (MediaQuery.sizeOf(context).width *
          MediaQuery.devicePixelRatioOf(context))
      .round();
}

class AgreeoSwipeScreen extends ConsumerStatefulWidget {
  const AgreeoSwipeScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  ConsumerState<AgreeoSwipeScreen> createState() => _AgreeoSwipeScreenState();
}

enum SwipeDirection { left, right, up, down }

class _AgreeoSwipeScreenState extends ConsumerState<AgreeoSwipeScreen> {
  bool _queueRefillScheduled = false;
  final Set<String> _precachedSwipeImages = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleRefillIfNeeded(0);
    });
  }

  void _scheduleRefillIfNeeded(int queueLength) {
    if (_queueRefillScheduled || !mounted) return;
    if (queueLength > AgreeoAppController.swipeQueueRefillThreshold) return;

    _queueRefillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(agreeoAppControllerProvider.notifier)
            .ensureSwipeQueueFilled();
      } finally {
        _queueRefillScheduled = false;
      }
    });
  }

  Future<void> _handleSwiped(String movieId, SwipeDirection direction) async {
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    Future<String> Function() action;
    switch (direction) {
      case SwipeDirection.left:
        action = () => controller.dislikeMovie(movieId);
      case SwipeDirection.right:
        action = () => controller.likeMovie(movieId);
      case SwipeDirection.up:
        action = () => controller.markAsWatched(movieId);
      case SwipeDirection.down:
        action = () => controller.addToWatchlist(movieId);
    }
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      // Only surface failures — routine swipes stay silent (no toast spam).
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _scheduleSwipeImagePrecache(BuildContext context, List<Movie> queue) {
    final urls = <String>[];
    for (final movie in queue.take(4)) {
      final imageUrl = _preferredSwipeImageUrl(movie);
      if (imageUrl.isNotEmpty && _precachedSwipeImages.add(imageUrl)) {
        urls.add(imageUrl);
      }
    }
    if (urls.isEmpty) return;
    final cacheWidth = _swipeImageCacheWidth(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final url in urls) {
        // Wrap in ResizeImage exactly like CachedNetworkImage does for
        // memCacheWidth — a bare provider has a different image-cache key,
        // so the precached frame would never be reused by the cards.
        final provider = ResizeImage.resizeIfNeeded(
            cacheWidth, null, CachedNetworkImageProvider(url));
        unawaited(precacheImage(provider, context,
            onError: (Object _, StackTrace? _) {}));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(agreeoAppControllerProvider);
    final queue = state.remainingDailySuggestions;
    _scheduleSwipeImagePrecache(context, queue);
    _scheduleRefillIfNeeded(queue.length);
    final currentMovie = queue.isNotEmpty ? queue.first : null;
    final nextMovie = queue.length > 1 ? queue[1] : null;

    if (currentMovie == null) {
      return _SwipeEmptyState(
        onRefresh: () {
          HapticFeedback.mediumImpact();
          ref.read(agreeoAppControllerProvider.notifier).refreshMovieSuggestions();
        },
        onLibrary: () => widget.onNavigateTab?.call(AgNavTab.library),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (nextMovie != null)
            Positioned.fill(
              child: RepaintBoundary(
                child: _BackgroundMovieCard(movie: nextMovie),
              ),
            ),
          Positioned.fill(
            child: RepaintBoundary(
              child: SwipeableCard(
                key: ValueKey<String>(currentMovie.id),
                movie: currentMovie,
                canUndo: state.undoStack.isNotEmpty,
                onSwiped: (direction) =>
                    _handleSwiped(currentMovie.id, direction),
                onUndo: () async {
                  HapticFeedback.lightImpact();
                  await ref
                      .read(agreeoAppControllerProvider.notifier)
                      .undoLastAction();
                },
                onInfoTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AgreeoMovieDetailsScreen(movieId: currentMovie.id),
                  ),
                ),
              ),
            ),
          ),
          // Header: Discover + queue pill + avatar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 20,
            right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover',
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontWeight: FontWeight.w800,
                          fontSize: 23,
                          letterSpacing: -0.5,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'Swipe to build your taste',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                _GlassPill(label: '${queue.length} left'),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AgreeoProfileScreen(),
                    ),
                  ),
                  child: AgAvatar(
                    name: state.session?.displayName ?? 'You',
                    color: t.red,
                    size: 42,
                  ),
                ),
              ],
            ),
          ),
          if (_queueRefillScheduled)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(child: _GlassPill(label: 'Loading more…')),
            ),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SwipeEmptyState extends StatelessWidget {
  const _SwipeEmptyState({required this.onRefresh, required this.onLibrary});
  final VoidCallback onRefresh;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: t.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: t.gradSoft,
                    border: Border.all(color: t.line2),
                  ),
                  child: Icon(AgIcons.film, size: 36, color: t.red),
                ),
                const SizedBox(height: 22),
                Text(
                  'All caught up',
                  style: TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.5,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "You've swiped through every suggestion.\nRefresh for new picks or browse your library.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Manrope', fontSize: 14, height: 1.5, color: t.sub),
                ),
                const SizedBox(height: 24),
                AgButton(label: 'Refresh suggestions', icon: AgIcons.refresh, onPressed: onRefresh),
                const SizedBox(height: 12),
                AgButton.secondary(label: 'Go to Library', icon: AgIcons.library, onPressed: onLibrary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SwipeableCard extends StatefulWidget {
  const SwipeableCard({
    super.key,
    required this.movie,
    required this.canUndo,
    required this.onSwiped,
    required this.onUndo,
    required this.onInfoTap,
  });

  final Movie movie;
  final bool canUndo;
  final ValueChanged<SwipeDirection> onSwiped;
  final VoidCallback onUndo;
  final VoidCallback onInfoTap;

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  static const Duration _programmaticSwipeDuration = Duration(milliseconds: 280);
  static const Duration _maxFlingDuration = Duration(milliseconds: 280);
  static const Duration _minFlingDuration = Duration(milliseconds: 170);

  late final AnimationController _swipeController;
  Animation<Offset>? _swipeAnimation;
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
  bool _isSubmittingSwipe = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        if (_swipeAnimation != null) {
          _dragOffsetNotifier.value = _swipeAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  Future<void> _animateDragTo(
    Offset target, {
    Duration duration = const Duration(milliseconds: 260),
    Curve curve = Curves.easeOutCubic,
  }) async {
    _swipeController.stop();
    _swipeController.duration = duration;
    final animation = Tween<Offset>(begin: _dragOffsetNotifier.value, end: target)
        .animate(CurvedAnimation(parent: _swipeController, curve: curve));
    _swipeAnimation = animation;
    try {
      await _swipeController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (_swipeAnimation == animation) _swipeAnimation = null;
    }
  }

  Duration _flingDurationFor(Offset target, Offset velocity) {
    final remainingDistance = (target - _dragOffsetNotifier.value).distance;
    final speed = velocity.distance;
    if (speed < 10) return _maxFlingDuration;
    final milliseconds = (remainingDistance / speed * 1000).clamp(
      _minFlingDuration.inMilliseconds.toDouble(),
      _maxFlingDuration.inMilliseconds.toDouble(),
    );
    return Duration(milliseconds: milliseconds.round());
  }

  Duration _snapBackDurationFor(Offset offset) {
    final progress = (offset.distance / 260).clamp(0.0, 1.0).toDouble();
    return Duration(milliseconds: (160 + progress * 70).round());
  }

  Future<void> _swipeProgrammatic(SwipeDirection direction) async {
    if (_isSubmittingSwipe) return;
    setState(() => _isSubmittingSwipe = true);
    final size = MediaQuery.sizeOf(context);
    Offset target;
    switch (direction) {
      case SwipeDirection.left:
        target = Offset(-size.width - 260, 0);
      case SwipeDirection.right:
        target = Offset(size.width + 260, 0);
      case SwipeDirection.up:
        target = Offset(0, -size.height - 260);
      case SwipeDirection.down:
        target = Offset(0, size.height + 260);
    }
    HapticFeedback.mediumImpact();
    await _animateDragTo(target, duration: _programmaticSwipeDuration);
    widget.onSwiped(direction);
  }

  Future<void> _handlePanEnd(DragEndDetails details) async {
    if (_isSubmittingSwipe) return;
    final size = MediaQuery.sizeOf(context);
    final dragOffset = _dragOffsetNotifier.value;
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final velocityY = details.velocity.pixelsPerSecond.dy;
    final isHorizontalDominant = dragOffset.dx.abs() >= dragOffset.dy.abs();

    if (isHorizontalDominant) {
      final shouldVote = dragOffset.dx.abs() > size.width * 0.28 || velocityX.abs() > 650;
      if (!shouldVote) {
        await _animateDragTo(Offset.zero, duration: _snapBackDurationFor(dragOffset));
        return;
      }
      final swipeLike = velocityX.abs() > dragOffset.dx.abs() ? velocityX > 0 : dragOffset.dx > 0;
      final direction = swipeLike ? SwipeDirection.right : SwipeDirection.left;
      final projectedY = (dragOffset.dy + velocityY * 0.10)
          .clamp(-size.height * 0.42, size.height * 0.42)
          .toDouble();
      final target = Offset((swipeLike ? 1 : -1) * (size.width + 260), projectedY);
      HapticFeedback.mediumImpact();
      setState(() => _isSubmittingSwipe = true);
      await _animateDragTo(target,
          duration: _flingDurationFor(target, details.velocity.pixelsPerSecond));
      widget.onSwiped(direction);
    } else {
      final shouldVote = dragOffset.dy.abs() > size.height * 0.18 || velocityY.abs() > 650;
      if (!shouldVote) {
        await _animateDragTo(Offset.zero, duration: _snapBackDurationFor(dragOffset));
        return;
      }
      final swipeUp = velocityY.abs() > dragOffset.dy.abs() ? velocityY < 0 : dragOffset.dy < 0;
      final direction = swipeUp ? SwipeDirection.up : SwipeDirection.down;
      final projectedX = (dragOffset.dx + velocityX * 0.10)
          .clamp(-size.width * 0.42, size.width * 0.42)
          .toDouble();
      final target = Offset(projectedX, (swipeUp ? -1 : 1) * (size.height + 260));
      HapticFeedback.mediumImpact();
      setState(() => _isSubmittingSwipe = true);
      await _animateDragTo(target,
          duration: _flingDurationFor(target, details.velocity.pixelsPerSecond));
      widget.onSwiped(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movieCard = RepaintBoundary(
      child: _ImmersiveMovieCard(
        movie: widget.movie,
        onInfoTap: widget.onInfoTap,
        actions: _SwipeActionBar(
          canUndo: widget.canUndo,
          onUndo: widget.onUndo,
          onDislike: () => _swipeProgrammatic(SwipeDirection.left),
          onSeen: () => _swipeProgrammatic(SwipeDirection.up),
          onLike: () => _swipeProgrammatic(SwipeDirection.right),
          onWatchlist: () => _swipeProgrammatic(SwipeDirection.down),
        ),
      ),
    );

    return GestureDetector(
      onPanStart: _isSubmittingSwipe
          ? null
          : (_) {
              _swipeController.stop();
              _swipeAnimation = null;
            },
      onPanUpdate: _isSubmittingSwipe
          ? null
          : (details) => _dragOffsetNotifier.value += details.delta,
      onPanEnd: _handlePanEnd,
      onPanCancel: () => _animateDragTo(Offset.zero,
          duration: _snapBackDurationFor(_dragOffsetNotifier.value)),
      child: ValueListenableBuilder<Offset>(
        valueListenable: _dragOffsetNotifier,
        child: movieCard,
        builder: (context, dragOffset, child) {
          final size = MediaQuery.sizeOf(context);
          final rotation = (dragOffset.dx / size.width).clamp(-1.0, 1.0).toDouble() * 0.18;
          final hProgress = (dragOffset.dx.abs() / (size.width * 0.42)).clamp(0.0, 1.0).toDouble();
          final vProgress = (dragOffset.dy.abs() / (size.height * 0.22)).clamp(0.0, 1.0).toDouble();
          final isHoriz = dragOffset.dx.abs() >= dragOffset.dy.abs();
          final overlayProgress = isHoriz ? hProgress : vProgress;
          final transform = Matrix4.identity()
            ..translateByDouble(dragOffset.dx, dragOffset.dy, 0, 1)
            ..rotateZ(rotation);
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                child!,
                _SwipeStampOverlay(progress: overlayProgress, dragOffset: dragOffset),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BackgroundMovieCard extends StatelessWidget {
  const _BackgroundMovieCard({required this.movie});
  final Movie movie;

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    // Must mirror the foreground card layout (action bar + info button):
    // the bottom-aligned content shifts and the actions pop in on promotion
    // to front card otherwise.
    return IgnorePointer(
      child: KeyedSubtree(
        key: ValueKey<String>('background-${movie.id}'),
        child: _ImmersiveMovieCard(
          movie: movie,
          onInfoTap: _noop,
          actions: const _SwipeActionBar(
            canUndo: true,
            onUndo: _noop,
            onDislike: _noop,
            onSeen: _noop,
            onLike: _noop,
            onWatchlist: _noop,
          ),
        ),
      ),
    );
  }
}

class _ImmersiveMovieCard extends StatelessWidget {
  const _ImmersiveMovieCard({
    required this.movie,
    required this.actions,
    this.onInfoTap,
  });

  final Movie movie;
  final Widget actions;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final imageUrl = _preferredSwipeImageUrl(movie);
    final cacheWidth = _swipeImageCacheWidth(context);
    final meta = <String>[
      if (movie.releaseYear > 0) movie.releaseYear.toString(),
      if (movie.runtime > 0) _runtimeLabel(movie.runtime),
    ].join('   ·   ');

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            memCacheWidth: cacheWidth,
            errorWidget: (context, url, error) =>
                DecoratedBox(decoration: BoxDecoration(gradient: t.grad)),
          )
        else
          DecoratedBox(decoration: BoxDecoration(gradient: t.grad)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x1A000000), Color(0xF0000000)],
              stops: [0, 0.4, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 70, 24, 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (movie.genres.isNotEmpty)
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: movie.genres.take(3).map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                const SizedBox(height: 12),
                Text(
                  movie.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontWeight: FontWeight.w800,
                    fontSize: 35,
                    height: 1.0,
                    letterSpacing: -0.7,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 18)],
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                    if (movie.rating > 0) ...[
                      const SizedBox(width: 12),
                      Icon(AgIcons.star, size: 15, color: t.gold),
                      const SizedBox(width: 4),
                      Text(
                        movie.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (onInfoTap != null)
                      GestureDetector(
                        onTap: onInfoTap,
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                          ),
                          child: const Icon(Icons.info_outline_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
                if (movie.overview.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    movie.overview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13.5,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.84),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                actions,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SwipeStampOverlay extends StatelessWidget {
  const _SwipeStampOverlay({required this.progress, required this.dragOffset});
  final double progress;
  final Offset dragOffset;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isHoriz = dragOffset.dx.abs() >= dragOffset.dy.abs();

    Color color;
    Alignment alignment;
    double angle;
    String label;

    if (isHoriz) {
      if (dragOffset.dx >= 0) {
        color = t.green;
        alignment = Alignment.topRight;
        angle = 0.244;
        label = 'LIKE';
      } else {
        color = t.red;
        alignment = Alignment.topLeft;
        angle = -0.244;
        label = 'NOPE';
      }
    } else {
      if (dragOffset.dy < 0) {
        color = t.gold;
        alignment = Alignment.topCenter;
        angle = 0;
        label = 'SEEN';
      } else {
        color = t.purple;
        alignment = Alignment.topCenter;
        angle = 0;
        label = 'WATCHLIST';
      }
    }

    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 96, 24, 0),
          child: Align(
            alignment: alignment,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.86 + progress * 0.2,
                child: AgStamp(label: label, color: color, angle: angle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeActionBar extends StatelessWidget {
  const _SwipeActionBar({
    required this.canUndo,
    required this.onUndo,
    required this.onDislike,
    required this.onSeen,
    required this.onLike,
    required this.onWatchlist,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onDislike;
  final VoidCallback onSeen;
  final VoidCallback onLike;
  final VoidCallback onWatchlist;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActButton(icon: AgIcons.undo, color: t.faint, enabled: canUndo, onTap: onUndo),
        const SizedBox(width: 16),
        _ActButton(icon: AgIcons.close, color: t.red, big: true, onTap: onDislike),
        const SizedBox(width: 16),
        _ActButton(icon: AgIcons.bookmark, color: t.purple, onTap: onWatchlist),
        const SizedBox(width: 16),
        _ActButton(icon: AgIcons.heartFilled, color: t.green, big: true, onTap: onLike),
        const SizedBox(width: 16),
        _ActButton(icon: AgIcons.eye, color: t.gold, onTap: onSeen),
      ],
    );
  }
}

class _ActButton extends StatelessWidget {
  const _ActButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.big = false,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool big;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final size = big ? 64.0 : 52.0;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: t.surface,
              shape: BoxShape.circle,
              border: Border.all(color: t.line2),
              boxShadow: [
                BoxShadow(
                  color: big
                      ? color.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.4),
                  blurRadius: big ? 26 : 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Icon(icon, size: big ? 28 : 23, color: color),
          ),
        ),
      ),
    );
  }
}
