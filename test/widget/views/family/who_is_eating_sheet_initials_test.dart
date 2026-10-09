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
import 'package:butlery/views/family/who_is_eating_sheet.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

class _MockCookEventRepository extends Mock implements CookEventRepository {}

void main() {
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
          displayName: 'Maria Andersson',
          isMinor: false,
        ),
        HouseholdRosterMember(
          memberId: 'diner-1',
          type: HouseholdMemberType.profile,
          displayName: 'Mikael Ahl',
          isMinor: false,
        ),
        HouseholdRosterMember(
          memberId: 'diner-2',
          type: HouseholdMemberType.profile,
          displayName: 'Ester Berg',
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

  // BUT-2275 finding 3: avatars are worked out over the whole roster.
  testWidgets('members with the same initials get distinct avatars', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showWhoIsHomeSheet(
                context,
                slotLabel: 'lunch på måndag',
                seedMemberIds: const ['test-user-123', 'diner-1', 'diner-2'],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ma'), findsOneWidget);
    expect(find.text('Mi'), findsOneWidget);
    expect(find.text('EB'), findsOneWidget);
    expect(find.text('MA'), findsNothing);
  });
}
