// Global locale accessor for services/viewmodels without BuildContext.
// Initialized at app startup, updated on locale change.

import 'package:flutter/widgets.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';

class AppLocale {
  AppLocale._();

  static AppLocalizations _current = AppLocalizationsSv();

  /// Current localization instance. Falls back to Swedish.
  static AppLocalizations get current => _current;

  /// Initialize with a locale at app startup.
  static void initialize(Locale locale) {
    _current = lookupAppLocalizations(locale);
  }

  /// Update locale at runtime (e.g. user changes language).
  static void updateLocale(Locale locale) {
    _current = lookupAppLocalizations(locale);
  }
}
