// BUT-923: Widget gate for the Settings hub "Food" entry.
//
// The food/allergen tile was relabelled (`allergenSettingsTitle`:
// "Allergeninställningar" → "Allergener & kostpreferenser") and gained an
// explanatory subtitle via the new optional `subtitle:` on `_SettingsTile`
// (`allergenSettingsHubSubtitle`). These tests prove the live wiring renders
// that title + subtitle in BOTH locales, and that tiles WITHOUT a subtitle
// (the null branch) render none — so a refactor that drops the subtitle,
// wires the wrong l10n key, or removes the null-guard is caught.
//
// We render the full `SettingsHubView` (the subtitle lives on the private
// `_SettingsTile`, only reachable through the hub) with a stubbed
// `ReportService` returning a non-admin stream, so the admin tile collapses
// to a SizedBox and no Firestore is touched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/settings_hub_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockReportService extends Mock implements ReportService {}

void main() {
  group('SettingsHubView food tile (BUT-923)', () {
    late _MockReportService reportService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GetIt.instance.reset();
      ServiceLocator.reset();

      reportService = _MockReportService();
      // Non-admin: the moderation tile collapses to SizedBox.shrink, and no
      // real Firestore stream is opened.
      when(
        () => reportService.watchIsAdmin(),
      ).thenAnswer((_) => Stream<bool>.value(false));

      final container = DIContainer();
      container.container.registerSingleton<ReportService>(reportService);
      // The embedded LanguageTile resolves LocaleProvider from DI in initState.
      container.container.registerSingleton<LocaleProvider>(LocaleProvider());
      // BUT-1306's AutoAddPantryTile resolves UserService in initState; without
      // it the whole settings ListView throws (stale-harness drift).
      container.container.registerSingleton<UserService>(MockUserService());
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets(
      'food tile renders the relabelled title + explanatory subtitle (sv)',
      (tester) async {
        final sv = AppLocalizationsSv();

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false, // SettingsHubView supplies its own Scaffold.
            child: const SettingsHubView(),
          ),
        );
        await tester.pump();

        expect(
          find.text(sv.allergenSettingsTitle),
          findsOneWidget,
          reason: 'Food entry must show the relabelled title.',
        );
        expect(
          find.text(sv.allergenSettingsHubSubtitle),
          findsOneWidget,
          reason: 'Food entry must wire the new explanatory subtitle.',
        );

        // The subtitle belongs to the SAME ListTile as the title — proves the
        // subtitle is attached to the food tile, not floating elsewhere.
        final foodTile = find.ancestor(
          of: find.text(sv.allergenSettingsTitle),
          matching: find.byType(ListTile),
        );
        expect(
          find.descendant(
            of: foodTile,
            matching: find.text(sv.allergenSettingsHubSubtitle),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a subtitle-less tile renders no subtitle (null-guard holds)', (
      tester,
    ) async {
      final sv = AppLocalizationsSv();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const SettingsHubView(),
        ),
      );
      await tester.pump();

      // "Personliga taggar" tile passes no subtitle to _SettingsTile.
      final tagTile = find.ancestor(
        of: find.text(sv.personalTagsViewTitle),
        matching: find.byType(ListTile),
      );
      expect(tagTile, findsOneWidget);

      final tile = tester.widget<ListTile>(tagTile);
      expect(
        tile.subtitle,
        isNull,
        reason:
            'Tiles given no subtitle must not render one — the '
            '`subtitle != null` guard must hold.',
      );
    });

    testWidgets('food title + subtitle localise to English', (tester) async {
      final en = AppLocalizationsEn();

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          wrapInScaffold: false,
          child: const SettingsHubView(),
        ),
      );
      await tester.pump();

      expect(
        find.text(en.allergenSettingsTitle),
        findsOneWidget,
        reason: 'English table must carry the relabelled title.',
      );
      expect(
        find.text(en.allergenSettingsHubSubtitle),
        findsOneWidget,
        reason:
            'English table must carry the new subtitle key — guards '
            'against a key added to one locale table but not the other.',
      );
    });
  });
}
