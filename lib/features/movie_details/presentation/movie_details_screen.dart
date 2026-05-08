import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/components/review_editor.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AgreeoMovieDetailsScreen extends ConsumerWidget {
  const AgreeoMovieDetailsScreen({super.key, required this.movieId});

  final String movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(agreeoAppControllerProvider);
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final movie = appState.movieById(movieId);

    if (movie == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Movie not found',
            message: 'This mock title is no longer available in the local catalog.',
          ),
        ),
      );
    }

    final userState = appState.userMovieStateFor(movieId);

    Future<void> handleQuickAction(Future<String> Function() action) async {
      final message = await action();
      if (!context.mounted) {
        return;
      }
      await showUndoSnackbar(
        context,
        message: message,
        onUndo: () async {
          await controller.undoLastAction();
        },
      );
    }

    Future<void> saveRating(int value) async {
      final message = await controller.rateMovie(movieId, value);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> editReview() async {
      final result = await showReviewEditorSheet(
        context,
        title: 'Your review',
        initialReview: userState.review,
        allowDelete: userState.hasReview,
      );
      if (result == null) {
        return;
      }

      final message = result == '__DELETE__'
          ? await controller.deleteReview(movieId)
          : await controller.saveReview(movieId, result);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    Future<void> openTrailer() async {
      final uri = Uri.tryParse(movie.trailerUrl);
      if (uri == null) {
        return;
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open trailer.')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: <Widget>[
          MovieDetailsHeader(movie: movie),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              SelectableChip(
                label: userState.preference == MoviePreference.liked ? 'Liked' : 'Like',
                icon: Icons.thumb_up_alt_outlined,
                selected: userState.preference == MoviePreference.liked,
                onTap: () => handleQuickAction(
                  userState.preference == MoviePreference.liked
                      ? () => controller.clearPreference(movieId)
                      : () => controller.likeMovie(movieId),
                ),
              ),
              SelectableChip(
                label: userState.preference == MoviePreference.disliked
                    ? 'Hidden'
                    : 'Dislike',
                icon: Icons.thumb_down_alt_outlined,
                selected: userState.preference == MoviePreference.disliked,
                onTap: () => handleQuickAction(
                  userState.preference == MoviePreference.disliked
                      ? () => controller.clearPreference(movieId)
                      : () => controller.dislikeMovie(movieId),
                ),
              ),
              SelectableChip(
                label: userState.inWatchlist ? 'In Watchlist' : 'Watchlist',
                icon: Icons.bookmark_outline_rounded,
                selected: userState.inWatchlist,
                onTap: () => handleQuickAction(
                  userState.inWatchlist
                      ? () => controller.removeFromWatchlist(movieId)
                      : () => controller.addToWatchlist(movieId),
                ),
              ),
              SelectableChip(
                label: userState.watched ? 'Watched' : 'Already Seen',
                icon: Icons.visibility_outlined,
                selected: userState.watched,
                onTap: () => handleQuickAction(
                  userState.watched
                      ? () => controller.removeFromWatched(movieId)
                      : () => controller.markAsWatched(movieId),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _DetailsSection(
            title: 'Snapshot',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                InfoBadge(label: '${movie.rating.toStringAsFixed(1)} rating'),
                InfoBadge(label: movie.director),
                ...movie.genres.map((genre) => InfoBadge(label: genre)),
              ],
            ),
          ),
          _DetailsSection(
            title: 'Plot',
            child: Text(
              movie.overview,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
          _DetailsSection(
            title: 'Cast',
              child: SizedBox(
                height: 46,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                    child: Text(movie.cast[index]),
                  ),
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemCount: movie.cast.length,
                ),
              ),
          ),
          _DetailsSection(
            title: 'Trailer',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.16),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Trailer preview area',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This keeps long-form media details out of the swipe card.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: openTrailer,
                      child: const Text('Play'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _DetailsSection(
            title: 'Your rating',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RatingStars(value: userState.rating ?? 0, onChanged: saveRating),
                const SizedBox(height: 10),
                Text(
                  userState.rating == null
                      ? 'Rating is optional.'
                      : 'You rated this ${userState.rating}/5.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          _DetailsSection(
            title: 'Your review',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      userState.hasReview
                          ? userState.review!
                          : 'No review yet. Leave a quick thought so future group picks carry your actual context, not just a thumbs up.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: userState.hasReview
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: editReview,
                      icon: Icon(
                        userState.hasReview ? Icons.edit_note_rounded : Icons.edit_rounded,
                      ),
                      label: Text(userState.hasReview ? 'Edit review' : 'Write review'),
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

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
