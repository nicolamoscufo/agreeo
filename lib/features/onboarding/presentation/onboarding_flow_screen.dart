import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/mock_data/mock_movies.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoOnboardingFlowScreen extends ConsumerStatefulWidget {
  const AgreeoOnboardingFlowScreen({super.key});

  @override
  ConsumerState<AgreeoOnboardingFlowScreen> createState() =>
      _AgreeoOnboardingFlowScreenState();
}

class _AgreeoOnboardingFlowScreenState
    extends ConsumerState<AgreeoOnboardingFlowScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);
    final onboarding = state.onboarding;
    final selectedMovieIds = onboarding.favoriteMovieIds.toSet();
    final query = _searchController.text.trim().toLowerCase();
    final filteredMovies = state.catalog
        .where((movie) {
          if (query.isEmpty) {
            return true;
          }
          return movie.title.toLowerCase().contains(query) ||
              movie.genres.any((genre) => genre.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _pageIndex == 0 ? 'Step 2 of 3' : 'Step 3 of 3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _pageIndex == 0 ? 2 / 3 : 1,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) {
                    setState(() {
                      _pageIndex = value;
                    });
                  },
                  children: <Widget>[
                    _GenresStep(
                      selectedGenres: onboarding.favoriteGenres.toSet(),
                      onToggle: (genre) async {
                        final next = onboarding.favoriteGenres.toSet();
                        if (next.contains(genre)) {
                          next.remove(genre);
                        } else {
                          next.add(genre);
                        }
                        await ref
                            .read(agreeoAppControllerProvider.notifier)
                            .updateOnboardingGenres(
                              next.toList(growable: false),
                            );
                      },
                    ),
                    _FavoriteMoviesStep(
                      searchController: _searchController,
                      selectedCount: onboarding.favoriteMovieIds.length,
                      selectedMovieIds: selectedMovieIds,
                      movies: filteredMovies,
                      onSearchChanged: (_) => setState(() {}),
                      onToggleMovie: (movie) {
                        ref
                            .read(agreeoAppControllerProvider.notifier)
                            .toggleFavoriteMovieSelection(movie.id);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _pageIndex == 0
                    ? onboarding.favoriteGenres.length >= 3
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          : null
                    : () async {
                        await ref
                            .read(agreeoAppControllerProvider.notifier)
                            .finishOnboarding();
                      },
                child: Text(_pageIndex == 0 ? 'Continue' : 'Finish onboarding'),
              ),
              if (_pageIndex == 1) ...<Widget>[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GenresStep extends StatelessWidget {
  const _GenresStep({required this.selectedGenres, required this.onToggle});

  final Set<String> selectedGenres;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(
          title: 'Choose your favorite genres',
          subtitle: 'Pick at least 3 so Agreeo can shape a fast first queue.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: agreeoGenreOptions
              .map(
                (genre) => SelectableChip(
                  label: genre,
                  selected: selectedGenres.contains(genre),
                  onTap: () => onToggle(genre),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        Text(
          '${selectedGenres.length} selected',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FavoriteMoviesStep extends StatelessWidget {
  const _FavoriteMoviesStep({
    required this.searchController,
    required this.selectedCount,
    required this.selectedMovieIds,
    required this.movies,
    required this.onSearchChanged,
    required this.onToggleMovie,
  });

  final TextEditingController searchController;
  final int selectedCount;
  final Set<String> selectedMovieIds;
  final List<Movie> movies;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Movie> onToggleMovie;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: 'Select up to 10 favorite movies',
          subtitle: '$selectedCount / 10 selected',
        ),
        const SizedBox(height: 16),
        AgreeoSearchBar(
          controller: searchController,
          hintText: 'Search favorite movies',
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: PosterGrid(
            movies: movies,
            selectedIds: selectedMovieIds,
            onToggle: onToggleMovie,
          ),
        ),
      ],
    );
  }
}
