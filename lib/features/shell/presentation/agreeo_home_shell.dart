import 'package:agreeo/features/friends/presentation/friends_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_result_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_voting_screen.dart';
import 'package:agreeo/features/friends/presentation/movie_night_waiting_room_screen.dart';
import 'package:agreeo/features/friends/state/friends_movie_night_controller.dart';
import 'package:agreeo/features/home/presentation/home_screen.dart';
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

class AgreeoHomeShell extends ConsumerStatefulWidget {
  const AgreeoHomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<AgreeoHomeShell> createState() => _AgreeoHomeShellState();
}

class _AgreeoHomeShellState extends ConsumerState<AgreeoHomeShell> {
  bool _handlingInvite = false;

  void _selectTab(int index) {
    if (index == 0) {
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

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: AgreeoBottomNavigation(
        selectedIndex: currentIndex,
        onSelected: _selectTab,
      ),
    );
  }
}
