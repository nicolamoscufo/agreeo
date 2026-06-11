import 'dart:ui';

import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';

/// Master switch for glassmorphism blur. Set to false (e.g. on low-end Android)
/// to fall back to an opaque `surface2` fill instead of a [BackdropFilter].
/// (Phase 8 will wire this to a runtime capability check.)
const bool kEnableBlur = true;

/// Borderless [InputDecoration] for [TextField]s that live INSIDE a custom
/// bordered container. Without this, the app's global `inputDecorationTheme`
/// (which defines `enabledBorder`/`focusedBorder`) draws a second rounded
/// outline inside the container. Pass [hint]/[hintStyle] per field.
InputDecoration agBareInput({
  String? hint,
  TextStyle? hintStyle,
  bool collapsed = true,
  EdgeInsetsGeometry? contentPadding,
}) {
  return InputDecoration(
    isCollapsed: collapsed,
    contentPadding: contentPadding,
    hintText: hint,
    hintStyle: hintStyle,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );
}

/// A rounded "glass" container: blurred translucent fill + `line2` border.
/// Falls back to an opaque [AgreeoTokens.surface2] fill when [kEnableBlur] is off.
class AgGlass extends StatelessWidget {
  const AgGlass({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 18,
    this.border = true,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final bool border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: border ? BorderSide(color: t.line2) : BorderSide.none,
    );
    final content = DecoratedBox(
      decoration: ShapeDecoration(
        color: kEnableBlur ? t.glass : t.surface2,
        shape: shape,
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );

    if (!kEnableBlur) return content;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );
  }
}
