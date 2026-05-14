import 'dart:ui';

import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
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
            movie.runtimeLabel,
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
                                    const Color(0xFF111111).withOpacity(0.8),
                                    const Color(0xFF111111),
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
                                  _GlassButton(
                                    icon: Icons.favorite,
                                    onPressed: () {},
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
                          const SizedBox(height: 12),
                          Text(
                            metadata,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return Icon(
                                index < 4 ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 24,
                              );
                            }),
                          ),
                          const SizedBox(height: 32),
                          _buildSectionHeader('Plot'),
                          const SizedBox(height: 12),
                          Text(
                            movie.overview,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildSectionHeader('Cast'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: movie.cast.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 20),
                              itemBuilder: (context, index) {
                                return Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.white10,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      movie.cast[index],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: _FakeBottomNav(),
              ),
            ],
          );
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
  const _GlassButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withOpacity(0.15),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _FakeBottomNav extends StatelessWidget {
  const _FakeBottomNav();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(Icons.home, color: Colors.white, size: 28),
          Icon(Icons.play_circle_outline, color: Colors.white54, size: 28),
          Icon(Icons.search, color: Colors.white54, size: 28),
          Icon(Icons.person_outline, color: Colors.white54, size: 28),
        ],
      ),
    );
  }
}
