import 'package:agreeo/screens/dashboard/dashboard_screen.dart';
import 'package:agreeo/screens/events/create_event_screen.dart';
import 'package:agreeo/screens/settings/settings_screen.dart';
import 'package:agreeo/screens/swipe/swipe_screen.dart';
import 'package:agreeo/screens/watchlist/watchlist_screen.dart';
import 'package:flutter/material.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    DashboardScreen(),
    SwipeScreen(),
    WatchlistScreen(),
    CreateEventScreen(),
    SettingsScreen(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_rounded),
          label: 'Home',
        ),
        NavigationDestination(icon: Icon(Icons.swipe_rounded), label: 'Swipe'),
        NavigationDestination(
          icon: Icon(Icons.bookmark_rounded),
          label: 'Watchlist',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_available_rounded),
          label: 'Event',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_rounded),
          label: 'Settings',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _destinations,
      ),
    );
  }
}
