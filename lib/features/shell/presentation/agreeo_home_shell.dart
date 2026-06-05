import 'package:agreeo/features/friends/presentation/friends_screen.dart';
import 'package:agreeo/shared/theme/agreeo_colors.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/home/presentation/home_screen.dart';
import 'package:agreeo/features/home/presentation/mood_selector_sheet.dart';
import 'package:agreeo/features/library/presentation/library_screen.dart';
import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/features/swipe/presentation/swipe_screen.dart';
import 'package:agreeo/shared/components/agreeo_bottom_navigation.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/home_refresh_provider.dart';
import 'package:agreeo/shared/state/movie_night_invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';
import 'package:agreeo/features/shell/presentation/notifications_page.dart';
import 'package:agreeo/providers/notifications_provider.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agreeo/features/movie_details/presentation/movie_details_screen.dart';
import 'package:agreeo/shared/models/agreeo_models.dart';

class AgreeoHomeShell extends ConsumerStatefulWidget {
  const AgreeoHomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<AgreeoHomeShell> createState() => _AgreeoHomeShellState();
}

class _AgreeoHomeShellState extends ConsumerState<AgreeoHomeShell> {
  bool _handlingInvite = false;

  void _selectTab(int index) {
    final currentIndex = ref.read(navIndexProvider);
    if (index == 0 && currentIndex == 0) {
      ref.read(agreeoAppControllerProvider.notifier).refreshHomeFeed();
      ref.read(homeRefreshProvider.notifier).state++;
    }
    ref.read(navIndexProvider.notifier).state = index;
  }

  @override
  void initState() {
    super.initState();
    // initialize provider with optional initialIndex
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navIndexProvider.notifier).state = widget.initialIndex;
      _handlePendingInvite();
    });
  }

  Future<void> _handlePendingInvite() async {
    if (_handlingInvite) {
      return;
    }
    final eventId = ref.read(pendingMovieNightInviteProvider);
    if (eventId == null) {
      return;
    }

    _handlingInvite = true;
    ref.read(pendingMovieNightInviteProvider.notifier).state = null;
    final event = await ref
        .read(friendsMovieNightControllerProvider.notifier)
        .resolveMovieNightInvite(eventId);

    if (!mounted) {
      return;
    }
    ref.read(pendingMovieNightInviteProvider.notifier).state = null;
    _handlingInvite = false;

    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie Night invite not available.')),
      );
      return;
    }

    ref.read(navIndexProvider.notifier).state = 3;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _routeForMovieNight(event)));
  }

  Widget _routeForMovieNight(MovieNightEvent event) {
    return switch (event.status) {
      MovieNightStatus.draft || MovieNightStatus.waiting =>
        MovieNightWaitingRoomScreen(eventId: event.id),
      MovieNightStatus.voting => MovieNightVotingScreen(eventId: event.id),
      MovieNightStatus.completed => MovieNightResultScreen(eventId: event.id),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingMovieNightInviteProvider, (_, next) {
      if (next != null) {
        _handlePendingInvite();
      }
    });

    final screens = <Widget>[
      const AgreeoHomeScreen(),
      const AgreeoLibraryScreen(),
      AgreeoSwipeScreen(onNavigateTab: _selectTab),
      const FriendsScreen(),
      const AgreeoProfileScreen(),
    ];

    final currentIndex = ref.watch(navIndexProvider);
    final showAppBar = currentIndex != 2;

    return Scaffold(
      extendBody: true,
      backgroundColor: currentIndex == 0 ? AgreeoColors.trueBlack : null,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: currentIndex == 0 ? AgreeoColors.trueBlack : Colors.transparent,
              elevation: 0,
              title: Text(
                'Agreeo',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: -0.5,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: <Color>[
                        AgreeoColors.cinematicRed,
                        AgreeoColors.kernelGold,
                      ],
                    ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                ),
              ),
              centerTitle: false,
              actions: [
                if (currentIndex == 0) ...[
                  IconButton(
                    icon: const Icon(Icons.psychology_rounded, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      showMoodSelectorSheet(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, size: 28),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showRandomMovie(context);
                    },
                  ),
                ],
                const _NotificationBadgeButton(),
              ],
            )
          : null,
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: AgreeoBottomNavigation(
        selectedIndex: currentIndex,
        onSelected: _selectTab,
      ),
    );
  }

  void _showRandomMovie(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _RandomMovieDialog(
        onViewDetails: (movie) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AgreeoMovieDetailsScreen(movieId: movie.id),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationBadgeButton extends ConsumerWidget {
  const _NotificationBadgeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final count = state.unreadCount;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 28),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
          ),
          if (count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AgreeoColors.cinematicRed,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RandomMovieDialog extends ConsumerStatefulWidget {
  const _RandomMovieDialog({
    required this.onViewDetails,
  });

  final ValueChanged<Movie> onViewDetails;

  @override
  ConsumerState<_RandomMovieDialog> createState() => _RandomMovieDialogState();
}

class _RandomMovieDialogState extends ConsumerState<_RandomMovieDialog> {
  Movie? _currentMovie;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRandomMovie();
  }

  Future<void> _fetchRandomMovie() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final movie = await ref.read(movieServiceProvider).getRandomMovie();
      if (mounted) {
        setState(() {
          _currentMovie = movie;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load a random movie. Try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBtnDisabled = _isLoading || _currentMovie == null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: AgreeoColors.anthraciteBlack,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Random Pick',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _buildSwitcherContent(colorScheme),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _fetchRandomMovie();
                          },
                    icon: const Icon(Icons.shuffle_rounded, size: 18),
                    label: const Text('Try Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: isBtnDisabled
                          ? null
                          : const LinearGradient(
                              colors: [
                                AgreeoColors.cinematicRed,
                                AgreeoColors.kernelGold,
                              ],
                            ),
                      color: isBtnDisabled
                          ? Colors.white.withValues(alpha: 0.05)
                          : null,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isBtnDisabled
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                              widget.onViewDetails(_currentMovie!);
                            },
                      child: const Text(
                        'Details',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitcherContent(ColorScheme colorScheme) {
    if (_isLoading) {
      return Container(
        key: const ValueKey<String>('loading'),
        height: 330,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AgreeoColors.kernelGold,
            ),
            SizedBox(height: 16),
            Text(
              'Picking something for you...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        key: const ValueKey<String>('error'),
        height: 330,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AgreeoColors.cinematicRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final movie = _currentMovie;
    if (movie == null) {
      return const SizedBox(key: ValueKey<String>('empty'), height: 330);
    }

    return Container(
      key: ValueKey<String>(movie.id),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: movie.posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: movie.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: AgreeoColors.kernelGold,
                          ),
                        ),
                        errorWidget: (context, url, dynamic error) =>
                            const Center(
                          child: Icon(
                            Icons.movie_creation_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.movie_creation_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            movie.runtimeLabel.isEmpty
                ? movie.releaseYear.toString()
                : '${movie.releaseYear} • ${movie.runtimeLabel}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          if (movie.genres.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                movie.genres.take(2).join(' · '),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.secondary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
