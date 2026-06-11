import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';

/// Pill chip. Inactive: surface fill + line border + sub text. Active: brand
/// gradient + onText + glow. Reference: `ag-shared.jsx` `Chip` / `FChip`.
class AgChip extends StatelessWidget {
  const AgChip({
    super.key,
    required this.label,
    this.active = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = active ? t.onText : t.sub;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(icon != null ? 11 : 14, 8, 14, 8),
        decoration: BoxDecoration(
          gradient: active ? t.grad : null,
          color: active ? null : t.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.transparent : t.line),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: t.purple.withValues(alpha: 0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.1,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
