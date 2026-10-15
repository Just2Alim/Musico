import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:musico_app/features/navigation/main_navigation_shell.dart';

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetDevicePixelRatio();
  });

  testWidgets('uses bottom navigation on a phone in portrait and landscape', (
    tester,
  ) async {
    await _pumpAtSize(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await _pumpAtSize(tester, const Size(844, 390));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses a navigation rail on a tablet in both orientations', (
    tester,
  ) async {
    await _pumpAtSize(tester, const Size(800, 1280));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);

    await _pumpAtSize(tester, const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(800, 1280)]) {
    testWidgets('notifies on every library selection at $size', (tester) async {
      final selections = <int>[];
      await _pumpAtSize(tester, size, onBranchSelected: selections.add);
      expect(selections, isEmpty);

      await tester.tap(find.text('Медиатека'));
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);

      await tester.tap(find.text('Поиск'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Медиатека'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Медиатека'));
      await tester.pumpAndSettle();

      expect(selections, [2, 1, 2, 2]);
      expect(find.text('Library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size, {
  ValueChanged<int>? onBranchSelected,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainNavigationShell(
          navigationShell: shell,
          onBranchSelected: onBranchSelected,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const Text('Home')),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (_, __) => const Text('Search'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, __) => const Text('Library'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, __) => const Text('Account'),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}
