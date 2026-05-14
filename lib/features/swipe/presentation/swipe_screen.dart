import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Modello fittizio per completezza (assicurati che corrisponda al tuo)
import 'package:agreeo/shared/models/agreeo_models.dart';

enum _SwipeFeedback { like, dislike }

class AgreeoSwipeScreen extends ConsumerStatefulWidget {
  const AgreeoSwipeScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  ConsumerState<AgreeoSwipeScreen> createState() => _AgreeoSwipeScreenState();
}

class _AgreeoSwipeScreenState extends ConsumerState<AgreeoSwipeScreen> {
  bool _queueRefillScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleRefillIfNeeded(0);
    });
  }

  Future<void> _runAction(Future<String> Function() action) async {
    try {
      final message = await action();
      if (!mounted) {
        return;
      }
      await showUndoSnackbar(
        context,
        message: message,
        onUndo: () async {
          await ref.read(agreeoAppControllerProvider.notifier).undoLastAction();
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);
    final queue = state.remainingDailySuggestions;
    _scheduleRefillIfNeeded(queue.length);
    final currentMovie = queue.isNotEmpty ? queue.first : null;
    final nextMovie = queue.length > 1 ? queue[1] : null;

    if (currentMovie == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF060B16),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.celebration_rounded,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                Text(
                  'No more suggestions available right now.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can refresh the queue for any newly available candidates or explore the rest of the catalog.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => ref
                      .read(agreeoAppControllerProvider.notifier)
                      .refreshMovieSuggestions(),
                  child: const Text('Refresh suggestions'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  child: const Text('Go to Library'),
                ),
              ],
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
          // Background Movie (Il prossimo film, visibile leggermente dietro/durante lo swipe)
          if (nextMovie != null)
            Positioned.fill(
              child: _ImmersiveMovieCard(
                movie: nextMovie,
                isBackground: true,
                actions: const _SwipeCardFooterSkeleton(),
              ),
            ),

          // Current Movie (Interattivo con Dismissible)
          Positioned.fill(
            child: Dismissible(
              key: ValueKey<String>(currentMovie.id),
              direction: DismissDirection.horizontal,
              resizeDuration: null,
              movementDuration: const Duration(milliseconds: 240),
              background: const _SwipeBackground(
                alignment: Alignment.centerLeft,
                icon: Icons.thumb_up_alt_rounded,
                label: 'Like',
                color: Color(0xFF16A34A),
              ),
              secondaryBackground: const _SwipeBackground(
                alignment: Alignment.centerRight,
                icon: Icons.close_rounded,
                label: 'Dislike',
                color: Color(0xFFDC2626),
              ),
              onDismissed: (direction) {
                final feedback = direction == DismissDirection.startToEnd
                    ? _SwipeFeedback.like
                    : _SwipeFeedback.dislike;
                _runAction(
                  feedback == _SwipeFeedback.like
                      ? () => ref
                            .read(agreeoAppControllerProvider.notifier)
                            .likeMovie(currentMovie.id)
                      : () => ref
                            .read(agreeoAppControllerProvider.notifier)
                            .dislikeMovie(currentMovie.id),
                );
              },
              child: _ImmersiveMovieCard(
                movie: currentMovie,
                isBackground: false,
                onInfoTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AgreeoMovieDetailsScreen(movieId: currentMovie.id),
                    ),
                  );
                },
                actions: _SwipeCardActions(
                  canUndo: state.undoStack.isNotEmpty,
                  onUndo: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final message = await ref
                        .read(agreeoAppControllerProvider.notifier)
                        .undoLastAction();
                    if (!mounted) return;
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                  },
                  onDislike: () => _runAction(
                    () => ref
                        .read(agreeoAppControllerProvider.notifier)
                        .dislikeMovie(currentMovie.id),
                  ),
                  onSeen: () => _runAction(
                    () => ref
                        .read(agreeoAppControllerProvider.notifier)
                        .markAsWatched(currentMovie.id),
                  ),
                  onLike: () => _runAction(
                    () => ref
                        .read(agreeoAppControllerProvider.notifier)
                        .likeMovie(currentMovie.id),
                  ),
                  onWatchlist: () => _runAction(
                    () => ref
                        .read(agreeoAppControllerProvider.notifier)
                        .addToWatchlist(currentMovie.id),
                  ),
                ),
              ),
            ),
          ),
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

class _ImmersiveMovieCard extends StatelessWidget {
  const _ImmersiveMovieCard({
    required this.movie,
    required this.actions,
    this.isBackground = false,
    this.onInfoTap,
  });

  final Movie movie;
  final Widget actions;
  final bool isBackground;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _preferredImageUrl(movie);
    final metadata = <String>[
      if (movie.releaseYear > 0) movie.releaseYear.toString(),
      if (movie.genres.isNotEmpty) movie.genres.take(3).join(', '),
    ].join(' • ');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isBackground ? 26 : 16,
        isBackground ? 36 : 18,
        isBackground ? 26 : 16,
        isBackground ? 120 : 18,
      ),
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
                  errorWidget: (context, url, error) =>
                      Container(color: const Color(0xFF0F172A)),
                )
              else
                Container(color: const Color(0xFF0F172A)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x22060B16),
                      Color(0x66060B16),
                      Color(0xE6060B16),
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
                      Align(
                        alignment: Alignment.topRight,
                        child: onInfoTap == null
                            ? const SizedBox.shrink()
                            : Material(
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
                      ),
                      const Spacer(),
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
                      if (movie.overview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          movie.overview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      actions,
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

  String _preferredImageUrl(Movie movie) {
    final raw = movie.posterUrl.isNotEmpty
        ? movie.posterUrl
        : movie.backdropUrl;
    return raw.replaceFirst('/w500/', '/w780/');
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 48),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
        ],
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
        final baseSize = isSmallPhone ? 48.0 : 56.0;
        final mainSize = isSmallPhone
            ? 56.0
            : 68.0; // Per X e Cuore (più grandi)

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _SwipeCardActionButton(
              icon: Icons.undo_rounded,
              semanticLabel: 'Undo',
              size: baseSize,
              enabled: canUndo,
              onTap: onUndo,
            ),
            _SwipeCardActionButton(
              icon: Icons.close_rounded,
              semanticLabel: 'Dislike',
              size: mainSize,
              onTap: onDislike,
            ),
            _SwipeCardActionButton(
              icon: Icons.remove_red_eye_outlined,
              semanticLabel: 'Already seen',
              size: baseSize,
              onTap: onSeen,
            ),
            _SwipeCardActionButton(
              icon: Icons.favorite_rounded,
              semanticLabel: 'Like',
              size: mainSize,
              onTap: onLike,
            ),
            _SwipeCardActionButton(
              icon: Icons.bookmark_rounded,
              semanticLabel: 'Watchlist',
              size: baseSize,
              onTap: onWatchlist,
            ),
          ],
        );
      },
    );
  }
}

class _SwipeCardFooterSkeleton extends StatelessWidget {
  const _SwipeCardFooterSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List<Widget>.generate(5, (index) {
        final isMain = index == 1 || index == 3;
        return Container(
          width: isMain ? 68 : 56,
          height: isMain ? 68 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
          ),
        );
      }),
    );
  }
}

class _SwipeCardActionButton extends StatelessWidget {
  const _SwipeCardActionButton({
    required this.icon,
    required this.semanticLabel,
    required this.size,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String semanticLabel;
  final double size;
  final VoidCallback onTap;
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
            color: Colors.white, // Bottoni bianchi dello screenshot
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  color: Colors.black, // Icone nere dello screenshot
                  size: size * 0.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
