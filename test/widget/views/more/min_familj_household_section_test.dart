/// "Familj & hushåll" carries the household settings that used to sit in
/// Inställningar: the household-size row always, and the allergen switches
/// only for a user who has a household. Drives the real view; the roster,
/// the diner repository and the household service are stubbed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/views/family/min_familj_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../views/helpers/view_test_helpers.dart';

class _MockRoster extends Mock implements HouseholdRosterService {}

class _MockHouseholdService extends Mock implements HouseholdService {}

void main() {
  final sv = AppLocalizationsSv();

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    final roster = _MockRoster();
    when(() => roster.getRoster(any())).thenAnswer((_) async => const []);
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Future<List<String?>> pump(
    WidgetTester tester, {
    required bool hasHousehold,
  }) async {
    final household = _MockHouseholdService();
    when(() => household.hasHousehold).thenReturn(hasHousehold);
    TestServiceLocator.registerSingleton<HouseholdService>(household);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pushed = <String?>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const MinFamiljView(),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    return pushed;
  }

  testWidgets('the household-size row opens the household-size route', (
    tester,
  ) async {
    final pushed = await pump(tester, hasHousehold: false);

    final row = find.text(sv.settingsHouseholdSizeTitle);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(
      find.text(sv.moreHouseholdSection.toUpperCase()),
      findsOneWidget,
      reason: 'the row sits under its own overline',
    );
    pushed.clear();

    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(pushed, [Routes.settingsHousehold]);
  });

  testWidgets('a user with a household sees the allergen switches', (
    tester,
  ) async {
    await pump(tester, hasHousehold: true);

    expect(find.text(sv.householdAllergenFilterTitle), findsOneWidget);
  });

  testWidgets('a user without a household sees no allergen switch but keeps '
      'the size row', (tester) async {
    await pump(tester, hasHousehold: false);

    expect(find.text(sv.settingsHouseholdSizeTitle), findsOneWidget);
    expect(find.text(sv.householdAllergenFilterTitle), findsNothing);
  });
}
