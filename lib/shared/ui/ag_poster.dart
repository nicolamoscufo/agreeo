import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Movie poster: 2:3 aspect, radius 14, poster shadow, cached image with a brand
/// gradient placeholder (+ typeset title) on loading/error. Reference:
/// `ag-shared.jsx` `Poster`.
class AgPoster extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    Widget poster = AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PlaceholderArt(title: title),
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => _PlaceholderArt(title: title),
                errorWidget: (context, url, error) =>
                    _PlaceholderArt(title: title),
              ),
            if (showTitle && title != null)
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
                    title!,
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
            ?overlay,
          ],
        ),
      ),
    );

    if (shadow) {
      poster = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [t.posterShadow],
        ),
        child: poster,
      );
    }

    if (onTap != null) {
      poster = GestureDetector(onTap: onTap, child: poster);
    }

    poster = Semantics(
      label: (title == null || title!.isEmpty) ? 'Movie poster' : '$title, movie poster',
      image: true,
      button: onTap != null,
      child: poster,
    );

    return width != null ? SizedBox(width: width, child: poster) : poster;
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
