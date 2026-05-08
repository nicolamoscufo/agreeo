import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(
                title: 'Swipe',
                subtitle: queue.isEmpty
                    ? 'You are done for today.'
                    : '${queue.length} cards left in your daily stack.',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.45),
                ),
                child: const Text(
                  'Fast signals now make group movie nights much easier later.',
                ),
              ),
              const SizedBox(height: 18),
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
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          if (nextMovie != null)
                            Positioned(
                              top: 26,
                              left: 14,
                              right: 14,
                              child: Opacity(
                                opacity: 0.32,
                                child: Transform.scale(
                                  scale: 0.95,
                                  child: MovieSwipeCard(
                                    movie: nextMovie,
                                    onInfoTap: () {},
                                  ),
                                ),
                              ),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            child: MovieSwipeCard(
                              key: ValueKey<String>(currentMovie.id),
                              movie: currentMovie,
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
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Opacity(
                      opacity: state.undoStack.isEmpty ? 0.45 : 1,
                      child: IgnorePointer(
                        ignoring: state.undoStack.isEmpty,
                        child: ActionButton(
                          icon: Icons.undo_rounded,
                          label: 'Undo',
                          onTap: () async {
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
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      icon: Icons.thumb_down_alt_outlined,
                      label: 'Dislike',
                      onTap: currentMovie == null
                          ? () {}
                          : () => _runAction(
                                () => ref
                                    .read(agreeoAppControllerProvider.notifier)
                                    .dislikeMovie(currentMovie.id),
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      icon: Icons.visibility_outlined,
                      label: 'Seen',
                      onTap: currentMovie == null
                          ? () {}
                          : () => _runAction(
                                () => ref
                                    .read(agreeoAppControllerProvider.notifier)
                                    .markAsWatched(currentMovie.id),
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      icon: Icons.thumb_up_alt_outlined,
                      label: 'Like',
                      isPrimary: true,
                      onTap: currentMovie == null
                          ? () {}
                          : () => _runAction(
                                () => ref
                                    .read(agreeoAppControllerProvider.notifier)
                                    .likeMovie(currentMovie.id),
                              ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ActionButton(
                      icon: Icons.bookmark_add_outlined,
                      label: 'Watchlist',
                      onTap: currentMovie == null
                          ? () {}
                          : () => _runAction(
                                () => ref
                                    .read(agreeoAppControllerProvider.notifier)
                                    .addToWatchlist(currentMovie.id),
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
