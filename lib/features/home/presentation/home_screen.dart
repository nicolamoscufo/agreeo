import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/filter_bottom_sheet.dart';
import 'package:agreeo/shared/components/movie_widgets.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/mock_data/mock_movies.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoHomeScreen extends ConsumerStatefulWidget {
  const AgreeoHomeScreen({super.key});

  @override
  ConsumerState<AgreeoHomeScreen> createState() => _AgreeoHomeScreenState();
}

class _AgreeoHomeScreenState extends ConsumerState<AgreeoHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  MovieSearchFilters _filters = const MovieSearchFilters();
  String _activeQuickFilter = 'Any';
  Future<List<Movie>>? _searchFuture;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSearch() {
    final query = _searchController.text.trim();

    setState(() {
      if (query.isEmpty) {
        _searchFuture = null;
      } else {
        _searchFuture = ref
            .read(movieServiceProvider)
            .searchMovies(query, _filters);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);
    final session = state.session;
    final query = _searchController.text.trim().toLowerCase();
    final hasRemoteSearch = query.isNotEmpty;

    final recommended = _applyFilters(state.remainingDailySuggestions, query);
    final trending = _applyFilters(_buildTrending(state.catalog), query);
    final friends = _applyFilters(
      state.moviesByIds(mockPopularWithFriendsIds),
      query,
    );
    final shortTonight = _applyFilters(
      state.catalog
          .where((movie) => movie.runtime <= 110)
          .toList(growable: false),
      query,
    );
    final filteredCatalog = _applyFilters(state.catalog, query);

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
        child: ListView(
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
              onChanged: (_) => _refreshSearch(),
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
                    if (hasRemoteSearch) {
                      _refreshSearch();
                    }
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
                    'Movies',
                    const MovieSearchFilters(mediaType: CatalogMediaType.movie),
                  ),
                  _quickChip(
                    'TV Series',
                    const MovieSearchFilters(mediaType: CatalogMediaType.tv),
                  ),
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
                    title: 'Search results',
                    subtitle:
                        'TMDB search results enriched with your current app filters.',
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
                    'Based on your favorite genres and saved taste profile.',
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
              const SizedBox(height: 22),
              _CollectionSection(
                title: 'Short movies for tonight',
                subtitle:
                    'Good when the group wants something strong without a long runtime.',
                movies: shortTonight,
              ),
            ],
          ],
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
          if (_searchController.text.trim().isNotEmpty) {
            _refreshSearch();
          }
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
    return items.take(10).toList(growable: false);
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
