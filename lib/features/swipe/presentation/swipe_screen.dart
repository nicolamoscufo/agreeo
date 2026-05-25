import 'dart:async';

import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';

String _preferredSwipeImageUrl(Movie movie) {
  final raw = movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.backdropUrl;
  return raw.replaceFirst('/w500/', '/w780/');
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
    if (_queueRefillScheduled || !mounted) {
      return;
    }
    if (queueLength > AgreeoAppController.swipeQueueRefillThreshold) {
      return;
    }

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
        break;
      case SwipeDirection.right:
        action = () => controller.likeMovie(movieId);
        break;
      case SwipeDirection.up:
        action = () => controller.markAsWatched(movieId);
        break;
      case SwipeDirection.down:
        action = () => controller.addToWatchlist(movieId);
        break;
    }

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final url in urls) {
        unawaited(
          precacheImage(
            CachedNetworkImageProvider(url),
            context,
            onError: (Object _, StackTrace? _) {},
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);
    final queue = state.remainingDailySuggestions;
    _scheduleSwipeImagePrecache(context, queue);
    _scheduleRefillIfNeeded(queue.length);
    final currentMovie = queue.isNotEmpty ? queue.first : null;
    final nextMovie = queue.length > 1 ? queue[1] : null;

    if (currentMovie == null) {
      return Scaffold(
        backgroundColor: AgreeoColors.deepBlack,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AgreeoColors.cinematicRed.withValues(alpha: 0.08),
                    AgreeoColors.kernelGold.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AgreeoColors.cinematicRed.withValues(alpha: 0.2),
                          AgreeoColors.kernelGold.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      size: 40,
                      color: AgreeoColors.cinematicRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'All caught up! 🎬',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You\'ve swiped through all current suggestions.\nRefresh to discover new picks or browse your library.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(agreeoAppControllerProvider.notifier)
                            .refreshMovieSuggestions();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh suggestions'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onNavigateTab?.call(1),
                      icon: const Icon(Icons.video_library_rounded),
                      label: const Text('Go to Library'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Background Movie
          if (nextMovie != null)
            Positioned.fill(child: _BackgroundMovieCard(movie: nextMovie)),

          // Current Movie
          Positioned.fill(
            child: SwipeableCard(
              key: ValueKey<String>(currentMovie.id),
              movie: currentMovie,
              canUndo: state.undoStack.isNotEmpty,
              onSwiped: (direction) =>
                  _handleSwiped(currentMovie.id, direction),
              onUndo: () async {
                HapticFeedback.lightImpact();
                final messenger = ScaffoldMessenger.of(context);
                final message = await ref
                    .read(agreeoAppControllerProvider.notifier)
                    .undoLastAction();
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text(message)));
              },
              onInfoTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AgreeoMovieDetailsScreen(movieId: currentMovie.id),
                  ),
                );
              },
            ),
          ),

          // Queue counter pill
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.layers_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${queue.length} left',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_queueRefillScheduled)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Loading more suggestions...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
  static const Duration _programmaticSwipeDuration = Duration(
    milliseconds: 280,
  );
  static const Duration _maxFlingDuration = Duration(milliseconds: 280);
  static const Duration _minFlingDuration = Duration(milliseconds: 170);

  late final AnimationController _swipeController;
  Animation<Offset>? _swipeAnimation;
  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(
    Offset.zero,
  );
  bool _isSubmittingSwipe = false;

  @override
  void initState() {
    super.initState();
    _swipeController =
        AnimationController(
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
    final animation = Tween<Offset>(
      begin: _dragOffsetNotifier.value,
      end: target,
    ).animate(CurvedAnimation(parent: _swipeController, curve: curve));
    _swipeAnimation = animation;
    try {
      await _swipeController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (_swipeAnimation == animation) {
        _swipeAnimation = null;
      }
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
        break;
      case SwipeDirection.right:
        target = Offset(size.width + 260, 0);
        break;
      case SwipeDirection.up:
        target = Offset(0, -size.height - 260);
        break;
      case SwipeDirection.down:
        target = Offset(0, size.height + 260);
        break;
    }
    HapticFeedback.mediumImpact();
    await _animateDragTo(
      target,
      duration: _programmaticSwipeDuration,
      curve: Curves.easeOutCubic,
    );
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
      final shouldVote =
          dragOffset.dx.abs() > size.width * 0.28 || velocityX.abs() > 650;
      if (!shouldVote) {
        await _animateDragTo(
          Offset.zero,
          duration: _snapBackDurationFor(dragOffset),
        );
        return;
      }
      final swipeLike = velocityX.abs() > dragOffset.dx.abs()
          ? velocityX > 0
          : dragOffset.dx > 0;

      final direction = swipeLike ? SwipeDirection.right : SwipeDirection.left;
      final projectedY = (dragOffset.dy + velocityY * 0.10)
          .clamp(-size.height * 0.42, size.height * 0.42)
          .toDouble();
      final target = Offset(
        (swipeLike ? 1 : -1) * (size.width + 260),
        projectedY,
      );

      HapticFeedback.mediumImpact();
      setState(() => _isSubmittingSwipe = true);
      await _animateDragTo(
        target,
        duration: _flingDurationFor(target, details.velocity.pixelsPerSecond),
        curve: Curves.easeOutCubic,
      );
      widget.onSwiped(direction);
    } else {
      final shouldVote =
          dragOffset.dy.abs() > size.height * 0.18 || velocityY.abs() > 650;
      if (!shouldVote) {
        await _animateDragTo(
          Offset.zero,
          duration: _snapBackDurationFor(dragOffset),
        );
        return;
      }
      final swipeUp = velocityY.abs() > dragOffset.dy.abs()
          ? velocityY < 0
          : dragOffset.dy < 0;

      final direction = swipeUp ? SwipeDirection.up : SwipeDirection.down;
      final projectedX = (dragOffset.dx + velocityX * 0.10)
          .clamp(-size.width * 0.42, size.width * 0.42)
          .toDouble();
      final target = Offset(
        projectedX,
        (swipeUp ? -1 : 1) * (size.height + 260),
      );

      HapticFeedback.mediumImpact();
      setState(() => _isSubmittingSwipe = true);
      await _animateDragTo(
        target,
        duration: _flingDurationFor(target, details.velocity.pixelsPerSecond),
        curve: Curves.easeOutCubic,
      );
      widget.onSwiped(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movieCard = RepaintBoundary(
      child: _ImmersiveMovieCard(
        movie: widget.movie,
        onInfoTap: widget.onInfoTap,
        actions: _SwipeCardActions(
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
          : (details) {
              _dragOffsetNotifier.value += details.delta;
            },
      onPanEnd: (details) => _handlePanEnd(details),
      onPanCancel: () {
        _animateDragTo(
          Offset.zero,
          duration: _snapBackDurationFor(_dragOffsetNotifier.value),
        );
      },
      child: ValueListenableBuilder<Offset>(
        valueListenable: _dragOffsetNotifier,
        child: movieCard,
        builder: (context, dragOffset, child) {
          final width = MediaQuery.sizeOf(context).width;
          final rotation =
              (dragOffset.dx / width).clamp(-1.0, 1.0).toDouble() * 0.18;

          final hProgress = (dragOffset.dx.abs() / (width * 0.42))
              .clamp(0.0, 1.0)
              .toDouble();
          final vProgress =
              (dragOffset.dy.abs() / (MediaQuery.sizeOf(context).height * 0.22))
                  .clamp(0.0, 1.0)
                  .toDouble();
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
                _SwipeStampOverlay(
                  progress: overlayProgress,
                  dragOffset: dragOffset,
                ),
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

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>('background-${movie.id}'),
      child: _ImmersiveMovieCard(
        movie: movie,
        actions: const _SwipeCardActionsPreview(),
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
    final imageUrl = _preferredSwipeImageUrl(movie);
    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    final metadata = <String>[
      if (movie.releaseYear > 0) movie.releaseYear.toString(),
      if (movie.genres.isNotEmpty) movie.genres.take(3).join(', '),
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  useOldImageOnUrlChange: true,
                  filterQuality: FilterQuality.low,
                  memCacheWidth: cacheWidth,
                  errorWidget: (context, url, error) =>
                      Container(color: AgreeoColors.deepBlack),
                )
              else
                Container(color: AgreeoColors.deepBlack),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x22121212),
                      Color(0x66121212),
                      Color(0xE6121212),
                    ],
                    stops: <double>[0, 0.45, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          if (movie.rating > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AgreeoColors.kernelGold.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: AgreeoColors.kernelGold,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    movie.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: AgreeoColors.kernelGold,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          if (onInfoTap != null)
                            Material(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                onTap: onInfoTap,
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          if (onInfoTap == null)
                            const SizedBox(width: 44, height: 44),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movie.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: -0.6,
                              ),
                            ),
                            if (metadata.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                metadata,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (movie.genres.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: movie.genres
                                    .take(3)
                                    .map((genre) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          genre,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ],
                            if (movie.overview.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 14),
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Text(
                                    movie.overview,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            actions,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeStampOverlay extends StatelessWidget {
  const _SwipeStampOverlay({required this.progress, required this.dragOffset});

  final double progress;
  final Offset dragOffset;

  @override
  Widget build(BuildContext context) {
    final isHorizontalDominant = dragOffset.dx.abs() >= dragOffset.dy.abs();

    late final Color color;
    late final Alignment alignment;
    late final double angle;
    late final String label;

    if (isHorizontalDominant) {
      if (dragOffset.dx >= 0) {
        color = AgreeoColors.cinematicRed; // LIKE is brand red
        alignment = Alignment.topLeft;
        angle = -0.18;
        label = 'LIKE \u2665';
      } else {
        color = AgreeoColors.popcornWhite; // NOPE is neutral white
        alignment = Alignment.topRight;
        angle = 0.18;
        label = 'NOPE \u2715';
      }
    } else {
      if (dragOffset.dy < 0) {
        color = AgreeoColors.popcornWhite; // SEEN is neutral white
        alignment = Alignment.bottomCenter;
        angle = 0;
        label = 'SEEN \u{1F441}';
      } else {
        color = AgreeoColors.kernelGold; // WATCHLIST is gold
        alignment = Alignment.topCenter;
        angle = 0;
        label = 'WATCHLIST \u{1F516}';
      }
    }

    return IgnorePointer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(38, 78, 38, 0),
          child: Align(
            alignment: alignment,
            child: Opacity(
              opacity: progress,
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: 0.86 + progress * 0.24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color, width: 4),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeCardActions extends StatelessWidget {
  const _SwipeCardActions({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallPhone = constraints.maxWidth < 340;
        final baseSize = isSmallPhone ? 44.0 : 52.0;
        final mainSize = isSmallPhone ? 52.0 : 62.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _SwipeCardActionButton(
              icon: Icons.undo_rounded,
              semanticLabel: 'Undo',
              size: baseSize,
              enabled: canUndo,
              onTap: onUndo,
              backgroundColor: AgreeoColors.darkSurface,
              iconColor: Colors.white,
            ),
            _SwipeCardActionButton(
              icon: Icons.close_rounded,
              semanticLabel: 'Dislike',
              size: mainSize,
              onTap: onDislike,
              backgroundColor: AgreeoColors.popcornWhite.withValues(
                alpha: 0.12,
              ),
              iconColor: AgreeoColors.popcornWhite,
            ),
            _SwipeCardActionButton(
              icon: Icons.remove_red_eye_outlined,
              semanticLabel: 'Already seen',
              size: baseSize,
              onTap: onSeen,
              backgroundColor: AgreeoColors.popcornWhite.withValues(
                alpha: 0.12,
              ),
              iconColor: AgreeoColors.popcornWhite,
            ),
            _SwipeCardActionButton(
              icon: Icons.favorite_rounded,
              semanticLabel: 'Like',
              size: mainSize,
              onTap: onLike,
              backgroundColor: AgreeoColors.cinematicRed.withValues(
                alpha: 0.15,
              ),
              iconColor: AgreeoColors.cinematicRed,
            ),
            _SwipeCardActionButton(
              icon: Icons.bookmark_rounded,
              semanticLabel: 'Watchlist',
              size: baseSize,
              onTap: onWatchlist,
              backgroundColor: AgreeoColors.kernelGold.withValues(alpha: 0.15),
              iconColor: AgreeoColors.kernelGold,
            ),
          ],
        );
      },
    );
  }
}

class _SwipeCardActionsPreview extends StatelessWidget {
  const _SwipeCardActionsPreview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallPhone = constraints.maxWidth < 340;
        final baseSize = isSmallPhone ? 44.0 : 52.0;
        final mainSize = isSmallPhone ? 52.0 : 62.0;

        return ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _SwipeCardActionPreviewButton(
                icon: Icons.undo_rounded,
                size: baseSize,
                opacity: 0.4,
                backgroundColor: AgreeoColors.darkSurface,
                iconColor: Colors.white,
              ),
              _SwipeCardActionPreviewButton(
                icon: Icons.close_rounded,
                size: mainSize,
                backgroundColor: AgreeoColors.popcornWhite.withValues(
                  alpha: 0.12,
                ),
                iconColor: AgreeoColors.popcornWhite,
              ),
              _SwipeCardActionPreviewButton(
                icon: Icons.remove_red_eye_outlined,
                size: baseSize,
                backgroundColor: AgreeoColors.popcornWhite.withValues(
                  alpha: 0.12,
                ),
                iconColor: AgreeoColors.popcornWhite,
              ),
              _SwipeCardActionPreviewButton(
                icon: Icons.favorite_rounded,
                size: mainSize,
                backgroundColor: AgreeoColors.cinematicRed.withValues(
                  alpha: 0.15,
                ),
                iconColor: AgreeoColors.cinematicRed,
              ),
              _SwipeCardActionPreviewButton(
                icon: Icons.bookmark_rounded,
                size: baseSize,
                backgroundColor: AgreeoColors.kernelGold.withValues(
                  alpha: 0.15,
                ),
                iconColor: AgreeoColors.kernelGold,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwipeCardActionPreviewButton extends StatelessWidget {
  const _SwipeCardActionPreviewButton({
    required this.icon,
    required this.size,
    required this.backgroundColor,
    required this.iconColor,
    this.opacity = 1,
  });

  final IconData icon;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}

class _SwipeCardActionButton extends StatelessWidget {
  const _SwipeCardActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.size,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    this.enabled = true,
  });

  final IconData icon;
  final String semanticLabel;
  final double size;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: backgroundColor,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: iconColor, size: size * 0.45),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
