import 'dart:async';

import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/shared/components/filter_bottom_sheet.dart';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/home_refresh_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoHomeScreen extends ConsumerStatefulWidget {
  const AgreeoHomeScreen({super.key});

  @override
  ConsumerState<AgreeoHomeScreen> createState() => _AgreeoHomeScreenState();
}

class _AgreeoHomeScreenState extends ConsumerState<AgreeoHomeScreen> {
  static const int _sectionBatchSize = 30;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  MovieSearchFilters _filters = const MovieSearchFilters();
  String _activeQuickFilter = 'Any';
  Future<List<Movie>>? _searchFuture;
  int _recommendedVisibleCount = _sectionBatchSize;
  int _trendingVisibleCount = _sectionBatchSize;
  bool _isRefreshingHome = false;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    // Horizontal carousels now trigger load-more; no vertical listener.
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    if (_isRefreshingHome) {
      return;
    }

    _isRefreshingHome = true;
    try {
      _currentPage = 1;
      await ref
          .read(agreeoAppControllerProvider.notifier)
          .refreshHomeFeed(page: _currentPage);
      if (!mounted) {
        return;
      }

      ref.read(homeRefreshProvider.notifier).state++;
    } finally {
      _isRefreshingHome = false;
    }
  }

  void _refreshSearch() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();

    setState(() {
      if (query.isEmpty && !_filters.hasActiveFilters) {
        _searchFuture = null;
      } else {
        _searchFuture = ref
            .read(movieServiceProvider)
            .searchMovies(query, _filters);
      }
    });
  }

  void _scheduleSearchRefresh() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      _refreshSearch();
    });
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '☀️ Good morning';
    } else if (hour < 17) {
      return '👋 Good afternoon';
    } else {
      return '🌙 Good evening';
    }
  }

  String _dynamicSubtitle(AgreeoAppState state) {
    final unwatchedWatchlist = state.movieStates.values
        .where((s) => s.inWatchlist && !s.watched)
        .length;

    final parts = <String>[];
    if (unwatchedWatchlist > 0) {
      parts.add('$unwatchedWatchlist unwatched in your watchlist');
    }

    if (parts.isEmpty) {
      return 'What should we discover today?';
    }
    return '${parts.join(' · ')} 🍿';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeRefreshProvider, (previous, next) {
      if (previous == next) {
        return;
      }

      setState(() {
        _searchController.clear();
        _searchFuture = null;
        _filters = const MovieSearchFilters();
        _activeQuickFilter = 'Any';
        _recommendedVisibleCount = _sectionBatchSize;
        _trendingVisibleCount = _sectionBatchSize;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });

    final state = ref.watch(agreeoAppControllerProvider);
    final session = state.session;
    final query = _searchController.text.trim().toLowerCase();
    final hasRemoteSearch = query.isNotEmpty || _filters.hasActiveFilters;

    List<Movie> recommended = const <Movie>[];
    List<Movie> trending = const <Movie>[];
    List<Movie> filteredCatalog = const <Movie>[];

    if (!hasRemoteSearch) {
      recommended = _applyFilters(
        state.recommendedForYou,
        query,
      ).take(_recommendedVisibleCount).toList(growable: false);
      trending = _applyFilters(
        state.trendingMovies,
        query,
      ).take(_trendingVisibleCount).toList(growable: false);
      filteredCatalog = _applyFilters(state.catalog, query);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = session?.displayName ?? 'there';

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AgreeoColors.trueBlack,
            AgreeoColors.deepBlack,
            AgreeoColors.anthraciteBlack,
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            children: <Widget>[
              // ── Greeting ──────────────────────────────────
              Text(
                '${_timeBasedGreeting()}, $displayName',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(
                  _dynamicSubtitle(state),
                  key: ValueKey<String>(_dynamicSubtitle(state)),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── Search bar with filter badge ──────────────
              AgreeoSearchBar(
                controller: _searchController,
                hintText: 'Search a title, genre, or vibe',
                onChanged: (_) => _scheduleSearchRefresh(),
                trailing: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final updated = await showMovieFilterBottomSheet(
                          context,
                          initialFilters: _filters,
                          genres: agreeoGenreOptions,
                        );
                        if (updated != null) {
                          setState(() {
                            _filters = updated;
                          });
                          _refreshSearch();
                        }
                      },
                      icon: Icon(
                        Icons.tune_rounded,
                        color: _filters.hasActiveFilters
                            ? colorScheme.primary
                            : null,
                      ),
                    ),
                    // Active-filter badge
                    if (_filters.hasActiveFilters)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AgreeoColors.trueBlack,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Quick filter chips ────────────────────────
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _quickChip('Any', null, null),
                    _quickChip(
                      'Under 2h',
                      const MovieSearchFilters(maxRuntimeMinutes: 120),
                      Icons.timer_rounded,
                    ),
                    _quickChip(
                      'Sci-Fi',
                      const MovieSearchFilters(genre: 'Sci-Fi'),
                      Icons.rocket_launch_rounded,
                    ),
                    _quickChip(
                      'Comedy',
                      const MovieSearchFilters(genre: 'Comedy'),
                      Icons.sentiment_very_satisfied_rounded,
                    ),
                    _quickChip(
                      'Drama',
                      const MovieSearchFilters(genre: 'Drama'),
                      Icons.theater_comedy_rounded,
                    ),
                    _quickChip(
                      'Action',
                      const MovieSearchFilters(genre: 'Action'),
                      Icons.local_fire_department_rounded,
                    ),
                    _quickChip(
                      'Top Rated',
                      const MovieSearchFilters(minRating: 7.5),
                      Icons.star_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Content sections ──────────────────────────
              if (hasRemoteSearch)
                FutureBuilder<List<Movie>>(
                  future: _searchFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final results = snapshot.data ?? const <Movie>[];
                    return _CollectionSection(
                      icon: Icons.search_rounded,
                      iconColor: colorScheme.tertiary,
                      title: query.isNotEmpty
                          ? 'Search results'
                          : 'Filtered results',
                      subtitle: _appendCount(
                        query.isNotEmpty
                            ? 'TMDB search results enriched with your current app filters.'
                            : 'Results pulled from the full TMDB catalog with your active filters.',
                        results.length,
                      ),
                      movies: results,
                    );
                  },
                )
              else if (_filters.hasActiveFilters)
                _CollectionSection(
                  icon: Icons.filter_list_rounded,
                  iconColor: colorScheme.secondary,
                  title: 'Filtered picks',
                  subtitle: _appendCount(
                    'The current catalog after your discovery filters.',
                    filteredCatalog.length,
                  ),
                  movies: filteredCatalog,
                )
              else ...<Widget>[
                _CollectionSection(
                  icon: Icons.favorite_rounded,
                  iconColor: AgreeoColors.kernelGold,
                  title: 'Recommended for you',
                  subtitle: 'Your best current matches, ranked from your onboarding and feedback signals.',
                  movies: recommended,
                ),
                const SizedBox(height: 22),
                _CollectionSection(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AgreeoColors.kernelGold,
                  title: 'Trending now',
                  subtitle: _appendCount(
                    'Fresh, high-heat picks for a low-friction start.',
                    trending.length,
                  ),
                  movies: trending,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, MovieSearchFilters? filters, IconData? icon) {
    final selected = _activeQuickFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SelectableChip(
        label: label,
        selected: selected,
        icon: icon,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            if (selected || filters == null) {
              _activeQuickFilter = 'Any';
              _filters = const MovieSearchFilters();
            } else {
              _activeQuickFilter = label;
              _filters = filters;
            }
          });
          _refreshSearch();
        },
      ),
    );
  }

  String _appendCount(String base, int count) {
    if (count <= 0) {
      return base;
    }
    return '$base • $count title${count == 1 ? '' : 's'}';
  }

  List<Movie> _applyFilters(List<Movie> movies, String query) {
    final filtered = movies
        .where((movie) {
          final matchesSearch =
              query.isEmpty ||
              movie.title.toLowerCase().contains(query) ||
              movie.genres.any((genre) => genre.toLowerCase().contains(query));
          return matchesSearch && _filters.matches(movie);
        })
        .toList(growable: false);

    return filtered;
  }
}

class _CollectionSection extends StatelessWidget {
  const _CollectionSection({
    required this.title,
    required this.subtitle,
    required this.movies,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String subtitle;
  final List<Movie> movies;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null)
          SectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (iconColor ?? colorScheme.primary).withValues(
                  alpha: 0.14,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? colorScheme.primary,
              ),
            ),
          )
        else
          SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 14),
        if (movies.isEmpty)
          const EmptyState(
            icon: Icons.movie_filter_rounded,
            title: 'No picks match that filter',
            message:
                'Try relaxing one filter or switch back to a broader discovery view.',
          )
        else
          MovieHorizontalCarousel(
            movies: movies,
            onMovieTap: (movie) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                ),
              );
            },
          ),
      ],
    );
  }
}
