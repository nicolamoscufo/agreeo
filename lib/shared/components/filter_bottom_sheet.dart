import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:flutter/material.dart';

Future<MovieSearchFilters?> showMovieFilterBottomSheet(
  BuildContext context, {
  required MovieSearchFilters initialFilters,
  required List<String> genres,
}) {
  return showModalBottomSheet<MovieSearchFilters>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) =>
        _MovieFilterBottomSheet(initialFilters: initialFilters, genres: genres),
  );
}

class _MovieFilterBottomSheet extends StatefulWidget {
  const _MovieFilterBottomSheet({
    required this.initialFilters,
    required this.genres,
  });

  final MovieSearchFilters initialFilters;
  final List<String> genres;

  @override
  State<_MovieFilterBottomSheet> createState() =>
      _MovieFilterBottomSheetState();
}

class _MovieFilterBottomSheetState extends State<_MovieFilterBottomSheet> {
  late MovieSearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Filters',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep discovery fast by tightening only what matters tonight.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _FilterSection(
                title: 'Genre',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SelectableChip(
                      label: 'Any',
                      selected: _filters.genre == null,
                      onTap: () {
                        setState(() {
                          _filters = _filters.copyWith(clearGenre: true);
                        });
                      },
                    ),
                    ...widget.genres.map(
                      (genre) => SelectableChip(
                        label: genre,
                        selected: _filters.genre == genre,
                        onTap: () {
                          setState(() {
                            _filters = _filters.copyWith(genre: genre);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _FilterSection(
                title: 'Max duration',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _numericChip('Any', _filters.maxRuntimeMinutes == null, () {
                      setState(() {
                        _filters = _filters.copyWith(
                          clearMaxRuntimeMinutes: true,
                        );
                      });
                    }),
                    _numericChip('90m', _filters.maxRuntimeMinutes == 90, () {
                      setState(() {
                        _filters = _filters.copyWith(maxRuntimeMinutes: 90);
                      });
                    }),
                    _numericChip('120m', _filters.maxRuntimeMinutes == 120, () {
                      setState(() {
                        _filters = _filters.copyWith(maxRuntimeMinutes: 120);
                      });
                    }),
                    _numericChip('150m', _filters.maxRuntimeMinutes == 150, () {
                      setState(() {
                        _filters = _filters.copyWith(maxRuntimeMinutes: 150);
                      });
                    }),
                  ],
                ),
              ),
              _FilterSection(
                title: 'From year',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _numericChip('Any', _filters.minReleaseYear == null, () {
                      setState(() {
                        _filters = _filters.copyWith(clearMinReleaseYear: true);
                      });
                    }),
                    _numericChip('2015+', _filters.minReleaseYear == 2015, () {
                      setState(() {
                        _filters = _filters.copyWith(minReleaseYear: 2015);
                      });
                    }),
                    _numericChip('2020+', _filters.minReleaseYear == 2020, () {
                      setState(() {
                        _filters = _filters.copyWith(minReleaseYear: 2020);
                      });
                    }),
                    _numericChip('2023+', _filters.minReleaseYear == 2023, () {
                      setState(() {
                        _filters = _filters.copyWith(minReleaseYear: 2023);
                      });
                    }),
                  ],
                ),
              ),
              _FilterSection(
                title: 'Minimum rating',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _numericChip('Any', _filters.minRating == null, () {
                      setState(() {
                        _filters = _filters.copyWith(clearMinRating: true);
                      });
                    }),
                    _numericChip('7.0+', _filters.minRating == 7.0, () {
                      setState(() {
                        _filters = _filters.copyWith(minRating: 7.0);
                      });
                    }),
                    _numericChip('8.0+', _filters.minRating == 8.0, () {
                      setState(() {
                        _filters = _filters.copyWith(minRating: 8.0);
                      });
                    }),
                    _numericChip('8.5+', _filters.minRating == 8.5, () {
                      setState(() {
                        _filters = _filters.copyWith(minRating: 8.5);
                      });
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filters = const MovieSearchFilters();
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_filters),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numericChip(String label, bool selected, VoidCallback onTap) {
    return SelectableChip(label: label, selected: selected, onTap: onTap);
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
