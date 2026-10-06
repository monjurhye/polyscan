import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../widgets/ad_banner.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [DocumentsScreen(), ToolsScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!state.isPro) const AdBannerPlaceholder(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'Documents'),
              NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman), label: 'Tools'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }
}
