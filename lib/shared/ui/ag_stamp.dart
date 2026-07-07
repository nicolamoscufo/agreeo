import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:flutter/material.dart';

/// Swipe stamp (LIKE / NOPE): thick colored border, rotated badge, big Bricolage
/// label. Reference: `ag-main.jsx` SwipeScreen `Stamp` (border 3.5, radius 12,
/// rotate ±14°, font 28 w800 ls 1).
class AgStamp extends StatelessWidget {
  const AgStamp({
    super.key,
    required this.label,
    required this.color,
    this.angle = -0.244, // ~ -14°
  });

  /// LIKE leans right (+14°), NOPE leans left (-14°).
  const AgStamp.like({Key? key, required Color color})
      : this(key: key, label: 'LIKE', color: color, angle: 0.244);

  const AgStamp.nope({Key? key, required Color color})
      : this(key: key, label: 'NOPE', color: color, angle: -0.244);

  final String label;
  final Color color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.7),
              blurRadius: 22,
              offset: const Offset(0, 6),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Text(
          label,
          style: AgText.display.copyWith(
            fontSize: 28,
            letterSpacing: 1,
            color: color,
          ),
        ),
      ),
    );
  }
}
