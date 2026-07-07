import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Review editor sheet: movie header + interactive gold stars + textarea.
/// Reference: `ag-states.jsx` ReviewEditorScreen. Saves via controller
/// (`rateMovie` + `saveReview` / `deleteReview`).
Future<void> showReviewEditor(BuildContext context, Movie movie) {
  return showAgSheet<void>(
    context: context,
    heightFactor: 0.78,
    child: _ReviewEditor(movie: movie),
  );
}

class _ReviewEditor extends ConsumerStatefulWidget {
  const _ReviewEditor({required this.movie});
  final Movie movie;

  @override
  ConsumerState<_ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends ConsumerState<_ReviewEditor> {
  late final TextEditingController _controller;
  late int _rating;

  @override
  void initState() {
    super.initState();
    final state = ref
        .read(agreeoAppControllerProvider)
        .userMovieStateFor(widget.movie.id);
    _controller = TextEditingController(text: state.review ?? '');
    _rating = state.rating ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_rating > 0) await controller.rateMovie(widget.movie.id, _rating);
    final text = _controller.text.trim();
    final message = text.isEmpty
        ? await controller.deleteReview(widget.movie.id)
        : await controller.saveReview(widget.movie.id, text);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete() async {
    final controller = ref.read(agreeoAppControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final message = await controller.deleteReview(widget.movie.id);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              child: AgPoster(
                imageUrl: widget.movie.posterUrl,
                title: widget.movie.title,
                radius: 11,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOUR REVIEW',
                    style: AgText.overline.copyWith(color: t.faint),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AgText.h3.copyWith(
                      letterSpacing: -0.4,
                      height: 1.1,
                      color: t.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Your rating',
          style: AgText.h4.copyWith(fontSize: 14.5, color: t.text),
        ),
        const SizedBox(height: 10),
        AgStarRater(
          value: _rating,
          onChanged: (v) => setState(() => _rating = v),
        ),
        const SizedBox(height: 20),
        Text(
          'What stuck with you?',
          style: AgText.h4.copyWith(fontSize: 14.5, color: t.text),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 118),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.red.withValues(alpha: 0.4), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: TextField(
            controller: _controller,
            maxLines: 5,
            cursorColor: t.red,
            style: AgText.body.copyWith(color: t.text),
            decoration: agBareInput(
              hint: 'Cried twice. The docking scene is unreal…',
              hintStyle: AgText.body.copyWith(color: t.faint),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AgButton.secondary(
                label: 'Delete',
                icon: AgIcons.close,
                onPressed: _delete,
                height: 50,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: AgButton(
                label: 'Save review',
                icon: AgIcons.check,
                onPressed: _save,
                height: 50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
