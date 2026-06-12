import 'dart:convert';
import 'dart:typed_data';

import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar: accent gradient + initials, with optional accent ring.
/// Reference: `ag-shared.jsx` `Avatar`.
///
/// [imageUrl] accepts both http(s) URLs and base64 `data:image/...` URIs (the
/// format profile photos are stored in on the AppUser node). `seed` picks the
/// accent color deterministically from a name when no explicit [color] /
/// [imageUrl] is supplied.
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

  /// Decoded data-URI bytes, memoized so list rebuilds don't re-run base64
  /// decoding on every frame. Avatars are small (≤ ~40KB), so a handful of
  /// entries is cheap; the cache resets once it grows past visible-list size.
  static final Map<String, Uint8List> _dataUriBytesCache =
      <String, Uint8List>{};

  static Uint8List? _bytesFromDataUri(String? uri) {
    if (uri == null || !uri.startsWith('data:image/')) return null;
    final cached = _dataUriBytesCache[uri];
    if (cached != null) return cached;

    final comma = uri.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(uri.substring(comma + 1));
      if (_dataUriBytesCache.length > 32) _dataUriBytesCache.clear();
      _dataUriBytesCache[uri] = bytes;
      return bytes;
    } on FormatException {
      return null;
    }
  }

  Color _seedColor() {
    if (color != null) return color!;
    if (name.isEmpty) return _palette.first;
    return _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasNetworkImage = imageUrl != null && imageUrl!.startsWith('http');
    final dataUriBytes = _bytesFromDataUri(imageUrl);
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

    final Widget inner;
    if (dataUriBytes != null) {
      inner = ClipOval(
        child: Image.memory(
          dataUriBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      );
    } else if (hasNetworkImage) {
      inner = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => placeholder,
          errorWidget: (context, url, error) => placeholder,
        ),
      );
    } else {
      inner = placeholder;
    }

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
