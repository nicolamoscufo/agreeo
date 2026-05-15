import 'dart:async';

import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/filter_bottom_sheet.dart';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/mock_data/mock_movies.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/home_refresh_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  int _friendsVisibleCount = _sectionBatchSize;
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
      _currentPage++;
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

  // Loading of additional items is triggered per-carousel via onLoadMore callbacks.

  int _nextVisibleCount({required int current, required int total}) {
    if (total <= current) {
      return total;
    }
    return (current + _sectionBatchSize).clamp(_sectionBatchSize, total);
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
        _friendsVisibleCount = _sectionBatchSize;
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
    List<Movie> friends = const <Movie>[];
    List<Movie> filteredCatalog = const <Movie>[];

    if (!hasRemoteSearch) {
      recommended = _applyFilters(
        state.recommendedForYou,
        query,
      ).take(_recommendedVisibleCount).toList(growable: false);
      trending = _applyFilters(
        _buildTrending(state.catalog),
        query,
      ).take(_trendingVisibleCount).toList(growable: false);
      friends = _applyFilters(
        state.moviesByIds(mockPopularWithFriendsIds),
        query,
      ).take(_friendsVisibleCount).toList(growable: false);
      filteredCatalog = _applyFilters(state.catalog, query);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF08111F),
            Color(0xFF0B1120),
            Color(0xFF111827),
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
              Text(
                'Hi, ${session?.displayName ?? 'there'}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What should we discover today?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              AgreeoSearchBar(
                controller: _searchController,
                hintText: 'Search a title, genre, or vibe',
                onChanged: (_) => _scheduleSearchRefresh(),
                trailing: IconButton.filledTonal(
                  onPressed: () async {
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
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _quickChip('Any', null),
                    _quickChip(
                      'Under 2h',
                      const MovieSearchFilters(maxRuntimeMinutes: 120),
                    ),
                    _quickChip(
                      'Sci-Fi',
                      const MovieSearchFilters(genre: 'Sci-Fi'),
                    ),
                    _quickChip(
                      'Comedy',
                      const MovieSearchFilters(genre: 'Comedy'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
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

                    return _CollectionSection(
                      title: query.isNotEmpty
                          ? 'Search results'
                          : 'Filtered results',
                      subtitle: query.isNotEmpty
                          ? 'TMDB search results enriched with your current app filters.'
                          : 'Results pulled from the full TMDB catalog with your active filters.',
                      movies: snapshot.data ?? const <Movie>[],
                    );
                  },
                )
              else if (_filters.hasActiveFilters)
                _CollectionSection(
                  title: 'Filtered picks',
                  subtitle: 'The current catalog after your discovery filters.',
                  movies: filteredCatalog,
                )
              else ...<Widget>[
                _CollectionSection(
                  title: 'Recommended for you',
                  subtitle:
                      'Your best current matches, ranked from your onboarding and feedback signals.',
                  movies: recommended,
                ),
                const SizedBox(height: 22),
                _CollectionSection(
                  title: 'Trending now',
                  subtitle: 'Fresh, high-heat picks for a low-friction start.',
                  movies: trending,
                ),
                const SizedBox(height: 22),
                _CollectionSection(
                  title: 'Popular with your friends',
                  subtitle:
                      'A social placeholder for titles your circle keeps circling back to.',
                  movies: friends,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, MovieSearchFilters? filters) {
    final selected = _activeQuickFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SelectableChip(
        label: label,
        selected: selected,
        onTap: () {
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

  List<Movie> _buildTrending(List<Movie> catalog) {
    final items = List<Movie>.from(catalog)
      ..sort((left, right) {
        final yearCompare = right.releaseYear.compareTo(left.releaseYear);
        if (yearCompare != 0) {
          return yearCompare;
        }
        return right.rating.compareTo(left.rating);
      });
    return items.toList(growable: false);
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
  });

  final String title;
  final String subtitle;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
