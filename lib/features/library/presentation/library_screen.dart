import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/shared/components/primitives.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LibraryMediaFilter { all, movie, tv }

class AgreeoLibraryScreen extends ConsumerStatefulWidget {
  const AgreeoLibraryScreen({super.key});

  @override
  ConsumerState<AgreeoLibraryScreen> createState() =>
      _AgreeoLibraryScreenState();
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
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agreeoAppControllerProvider);

    final watchlistCount = _moviesForTab(state, _LibraryTab.watchlist).length;
    final likedCount = _moviesForTab(state, _LibraryTab.liked).length;
    final watchedCount = _moviesForTab(state, _LibraryTab.watched).length;
    final hiddenCount = _moviesForTab(state, _LibraryTab.hidden).length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeader(
              title: 'Library',
              subtitle:
                  'Your personal memory space — $watchedCount watched, $likedCount liked, $watchlistCount saved.',
            ),
            const SizedBox(height: 16),
            AgreeoSearchBar(
              controller: _searchController,
              hintText: 'Search inside your library',
              onChanged: (_) => setState(() {}),
              trailing: PopupMenuButton<LibrarySort>(
                initialValue: _sort,
                onSelected: (value) {
                  HapticFeedback.selectionClick();
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
                    HapticFeedback.selectionClick();
                    _mediaFilter = _LibraryMediaFilter.all;
                  }),
                ),
                SelectableChip(
                  label: 'Movie',
                  selected: _mediaFilter == _LibraryMediaFilter.movie,
                  onTap: () => setState(() {
                    HapticFeedback.selectionClick();
                    _mediaFilter = _LibraryMediaFilter.movie;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: <Widget>[
                _buildCountTab('Watchlist', watchlistCount),
                _buildCountTab('Liked', likedCount),
                _buildCountTab('Watched', watchedCount),
                _buildCountTab('Hidden', hiddenCount),
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

  Widget _buildCountTab(String label, int count) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label),
            if (count > 0) ...<Widget>[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
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
            HapticFeedback.lightImpact();
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
                color: AgreeoColors.cinematicRed,
                onTap: () => _showUndoAction(
                  () => controller.removeFromWatchlist(movie.id),
                ),
              ),
              _actionChip(
                label: 'Seen',
                icon: Icons.visibility_outlined,
                color: AgreeoColors.popcornWhite,
                onTap: () =>
                    _showUndoAction(() => controller.markAsWatched(movie.id)),
              ),
              _actionChip(
                label: 'Like',
                icon: Icons.thumb_up_alt_outlined,
                color: AgreeoColors.kernelGold,
                onTap: () =>
                    _showUndoAction(() => controller.likeMovie(movie.id)),
              ),
              _actionChip(
                label: 'Dislike',
                icon: Icons.thumb_down_alt_outlined,
                color: const Color(0xFF6B7280),
                onTap: () =>
                    _showUndoAction(() => controller.dislikeMovie(movie.id)),
              ),
            ],
            _LibraryTab.liked => <Widget>[
              _actionChip(
                label: 'Remove like',
                icon: Icons.heart_broken_outlined,
                color: AgreeoColors.cinematicRed,
                onTap: () =>
                    _showUndoAction(() => controller.clearPreference(movie.id)),
              ),
              _actionChip(
                label: userState.inWatchlist ? 'Saved' : 'Watchlist',
                icon: Icons.bookmark_outline_rounded,
                color: AgreeoColors.kernelGold,
                onTap: () => _showUndoAction(
                  userState.inWatchlist
                      ? () => controller.removeFromWatchlist(movie.id)
                      : () => controller.addToWatchlist(movie.id),
                ),
              ),
              _actionChip(
                label: userState.watched ? 'Watched' : 'Seen',
                icon: Icons.visibility_outlined,
                color: AgreeoColors.popcornWhite,
                onTap: () => _showUndoAction(
                  userState.watched
                      ? () => controller.removeFromWatched(movie.id)
                      : () => controller.markAsWatched(movie.id),
                ),
              ),
              _actionChip(
                label: 'Rate / Review',
                icon: Icons.rate_review_outlined,
                color: AgreeoColors.kernelGold,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AgreeoMovieDetailsScreen(movieId: movie.id),
                    ),
                  );
                },
              ),
            ],
            _LibraryTab.watched => <Widget>[
              _actionChip(
                label: userState.preference == MoviePreference.liked
                    ? 'Liked'
                    : 'Like',
                icon: Icons.thumb_up_alt_outlined,
                color: AgreeoColors.kernelGold,
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
                color: const Color(0xFF6B7280),
                onTap: () => _showUndoAction(
                  userState.preference == MoviePreference.disliked
                      ? () => controller.clearPreference(movie.id)
                      : () => controller.dislikeMovie(movie.id),
                ),
              ),
              _actionChip(
                label: 'Rate again',
                icon: Icons.star_outline_rounded,
                color: AgreeoColors.kernelGold,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AgreeoMovieDetailsScreen(movieId: movie.id),
                    ),
                  );
                },
              ),
              _actionChip(
                label: 'Edit review',
                icon: Icons.edit_note_rounded,
                color: AgreeoColors.popcornWhite,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AgreeoMovieDetailsScreen(movieId: movie.id),
                    ),
                  );
                },
              ),
              _actionChip(
                label: 'Remove watched',
                icon: Icons.remove_red_eye_outlined,
                color: AgreeoColors.cinematicRed,
                onTap: () => _showUndoAction(
                  () => controller.removeFromWatched(movie.id),
                ),
              ),
            ],
            _LibraryTab.hidden => <Widget>[
              _actionChip(
                label: 'Undo dislike',
                icon: Icons.undo_rounded,
                color: AgreeoColors.kernelGold,
                onTap: () =>
                    _showUndoAction(() => controller.clearPreference(movie.id)),
              ),
              _actionChip(
                label: 'Move to Watchlist',
                icon: Icons.bookmark_add_outlined,
                color: AgreeoColors.kernelGold,
                onTap: () =>
                    _showUndoAction(() => controller.addToWatchlist(movie.id)),
              ),
              _actionChip(
                label: userState.watched ? 'Watched' : 'Mark watched',
                icon: Icons.visibility_outlined,
                color: AgreeoColors.popcornWhite,
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
    return state.catalog
        .where((movie) {
          final userState = state.userMovieStateFor(movie.id);
          final inTab = switch (tab) {
            _LibraryTab.watchlist => userState.inWatchlist,
            _LibraryTab.liked => userState.preference == MoviePreference.liked,
            _LibraryTab.watched => userState.watched,
            _LibraryTab.hidden =>
              userState.preference == MoviePreference.disliked,
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
        })
        .toList(growable: false);
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
          return (rightState.rating ?? right.rating).compareTo(
            leftState.rating ?? left.rating,
          );
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
        message:
            'Disliked picks will move here so they stop crowding the stack.',
      ),
    };
  }

  Widget _actionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.10),
      side: BorderSide(color: color.withValues(alpha: 0.20)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
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

  static const _badgeColors = <String, Color>{
    'Watchlist': AgreeoColors.kernelGold,
    'Liked': AgreeoColors.cinematicRed,
    'Watched': AgreeoColors.popcornWhite,
    'Hidden': Color(0xFF6B7280),
  };

  static const Color _ratingColor = AgreeoColors.kernelGold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final badges = <({String label, Color color})>[
      if (userState.inWatchlist)
        (label: 'Watchlist', color: _badgeColors['Watchlist']!),
      if (userState.watched)
        (label: 'Watched', color: _badgeColors['Watched']!),
      if (userState.preference == MoviePreference.liked)
        (label: 'Liked', color: _badgeColors['Liked']!),
      if (userState.preference == MoviePreference.disliked)
        (label: 'Hidden', color: _badgeColors['Hidden']!),
      if (userState.rating != null)
        (label: '${userState.rating}/5', color: _ratingColor),
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
                          color: AgreeoColors.darkSurface,
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
                          spacing: 6,
                          runSpacing: 6,
                          children: badges
                              .map((b) => _MiniPillBadge(
                                    label: b.label,
                                    color: b.color,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (userState.hasReview) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.format_quote_rounded,
                        size: 18,
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userState.review!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
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

class _MiniPillBadge extends StatelessWidget {
  const _MiniPillBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
