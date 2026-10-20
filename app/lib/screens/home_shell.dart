import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'bin_map_page.dart';
import 'remarket_page.dart';
import 'services_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  final Stream<User?>? authStateChanges;

  const HomeShell({super.key, this.authStateChanges});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  late final _pages = [
    const ReMarketPage(),
    const BinMapPage(),
    const ServicesPage(),
    SettingsPage(authStateChanges: widget.authStateChanges),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _i, children: _pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _i,
      onDestinationSelected: (v) => setState(() => _i = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'ReMarket',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Bin Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Services',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    ),
  );
}
