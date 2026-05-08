import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _SwipeFeedback { like, dislike }

class AgreeoSwipeScreen extends ConsumerStatefulWidget {
  const AgreeoSwipeScreen({super.key, this.onNavigateTab});

  final ValueChanged<int>? onNavigateTab;

  @override
  ConsumerState<AgreeoSwipeScreen> createState() => _AgreeoSwipeScreenState();
}

class _AgreeoSwipeScreenState extends ConsumerState<AgreeoSwipeScreen> {
  Future<void> _runAction(
    Future<String> Function() action,
  ) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);
    final queue = state.remainingDailySuggestions;
    final currentMovie = queue.isNotEmpty ? queue.first : null;
    final nextMovie = queue.length > 1 ? queue[1] : null;
    final totalCards = state.dailySuggestionIds.length;
    final processedCards = totalCards - queue.length;
    final progressValue = totalCards == 0 ? 0.0 : processedCards / totalCards;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF060B16), Color(0xFF0B1120), Color(0xFF111827)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'Swipe',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    child: Text(
                      queue.isEmpty ? 'Done' : '${queue.length} left',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Swipe right to like. Swipe left to hide.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: currentMovie == null
                    ? EmptyState(
                        icon: Icons.celebration_rounded,
                        title: 'You\'re done for today.',
                        message:
                            'Come back tomorrow for new suggestions or explore more movies now.',
                        action: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            FilledButton(
                              onPressed: () => widget.onNavigateTab?.call(0),
                              child: const Text('Explore more movies'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () => widget.onNavigateTab?.call(1),
                              child: const Text('Go to Library'),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          if (nextMovie != null)
                            Positioned.fill(
                              top: 18,
                              left: 10,
                              right: 10,
                              bottom: 18,
                              child: Opacity(
                                opacity: 0.26,
                                child: Transform.scale(
                                  scale: 0.965,
                                  child: MovieSwipeCard(
                                    movie: nextMovie,
                                    expand: true,
                                    onInfoTap: () {},
                                    footer: const _SwipeCardFooterSkeleton(),
                                    footerReservedSpace: 84,
                                  ),
                                ),
                              ),
                            ),
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
                                icon: Icons.thumb_down_alt_rounded,
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
                              child: MovieSwipeCard(
                                movie: currentMovie,
                                expand: true,
                                header: _SwipeCardHeader(
                                  progress: progressValue,
                                  seenCount: processedCards,
                                  totalCount: totalCards,
                                ),
                                footer: _SwipeCardActions(
                                  canUndo: state.undoStack.isNotEmpty,
                                  onUndo: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final message = await ref
                                        .read(agreeoAppControllerProvider.notifier)
                                        .undoLastAction();
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
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
                                footerReservedSpace: 92,
                                onInfoTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AgreeoMovieDetailsScreen(
                                        movieId: currentMovie.id,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: alignment == Alignment.centerLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: alignment == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
          colors: <Color>[color.withValues(alpha: 0.88), color.withValues(alpha: 0.32)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (alignment == Alignment.centerRight) ...<Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Icon(icon, color: Colors.white, size: 30),
          if (alignment == Alignment.centerLeft) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipeCardHeader extends StatelessWidget {
  const _SwipeCardHeader({
    required this.progress,
    required this.seenCount,
    required this.totalCount,
  });

  final double progress;
  final int seenCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress <= 0 ? 0.04 : progress,
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          totalCount == 0 ? 'Daily queue' : '${seenCount + 1} of $totalCount',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
        ),
      ],
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
        final buttonSize = constraints.maxWidth < 340 ? 46.0 : 54.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _SwipeCardActionButton(
              icon: Icons.undo_rounded,
              semanticLabel: 'Undo',
              size: buttonSize,
              enabled: canUndo,
              onTap: onUndo,
            ),
            _SwipeCardActionButton(
              icon: Icons.close_rounded,
              semanticLabel: 'Dislike',
              size: buttonSize,
              onTap: onDislike,
            ),
            _SwipeCardActionButton(
              icon: Icons.visibility_outlined,
              semanticLabel: 'Already seen',
              size: buttonSize,
              onTap: onSeen,
            ),
            _SwipeCardActionButton(
              icon: Icons.favorite_rounded,
              semanticLabel: 'Like',
              size: buttonSize,
              onTap: onLike,
            ),
            _SwipeCardActionButton(
              icon: Icons.bookmark_rounded,
              semanticLabel: 'Watchlist',
              size: buttonSize,
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List<Widget>.generate(
        5,
        (index) => Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
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
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: const Color(0xFF0F172A), size: size * 0.46),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
