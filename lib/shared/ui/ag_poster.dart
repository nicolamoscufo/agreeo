import 'dart:async';

import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Movie poster: 2:3 aspect, radius 14, poster shadow, cached image with a brand
/// gradient placeholder (+ typeset title) on loading/error. Reference:
/// `ag-shared.jsx` `Poster`.
///
/// TMDB URLs are rewritten to the smallest size variant that still covers the
/// rendered cell (a w780 file is ~10x heavier than the w185 a grid cell needs),
/// and a failed load is retried automatically a couple of times so a transient
/// network error doesn't leave the poster blank until the next rebuild.
class AgPoster extends StatefulWidget {
  const AgPoster({
    super.key,
    required this.imageUrl,
    this.title,
    this.width,
    this.radius = 14,
    this.showTitle = false,
    this.shadow = true,
    this.overlay,
    this.onTap,
  });

  final String imageUrl;
  final String? title;
  final double? width;
  final double radius;
  final bool showTitle;
  final bool shadow;

  /// Optional widget stacked on top (badges, selection check, gradient scrim).
  final Widget? overlay;
  final VoidCallback? onTap;

  static final RegExp _tmdbSizeSegment = RegExp(r'/t/p/[^/]+/');

  /// Picks the lightest TMDB size variant that still covers [targetPx]
  /// physical pixels. Non-TMDB URLs pass through untouched.
  static String sizedImageUrl(String url, double targetPx) {
    if (!url.startsWith('https://image.tmdb.org/t/p/')) return url;
    final size = targetPx <= 154
        ? 'w154'
        : targetPx <= 185
            ? 'w185'
            : targetPx <= 342
                ? 'w342'
                : targetPx <= 500
                    ? 'w500'
                    : 'w780';
    return url.replaceFirst(_tmdbSizeSegment, '/t/p/$size/');
  }

  @override
  State<AgPoster> createState() => _AgPosterState();
}

class _AgPosterState extends State<AgPoster> {
  static const int _maxRetries = 2;

  int _attempt = 0;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(AgPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _attempt = 0;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetry(String url) {
    if (_attempt >= _maxRetries || _retryTimer != null) return;
    _retryTimer = Timer(Duration(seconds: 2 * (_attempt + 1)), () async {
      _retryTimer = null;
      await CachedNetworkImage.evictFromCache(url);
      if (mounted) setState(() => _attempt += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    Widget poster = AspectRatio(
      aspectRatio: 2 / 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : widget.width ?? 342;
          final targetPx = cellWidth * dpr;
          final url = widget.imageUrl.isEmpty
              ? ''
              : AgPoster.sizedImageUrl(widget.imageUrl, targetPx);

          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PlaceholderArt(title: widget.title),
                if (url.isNotEmpty)
                  CachedNetworkImage(
                    key: ValueKey('$url#$_attempt'),
                    imageUrl: url,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholderFadeInDuration: Duration.zero,
                    memCacheWidth: targetPx.round(),
                    placeholder: (context, url) =>
                        _PlaceholderArt(title: widget.title),
                    errorWidget: (context, erroredUrl, error) {
                      _scheduleRetry(erroredUrl);
                      return _PlaceholderArt(title: widget.title);
                    },
                  ),
                if (widget.showTitle && widget.title != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(11, 16, 11, 11),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        widget.title!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.04,
                          letterSpacing: -0.3,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ?widget.overlay,
              ],
            ),
          );
        },
      ),
    );

    if (widget.shadow) {
      poster = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [t.posterShadow],
        ),
        child: poster,
      );
    }

    if (widget.onTap != null) {
      poster = GestureDetector(onTap: widget.onTap, child: poster);
    }

    poster = Semantics(
      label: (widget.title == null || widget.title!.isEmpty)
          ? 'Movie poster'
          : '${widget.title}, movie poster',
      image: true,
      button: widget.onTap != null,
      child: poster,
    );

    return widget.width != null
        ? SizedBox(width: widget.width, child: poster)
        : poster;
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: t.grad),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            title ?? '',
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.05,
              letterSpacing: -0.3,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}
