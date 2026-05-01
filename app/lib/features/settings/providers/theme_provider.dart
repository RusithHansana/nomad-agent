import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  // Will be overridden in main.dart after SharedPreferences init
  return ThemeModeNotifier(ThemeMode.system);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial, {SharedPreferences? prefs})
      : _prefs = prefs;

  SharedPreferences? _prefs;

  // Call once after SharedPreferences is available
  void init(SharedPreferences prefs) {
    _prefs = prefs;
    final stored = prefs.getString(_kThemeModeKey);
    if (stored != null) {
      state = _fromString(stored);
    }
  }

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs?.setString(_kThemeModeKey, _toString(state));
  }

  static ThemeMode _fromString(String value) => switch (value) {
    'dark' => ThemeMode.dark,
    'light' => ThemeMode.light,
    _ => ThemeMode.system,
  };

  static String _toString(ThemeMode mode) => switch (mode) {
    ThemeMode.dark => 'dark',
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
  };
}
