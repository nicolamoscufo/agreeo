import 'dart:async';

import 'package:agreeo/features/friends/presentation/movie_night_wizard_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/home/presentation/mood_selector_sheet.dart';
import 'package:agreeo/features/home/presentation/random_pick_sheet.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/features/shell/presentation/notifications_page.dart';
import 'package:agreeo/providers/notifications_provider.dart';
import 'package:agreeo/shared/components/filter_bottom_sheet.dart';
import 'package:agreeo/shared/catalog/genre_options.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/home_refresh_provider.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';
import 'package:agreeo/shared/theme/ag_text.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AgreeoHomeScreen extends ConsumerStatefulWidget {
  const AgreeoHomeScreen({super.key});

  @override
  ConsumerState<AgreeoHomeScreen> createState() => _AgreeoHomeScreenState();
}

class _QuickFilter {
  const _QuickFilter(this.label, this.filters, {this.icon});
  final String label;
  final MovieSearchFilters? filters;
  final IconData? icon;
}

class _AgreeoHomeScreenState extends ConsumerState<AgreeoHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  MovieSearchFilters _filters = const MovieSearchFilters();
  String _activeQuickFilter = 'For you';
  Future<List<Movie>>? _searchFuture;
  bool _isRefreshingHome = false;

  static const _quickFilters = <_QuickFilter>[
    _QuickFilter('For you', null, icon: AgIcons.sparkle),
    _QuickFilter('Under 2h', MovieSearchFilters(maxRuntimeMinutes: 120)),
    _QuickFilter('Sci-Fi', MovieSearchFilters(genre: 'Sci-Fi')),
    _QuickFilter('Drama', MovieSearchFilters(genre: 'Drama')),
    _QuickFilter('Comedy', MovieSearchFilters(genre: 'Comedy')),
    _QuickFilter('Action', MovieSearchFilters(genre: 'Action')),
    _QuickFilter('Top rated', MovieSearchFilters(minRating: 7.5)),
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    if (_isRefreshingHome) return;
    _isRefreshingHome = true;
    try {
      await ref.read(agreeoAppControllerProvider.notifier).refreshHomeFeed();
      if (!mounted) return;
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
      if (mounted) _refreshSearch();
    });
  }

  void _openCreateMovieNight() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MovieNightWizardScreen()),
    );
  }

  void _openDetails(Movie movie) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
      ),
    );
  }

  void _surpriseMe() {
    // AgButton.secondary already fires a light-impact haptic on tap.
    showRandomPick(context);
  }

  Future<void> _openFilters() async {
    HapticFeedback.lightImpact();
    final updated = await showMovieFilterBottomSheet(
      context,
      initialFilters: _filters,
      genres: agreeoGenreOptions,
    );
    if (updated != null) {
      setState(() {
        _filters = updated;
        _activeQuickFilter = '';
      });
      _refreshSearch();
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeRefreshProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        _searchController.clear();
        _searchFuture = null;
        _filters = const MovieSearchFilters();
        _activeQuickFilter = 'For you';
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

    final t = context.tokens;
    final state = ref.watch(agreeoAppControllerProvider);
    final unread = ref.watch(notificationsProvider).unreadCount;
    final friends = ref.watch(friendsMovieNightControllerProvider).friends;
    final query = _searchController.text.trim().toLowerCase();
    final hasRemoteSearch = query.isNotEmpty || _filters.hasActiveFilters;
    final firstName = (state.session?.displayName ?? 'there').split(' ').first;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshHome,
        color: t.red,
        backgroundColor: t.surface,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, $firstName',
                        style: AgText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: t.faint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "What's the move?",
                        style: AgText.h1.copyWith(
                          letterSpacing: -0.6,
                          color: t.text,
                        ),
                      ),
                    ],
                  ),
                ),
                _BellButton(
                  unread: unread,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsPage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AgProfileButton(
                  name: state.session?.displayName ?? 'You',
                  imageUrl: state.session?.avatarUrl,
                  color: t.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Search + filters + mood
            Row(
              children: [
                Expanded(
                  child: AgSearchField(
                    controller: _searchController,
                    hint: 'Search films, people…',
                    onChanged: (_) => _scheduleSearchRefresh(),
                    onSubmitted: (_) => _refreshSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                _SquareButton(
                  icon: AgIcons.sliders,
                  semanticLabel: _filters.hasActiveFilters
                      ? 'Filters, active'
                      : 'Filters',
                  highlighted: _filters.hasActiveFilters,
                  badge: _filters.hasActiveFilters,
                  onTap: _openFilters,
                ),
                const SizedBox(width: 10),
                _SquareButton(
                  icon: AgIcons.sparkle,
                  semanticLabel: 'Pick by mood',
                  soft: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showMoodSelectorSheet(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick chips — rail height clears the 44pt touch target.
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final q = _quickFilters[i];
                  return AgChip(
                    label: q.label,
                    icon: q.icon,
                    active: _activeQuickFilter == q.label,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _activeQuickFilter = q.label;
                        _filters = q.filters ?? const MovieSearchFilters();
                      });
                      _refreshSearch();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Movie Night CTA
            _MovieNightCta(onCreate: _openCreateMovieNight, friends: friends),
            const SizedBox(height: 22),
            if (hasRemoteSearch)
              _SearchResults(
                future: _searchFuture,
                onTap: _openDetails,
                onRetry: _refreshSearch,
              )
            else if (state.discoveryFeedFailed &&
                state.recommendedHomeMovies.isEmpty &&
                state.trendingMovies.isEmpty)
              // The feed refresh failed with nothing cached to fall back on —
              // show one honest error + retry, not two "Nothing here yet" rails.
              _InlineStateCard(
                icon: AgIcons.wifiOff,
                title: "Couldn't load your feed",
                message: 'Check your connection and try again.',
                actionLabel: 'Retry',
                onAction: _refreshHome,
              )
            else ...[
              AgSectionHeader(
                title: 'Made for you',
                actionLabel: 'See all',
                onAction: () =>
                    ref.read(navIndexProvider.notifier).state = AgNavTab.swipe,
              ),
              const SizedBox(height: 14),
              _PosterRail(
                movies: state.recommendedHomeMovies,
                posterWidth: 132,
                showMeta: true,
                loading: !state.hydrated,
                onTap: _openDetails,
              ),
              const SizedBox(height: 18),
              _RandomPickCard(onSurprise: _surpriseMe),
              const SizedBox(height: 18),
              const AgSectionHeader(title: 'Trending with friends'),
              const SizedBox(height: 14),
              _PosterRail(
                movies: state.trendingMovies,
                posterWidth: 108,
                loading: !state.hydrated,
                onTap: _openDetails,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Notifications',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(AgIcons.bell, size: 21, color: t.text),
                if (unread > 0)
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: t.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.surface, width: 2),
                      ),
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

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.soft = false,
    this.highlighted = false,
    this.badge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  /// Soft branded treatment (gradient tint + red glyph) for a secondary accent
  /// action. The full brand gradient + glow is reserved for the one primary
  /// surface on the screen (the Movie Night CTA), so it stays the focal point.
  final bool soft;
  final bool highlighted;

  /// Shows a small accent dot so an active state isn't signalled by glyph color
  /// alone (which low-vision sighted users can miss).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: soft ? t.gradSoft : null,
              color: soft ? null : t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: soft ? t.line2 : t.line),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: soft ? t.red : (highlighted ? t.red : t.text),
                ),
                if (badge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.surface, width: 1.5),
                      ),
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

class _MovieNightCta extends StatelessWidget {
  const _MovieNightCta({required this.onCreate, required this.friends});
  final VoidCallback onCreate;
  final List<dynamic> friends;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: 'Start a Movie Night',
      child: GestureDetector(
        onTap: onCreate,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: t.grad,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: t.purple.withValues(alpha: 0.55),
                blurRadius: 34,
                offset: const Offset(0, 16),
                spreadRadius: -14,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _DiagonalPatternPainter()),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start a Movie Night',
                            style: AgText.h3.copyWith(
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Invite friends, swipe together, agree in minutes.',
                            style: AgText.caption.copyWith(
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Pill is always white → use a fixed dark ink in both themes.
                                const Icon(
                                  AgIcons.plus,
                                  size: 16,
                                  color: Color(0xFF1A120C),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'New session',
                                  style: AgText.label.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: const Color(0xFF1A120C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (friends.isNotEmpty)
                      SizedBox(
                        width: 42.0 + (friends.length.clamp(1, 3) - 1) * 28,
                        height: 42,
                        child: Stack(
                          children: [
                            for (var i = 0; i < friends.length.clamp(0, 3); i++)
                              Positioned(
                                left: i * 28.0,
                                child: AgAvatar(
                                  name:
                                      (friends[i].name as String?) ?? 'Friend',
                                  imageUrl: friends[i].avatarUrl,
                                  size: 42,
                                  ring: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagonalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    const spacing = 9.0;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RandomPickCard extends StatelessWidget {
  const _RandomPickCard({required this.onSurprise});
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: t.gradSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line2),
            ),
            child: Icon(AgIcons.dice, size: 26, color: t.gold),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Can't decide?", style: AgText.h4.copyWith(color: t.text)),
                const SizedBox(height: 1),
                Text(
                  'Pull a random pick from your watchlist',
                  style: AgText.caption.copyWith(color: t.sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AgButton.secondary(
            label: 'Surprise me',
            expand: false,
            height: 46,
            onPressed: onSurprise,
          ),
        ],
      ),
    );
  }
}

class _PosterRail extends StatelessWidget {
  const _PosterRail({
    required this.movies,
    required this.posterWidth,
    required this.onTap,
    this.showMeta = false,
    this.loading = false,
  });

  final List<Movie> movies;
  final double posterWidth;
  final ValueChanged<Movie> onTap;
  final bool showMeta;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (movies.isEmpty) {
      if (loading) {
        return AgPosterRailSkeleton(
          posterWidth: posterWidth,
          showMeta: showMeta,
        );
      }
      return Container(
        height: posterWidth * 1.5,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.line),
        ),
        child: Text(
          'Nothing here yet',
          style: AgText.body.copyWith(color: t.faint),
        ),
      );
    }
    final height = posterWidth * 1.5 + (showMeta ? 30 : 0);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final m = movies[i];
          return SizedBox(
            width: posterWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgPoster(
                  imageUrl: m.posterUrl,
                  title: m.title,
                  onTap: () => onTap(m),
                ),
                if (showMeta) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      AgStars(rating: m.rating),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '· ${m.releaseYear}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AgText.micro.copyWith(color: t.faint),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.future,
    required this.onTap,
    required this.onRetry,
  });
  final Future<List<Movie>>? future;
  final ValueChanged<Movie> onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Movie>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: AgPosterGridSkeleton(),
          );
        }
        // A failed search must not masquerade as "no results": the user is on a
        // flaky connection, not searching for the wrong thing.
        if (snapshot.hasError && !snapshot.hasData) {
          return _InlineStateCard(
            icon: AgIcons.wifiOff,
            title: "Couldn't load results",
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: onRetry,
          );
        }
        final results = snapshot.data ?? const <Movie>[];
        if (results.isEmpty) {
          return const _InlineStateCard(
            icon: AgIcons.search,
            title: 'No results',
            message: 'Try a different title or loosen your filters.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgSectionHeader(
              title: 'Results',
              subtitle: '${results.length} titles',
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2 / 3,
              ),
              itemBuilder: (context, i) {
                final m = results[i];
                return AgPoster(
                  imageUrl: m.posterUrl,
                  title: m.title,
                  onTap: () => onTap(m),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Inline empty/error card used by both the search area and the feed rails.
/// Mirrors the surface-card styling of the rest of Home (radius 28) and relies
/// on the parent list's horizontal padding, so it stays aligned with the
/// content above it.
class _InlineStateCard extends StatelessWidget {
  const _InlineStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: t.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: t.faint),
          const SizedBox(height: 14),
          Text(title, style: AgText.h3.copyWith(color: t.text)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AgText.caption.copyWith(color: t.sub),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            AgButton(label: actionLabel!, expand: false, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
