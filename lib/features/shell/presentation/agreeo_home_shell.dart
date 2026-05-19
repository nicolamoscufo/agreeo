import 'package:agreeo/features/friends/presentation/friends_screen.dart';
import 'package:agreeo/features/home/presentation/home_screen.dart';
import 'package:agreeo/features/library/presentation/library_screen.dart';
import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/features/swipe/presentation/swipe_screen.dart';
import 'package:agreeo/shared/components/agreeo_bottom_navigation.dart';
import 'package:agreeo/shared/state/agreeo_app_controller.dart';
import 'package:agreeo/shared/state/home_refresh_provider.dart';
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
    });
  }

  @override
  Widget build(BuildContext context) {
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
