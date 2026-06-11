import 'package:agreeo/features/movie_details/presentation/review_editor_sheet.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class AgreeoMovieDetailsScreen extends ConsumerStatefulWidget {
  const AgreeoMovieDetailsScreen({super.key, required this.movieId});

  final String movieId;

  @override
  ConsumerState<AgreeoMovieDetailsScreen> createState() =>
      _AgreeoMovieDetailsScreenState();
}

class _AgreeoMovieDetailsScreenState
    extends ConsumerState<AgreeoMovieDetailsScreen> {
  late final Future<Movie?> _movieFuture;

  @override
  void initState() {
    super.initState();
    _movieFuture = ref.read(movieServiceProvider).getMovieDetails(widget.movieId);
  }

  Future<void> _run(Future<String> Function() action) async {
    // State toggles update the UI directly via the provider — no toast spam.
    HapticFeedback.lightImpact();
    try {
      await action();
    } catch (_) {
      // Optimistic UI already reflects intent; ignore transient backend errors.
    }
  }

  Future<void> _openTrailer(Movie movie) async {
    final uri = Uri.tryParse(movie.trailerUrl);
    if (uri == null || movie.trailerUrl.isEmpty) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final appState = ref.watch(agreeoAppControllerProvider);
    final cached = appState.movieById(widget.movieId);
    final us = appState.userMovieStateFor(widget.movieId);
    final controller = ref.read(agreeoAppControllerProvider.notifier);

    return Scaffold(
      backgroundColor: t.bg,
      body: FutureBuilder<Movie?>(
        future: _movieFuture,
        initialData: cached,
        builder: (context, snapshot) {
          final movie = snapshot.data;
          if (movie == null) {
            return Center(child: CircularProgressIndicator(color: t.red));
          }
          final heroUrl = movie.backdropUrl.isNotEmpty ? movie.backdropUrl : movie.posterUrl;
          final liked = us.preference == MoviePreference.liked;

          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Hero
                  SizedBox(
                    height: 340,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(decoration: BoxDecoration(gradient: t.grad)),
                        if (heroUrl.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: heroUrl,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.55),
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                t.heroBg.withValues(alpha: 0.05),
                                t.heroBg.withValues(alpha: 0.45),
                                t.bg,
                              ],
                              stops: const [0, 0.5, 0.99],
                            ),
                          ),
                        ),
                        // Nav buttons
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 18,
                          right: 18,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _HeroButton(icon: AgIcons.chevronLeft, onTap: () => Navigator.of(context).pop()),
                              _HeroButton(
                                icon: liked ? AgIcons.heartFilled : AgIcons.heart,
                                iconColor: liked ? t.green : Colors.white,
                                onTap: () => _run(
                                  liked
                                      ? () => controller.clearPreference(movie.id)
                                      : () => controller.likeMovie(movie.id),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Poster + title
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 0,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(width: 108, child: AgPoster(imageUrl: movie.posterUrl, title: movie.title)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        movie.title,
                                        style: const TextStyle(
                                          fontFamily: 'Bricolage Grotesque',
                                          fontWeight: FontWeight.w800,
                                          fontSize: 25,
                                          letterSpacing: -0.5,
                                          height: 1.04,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        movie.runtimeLabel.isEmpty
                                            ? '${movie.releaseYear}'
                                            : '${movie.releaseYear} · ${movie.runtimeLabel}',
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      if (movie.rating > 0)
                                        Row(
                                          children: [
                                            Icon(AgIcons.star, size: 16, color: t.gold),
                                            const SizedBox(width: 4),
                                            Text(
                                              movie.rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontFamily: 'Manrope',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (movie.genres.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: movie.genres
                                .map((g) => _GenrePill(label: g))
                                .toList(growable: false),
                          ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _StateButton(
                                icon: AgIcons.heartFilled,
                                label: 'Liked',
                                color: t.green,
                                active: liked,
                                onTap: () => _run(liked
                                    ? () => controller.clearPreference(movie.id)
                                    : () => controller.likeMovie(movie.id)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StateButton(
                                icon: AgIcons.bookmark,
                                label: 'Watchlist',
                                color: t.purple,
                                active: us.inWatchlist,
                                onTap: () => _run(us.inWatchlist
                                    ? () => controller.removeFromWatchlist(movie.id)
                                    : () => controller.addToWatchlist(movie.id)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StateButton(
                                icon: AgIcons.eye,
                                label: 'Watched',
                                color: t.gold,
                                active: us.watched,
                                onTap: () => _run(us.watched
                                    ? () => controller.removeFromWatched(movie.id)
                                    : () => controller.markAsWatched(movie.id)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (movie.trailerUrl.isNotEmpty) ...[
                          AgButton(
                            label: 'Watch trailer',
                            icon: AgIcons.play,
                            onPressed: () => _openTrailer(movie),
                          ),
                          const SizedBox(height: 22),
                        ],
                        _SectionTitle('Synopsis'),
                        const SizedBox(height: 8),
                        Text(
                          movie.overview.isEmpty ? 'No synopsis available yet.' : movie.overview,
                          style: TextStyle(fontFamily: 'Manrope', fontSize: 14, height: 1.6, color: t.sub),
                        ),
                        if (movie.cast.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _SectionTitle('Cast'),
                          const SizedBox(height: 8),
                          Text(
                            movie.cast.take(6).join(' · '),
                            style: TextStyle(fontFamily: 'Manrope', fontSize: 14, height: 1.6, color: t.sub),
                          ),
                        ],
                        const SizedBox(height: 22),
                        _SectionTitle('Your review'),
                        const SizedBox(height: 10),
                        _ReviewCard(
                          userState: us,
                          authorName: appState.session?.displayName ?? 'You',
                          onEdit: () => showReviewEditor(context, movie),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.onTap, this.iconColor});
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: t.line2),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? Colors.white),
      ),
    );
  }
}

class _GenrePill extends StatelessWidget {
  const _GenrePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.line),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 12.5, color: t.sub),
      ),
    );
  }
}

class _StateButton extends StatelessWidget {
  const _StateButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color.withValues(alpha: 0.4) : t.line),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: active ? color : t.sub),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                color: active ? color : t.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      title,
      style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 16, color: t.text),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.userState, required this.authorName, required this.onEdit});
  final UserMovieState userState;
  final String authorName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasReview = userState.hasReview || userState.rating != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AgAvatar(name: authorName, color: t.red, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You',
                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 13.5, color: t.text),
                ),
              ),
              if (userState.rating != null)
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < userState.rating! ? AgIcons.star : AgIcons.starOutline,
                      size: 14,
                      color: i < userState.rating! ? t.gold : t.line2,
                    );
                  }),
                ),
            ],
          ),
          if (userState.hasReview) ...[
            const SizedBox(height: 9),
            Text(
              '"${userState.review}"',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13.5,
                height: 1.55,
                fontStyle: FontStyle.italic,
                color: t.sub,
              ),
            ),
          ],
          const SizedBox(height: 11),
          GestureDetector(
            onTap: onEdit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AgIcons.edit, size: 15, color: t.red),
                const SizedBox(width: 6),
                Text(
                  hasReview ? 'Edit review' : 'Add a review',
                  style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, color: t.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
