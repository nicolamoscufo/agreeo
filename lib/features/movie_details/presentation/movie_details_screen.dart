import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:agreeo/shared/components/agreeo_bottom_navigation.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';

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
    _movieFuture = ref
        .read(movieServiceProvider)
        .getMovieDetails(widget.movieId);
  }

  Future<void> _openTrailer(Movie movie) async {
    final uri = Uri.tryParse(movie.trailerUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(agreeoAppControllerProvider);
    final cachedMovie = appState.movieById(widget.movieId);
    final userMovieState = appState.userMovieStateFor(widget.movieId);

    return Scaffold(
      backgroundColor: AgreeoColors.deepBlack,
      body: FutureBuilder<Movie?>(
        future: _movieFuture,
        initialData: cachedMovie,
        builder: (context, snapshot) {
          final movie = snapshot.data;
          if (movie == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          final heroImageUrl = movie.backdropUrl.isNotEmpty
              ? movie.backdropUrl
              : movie.posterUrl;
          final metadata = [
            movie.releaseYear.toString(),
            if (movie.genres.isNotEmpty) movie.genres.take(3).join(', '),
            if (movie.runtimeLabel.isNotEmpty) movie.runtimeLabel,
          ].join('  |  ');

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.45,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: heroImageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(
                                      0xFF111111,
                                    ).withValues(alpha: 0.8),
                                    AgreeoColors.deepBlack,
                                  ],
                                  stops: const [0.6, 0.9, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () => _openTrailer(movie),
                              child: Container(
                                width: 65,
                                height: 65,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 45,
                                ),
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _GlassButton(
                                    icon: Icons.arrow_back,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  Row(
                                    children: [
                                      _GlassButton(
                                        icon: userMovieState.inWatchlist
                                            ? Icons.bookmark_rounded
                                            : Icons.bookmark_outline_rounded,
                                        isActive: userMovieState.inWatchlist,
                                        activeColor: AgreeoColors.kernelGold,
                                        onPressed: () {
                                          if (userMovieState.inWatchlist) {
                                            ref
                                                .read(agreeoAppControllerProvider.notifier)
                                                .removeFromWatchlist(widget.movieId);
                                          } else {
                                            ref
                                                .read(agreeoAppControllerProvider.notifier)
                                                .addToWatchlist(widget.movieId);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _GlassButton(
                                        icon: userMovieState.watched
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        isActive: userMovieState.watched,
                                        activeColor: AgreeoColors.popcornWhite,
                                        onPressed: () {
                                          if (userMovieState.watched) {
                                            ref
                                                .read(agreeoAppControllerProvider.notifier)
                                                .removeFromWatched(widget.movieId);
                                          } else {
                                            ref
                                                .read(agreeoAppControllerProvider.notifier)
                                                .markAsWatched(widget.movieId);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      _GlassButton(
                                        icon: userMovieState.preference == MoviePreference.liked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_outline_rounded,
                                        isActive: userMovieState.preference == MoviePreference.liked,
                                        activeColor: AgreeoColors.cinematicRed,
                                        onPressed: () {
                                          if (userMovieState.preference == MoviePreference.liked) {
                                            ref
                                                .read(agreeoAppControllerProvider.notifier)
                                                .clearPreference(widget.movieId);
                                          } else {
                                            ref
                                                .read(agreeoAppControllerProvider.notifier)
                                                .likeMovie(widget.movieId);
                                          }
                                        },
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            movie.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (movie.director.isNotEmpty)
                            Text(
                              'Directed by ${movie.director}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 8),
                          const SizedBox(height: 12),
                          Text(
                            metadata,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ...List.generate(10, (index) {
                                final ratingOutOfTen = movie.rating.clamp(
                                  0.0,
                                  10.0,
                                );
                                final starValue = ratingOutOfTen - index;
                                final icon = starValue >= 1
                                    ? Icons.star_rounded
                                    : starValue >= 0.5
                                    ? Icons.star_half_rounded
                                    : Icons.star_border_rounded;
                                return Icon(
                                  icon,
                                  color: Colors.amber,
                                  size: 18,
                                );
                              }),
                              const SizedBox(width: 10),
                              Text(
                                movie.rating > 0
                                    ? '${movie.rating.toStringAsFixed(1)}/10'
                                    : 'No rating',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildSectionHeader('Plot'),
                          const SizedBox(height: 12),
                          Text(
                            movie.overview,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildSectionHeader('Cast'),
                          const SizedBox(height: 12),
                          Text(
                            movie.cast.isNotEmpty
                                ? movie.cast.join(', ')
                                : 'Cast not available',
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AgreeoBottomNavigation(
        selectedIndex: ref.watch(navIndexProvider),
        onSelected: (index) {
          ref.read(navIndexProvider.notifier).state = index;
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color activeColor;

  const _GlassButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: isActive
              ? activeColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.15),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? activeColor : Colors.white,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              onPressed();
            },
          ),
        ),
      ),
    );
  }
}

// Note: bottom navigation replaced by AgreeoBottomNavigation above.
