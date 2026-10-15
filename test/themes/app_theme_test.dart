import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/themes/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('dark pages share Musico background, accent, and card surface', () {
      final theme = AppTheme.forBrightness(Brightness.dark);

      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppTheme.canvas);
      expect(theme.colorScheme.primary, AppTheme.accent);
      expect(theme.cardTheme.color, AppTheme.surface);
    });

    test('navigation and form fields use shared surfaces', () {
      final theme = AppTheme.forBrightness(Brightness.dark);

      expect(theme.navigationBarTheme.backgroundColor, AppTheme.surface);
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, AppTheme.surface);
    });
  });
}
