import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('ru');
  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 0];
    final languageCode = prefs.getString('app_locale') ?? 'ru';
    _locale = switch (languageCode) {
      'en' => const Locale('en'),
      'kk' => const Locale('kk'),
      _ => const Locale('ru'),
    };
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode value) async {
    _themeMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', value.index);
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    if (!{'ru', 'en', 'kk'}.contains(value.languageCode)) {
      throw ArgumentError.value(value, 'value', 'Unsupported locale');
    }
    _locale = Locale(value.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', _locale.languageCode);
    notifyListeners();
  }
}
