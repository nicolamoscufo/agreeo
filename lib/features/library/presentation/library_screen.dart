import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LibraryTab { watchlist, liked, watched }

class AgreeoLibraryScreen extends ConsumerStatefulWidget {
  const AgreeoLibraryScreen({super.key});

  @override
  ConsumerState<AgreeoLibraryScreen> createState() => _AgreeoLibraryScreenState();
}

class _AgreeoLibraryScreenState extends ConsumerState<AgreeoLibraryScreen> {
  _LibraryTab _tab = _LibraryTab.watchlist;
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _runtimeLabel(int m) => m <= 0 ? '' : '${m ~/ 60}h ${m % 60}m';

  List<Movie> _moviesForTab(AgreeoAppState state, _LibraryTab tab) {
    final query = _searchController.text.trim().toLowerCase();
    final items = state.catalog.where((movie) {
      final s = state.userMovieStateFor(movie.id);
      final inTab = switch (tab) {
        _LibraryTab.watchlist => s.inWatchlist && !s.watched,
        _LibraryTab.liked => s.preference == MoviePreference.liked,
        _LibraryTab.watched => s.watched,
      };
      if (!inTab) return false;
      if (query.isEmpty) return true;
      return movie.title.toLowerCase().contains(query) ||
          movie.genres.any((g) => g.toLowerCase().contains(query));
    }).toList(growable: false);
    items.sort((a, b) => state
        .userMovieStateFor(b.id)
        .updatedAt
        .compareTo(state.userMovieStateFor(a.id).updatedAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final state = ref.watch(agreeoAppControllerProvider);
    final counts = {
      _LibraryTab.watchlist: _moviesForTab(state, _LibraryTab.watchlist).length,
      _LibraryTab.liked: _moviesForTab(state, _LibraryTab.liked).length,
      _LibraryTab.watched: _moviesForTab(state, _LibraryTab.watched).length,
    };
    final rows = _moviesForTab(state, _tab);
    final controller = ref.read(agreeoAppControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Library',
                    style: TextStyle(
                      fontFamily: 'Bricolage Grotesque',
                      fontWeight: FontWeight.w800,
                      fontSize: 27,
                      letterSpacing: -0.6,
                      color: t.text,
                    ),
                  ),
                ),
                _IconSquare(
                  icon: AgIcons.search,
                  active: _searchOpen,
                  onTap: () => setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) _searchController.clear();
                  }),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AgreeoProfileScreen()),
                  ),
                  child: AgAvatar(name: state.session?.displayName ?? 'You', color: t.red, size: 42),
                ),
              ],
            ),
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: AgSearchField(
                controller: _searchController,
                hint: 'Search inside your library',
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
          // Segmented tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  _segTab('Watchlist', _LibraryTab.watchlist, counts),
                  _segTab('Liked', _LibraryTab.liked, counts),
                  _segTab('Watched', _LibraryTab.watched, counts),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => controller.syncLibrary(),
              color: t.red,
              backgroundColor: t.surface,
              child: rows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        _emptyForTab(context),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final movie = rows[i];
                        return _LibraryRow(
                          movie: movie,
                          userState: state.userMovieStateFor(movie.id),
                          tab: _tab,
                          runtimeLabel: _runtimeLabel(movie.runtime),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                            ));
                          },
                          onLike: () => controller.likeMovie(movie.id),
                          onDislike: () => controller.dislikeMovie(movie.id),
                          onSeen: () => controller.markAsWatched(movie.id),
                          onReview: () {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
                            ));
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segTab(String label, _LibraryTab tab, Map<_LibraryTab, int> counts) {
    final t = context.tokens;
    final on = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tab = tab);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            gradient: on ? t.grad : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: on ? Colors.white : t.sub,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${counts[tab] ?? 0}',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: on ? Colors.white70 : t.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyForTab(BuildContext context) {
    final (icon, title, message) = switch (_tab) {
      _LibraryTab.watchlist => (
          AgIcons.bookmark,
          'Your watchlist is empty',
          'Save movies from Swipe or Home to find them here.',
        ),
      _LibraryTab.liked => (
          AgIcons.heart,
          'No liked movies yet',
          'Like movies from Swipe to sharpen your taste.',
        ),
      _LibraryTab.watched => (
          AgIcons.eye,
          'Nothing watched yet',
          'Movies you finish build your memory lane here.',
        ),
    };
    return AgStateCard(icon: icon, title: title, message: message);
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? t.surface2 : t.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? t.line2 : t.line),
        ),
        child: Icon(icon, size: 20, color: active ? t.red : t.text),
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.movie,
    required this.userState,
    required this.tab,
    required this.runtimeLabel,
    required this.onTap,
    required this.onLike,
    required this.onDislike,
    required this.onSeen,
    required this.onReview,
  });

  final Movie movie;
  final UserMovieState userState;
  final _LibraryTab tab;
  final String runtimeLabel;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onSeen;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (badgeLabel, badgeColor) = switch (tab) {
      _LibraryTab.watchlist => ('Watchlist', t.purple),
      _LibraryTab.liked => ('★ Liked', t.green),
      _LibraryTab.watched => ('Watched', t.gold),
    };
    final meta = [
      if (movie.releaseYear > 0) '${movie.releaseYear}',
      if (runtimeLabel.isNotEmpty) runtimeLabel,
      if (movie.genres.isNotEmpty) movie.genres.take(2).join(', '),
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 66, child: AgPoster(imageUrl: movie.posterUrl, title: movie.title, radius: 10)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          movie.title,
                          style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            height: 1.1,
                            color: t.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: t.faint),
                  ),
                  const SizedBox(height: 6),
                  if (userState.hasReview)
                    Container(
                      padding: const EdgeInsets.only(left: 9),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: t.line2, width: 2)),
                      ),
                      child: Text(
                        '"${userState.review}"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                          color: t.sub,
                        ),
                      ),
                    )
                  else if (tab == _LibraryTab.watchlist)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Qa(icon: AgIcons.heart, onTap: onLike),
                        _Qa(icon: AgIcons.dislike, onTap: onDislike),
                        _Qa(icon: AgIcons.eye, onTap: onSeen),
                        _Qa(icon: AgIcons.edit, label: 'Review', onTap: onReview),
                      ],
                    )
                  else
                    Row(
                      children: [
                        AgStars(rating: (userState.rating ?? movie.rating.round()).toDouble()),
                        const SizedBox(width: 8),
                        Text(
                          '· your rating',
                          style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: t.faint),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Qa extends StatelessWidget {
  const _Qa({required this.icon, required this.onTap, this.label});
  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label != null ? 10 : 6, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: t.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: t.sub),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                  color: t.sub,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
