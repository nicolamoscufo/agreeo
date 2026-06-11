import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_button.dart';
import 'package:flutter/material.dart';

/// Empty / no-results / error state: icon bubble + title + message + optional
/// action, on a surface card (radius 28). Reference: `ag-states.jsx` empty states.
class AgStateCard extends StatelessWidget {
  const AgStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = iconColor ?? t.red;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: t.gradSoft,
              border: Border.all(color: t.line2),
            ),
            child: Icon(icon, size: 34, color: accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.4,
              color: t.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13.5,
              height: 1.5,
              color: t.sub,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 22),
            AgButton(label: actionLabel!, expand: false, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
