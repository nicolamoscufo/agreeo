import 'dart:ui';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/components/review_editor.dart';
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

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(agreeoAppControllerProvider);
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final cachedMovie = appState.movieById(widget.movieId);
    final userState = appState.userMovieStateFor(widget.movieId);

    Future<void> openTrailer(Movie movie) async {
      final uri = Uri.tryParse(movie.trailerUrl);
      if (uri == null) return;

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open trailer.')),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC026D3)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF22D3EE)),
            onPressed: () {},
          )
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Movie?>(
        future: _movieFuture,
        initialData: cachedMovie,
        builder: (context, snapshot) {
          final movie = snapshot.data;

          if (movie == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Immagine Sotto a tutto schermo
              CachedNetworkImage(
                imageUrl: movie.posterUrl.isNotEmpty ? movie.posterUrl : movie.backdropUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(color: Colors.black),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(1.0),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
              // Content
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Column(
                  children: [
                    // Title
                    Text(
                      movie.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Color(0x60C026D3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Year & Duration
                    Text(
                      '${movie.releaseYear} • 2h 46m', 
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Neon Genres
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: movie.genres.take(3).map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF22D3EE), width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2022D3EE),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: Text(
                            g.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF22D3EE),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    // Match & Rating Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Radial Match
                        Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x30C026D3),
                                blurRadius: 30,
                                spreadRadius: -5,
                              )
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (rect) => const SweepGradient(
                                  colors: [Color(0xFFC026D3), Color(0xFF22D3EE)],
                                  stops: [0.3, 1.0],
                                ).createShader(rect),
                                child: const CircularProgressIndicator(
                                  value: 0.92,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white12,
                                  color: Colors.white,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    '92%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'MATCH',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 30),
                        // Rating
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < 4 ? Icons.star : Icons.star_half,
                                  color: const Color(0xFF22D3EE),
                                  size: 24,
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${movie.rating.toStringAsFixed(1)}/5',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Plot
                    Text(
                      movie.overview,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Director & Cast
                    Row(
                      children: [
                         const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white70, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Director: ${movie.director.isNotEmpty ? movie.director : 'N/A'}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Cast
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cast: ',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            movie.cast.join(', '),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Buttons
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => openTrailer(movie),
                          child: const Center(
                            child: Text(
                              'WATCH TRAILER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
