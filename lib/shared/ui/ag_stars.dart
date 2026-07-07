import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_icons.dart';
import 'package:flutter/material.dart';

/// Compact rating: gold star + numeric value. Reference: `ag-shared.jsx` `Stars`.
class AgStars extends StatelessWidget {
  const AgStars({super.key, required this.rating, this.size = 12});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AgIcons.star, size: size + 2, color: t.gold),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: AgText.label.copyWith(fontSize: size, color: t.text),
        ),
      ],
    );
  }
}

/// Interactive 1–5 (or N) star rater for the review editor.
class AgStarRater extends StatelessWidget {
  const AgStarRater({
    super.key,
    required this.value,
    required this.onChanged,
    this.count = 5,
    this.size = 34,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final filled = i < value;
        return Semantics(
          button: true,
          selected: filled,
          label: 'Rate ${i + 1} of $count stars',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onChanged(i + 1),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(
                filled ? AgIcons.star : AgIcons.starOutline,
                size: size,
                color: filled ? t.gold : t.faint,
              ),
            ),
          ),
        );
      }),
    );
  }
}
