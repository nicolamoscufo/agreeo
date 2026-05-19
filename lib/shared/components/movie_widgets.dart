import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.width = 150,
  });

  final Movie movie;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: _MovieArtwork(imageUrl: movie.posterUrl),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                movie.runtimeLabel.isEmpty
                    ? movie.releaseYear.toString()
                    : '${movie.releaseYear} • ${movie.runtimeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MovieHorizontalCarousel extends StatelessWidget {
  const MovieHorizontalCarousel({
    super.key,
    required this.movies,
    required this.onMovieTap,
  });

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) {
      return SizedBox(
        height: 294,
        child: Center(
          child: Text(
            'No movies',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
          ),
        ),
      );
    }

    // Infinite cycling: itemCount is arbitrarily large, actual movie fetched via modulo
    const int cyclicCount = 10000;
    return SizedBox(
      height: 294,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: movies.isNotEmpty ? cyclicCount : 0,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final movie = movies[index % movies.length];
          return MoviePosterCard(movie: movie, onTap: () => onMovieTap(movie));
        },
      ),
    );
  }
}

class MovieSwipeCard extends StatelessWidget {
  const MovieSwipeCard({
    super.key,
    required this.movie,
    required this.onInfoTap,
    this.expand = false,
    this.header,
    this.footer,
    this.footerReservedSpace = 0,
  });

  final Movie movie;
  final VoidCallback onInfoTap;
  final bool expand;
  final Widget? header;
  final Widget? footer;
  final double footerReservedSpace;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        // Full Image
        _MovieArtwork(
          imageUrl: movie.posterUrl.isNotEmpty
              ? movie.posterUrl
              : movie.backdropUrl,
          fallbackSeed: movie.title,
        ),
        // Dark Gradient for Neon readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.9),
                Colors.black.withValues(alpha: 1.0),
              ],
              stops: const [0.0, 0.4, 0.7, 1.0],
            ),
          ),
        ),
        // Overlay Content
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (header != null)
                  Align(alignment: Alignment.topCenter, child: header!),
                const Spacer(),
                // Information
                Text(
                  movie.title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [Shadow(color: Color(0x60C026D3), blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  movie.runtimeLabel.isEmpty
                      ? movie.releaseYear.toString()
                      : '${movie.releaseYear} • ${movie.runtimeLabel}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: movie.genres.take(3).map((g) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF22D3EE),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2022D3EE),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
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
                const SizedBox(height: 24),
                // Plot
                Text(
                  movie.overview,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                // Detail Button
                Container(
                  width: double.infinity,
                  height: 56,
                  margin: EdgeInsets.only(
                    bottom: footer != null ? footerReservedSpace : 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.white.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: onInfoTap,
                      child: const Center(
                        child: Text(
                          'VIEW DETAILS',
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
              ],
            ),
          ),
        ),
        if (footer != null)
          Positioned(left: 18, right: 18, bottom: 18, child: footer!),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: expand ? content : AspectRatio(aspectRatio: 0.74, child: content),
    );
  }
}

class _MovieArtwork extends StatelessWidget {
  const _MovieArtwork({required this.imageUrl, this.fallbackSeed = ''});

  final String imageUrl;
  final String fallbackSeed;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        errorWidget: (context, url, dynamic error) => _buildFallback(context),
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      color: Colors.grey.shade900,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_creation_outlined,
        color: Colors.white54,
        size: 48,
      ),
    );
  }
}

class GenreChip extends StatelessWidget {
  const GenreChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}

class PosterGrid extends StatelessWidget {
  const PosterGrid({
    super.key,
    required this.movies,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Movie> movies;
  final Set<String> selectedIds;
  final ValueChanged<Movie> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: movies.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final movie = movies[index];
        final selected = selectedIds.contains(movie.id);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onToggle(movie),
            child: Container(
              decoration: selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF22D3EE),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4022D3EE),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : BoxDecoration(borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _MovieArtwork(imageUrl: movie.posterUrl),
              ),
            ),
          ),
        );
      },
    );
  }
}
