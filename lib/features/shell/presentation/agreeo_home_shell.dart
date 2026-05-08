import 'package:agreeo/features/friends/presentation/friends_placeholder_screen.dart';
import 'package:agreeo/features/home/presentation/home_screen.dart';
import 'package:agreeo/features/library/presentation/library_screen.dart';
import 'package:agreeo/features/profile/presentation/profile_screen.dart';
import 'package:agreeo/features/swipe/presentation/swipe_screen.dart';
import 'package:agreeo/shared/components/agreeo_bottom_navigation.dart';
import 'package:flutter/material.dart';

class AgreeoHomeShell extends StatefulWidget {
  const AgreeoHomeShell({super.key});

  @override
  State<AgreeoHomeShell> createState() => _AgreeoHomeShellState();
}

class _AgreeoHomeShellState extends State<AgreeoHomeShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const AgreeoHomeScreen(),
      const AgreeoLibraryScreen(),
      AgreeoSwipeScreen(onNavigateTab: _selectTab),
      const FriendsPlaceholderScreen(),
      const AgreeoProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: AgreeoBottomNavigation(
        selectedIndex: _selectedIndex,
        onSelected: _selectTab,
      ),
    );
  }
}
