import 'package:agreeo/features/friends/presentation/friends_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_wizard_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/home/presentation/home_screen.dart';
import 'package:agreeo/features/library/presentation/library_screen.dart';
import 'package:agreeo/features/swipe/presentation/swipe_screen.dart';
import 'package:agreeo/shared/models/social_models.dart';
import 'package:agreeo/shared/state/movie_night_invite_provider.dart';
import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:agreeo/shared/ui/ag_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agreeo/shared/state/nav_index_provider.dart';

/// Main authenticated shell. Tab order (Daylight): Home · Swipe · [Movie-Night
/// FAB] · Library · Friends. Profile is reached from each screen's header avatar,
/// not a tab. Indices are defined in [AgNavTab].
class AgreeoHomeShell extends ConsumerStatefulWidget {
  const AgreeoHomeShell({super.key, this.initialIndex = AgNavTab.home});

  final int initialIndex;

  @override
  ConsumerState<AgreeoHomeShell> createState() => _AgreeoHomeShellState();
}

class _AgreeoHomeShellState extends ConsumerState<AgreeoHomeShell> {
  bool _handlingInvite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navIndexProvider.notifier).state = widget.initialIndex;
      _handlePendingInvite();
    });
  }

  Future<void> _handlePendingInvite() async {
    if (_handlingInvite) return;
    final eventId = ref.read(pendingMovieNightInviteProvider);
    if (eventId == null) return;

    _handlingInvite = true;
    ref.read(pendingMovieNightInviteProvider.notifier).state = null;
    final event = await ref
        .read(friendsMovieNightControllerProvider.notifier)
        .resolveMovieNightInvite(eventId);

    if (!mounted) return;
    _handlingInvite = false;

    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movie Night invite not available.')),
      );
      return;
    }

    ref.read(navIndexProvider.notifier).state = AgNavTab.friends;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _routeForMovieNight(event)),
    );
  }

  Widget _routeForMovieNight(MovieNightEvent event) {
    return switch (event.status) {
      MovieNightStatus.draft || MovieNightStatus.waiting =>
        MovieNightWaitingRoomScreen(eventId: event.id),
      MovieNightStatus.voting => MovieNightVotingScreen(eventId: event.id),
      MovieNightStatus.completed => MovieNightResultScreen(eventId: event.id),
    };
  }

  void _selectTab(int index) {
    ref.read(navIndexProvider.notifier).state = index;
  }

  void _openCreateMovieNight() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MovieNightWizardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    ref.listen<String?>(pendingMovieNightInviteProvider, (_, next) {
      if (next != null) _handlePendingInvite();
    });

    final index = ref.watch(navIndexProvider).clamp(0, 3);
    final screens = <Widget>[
      const AgreeoHomeScreen(),
      AgreeoSwipeScreen(onNavigateTab: _selectTab),
      const AgreeoLibraryScreen(),
      const FriendsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: t.bg,
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: AgGlassBottomNav(onCenterTap: () {
        HapticFeedback.mediumImpact();
        _openCreateMovieNight();
      }),
    );
  }
}
