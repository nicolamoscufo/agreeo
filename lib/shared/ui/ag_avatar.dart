import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar: accent gradient + initials, with optional accent ring.
/// Reference: `ag-shared.jsx` `Avatar`.
///
/// `seed` picks the accent color deterministically from a name when no explicit
/// [color] / network [imageUrl] is supplied (the user session has no avatar field
/// — see BACKEND_CONTRACT gap §4.3).
class AgAvatar extends StatelessWidget {
  const AgAvatar({
    super.key,
    required this.name,
    this.color,
    this.imageUrl,
    this.size = 44,
    this.ring = false,
  });

  final String name;
  final Color? color;
  final String? imageUrl;
  final double size;
  final bool ring;

  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((w) => w[0]).take(2).join().toUpperCase();
  }

  static const _palette = [
    Color(0xFFEF563B),
    Color(0xFF6B45F0),
    Color(0xFF1E9E73),
    Color(0xFFC9890F),
    Color(0xFFFF8FB1),
    Color(0xFF5C9BE0),
  ];

  Color _seedColor() {
    if (color != null) return color!;
    if (name.isEmpty) return _palette.first;
    return _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasImage = imageUrl != null && imageUrl!.startsWith('http');
    final accent = _seedColor();

    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accent.withValues(alpha: 0.55)],
        ),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontFamily: 'Bricolage Grotesque',
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          color: Colors.white,
        ),
      ),
    );

    final Widget inner = hasImage
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (context, url) => placeholder,
              errorWidget: (context, url, error) => placeholder,
            ),
          )
        : placeholder;

    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
        color: t.bg,
      ),
      child: inner,
    );
  }
}
