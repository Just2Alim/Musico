import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({
    super.key,
    required this.navigationShell,
    this.onBranchSelected,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int>? onBranchSelected;

  static const _destinations = [
    _NavigationDestination(Icons.home_outlined, 'Главная'),
    _NavigationDestination(Icons.search, 'Поиск'),
    _NavigationDestination(Icons.library_music_outlined, 'Медиатека'),
    _NavigationDestination(Icons.person_outline, 'Аккаунт'),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWide =
          constraints.maxWidth >= 700 &&
          MediaQuery.sizeOf(context).shortestSide >= 600;
      return Scaffold(
        body: Row(
          children: [
            if (isWide)
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: _goToBranch,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.icon),
                      label: Text(destination.label),
                    ),
                ],
              ),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goToBranch,
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      label: destination.label,
                    ),
                ],
              ),
      );
    },
  );

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    onBranchSelected?.call(index);
  }
}

class _NavigationDestination {
  const _NavigationDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}
