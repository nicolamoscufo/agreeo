import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/services/backend_auth_session_service.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Profile › Favorite genres editor. Same chip styling as the onboarding
/// genres step, same minimum (3) so recommendations stay meaningful; persists
/// via `updateFavoriteGenres` (PREFERS_GENRE replace on the backend).
Future<void> showEditGenresSheet(BuildContext context) {
  return showAgSheet<void>(
    context: context,
    heightFactor: 0.72,
    child: const _EditGenres(),
  );
}

class _EditGenres extends ConsumerStatefulWidget {
  const _EditGenres();

  @override
  ConsumerState<_EditGenres> createState() => _EditGenresState();
}

class _EditGenresState extends ConsumerState<_EditGenres> {
  static const int _minGenres = 3;

  late final Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = ref
        .read(agreeoAppControllerProvider)
        .onboarding
        .favoriteGenres
        .toSet();
  }

  void _toggle(String genre) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(genre)) _selected.remove(genre);
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(agreeoAppControllerProvider.notifier)
          .updateFavoriteGenres(_selected.toList());
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Favorite genres updated')),
      );
    } on BackendAuthException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save genres. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canSave = _selected.length >= _minGenres && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorite genres',
          style: TextStyle(
            fontFamily: 'Bricolage Grotesque',
            fontWeight: FontWeight.w800,
            fontSize: 25,
            letterSpacing: -0.5,
            color: t.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pick at least $_minGenres. This reshapes your daily picks and recommendations.',
          style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.sub),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final g in agreeoGenreOptions)
                  GestureDetector(
                    onTap: _saving ? null : () => _toggle(g),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _selected.contains(g) ? t.grad : null,
                        color: _selected.contains(g) ? null : t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selected.contains(g) ? Colors.transparent : t.line,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selected.contains(g)) ...[
                            const Icon(AgIcons.check, size: 15, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            g,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: _selected.contains(g) ? Colors.white : t.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AgButton(
          label: _saving
              ? 'Saving…'
              : _selected.length < _minGenres
                  ? 'Pick at least $_minGenres'
                  : 'Save genres',
          icon: AgIcons.check,
          onPressed: canSave ? _save : null,
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
