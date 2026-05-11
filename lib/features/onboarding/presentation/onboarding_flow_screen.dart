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

    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );

    final isMoviesStep = _pageIndex == 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1E), // Dark neon background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top Bar
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Agreeo',
                    style:
                        TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.transparent,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(color: Color(0xFFFF00FF), blurRadius: 10),
                          ],
                          decoration: TextDecoration.none,
                        ).copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.5
                            ..color = const Color(0xFFFF00FF),
                        ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pageIndex == 0
                            ? 'Step 1 of 3: Genres'
                            : 'Step 2 of 3: Pick Your Favourites',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 140,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _pageIndex == 0 ? 0.33 : 0.66,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title and Subtitle dynamically handled by the views but in the screenshot it's part of the header
              if (isMoviesStep) ...[
                RichText(
                  text: TextSpan(
                    text: 'Select ',
                    style: titleStyle,
                    children: [
                      TextSpan(
                        text: 'Movies You Like',
                        style: titleStyle?.copyWith(
                          color: const Color(0xFF00FFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "We'll use your choices to find the perfect match.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
              ],

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

              // Gradient Button Container
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pageIndex == 0
                          ? onboarding.favoriteGenres.length >= 3
                                ? () {
                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                : null
                          : () async {
                              await ref
                                  .read(agreeoAppControllerProvider.notifier)
                                  .finishOnboarding();
                            },
                      child: Center(
                        child: Text(
                          _pageIndex == 0 ? 'Continue' : 'Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
        // The title is now handled by the parent screen
        // Search bar disabled for a cleaner look as per mockup, or preserved below
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
