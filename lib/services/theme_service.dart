/// Theme service for managing app theme mode (light/dark/system).
/// Persists user preference using SharedPreferences.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service for managing application theme mode.
/// Supports system, light, and dark modes with persistent storage.
class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  /// Current theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Whether the service has been initialized.
  bool get isInitialized => _isInitialized;

  /// Initialize the service by loading persisted theme preference.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);

      if (savedMode != null) {
        _themeMode = _themeModeFromString(savedMode);
        AppLogger.info('ThemeService: Loaded theme mode: $_themeMode');
      }
    } catch (e) {
      AppLogger.warning('ThemeService: Failed to load theme preference: $e');
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Set the theme mode and persist the preference.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _themeModeToString(mode));
      AppLogger.info('ThemeService: Saved theme mode: $mode');
    } catch (e) {
      AppLogger.warning('ThemeService: Failed to save theme preference: $e');
    }
  }

  /// Toggle between light and dark mode (skipping system).
  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  /// Convert ThemeMode to string for storage.
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  /// Convert string to ThemeMode.
  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
