import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/coursework/state_management_examples_screen.dart';

void main() {
  testWidgets('shows all three implementations for the same favorite action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StateManagementExamplesScreen()),
    );

    expect(find.text('Локальное состояние: setState'), findsOneWidget);
    expect(find.text('Передача состояния: InheritedWidget'), findsOneWidget);
    expect(find.text('Общее состояние: Provider'), findsOneWidget);
  });
}
