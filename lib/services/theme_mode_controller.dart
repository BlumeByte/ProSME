import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';
const _defaultThemeMode = ThemeMode.light;

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(_initialThemeMode);
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(super.initialMode);

  static ThemeMode _initialThemeMode = _defaultThemeMode;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModeKey) ?? _defaultThemeMode.name;
    _initialThemeMode = _modeFromName(stored);
  }

  Future<void> setDarkMode(bool enabled) async {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  static ThemeMode _modeFromName(String mode) {
    for (final value in ThemeMode.values) {
      if (value.name == mode) return value;
    }
    return _defaultThemeMode;
  }
}
