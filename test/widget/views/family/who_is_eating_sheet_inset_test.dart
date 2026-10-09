import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart' as prod_di;
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/family/who_is_eating_sheet.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockCookEventRepository extends Mock implements CookEventRepository {}

// Mirrors FeedbackFAB's right offset; the FAB is positioned from the right.
const double _feedbackFabRightOffset = 16;

void main() {
  const surface = Size(420, 900);

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();

    final householdRepo = _MockHouseholdRepository();
    when(
      () => householdRepo.getActiveForUser(any()),
    ).thenAnswer((_) async => Household.create(creatorId: 'test-user-123'));
    TestServiceLocator.registerSingleton<HouseholdRepository>(householdRepo);

    final rosterService = _MockHouseholdRosterService();
    when(() => rosterService.getRoster(any())).thenAnswer(
      (_) async => const [
        HouseholdRosterMember(
          memberId: 'test-user-123',
          type: HouseholdMemberType.user,
          displayName: 'Malin',
          isMinor: false,
        ),
        HouseholdRosterMember(
          memberId: 'diner-1',
          type: HouseholdMemberType.profile,
          displayName: 'Ester',
          isMinor: true,
        ),
      ],
    );
    TestServiceLocator.registerSingleton<HouseholdRosterService>(rosterService);
    TestServiceLocator.registerSingleton<CookEventRepository>(
      _MockCookEventRepository(),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_di.ServiceLocator.reset();
  });

  testWidgets('roster checkboxes stay left of the feedback button', (
    tester,
  ) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showWhoIsHomeSheet(
                context,
                slotLabel: 'lunch på måndag',
                seedMemberIds: const ['test-user-123', 'diner-1'],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final checkBoxes = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_CheckBox',
    );
    expect(
      checkBoxes.evaluate().length,
      greaterThanOrEqualTo(2),
      reason: 'the sheet must list the roster or the test proves nothing',
    );

    final feedbackButtonLeft =
        surface.width - _feedbackFabRightOffset - AppDimensions.minTouchTarget;
    for (final element in checkBoxes.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      expect(
        rect.right,
        lessThanOrEqualTo(feedbackButtonLeft),
        reason: 'a checkbox under the feedback button cannot be tapped',
      );
    }
  });
}
