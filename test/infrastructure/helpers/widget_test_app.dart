import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

/// Creates a localized MaterialApp wrapper for widget tests.
///
/// Defaults to Swedish locale; pass [locale] to test other locales (e.g. en).
/// Provides all 4 l10n delegates and Butlery's light theme.
/// Replaces the private `_testApp()` helpers duplicated across 9+ widget test files.
Widget createLocalizedTestApp({
  required Widget child,
  bool wrapInScaffold = true,
  bool wrapInScrollView = false,
  Route<dynamic>? Function(RouteSettings)? onGenerateRoute,
  Locale locale = const Locale('sv'),
}) {
  Widget body = child;
  if (wrapInScrollView) {
    body = SingleChildScrollView(child: body);
  }
  if (wrapInScaffold) {
    body = Scaffold(body: body);
  }

  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    home: body,
    onGenerateRoute: onGenerateRoute,
  );
}
