import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Provider for managing app locale preference.
/// Persists locale choice to SharedPreferences.
class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'preferred_locale';
  static const String _defaultLocale = 'sv';
  static const List<String> supportedLocales = ['sv', 'en'];

  Locale _locale = const Locale('sv');
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  /// Get display name for a locale code
  static String getLocaleName(String code) {
    switch (code) {
      case 'sv':
        return 'Svenska';
      case 'en':
        return 'English';
      default:
        return code;
    }
  }

  /// Initialize provider - load saved locale preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    _initCompleter = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_localeKey);

      if (savedLocale != null && supportedLocales.contains(savedLocale)) {
        _locale = Locale(savedLocale);
      } else {
        // Check UserProfile for preference as fallback
        try {
          final userService = ServiceLocator.get<UserService>();
          final profile = userService.currentUserProfile;
          if (profile?.preferredLocale != null &&
              supportedLocales.contains(profile!.preferredLocale)) {
            _locale = Locale(profile.preferredLocale!);
            await prefs.setString(_localeKey, profile.preferredLocale!);
          }
        } catch (_) {
          // UserService not available yet, use default
        }
      }

      _isInitialized = true;
      notifyListeners();
    } finally {
      _initCompleter!.complete();
    }
  }

  /// Set the app locale
  Future<void> setLocale(String localeCode) async {
    if (!supportedLocales.contains(localeCode)) return;

    // Wait for initialization to complete before writing
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }

    if (_locale.languageCode == localeCode) return;

    _locale = Locale(localeCode);

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);

    notifyListeners();
  }

  /// Clear locale preference (reset to default)
  Future<void> clearLocale() async {
    _locale = const Locale(_defaultLocale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localeKey);

    notifyListeners();
  }
}
