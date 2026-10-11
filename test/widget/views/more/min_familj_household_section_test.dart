/// "Familj & hushåll" carries the household settings that used to sit in
/// Inställningar: the default-portions row always, and the allergen switches
/// only for a user who has a household. Drives the real view; the roster,
/// the diner repository and the household service are stubbed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/family/household_portions_sheet.dart';
import 'package:butlery/views/family/min_familj_view.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../views/helpers/view_test_helpers.dart';

class _MockRoster extends Mock implements HouseholdRosterService {}

class _MockHouseholdService extends Mock implements HouseholdService {}

class _FakeImagePickerService extends Fake implements ImagePickerService {}

class _FakeImageUploadService extends Fake implements ImageUploadService {}

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

  Future<void> pump(WidgetTester tester, {required bool hasHousehold}) async {
    final household = _MockHouseholdService();
    when(() => household.hasHousehold).thenReturn(hasHousehold);
    TestServiceLocator.registerSingleton<HouseholdService>(household);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const MinFamiljView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the portions row sits under Måltider and opens its sheet', (
    tester,
  ) async {
    await pump(tester, hasHousehold: false);

    expect(
      find.text(sv.familyMealsSection.toUpperCase()),
      findsOneWidget,
      reason: 'the row sits under its own overline',
    );
    final row = find.widgetWithText(ButleryListRow, sv.householdPortionsTitle);
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text(sv.householdSizeRecipeDefault),
      ),
      findsOneWidget,
      reason: 'an unset profile reads as the recipe default',
    );

    TestServiceLocator.registerFactory<UserProfileViewModel>(
      () => UserProfileViewModel(
        TestServiceLocator.get<UserService>(),
        _FakeImagePickerService(),
        uploadService: _FakeImageUploadService(),
      ),
    );
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdPortionsSheet), findsOneWidget);
  });

  testWidgets('a user with a household sees the allergen switches as rows', (
    tester,
  ) async {
    await pump(tester, hasHousehold: true);

    expect(
      find.text(sv.familyAllergiesSection.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ButleryListRow, sv.householdAllergenFilterTitle),
      findsOneWidget,
    );
  });

  testWidgets('a user without a household sees no allergen section but keeps '
      'the portions row', (tester) async {
    await pump(tester, hasHousehold: false);

    expect(find.text(sv.householdPortionsTitle), findsOneWidget);
    expect(find.text(sv.familyAllergiesSection.toUpperCase()), findsNothing);
    expect(find.text(sv.householdAllergenFilterTitle), findsNothing);
  });

  testWidgets('the add row opens the new-member form', (tester) async {
    await pump(tester, hasHousehold: false);

    expect(find.text(sv.familyProfilesSection.toUpperCase()), findsOneWidget);
    final add = find.widgetWithText(ButleryListRow, sv.familyAddMemberRow);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.text(sv.familyAddMemberRow), findsNothing);
  });
}
