import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/coursework/state_management_examples.dart';

void main() {
  testWidgets('setState example toggles a saved track', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetStateFavoriteExample()));

    await tester.tap(find.byKey(const ValueKey('set-state-favorite-toggle')));
    await tester.pump();

    expect(find.text('Трек в избранном'), findsOneWidget);
  });

  testWidgets('InheritedWidget example propagates favorite changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: InheritedFavoriteExample()),
    );

    await tester.tap(find.byKey(const ValueKey('inherited-favorite-toggle')));
    await tester.pump();

    expect(find.text('Трек в избранном'), findsOneWidget);
  });

  testWidgets('Provider example exposes shared favorite state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProviderFavoriteExample()));

    await tester.tap(find.byKey(const ValueKey('provider-favorite-toggle')));
    await tester.pump();

    expect(find.text('Трек в избранном'), findsOneWidget);
  });
}
