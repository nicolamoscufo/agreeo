import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/shared/ui/ag_avatar.dart';
import 'package:flutter/material.dart';

/// Fixed-size profile avatar button used in every screen header.
///
/// Tapping opens [AgreeoProfileScreen]. The widget enforces a strict 44×44
/// hit-target with consistent `Semantics` and `Tooltip` wrapping so the
/// avatar never shifts position or size across tabs.
class AgProfileButton extends StatelessWidget {
  const AgProfileButton({
    super.key,
    required this.name,
    this.imageUrl,
    this.color,
  });

  final String name;
  final String? imageUrl;
  final Color? color;

  /// Standard diameter matching the other header icon-squares (Bell, Search).
  static const double diameter = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Your profile',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Your profile',
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AgreeoProfileScreen(),
            ),
          ),
          child: AgAvatar(
            name: name,
            color: color,
            imageUrl: imageUrl,
            size: diameter,
          ),
        ),
      ),
    );
  }
}
