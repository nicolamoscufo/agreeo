import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';

/// Daylight Filters sheet. Reference: `ag-states.jsx` FilterSheetScreen.
/// Returns the chosen [MovieSearchFilters] (or null if dismissed).
Future<MovieSearchFilters?> showMovieFilterBottomSheet(
  BuildContext context, {
  required MovieSearchFilters initialFilters,
  required List<String> genres,
}) {
  return showAgSheet<MovieSearchFilters>(
    context: context,
    heightFactor: 0.86,
    child: _FilterSheet(initialFilters: initialFilters, genres: genres),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initialFilters, required this.genres});

  final MovieSearchFilters initialFilters;
  final List<String> genres;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late MovieSearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  int get _activeCount => [
        _filters.genre,
        _filters.maxRuntimeMinutes,
        _filters.minReleaseYear,
        _filters.minRating,
      ].where((v) => v != null).length;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Filters', style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 25, letterSpacing: -0.5, color: t.text)),
        const SizedBox(height: 7),
        Text('Keep discovery fast by tightening only what matters tonight.', style: TextStyle(fontFamily: 'Manrope', fontSize: 13, height: 1.45, color: t.sub)),
        const SizedBox(height: 22),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  title: 'Genre',
                  children: [
                    AgChip(label: 'Any', active: _filters.genre == null, onTap: () => setState(() => _filters = _filters.copyWith(clearGenre: true))),
                    for (final g in widget.genres)
                      AgChip(label: g, active: _filters.genre == g, onTap: () => setState(() => _filters = _filters.copyWith(genre: g))),
                  ],
                ),
                _Section(
                  title: 'Max duration',
                  children: [
                    AgChip(label: 'Any', active: _filters.maxRuntimeMinutes == null, onTap: () => setState(() => _filters = _filters.copyWith(clearMaxRuntimeMinutes: true))),
                    for (final m in const [90, 120, 150])
                      AgChip(label: '${m}m', active: _filters.maxRuntimeMinutes == m, onTap: () => setState(() => _filters = _filters.copyWith(maxRuntimeMinutes: m))),
                  ],
                ),
                _Section(
                  title: 'From year',
                  children: [
                    AgChip(label: 'Any', active: _filters.minReleaseYear == null, onTap: () => setState(() => _filters = _filters.copyWith(clearMinReleaseYear: true))),
                    for (final y in const [2015, 2020, 2023])
                      AgChip(label: '$y+', active: _filters.minReleaseYear == y, onTap: () => setState(() => _filters = _filters.copyWith(minReleaseYear: y))),
                  ],
                ),
                _Section(
                  title: 'Minimum rating',
                  children: [
                    AgChip(label: 'Any', active: _filters.minRating == null, onTap: () => setState(() => _filters = _filters.copyWith(clearMinRating: true))),
                    for (final r in const [7.0, 8.0, 8.5])
                      AgChip(label: '${r.toStringAsFixed(1)}+', active: _filters.minRating == r, onTap: () => setState(() => _filters = _filters.copyWith(minRating: r))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: AgButton.secondary(label: 'Reset', height: 50, onPressed: () => setState(() => _filters = const MovieSearchFilters()))),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AgButton(
                label: _activeCount == 0 ? 'Apply' : 'Apply · $_activeCount set',
                icon: AgIcons.check,
                height: 50,
                onPressed: () => Navigator.of(context).pop(_filters),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, fontSize: 14.5, color: t.text)),
          const SizedBox(height: 11),
          Wrap(spacing: 9, runSpacing: 9, children: children),
        ],
      ),
    );
  }
}
