import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/settings/providers/theme_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeModeNotifier', () {
    test('defaults to system theme when no preference is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(ThemeMode.system)..init(prefs);

      expect(notifier.state, ThemeMode.system);
    });

    test('loads saved theme mode from preferences', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(ThemeMode.system)..init(prefs);

      expect(notifier.state, ThemeMode.dark);
    });

    test('toggles theme mode and saves to preferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(ThemeMode.system)..init(prefs);

      notifier.toggle();

      expect(notifier.state, ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');

      notifier.toggle();

      expect(notifier.state, ThemeMode.light);
      expect(prefs.getString('theme_mode'), 'light');
    });
  });
}
