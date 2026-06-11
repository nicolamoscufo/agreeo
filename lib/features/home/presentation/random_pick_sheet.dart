import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Random Pick modal. Reference: `ag-extra.jsx` RandomPickScreen.
/// Maps to `movieService.getRandomMovie()`; "Try again" spins a new pick.
Future<void> showRandomPick(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => const _RandomPickDialog(),
  );
}

class _RandomPickDialog extends ConsumerStatefulWidget {
  const _RandomPickDialog();

  @override
  ConsumerState<_RandomPickDialog> createState() => _RandomPickDialogState();
}

class _RandomPickDialogState extends ConsumerState<_RandomPickDialog> {
  Movie? _movie;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _spin();
  }

  Future<void> _spin() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    HapticFeedback.lightImpact();
    try {
      final movie = await ref.read(movieServiceProvider).getRandomMovie();
      if (mounted) setState(() { _movie = movie; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.line2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 60, offset: const Offset(0, 30), spreadRadius: -20)],
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(gradient: t.gradSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line2)),
                  child: Icon(AgIcons.dice, size: 22, color: t.gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Your random pick', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.4, color: t.text)),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
                    child: Icon(AgIcons.close, size: 17, color: t.sub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildBody(t),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AgreeoTokens t) {
    if (_loading) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: t.gold, strokeWidth: 3.5)),
              const SizedBox(height: 16),
              Text('Picking something for you…', style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.sub)),
            ],
          ),
        ),
      );
    }
    if (_error || _movie == null) {
      return Column(
        children: [
          SizedBox(
            height: 200,
            child: Center(child: Icon(AgIcons.film, size: 48, color: t.faint)),
          ),
          const SizedBox(height: 8),
          Text('Could not pull a pick. Try again.', style: TextStyle(fontFamily: 'Manrope', fontSize: 13.5, color: t.sub)),
          const SizedBox(height: 20),
          AgButton(label: 'Try again', icon: AgIcons.undo, onPressed: _spin),
        ],
      );
    }

    final m = _movie!;
    final meta = [
      if (m.releaseYear > 0) '${m.releaseYear}',
      if (m.runtimeLabel.isNotEmpty) m.runtimeLabel,
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 172, child: AgPoster(imageUrl: m.posterUrl, title: m.title, radius: 18)),
        const SizedBox(height: 18),
        Text(m.title, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 21, letterSpacing: -0.4, height: 1.1, color: t.text)),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (meta.isNotEmpty) Text('$meta   ', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 12.5, color: t.sub)),
            if (m.rating > 0) AgStars(rating: m.rating, size: 12),
          ],
        ),
        if (m.genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              for (final g in m.genres.take(3))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line)),
                  child: Text(g, style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 11.5, color: t.sub)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: AgButton.secondary(label: 'Try again', icon: AgIcons.undo, height: 50, onPressed: _spin)),
            const SizedBox(width: 11),
            Expanded(
              child: AgButton(
                label: 'Details',
                icon: AgIcons.play,
                height: 50,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => AgreeoMovieDetailsScreen(movieId: m.id)),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
