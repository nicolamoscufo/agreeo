import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';

/// Bottom-sheet shell: bg2 fill, rounded top (30), line2 border, drag handle
/// (44×5). Reference: `ag-states.jsx` `Sheet`.
class AgSheetShell extends StatelessWidget {
  const AgSheetShell({
    super.key,
    required this.child,
    this.heightFactor,
    this.padding = const EdgeInsets.fromLTRB(22, 6, 22, 0),
  });

  final Widget child;

  /// Fraction of available height (e.g. 0.86). Null = wrap content.
  final double? heightFactor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final media = MediaQuery.of(context);

    final sheet = Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: t.line2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 50,
            offset: const Offset(0, -20),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 11, bottom: 4),
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: t.line2,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          Flexible(
            child: Padding(
              padding: padding.add(
                EdgeInsets.only(bottom: media.viewInsets.bottom),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );

    if (heightFactor == null) {
      return SafeArea(top: false, child: sheet);
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        height: media.size.height * heightFactor!,
        child: sheet,
      ),
    );
  }
}

/// Shows [child] wrapped in an [AgSheetShell] as a modal bottom sheet with the
/// Daylight scrim (0.62).
Future<T?> showAgSheet<T>({
  required BuildContext context,
  required Widget child,
  double? heightFactor,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => AgSheetShell(heightFactor: heightFactor, child: child),
  );
}
