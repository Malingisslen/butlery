// Konto & app in Mer. The pages are routes behind sign-in, so
// `generateRoute` cannot build them in a test host without Firebase; the
// old about route is not auth-gated and is walked through the real
// AppRouter to Hjälp & om and on to the licences.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/more/help_area_view.dart';
import 'package:butlery/views/settings/licenses_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

class _MockReportService extends Mock implements ReportService {}

void main() {
  final sv = AppLocalizationsSv();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();

    final users = _MockUserService();
    when(() => users.currentUserProfile).thenReturn(null);
    when(() => users.addListener(any())).thenReturn(null);
    when(() => users.removeListener(any())).thenReturn(null);
    final reports = _MockReportService();
    when(
      () => reports.watchIsAdmin(),
    ).thenAnswer((_) => Stream<bool>.value(false));

    final container = DIContainer();
    container.container.registerSingleton<UserService>(users);
    container.container.registerSingleton<ReportService>(reports);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> open(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const SizedBox(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed(route);
    await tester.pumpAndSettle();
  }

  test('the pages under Konto & app are behind sign-in and slide in from '
      'the right', () {
    for (final route in [
      Routes.settings,
      Routes.settingsAccount,
      Routes.settingsPrivacy,
      Routes.settingsHelp,
    ]) {
      expect(Routes.isValidRoute(route), isTrue, reason: route);
      expect(Routes.requiresAuth(route), isTrue, reason: route);
      expect(
        Routes.getAnimationType(route),
        RouteAnimationType.slideFromRight,
        reason: route,
      );
    }
  });

  testWidgets('the old about route opens Hjälp & om', (tester) async {
    await open(tester, Routes.settingsAbout);

    expect(find.byType(HelpAreaView), findsOneWidget);
  });

  testWidgets(
    'the Licences row on Hjälp & om opens the licences, which lead back there',
    (
      tester,
    ) async {
      await open(tester, Routes.settingsAbout);

      await tester.tap(find.text(sv.settingsLicensesTitle));
      await tester.pumpAndSettle();

      expect(find.byType(LicensesView), findsOneWidget);
      expect(find.text(sv.licensesOflHeading), findsOneWidget);
      expect(
        find.byTooltip(sv.commonBackTo(sv.settingsHelpTitle)),
        findsOneWidget,
      );
    },
  );
}
