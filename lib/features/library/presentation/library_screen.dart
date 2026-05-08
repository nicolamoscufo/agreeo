import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LibraryMediaFilter { all, movie, tv }

class AgreeoLibraryScreen extends ConsumerStatefulWidget {
  const AgreeoLibraryScreen({super.key});

  @override
  ConsumerState<AgreeoLibraryScreen> createState() => _AgreeoLibraryScreenState();
}

class _AgreeoLibraryScreenState extends ConsumerState<AgreeoLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  _LibraryMediaFilter _mediaFilter = _LibraryMediaFilter.all;
  LibrarySort _sort = LibrarySort.recent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showUndoAction(Future<String> Function() action) async {
    final message = await action();
    if (!mounted) {
      return;
    }
    await showUndoSnackbar(
      context,
      message: message,
      onUndo: () async {
        await ref.read(agreeoAppControllerProvider.notifier).undoLastAction();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SectionHeader(
              title: 'Library',
              subtitle:
                  'Your personal memory space: what you saved, liked, watched, and hid.',
            ),
            const SizedBox(height: 16),
            AgreeoSearchBar(
              controller: _searchController,
              hintText: 'Search inside your library',
              onChanged: (_) => setState(() {}),
              trailing: PopupMenuButton<LibrarySort>(
                initialValue: _sort,
                onSelected: (value) {
                  setState(() {
                    _sort = value;
                  });
                },
                itemBuilder: (_) => LibrarySort.values
                    .map(
                      (sort) => PopupMenuItem<LibrarySort>(
                        value: sort,
                        child: Text(sort.label),
                      ),
                    )
                    .toList(growable: false),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.swap_vert_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SelectableChip(
                  label: 'All',
                  selected: _mediaFilter == _LibraryMediaFilter.all,
                  onTap: () => setState(() {
                    _mediaFilter = _LibraryMediaFilter.all;
                  }),
                ),
                SelectableChip(
                  label: 'Movie',
                  selected: _mediaFilter == _LibraryMediaFilter.movie,
                  onTap: () => setState(() {
                    _mediaFilter = _LibraryMediaFilter.movie;
                  }),
                ),
                SelectableChip(
                  label: 'TV Series',
                  selected: _mediaFilter == _LibraryMediaFilter.tv,
                  onTap: () => setState(() {
                    _mediaFilter = _LibraryMediaFilter.tv;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const <Widget>[
                Tab(text: 'Watchlist'),
                Tab(text: 'Liked'),
                Tab(text: 'Watched'),
                Tab(text: 'Hidden'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _buildTabView(context, state, _LibraryTab.watchlist),
                  _buildTabView(context, state, _LibraryTab.liked),
                  _buildTabView(context, state, _LibraryTab.watched),
                  _buildTabView(context, state, _LibraryTab.hidden),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView(
    BuildContext context,
    AgreeoAppState state,
    _LibraryTab tab,
  ) {
    final movies = _sortedMovies(_moviesForTab(state, tab), state);
    if (movies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 120),
        child: _emptyForTab(tab),
      );
    }

    final controller = ref.read(agreeoAppControllerProvider.notifier);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 140),
      itemBuilder: (_, index) {
        final movie = movies[index];
        final userState = state.userMovieStateFor(movie.id);

        return _LibraryMovieCard(
          movie: movie,
          userState: userState,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
              ),
            );
          },
          actions: switch (tab) {
            _LibraryTab.watchlist => <Widget>[
                _actionChip(
                  label: 'Remove',
                  icon: Icons.bookmark_remove_outlined,
                  onTap: () => _showUndoAction(
                    () => controller.removeFromWatchlist(movie.id),
                  ),
                ),
                _actionChip(
                  label: 'Seen',
                  icon: Icons.visibility_outlined,
                  onTap: () => _showUndoAction(
                    () => controller.markAsWatched(movie.id),
                  ),
                ),
                _actionChip(
                  label: 'Like',
                  icon: Icons.thumb_up_alt_outlined,
                  onTap: () => _showUndoAction(() => controller.likeMovie(movie.id)),
                ),
                _actionChip(
                  label: 'Dislike',
                  icon: Icons.thumb_down_alt_outlined,
                  onTap: () => _showUndoAction(
                    () => controller.dislikeMovie(movie.id),
                  ),
                ),
                _disabledChip('Movie Night (Phase 2)'),
              ],
            _LibraryTab.liked => <Widget>[
                _actionChip(
                  label: 'Remove like',
                  icon: Icons.heart_broken_outlined,
                  onTap: () => _showUndoAction(
                    () => controller.clearPreference(movie.id),
                  ),
                ),
                _actionChip(
                  label: userState.inWatchlist ? 'Saved' : 'Watchlist',
                  icon: Icons.bookmark_outline_rounded,
                  onTap: () => _showUndoAction(
                    userState.inWatchlist
                        ? () => controller.removeFromWatchlist(movie.id)
                        : () => controller.addToWatchlist(movie.id),
                  ),
                ),
                _actionChip(
                  label: userState.watched ? 'Watched' : 'Seen',
                  icon: Icons.visibility_outlined,
                  onTap: () => _showUndoAction(
                    userState.watched
                        ? () => controller.removeFromWatched(movie.id)
                        : () => controller.markAsWatched(movie.id),
                  ),
                ),
                _actionChip(
                  label: 'Rate / Review',
                  icon: Icons.rate_review_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                      ),
                    );
                  },
                ),
              ],
            _LibraryTab.watched => <Widget>[
                _actionChip(
                  label: userState.preference == MoviePreference.liked ? 'Liked' : 'Like',
                  icon: Icons.thumb_up_alt_outlined,
                  onTap: () => _showUndoAction(
                    userState.preference == MoviePreference.liked
                        ? () => controller.clearPreference(movie.id)
                        : () => controller.likeMovie(movie.id),
                  ),
                ),
                _actionChip(
                  label: userState.preference == MoviePreference.disliked
                      ? 'Hidden'
                      : 'Dislike',
                  icon: Icons.thumb_down_alt_outlined,
                  onTap: () => _showUndoAction(
                    userState.preference == MoviePreference.disliked
                        ? () => controller.clearPreference(movie.id)
                        : () => controller.dislikeMovie(movie.id),
                  ),
                ),
                _actionChip(
                  label: 'Rate again',
                  icon: Icons.star_outline_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                      ),
                    );
                  },
                ),
                _actionChip(
                  label: 'Edit review',
                  icon: Icons.edit_note_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                      ),
                    );
                  },
                ),
                _actionChip(
                  label: 'Remove watched',
                  icon: Icons.remove_red_eye_outlined,
                  onTap: () => _showUndoAction(
                    () => controller.removeFromWatched(movie.id),
                  ),
                ),
              ],
            _LibraryTab.hidden => <Widget>[
                _actionChip(
                  label: 'Undo dislike',
                  icon: Icons.undo_rounded,
                  onTap: () => _showUndoAction(
                    () => controller.clearPreference(movie.id),
                  ),
                ),
                _actionChip(
                  label: 'Move to Watchlist',
                  icon: Icons.bookmark_add_outlined,
                  onTap: () => _showUndoAction(
                    () => controller.addToWatchlist(movie.id),
                  ),
                ),
                _actionChip(
                  label: userState.watched ? 'Watched' : 'Mark watched',
                  icon: Icons.visibility_outlined,
                  onTap: () => _showUndoAction(
                    userState.watched
                        ? () => controller.removeFromWatched(movie.id)
                        : () => controller.markAsWatched(movie.id),
                  ),
                ),
              ],
          },
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemCount: movies.length,
    );
  }

  List<Movie> _moviesForTab(AgreeoAppState state, _LibraryTab tab) {
    final query = _searchController.text.trim().toLowerCase();
    return state.catalog.where((movie) {
      final userState = state.userMovieStateFor(movie.id);
      final inTab = switch (tab) {
        _LibraryTab.watchlist => userState.inWatchlist,
        _LibraryTab.liked => userState.preference == MoviePreference.liked,
        _LibraryTab.watched => userState.watched,
        _LibraryTab.hidden => userState.preference == MoviePreference.disliked,
      };
      if (!inTab) {
        return false;
      }
      if (_mediaFilter == _LibraryMediaFilter.movie &&
          movie.mediaType != CatalogMediaType.movie) {
        return false;
      }
      if (_mediaFilter == _LibraryMediaFilter.tv &&
          movie.mediaType != CatalogMediaType.tv) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return movie.title.toLowerCase().contains(query) ||
          movie.genres.any((genre) => genre.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  List<Movie> _sortedMovies(List<Movie> movies, AgreeoAppState state) {
    final items = List<Movie>.from(movies);
    items.sort((left, right) {
      final leftState = state.userMovieStateFor(left.id);
      final rightState = state.userMovieStateFor(right.id);

      switch (_sort) {
        case LibrarySort.recent:
          return rightState.updatedAt.compareTo(leftState.updatedAt);
        case LibrarySort.title:
          return left.title.compareTo(right.title);
        case LibrarySort.rating:
          return (rightState.rating ?? right.rating)
              .compareTo(leftState.rating ?? left.rating);
        case LibrarySort.year:
          return right.releaseYear.compareTo(left.releaseYear);
      }
    });
    return items;
  }

  Widget _emptyForTab(_LibraryTab tab) {
    return switch (tab) {
      _LibraryTab.watchlist => const EmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'Your watchlist is empty.',
          message: 'Save movies from Swipe or Home to find them here.',
        ),
      _LibraryTab.liked => const EmptyState(
          icon: Icons.thumb_up_alt_outlined,
          title: 'No liked movies yet.',
          message: 'Like movies from Swipe to improve your suggestions.',
        ),
      _LibraryTab.watched => const EmptyState(
          icon: Icons.visibility_outlined,
          title: 'No watched movies yet.',
          message: 'Movies you finish will start building your memory lane here.',
        ),
      _LibraryTab.hidden => const EmptyState(
          icon: Icons.hide_source_outlined,
          title: 'No hidden movies.',
          message: 'Disliked picks will move here so they stop crowding the stack.',
        ),
    };
  }

  Widget _actionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _disabledChip(String label) {
    return Chip(label: Text(label));
  }
}

enum _LibraryTab { watchlist, liked, watched, hidden }

class _LibraryMovieCard extends StatelessWidget {
  const _LibraryMovieCard({
    required this.movie,
    required this.userState,
    required this.onTap,
    required this.actions,
  });

  final Movie movie;
  final UserMovieState userState;
  final VoidCallback onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badges = <String>[
      if (userState.inWatchlist) 'Watchlist',
      if (userState.watched) 'Watched',
      if (userState.preference == MoviePreference.liked) 'Liked',
      if (userState.preference == MoviePreference.disliked) 'Hidden',
      if (userState.rating != null) '${userState.rating}/5',
    ];

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 84,
                      height: 124,
                      child: CachedNetworkImage(
                        imageUrl: movie.posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, error, stackTrace) => Container(
                          color: const Color(0xFF1E293B),
                          alignment: Alignment.center,
                          child: Text(
                            movie.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          movie.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          movie.subtitleLine,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          movie.genres.join(' • '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: badges.map((badge) => Chip(label: Text(badge))).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (userState.hasReview) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  userState.review!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}
