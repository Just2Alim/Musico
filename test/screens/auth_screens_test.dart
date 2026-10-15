import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/screens/login_screen.dart';
import 'package:musico_app/screens/register_screen.dart';
import 'package:musico_app/themes/app_theme.dart';

void main() {
  Widget themedApp(Widget home) =>
      MaterialApp(theme: AppTheme.darkTheme, home: home);

  testWidgets('login uses Musico theme and localized streaming copy', (
    tester,
  ) async {
    await tester.pumpWidget(themedApp(LoginScreen()));

    expect(find.text('С возвращением'), findsOneWidget);
    expect(find.text('Электронная почта'), findsOneWidget);
    expect(find.text('Продолжить с Google'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('registration uses the same shared form and button style', (
    tester,
  ) async {
    await tester.pumpWidget(themedApp(RegisterScreen()));

    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.text('Имя'), findsOneWidget);
    expect(find.text('Зарегистрироваться'), findsOneWidget);
  });
}
