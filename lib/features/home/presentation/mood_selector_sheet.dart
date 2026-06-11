import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MoodPreset {
  const MoodPreset({required this.name, required this.feeling, required this.wantToFeel});
  final String name;
  final String feeling;
  final String wantToFeel;
}

const List<MoodPreset> moodPresets = [
  MoodPreset(name: 'Romantic', feeling: 'sentimental', wantToFeel: 'romantic, moved, and warm'),
  MoodPreset(name: 'Stressed', feeling: 'stressed and overwhelmed', wantToFeel: 'relaxed, lighthearted, and calm'),
  MoodPreset(name: 'Tired', feeling: 'tired and low energy', wantToFeel: 'energized, excited, and motivated'),
  MoodPreset(name: 'Bored', feeling: 'bored and uninspired', wantToFeel: 'intrigued, mind-blown, and mystery'),
  MoodPreset(name: 'Sad', feeling: 'a bit sad or down', wantToFeel: 'happy, comforted, and uplifted'),
  MoodPreset(name: 'Spooky', feeling: 'brave and adventurous', wantToFeel: 'scared, thrilled, and suspenseful'),
];

Future<void> showMoodSelectorSheet(BuildContext context) {
  return showAgSheet<void>(context: context, heightFactor: 0.84, child: const MoodSelectorSheet());
}

class MoodSelectorSheet extends ConsumerStatefulWidget {
  const MoodSelectorSheet({super.key});

  @override
  ConsumerState<MoodSelectorSheet> createState() => _MoodSelectorSheetState();
}

class _MoodSelectorSheetState extends ConsumerState<MoodSelectorSheet> {
  final _feeling = TextEditingController();
  final _wantToFeel = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  String? _error;
  List<Movie> _results = const [];
  MoodPreset? _preset;

  @override
  void dispose() {
    _feeling.dispose();
    _wantToFeel.dispose();
    super.dispose();
  }

  void _applyPreset(MoodPreset p) {
    HapticFeedback.selectionClick();
    setState(() {
      _preset = p;
      _feeling.text = p.feeling;
      _wantToFeel.text = p.wantToFeel;
    });
  }

  Future<void> _match() async {
    final feeling = _feeling.text.trim();
    final want = _wantToFeel.text.trim();
    if (feeling.isEmpty && want.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe how you feel or want to feel.')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final movies = await ref.read(movieServiceProvider).getMoviesByMood(feeling: feeling, wantToFeel: want);
      if (mounted) setState(() { _results = movies; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not match your vibe. Try again.'; _loading = false; });
    }
  }

  void _reset() => setState(() { _searched = false; _preset = null; });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: t.gradSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line2)),
                child: Icon(AgIcons.sparkle, size: 24, color: t.red),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text('Mood Matcher', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 23, letterSpacing: -0.5, color: t.text)),
              ),
              if (_searched)
                GestureDetector(
                  onTap: _reset,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(11), border: Border.all(color: t.line)),
                    child: Icon(AgIcons.undo, size: 18, color: t.sub),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'On-device tag-embeddings read how you feel and match it to films.',
            style: TextStyle(fontFamily: 'Manrope', fontSize: 13, height: 1.45, color: t.sub),
          ),
          const SizedBox(height: 20),
          if (!_searched) ...[
            Text('QUICK VIBES', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: 0.3, color: t.faint)),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: moodPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = moodPresets[i];
                  return AgChip(label: p.name, active: _preset == p, onTap: () => _applyPreset(p));
                },
              ),
            ),
            const SizedBox(height: 20),
            _Label('How do you feel right now?'),
            const SizedBox(height: 8),
            _MoodField(controller: _feeling, hint: 'e.g. stressed, tired, down…'),
            const SizedBox(height: 16),
            _Label('How do you want to feel after?'),
            const SizedBox(height: 8),
            _MoodField(controller: _wantToFeel, hint: 'e.g. relaxed, happy, scared…', focus: true),
            const SizedBox(height: 22),
            AgButton(label: 'Match my mood', icon: AgIcons.sparkle, onPressed: _match),
            const SizedBox(height: 16),
          ] else
            _buildResults(t),
        ],
      ),
    );
  }

  Widget _buildResults(AgreeoTokens t) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            SizedBox(width: 44, height: 44, child: CircularProgressIndicator(color: t.gold, strokeWidth: 3.5)),
            const SizedBox(height: 18),
            Text('Running local transformer model…', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14.5, color: t.text)),
            const SizedBox(height: 6),
            Text('Comparing tags to find your vibe…', style: TextStyle(fontFamily: 'Manrope', fontSize: 12.5, color: t.faint)),
          ],
        ),
      );
    }
    if (_error != null) {
      return AgStateCard(icon: AgIcons.wifiOff, title: 'Something went wrong', message: _error!, actionLabel: 'Try again', onAction: _match);
    }
    if (_results.isEmpty) {
      return AgStateCard(icon: AgIcons.film, title: 'No matches for your vibe', message: 'Adjust your inputs or pick another quick vibe.', actionLabel: 'Back to inputs', onAction: _reset);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Your vibe matches', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 18, color: t.text)),
            Text('${_results.length} titles found', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 12.5, color: t.gold)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _results.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final m = _results[i];
              return SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AgPoster(
                      imageUrl: m.posterUrl,
                      title: m.title,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => AgreeoMovieDetailsScreen(movieId: m.id)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${m.releaseYear}', style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: t.faint)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        AgButton.secondary(label: 'Adjust vibe inputs', icon: AgIcons.chevronLeft, onPressed: _reset, height: 50),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 14.5, color: context.tokens.text));
  }
}

class _MoodField extends StatelessWidget {
  const _MoodField({required this.controller, required this.hint, this.focus = false});
  final TextEditingController controller;
  final String hint;
  final bool focus;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: focus ? t.red.withValues(alpha: 0.4) : t.line, width: focus ? 1.5 : 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: TextField(
        controller: controller,
        maxLines: 2,
        cursorColor: t.red,
        style: TextStyle(fontFamily: 'Manrope', fontSize: 14, color: t.text, height: 1.4),
        decoration: agBareInput(
          hint: hint,
          hintStyle: TextStyle(fontFamily: 'Manrope', fontSize: 14, color: t.faint),
        ),
      ),
    );
  }
}
