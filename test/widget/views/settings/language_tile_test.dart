// BUT-869: Widget test for `LanguageTile` (the locale switcher introduced
// in BUT-801).
//
// The tile reads `LocaleProvider` via `ServiceLocator`, listens for changes
// (so the subtitle reflects switches without rebuild from above), and on tap
// opens an AlertDialog with the two supported locales. Selecting a non-current
// locale calls `LocaleProvider.setLocale(code)`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/views/settings/settings_hub_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('LanguageTile (BUT-869)', () {
    late LocaleProvider localeProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GetIt.instance.reset();
      ServiceLocator.reset();

      localeProvider = LocaleProvider();
      final container = DIContainer();
      container.container.registerSingleton<LocaleProvider>(localeProvider);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('renders with current locale name as subtitle', (tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        child: const LanguageTile(),
      ));

      // Default locale is sv → 'Svenska'.
      expect(find.text('Svenska'), findsOneWidget);
    });

    testWidgets('opens a dialog with both supported locales when tapped',
        (tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        child: const LanguageTile(),
      ));

      await tester.tap(find.byType(LanguageTile));
      await tester.pumpAndSettle();

      // Dialog content is a Column of ListTiles, one per supported locale.
      // The visible LanguageTile subtitle also reads "Svenska", so we look
      // for the dialog's ListTile entries inside the AlertDialog scope.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Svenska'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('English'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'selecting a non-current locale calls setLocale and updates '
        'the subtitle', (tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        child: const LanguageTile(),
      ));

      expect(localeProvider.locale.languageCode, 'sv');

      await tester.tap(find.byType(LanguageTile));
      await tester.pumpAndSettle();

      // Pick the English ListTile inside the dialog.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('English'),
      ));
      await tester.pumpAndSettle();

      expect(localeProvider.locale.languageCode, 'en',
          reason: 'Tapping English must call LocaleProvider.setLocale("en").');
      // Subtitle reflects the new locale via the tile's ChangeNotifier listener.
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('selecting the current locale does not change state',
        (tester) async {
      await tester.pumpWidget(createLocalizedTestApp(
        child: const LanguageTile(),
      ));

      await tester.tap(find.byType(LanguageTile));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Svenska'),
      ));
      await tester.pumpAndSettle();

      expect(localeProvider.locale.languageCode, 'sv',
          reason: 'LocaleProvider.setLocale short-circuits when the locale '
              "already matches; this confirms the tile doesn't double-fire.");
    });
  });
}
