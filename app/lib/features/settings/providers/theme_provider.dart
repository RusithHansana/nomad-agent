import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

/// Provider for the app-wide theme mode, backed by [SharedPreferences].
///
/// Overridden in `main.dart` after [SharedPreferences] initialisation so that
/// the persisted user preference is loaded before the first frame.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  // Will be overridden in main.dart after SharedPreferences init
  return ThemeModeNotifier(ThemeMode.system);
});

/// Manages the current [ThemeMode] and persists changes to [SharedPreferences].
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial, {SharedPreferences? prefs})
      : _prefs = prefs;

  SharedPreferences? _prefs;

  /// Loads the persisted theme preference from [prefs].
  ///
  /// Must be called once after [SharedPreferences] is available.
  void init(SharedPreferences prefs) {
    _prefs = prefs;
    final stored = prefs.getString(_kThemeModeKey);
    if (stored != null) {
      state = _fromString(stored);
    }
  }

  /// Toggles between [ThemeMode.dark] and [ThemeMode.light].
  ///
  /// When the current mode is [ThemeMode.system], switches to dark.
  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _prefs?.setString(_kThemeModeKey, _toString(state));
  }

  /// Sets an explicit [ThemeMode] and persists the choice.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _prefs?.setString(_kThemeModeKey, _toString(mode));
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
