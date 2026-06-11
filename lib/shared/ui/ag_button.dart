import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primary (gradient fill + glow) and secondary (surface + line2 border) buttons.
/// Reference: `ag-shared.jsx` `GButton` / `SButton` (height 54, radius 16, gap 9).
class AgButton extends StatefulWidget {
  const AgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AgButtonVariant.primary,
    this.expand = true,
    this.height = 54,
  });

  const AgButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.height = 54,
  }) : variant = AgButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AgButtonVariant variant;
  final bool expand;
  final double height;

  @override
  State<AgButton> createState() => _AgButtonState();
}

enum AgButtonVariant { primary, secondary }

class _AgButtonState extends State<AgButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isPrimary = widget.variant == AgButtonVariant.primary;
    final enabled = widget.onPressed != null;

    final fg = isPrimary ? t.onText : t.text;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: fg),
          const SizedBox(width: 9),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
            color: fg,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!.call();
              }
            : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: widget.expand
                ? null
                : const EdgeInsets.symmetric(horizontal: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isPrimary ? t.grad : null,
              color: isPrimary ? null : t.surface,
              borderRadius: BorderRadius.circular(16),
              border: isPrimary ? null : Border.all(color: t.line2),
              boxShadow: isPrimary && enabled ? [t.accentGlow] : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
