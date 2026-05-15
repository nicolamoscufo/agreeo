import 'package:agreeo/models/app_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MovieCard extends StatefulWidget {
  const MovieCard({
    super.key,
    required this.movie,
    this.onLike,
    this.onDislike,
    this.onSeen,
    this.onLater,
    this.onTap,
    this.compact = false,
  });

  final Movie movie;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onSeen;
  final VoidCallback? onLater;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  static const double _swipeThreshold = 120;
  static const double _maxDrag = 240;
  static const Duration _snapDuration = Duration(milliseconds: 240);

  double _dragDx = 0;
  bool _isAnimatingOut = false;

  bool get _swipeEnabled => widget.onLike != null || widget.onDislike != null;

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_swipeEnabled || _isAnimatingOut) {
      return;
    }

    setState(() {
      final next = _dragDx + details.delta.dx;
      _dragDx = next.clamp(-_maxDrag, _maxDrag);
    });
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    if (!_swipeEnabled || _isAnimatingOut) {
      return;
    }

    final swipedRight = _dragDx > _swipeThreshold;
    final swipedLeft = _dragDx < -_swipeThreshold;
    final canLike = swipedRight && widget.onLike != null;
    final canDislike = swipedLeft && widget.onDislike != null;

    if (!canLike && !canDislike) {
      setState(() {
        _dragDx = 0;
      });
      return;
    }

    final exitToRight = canLike;
    setState(() {
      _isAnimatingOut = true;
      _dragDx = exitToRight ? 420 : -420;
    });

    await Future<void>.delayed(_snapDuration);
    if (!mounted) {
      return;
    }

    if (exitToRight) {
      widget.onLike?.call();
    } else {
      widget.onDislike?.call();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isAnimatingOut = false;
      _dragDx = 0;
    });
  }

  Future<void> _openTrailer() async {
    if (widget.movie.trailerUrl.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(widget.movie.trailerUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final swipeRatio = (_dragDx.abs() / _swipeThreshold).clamp(0.0, 1.0);
    final rotation = (_dragDx / _maxDrag) * 0.1;
    final scale = 1 - ((_dragDx.abs() / _maxDrag) * 0.04);

    Widget card = AnimatedContainer(
      duration: _snapDuration,
      curve: Curves.easeOutCubic,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..translateByDouble(_dragDx, 0, 0, 1)
        ..rotateZ(rotation)
        ..scaleByDouble(scale, scale, 1, 1),
      child: _buildCardSurface(
        theme: theme,
        colorScheme: colorScheme,
        swipeRatio: swipeRatio,
      ),
    );

    if (widget.onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: widget.onTap,
          child: card,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _swipeEnabled ? _handleDragUpdate : null,
      onHorizontalDragEnd: _swipeEnabled ? _handleDragEnd : null,
      child: card,
    );
  }

  Widget _buildCardSurface({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required double swipeRatio,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withAlpha(36),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(70)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AspectRatio(
                aspectRatio: widget.compact ? 0.92 : 0.74,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CachedNetworkImage(
                      imageUrl: widget.movie.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          _PosterFallback(isSeries: widget.movie.isSeries),
                      errorWidget: (context, url, error) =>
                          _PosterFallback(isSeries: widget.movie.isSeries),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withAlpha(188),
                          ],
                        ),
                      ),
                    ),
                    if (_swipeEnabled && swipeRatio > 0)
                      Align(
                        alignment: _dragDx >= 0
                            ? Alignment.topRight
                            : Alignment.topLeft,
                        child: _SwipeBadge(
                          label: _dragDx >= 0 ? 'LIKE' : 'NOPE',
                          color: _dragDx >= 0
                              ? Colors.greenAccent.shade400
                              : Colors.redAccent.shade200,
                          opacity: swipeRatio,
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.movie.genres
                                .take(3)
                                .map(
                                  (genre) => _Tag(
                                    label: genre,
                                    background: Colors.white.withAlpha(38),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.movie.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _summaryLine(widget.movie),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      widget.movie.overview,
                      maxLines: widget.compact ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _OutlineAction(
                          icon: Icons.thumb_up_alt_rounded,
                          label: 'Like',
                          onPressed: widget.onLike,
                        ),
                        _OutlineAction(
                          icon: Icons.thumb_down_alt_rounded,
                          label: 'Dislike',
                          onPressed: widget.onDislike,
                        ),
                        _OutlineAction(
                          icon: Icons.visibility_rounded,
                          label: 'Seen',
                          onPressed: widget.onSeen,
                        ),
                        _OutlineAction(
                          icon: Icons.bookmark_add_rounded,
                          label: 'Later',
                          onPressed: widget.onLater,
                        ),
                        _OutlineAction(
                          icon: Icons.open_in_new_rounded,
                          label: 'Trailer',
                          onPressed: widget.movie.trailerUrl.isEmpty
                              ? null
                              : _openTrailer,
                        ),
                      ],
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

  String _summaryLine(Movie movie) {
    if (movie.runtimeMinutes > 0) {
      return '${movie.releaseYear} • ${movie.runtimeMinutes} min';
    }
    return '${movie.releaseYear}';
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.isSeries});

  final bool isSeries;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        isSeries ? Icons.tv_rounded : Icons.movie_rounded,
        size: 56,
        color: colorScheme.primary,
      ),
    );
  }
}

class _SwipeBadge extends StatelessWidget {
  const _SwipeBadge({
    required this.label,
    required this.color,
    required this.opacity,
  });

  final String label;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(110),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.background});

  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(180)),
      ),
    );
  }
}
