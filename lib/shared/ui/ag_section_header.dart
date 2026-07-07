import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';

/// Row header: Bricolage w800 title (+ optional Manrope sub) and an optional
/// trailing action in accent red. Reference: `ag-shared.jsx` `RowHead`.
class AgSectionHeader extends StatelessWidget {
  const AgSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AgText.h3.copyWith(letterSpacing: -0.4, color: t.text),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AgText.caption.copyWith(color: t.faint)),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Text(
                actionLabel!,
                style: AgText.label.copyWith(color: t.red),
              ),
            ),
          ),
      ],
    );
  }
}
