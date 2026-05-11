import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/components/primitives.dart';
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
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${movie.releaseYear} • ${movie.typeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
    return SizedBox(
      height: 294,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return MoviePosterCard(
            movie: movies[index],
            onTap: () => onMovieTap(movies[index]),
          );
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
    final theme = Theme.of(context);
    final content = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _MovieArtwork(imageUrl: movie.posterUrl, fallbackSeed: movie.title),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.82),
              ],
              stops: const <double>[0.0, 0.42, 1.0],
            ),
          ),
        ),
        if (header != null)
          Positioned(top: 18, left: 18, right: 72, child: header!),
        Positioned(
          top: 18,
          right: 18,
          child: Material(
            color: Colors.black.withValues(alpha: 0.35),
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onInfoTap,
              icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: footer == null ? 20 : footerReservedSpace + 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: movie.genres
                    .take(3)
                    .map((genre) => GenreChip(label: genre))
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text(
                movie.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.subtitleLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Directed by ${movie.director}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                movie.overview,
                maxLines: expand ? 4 : 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.4,
                ),
              ),
            ],
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

class MovieDetailsHeader extends StatelessWidget {
  const MovieDetailsHeader({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.24,
            child: _MovieArtwork(
              imageUrl: movie.backdropUrl,
              fallbackSeed: movie.title,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    width: 108,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: _MovieArtwork(
                        imageUrl: movie.posterUrl,
                        fallbackSeed: movie.title,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        movie.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.subtitleLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: movie.genres
                            .take(3)
                            .map((genre) => GenreChip(label: genre))
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

        final decoration = selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.transparent,
                  width: 2,
                ), // Gradient border padding
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.transparent, width: 2),
              );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onToggle(movie),
            child: Container(
              decoration: selected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : null,
              padding: selected
                  ? const EdgeInsets.all(2)
                  : const EdgeInsets.all(
                      2,
                    ), // transparent padding for non-selected to maintain size
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _MovieArtwork(
                      imageUrl: movie.posterUrl,
                      fallbackSeed: movie.title,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                            Colors.black,
                          ],
                          stops: const [0.0, 0.5, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          movie.title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                height: 1.1,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          movie.releaseYear.toString(),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 9,
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
      },
    );
  }
}

class _MovieArtwork extends StatelessWidget {
  const _MovieArtwork({required this.imageUrl, this.fallbackSeed});

  final String imageUrl;
  final String? fallbackSeed;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => _ArtworkFallback(seed: fallbackSeed),
      errorWidget: (context, error, stackTrace) =>
          _ArtworkFallback(seed: fallbackSeed),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({this.seed});

  final String? seed;

  @override
  Widget build(BuildContext context) {
    final title = seed ?? 'Agreeo';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF312E81),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}
