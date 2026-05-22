import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

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
  Timer? _searchDebounce;
  Future<List<Movie>>? _searchFuture;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _scheduleSearchRefresh() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.trim();
      setState(() {
        if (query.isEmpty) {
          _searchFuture = null;
        } else {
          _searchFuture = ref
              .read(movieServiceProvider)
              .searchMovies(query, const MovieSearchFilters());
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);
    final onboarding = state.onboarding;
    final selectedMovieIds = onboarding.favoriteMovieIds.toSet();
    final localCatalogMovies = state.catalog;

    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.6,
    );

    final isButtonEnabled = _pageIndex == 0
        ? onboarding.favoriteGenres.length >= 3
        : true; // Step 2 is always enabled to allow completion

    return Scaffold(
      backgroundColor:
          AgreeoColors.anthraciteBlack, // Cinema Popcorn dark background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                        const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.transparent,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: AgreeoColors.cinematicRed,
                              blurRadius: 10,
                            ),
                          ],
                          decoration: TextDecoration.none,
                        ).copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 1.5
                            ..color = AgreeoColors.cinematicRed,
                        ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pageIndex == 0
                            ? 'Step 1 of 2: Genres'
                            : 'Step 2 of 2: Pick Your Favorites',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w700,
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
                          widthFactor: _pageIndex == 0 ? 0.5 : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: const LinearGradient(
                                colors: [
                                  AgreeoColors.cinematicRed,
                                  AgreeoColors.kernelGold,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Consistent Title & Subtitle Section
              if (_pageIndex == 0) ...[
                RichText(
                  text: TextSpan(
                    text: 'Choose ',
                    style: titleStyle,
                    children: [
                      TextSpan(
                        text: 'Favorite Genres',
                        style: titleStyle?.copyWith(
                          color: AgreeoColors.cinematicRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick at least 3 so Agreeo can shape a fast first queue.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                ),
              ] else ...[
                RichText(
                  text: TextSpan(
                    text: 'Select ',
                    style: titleStyle,
                    children: [
                      TextSpan(
                        text: 'Movies You Like',
                        style: titleStyle?.copyWith(
                          color: AgreeoColors.kernelGold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "We'll use your choices to find the perfect match.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Page View step contents
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
                      movies: localCatalogMovies,
                      searchFuture: _searchFuture,
                      onSearchChanged: (_) => _scheduleSearchRefresh(),
                      onToggleMovie: (movie) {
                        ref
                            .read(agreeoAppControllerProvider.notifier)
                            .toggleFavoriteMovieSelection(movie.id);
                      },
                    ),
                  ],
                ),
              ),

              // Action button bottom container
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: isButtonEnabled
                        ? const LinearGradient(
                            colors: [
                              AgreeoColors.cinematicRed,
                              AgreeoColors.kernelGold,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isButtonEnabled
                        ? null
                        : Colors.white.withValues(alpha: 0.08),
                    border: isButtonEnabled
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isButtonEnabled
                          ? _pageIndex == 0
                                ? () {
                                    _pageController.nextPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : () async {
                                    await ref
                                        .read(
                                          agreeoAppControllerProvider.notifier,
                                        )
                                        .finishOnboarding();
                                  }
                          : null,
                      child: Center(
                        child: Text(
                          _pageIndex == 0 ? 'Continue' : 'Get Started',
                          style: TextStyle(
                            color: isButtonEnabled
                                ? Colors.white
                                : Colors.white38,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: agreeoGenreOptions
                .map(
                  (genre) => _OnboardingGenreChip(
                    label: genre,
                    selected: selectedGenres.contains(genre),
                    onTap: () => onToggle(genre),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selectedGenres.length >= 3
                  ? AgreeoColors.cinematicRed.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selectedGenres.length >= 3
                    ? AgreeoColors.cinematicRed.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selectedGenres.length >= 3
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: selectedGenres.length >= 3
                      ? AgreeoColors.cinematicRed
                      : Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedGenres.length >= 3
                      ? '${selectedGenres.length} genres selected — Ready to continue!'
                      : '${selectedGenres.length} selected (need at least 3)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingGenreChip extends StatelessWidget {
  const _OnboardingGenreChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: selected
            ? AgreeoColors.cinematicRed.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected
                    ? AgreeoColors.cinematicRed
                    : Colors.white.withValues(alpha: 0.12),
                width: selected ? 2.0 : 1.0,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AgreeoColors.cinematicRed.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AgreeoColors.cinematicRed,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.75),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteMoviesStep extends StatelessWidget {
  const _FavoriteMoviesStep({
    required this.searchController,
    required this.selectedCount,
    required this.selectedMovieIds,
    required this.movies,
    this.searchFuture,
    required this.onSearchChanged,
    required this.onToggleMovie,
  });

  final TextEditingController searchController;
  final int selectedCount;
  final Set<String> selectedMovieIds;
  final List<Movie> movies;
  final Future<List<Movie>>? searchFuture;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Movie> onToggleMovie;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search for movies...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AgreeoColors.kernelGold,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended movies',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selectedCount > 0
                    ? AgreeoColors.kernelGold.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedCount > 0
                      ? AgreeoColors.kernelGold.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                '$selectedCount selected',
                style: TextStyle(
                  color: selectedCount > 0
                      ? AgreeoColors.kernelGold
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: searchFuture != null
              ? FutureBuilder<List<Movie>>(
                  future: searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    final results = snapshot.data ?? [];
                    if (results.isEmpty) {
                      return const Center(
                        child: Text(
                          'No movies found.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return PosterGrid(
                      movies: results,
                      selectedIds: selectedMovieIds,
                      onToggle: onToggleMovie,
                    );
                  },
                )
              : PosterGrid(
                  movies: movies,
                  selectedIds: selectedMovieIds,
                  onToggle: onToggleMovie,
                ),
        ),
      ],
    );
  }
}
