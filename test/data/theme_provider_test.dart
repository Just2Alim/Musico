import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musico_app/data/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists the selected language', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    final provider = ThemeProvider();

    await provider.load();
    expect(provider.locale, const Locale('en'));

    await provider.setLocale(const Locale('kk'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_locale'), 'kk');
    expect(provider.locale, const Locale('kk'));
  });
}
