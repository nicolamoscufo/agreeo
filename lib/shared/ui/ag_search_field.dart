import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_effects.dart';
import 'package:agreeo/shared/ui/ag_icons.dart';
import 'package:flutter/material.dart';

/// Search input: height 46, radius 14, surface fill, line border, faint search
/// icon + placeholder. Reference: `ag-main.jsx` HomeScreen search.
///
/// Use [onTap] (with [readOnly] true) to make it a button that opens a search
/// screen, or provide [controller]/[onChanged] for inline editing.
class AgSearchField extends StatelessWidget {
  const AgSearchField({
    super.key,
    this.hint = 'Search movies, shows…',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final field = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Icon(AgIcons.search, size: 19, color: t.faint),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTap: onTap,
              readOnly: readOnly,
              autofocus: autofocus,
              cursorColor: t.red,
              style: AgText.body.copyWith(color: t.text),
              decoration: agBareInput(
                hint: hint,
                hintStyle: AgText.body.copyWith(color: t.faint),
              ),
            ),
          ),
        ],
      ),
    );

    // When used as a tap-to-open button (readOnly), announce it as a button
    // with the hint as its label. Editable mode keeps the native TextField
    // semantics.
    if (readOnly && onTap != null) {
      return Semantics(
        button: true,
        label: hint,
        excludeSemantics: true,
        child: field,
      );
    }
    return field;
  }
}
