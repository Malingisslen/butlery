// BUT-1340 (SET-01): Widget gate for the Settings hub account/legal/notification
// tiles + the admin-only moderator tile guard.
//
// These tests prove the live wiring of SettingsHubView's non-food entries:
//   - account-security, logout, delete-account, notification and
//     terms-of-service tiles all render with their localized titles;
//   - the moderator-review tile is HIDDEN for a non-admin user (the
//     StreamBuilder on `watchIsAdmin()` collapses to SizedBox.shrink), so a
//     regression that leaks the admin entry to ordinary users is caught;
//   - the delete-account tile is rendered in the error colour (the destructive
//     variant), proving the irreversibility is flagged before the confirm
//     dialog — asserted against the LIVE theme, not a hardcoded colour.
//
// Harness mirrors settings_hub_food_tile_test.dart (the working sibling):
// a DIContainer with stubbed ReportService + LocaleProvider. It ALSO registers
// a UserService because the embedded AutoAddPantryTile (BUT-1306) resolves it
// in initState — without it the whole ListView throws and every assertion
// fails (this is exactly the stale-harness trap a prior attempt hit).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/settings_hub_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockReportService extends Mock implements ReportService {}

void main() {
  group('SettingsHubView account/legal tiles (BUT-1340 SET-01)', () {
    late _MockReportService reportService;

    Future<void> pumpHub(WidgetTester tester, {required bool isAdmin}) async {
      when(() => reportService.watchIsAdmin())
          .thenAnswer((_) => Stream<bool>.value(isAdmin));

      // Tall surface so the whole settings ListView lays out without the
      // off-screen culling that would hide the bottom (terms/moderator) tiles.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createLocalizedTestApp(
        wrapInScaffold: false, // SettingsHubView supplies its own Scaffold.
        child: const SettingsHubView(),
      ));
      // Let the watchIsAdmin StreamBuilder resolve its first event.
      await tester.pump();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await GetIt.instance.reset();
      ServiceLocator.reset();

      reportService = _MockReportService();

      final container = DIContainer();
      container.container.registerSingleton<ReportService>(reportService);
      // LanguageTile resolves LocaleProvider from DI in initState.
      container.container.registerSingleton<LocaleProvider>(LocaleProvider());
      // AutoAddPantryTile (BUT-1306) resolves UserService in initState; the
      // unstubbed mock returns a null profile so the switch reads `false`.
      container.container.registerSingleton<UserService>(MockUserService());
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('account, notification, logout, delete and terms tiles render',
        (tester) async {
      final sv = AppLocalizationsSv();
      await pumpHub(tester, isAdmin: false);

      expect(find.text(sv.accountSecurityTitle), findsOneWidget,
          reason: 'Account-security entry must be present in /settings.');
      // "Aviseringar" appears both as the section header AND the tile title
      // (settingsSectionNotifications == notificationTitle), so the tile is
      // asserted via its ListTile ancestor to prove it's a tappable entry.
      final notificationTile = find.ancestor(
        of: find.text(sv.notificationTitle),
        matching: find.byType(ListTile),
      );
      expect(notificationTile, findsOneWidget,
          reason: 'Notification settings entry must be a tappable tile.');
      expect(find.text(sv.profileLogout), findsOneWidget,
          reason: 'GDPR sign-out surface must be discoverable from /settings.');
      expect(find.text(sv.profileDeleteAccount), findsOneWidget,
          reason: 'GDPR delete-account surface must be discoverable.');
      expect(find.text(sv.legalTermsOfService), findsOneWidget,
          reason: 'Terms-of-service entry must be present in the About group.');
    });

    testWidgets('moderator tile is hidden for a non-admin user',
        (tester) async {
      final sv = AppLocalizationsSv();
      await pumpHub(tester, isAdmin: false);

      expect(find.text(sv.moderatorReviewTitle), findsNothing,
          reason: 'The admin-only moderator entry must NOT leak to ordinary '
              'users — the watchIsAdmin StreamBuilder must collapse it.');
    });

    testWidgets('moderator tile appears for an admin user', (tester) async {
      final sv = AppLocalizationsSv();
      await pumpHub(tester, isAdmin: true);

      expect(find.text(sv.moderatorReviewTitle), findsOneWidget,
          reason: 'An admin user must see the moderator-review entry once '
              'watchIsAdmin emits true.');
    });

    testWidgets('delete-account tile is flagged in the live error colour',
        (tester) async {
      final sv = AppLocalizationsSv();
      late ColorScheme cs;

      when(() => reportService.watchIsAdmin())
          .thenAnswer((_) => Stream<bool>.value(false));

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(builder: (context) {
          cs = Theme.of(context).colorScheme;
          return const SettingsHubView();
        }),
      ));
      await tester.pump();

      // The destructive variant renders its title text in cs.error — assert
      // against the live ColorScheme so a theme tweak doesn't break the test,
      // but a regression dropping the destructive styling does.
      final titleText = tester.widget<Text>(
        find.text(sv.profileDeleteAccount),
      );
      expect(titleText.style?.color, cs.error,
          reason: 'Delete-account must use the theme error colour to flag '
              'irreversibility before the confirm dialog opens.');
    });
  });
}
