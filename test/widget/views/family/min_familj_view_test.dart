/// "Min familj" shows account holders and family members in two sections but
/// tells people apart across both: two people who would otherwise share
/// initials get different avatars even when one is an account and the other a
/// family member. Drives the real view and ViewModel; only the repositories
/// and the roster service behind them are stubbed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/views/family/min_familj_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../views/helpers/view_test_helpers.dart';

class _MockRoster extends Mock implements HouseholdRosterService {}

class _MockDinerRepo extends Mock implements DinerProfileRepository {}

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  testWidgets('an account and a family member with the same initials get '
      'different avatars', (tester) async {
    final roster = _MockRoster();
    when(() => roster.getRoster(any())).thenAnswer(
      (_) async => [
        HouseholdRosterMember.fromUser(userId: 'u1', displayName: 'Test 16'),
      ],
    );
    final dinerRepo = _MockDinerRepo();
    when(() => dinerRepo.getByHousehold(any())).thenAnswer(
      (_) async => [
        DinerProfile.create(
          householdId: 'hh-1',
          name: 'Test 17',
          ageBand: DinerAgeBand.child,
          createdBy: 'u1',
        ),
      ],
    );
    TestServiceLocator.registerSingleton<HouseholdRosterService>(roster);
    TestServiceLocator.registerSingleton<DinerProfileRepository>(dinerRepo);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const MinFamiljView(),
      ),
    );
    await tester.pumpAndSettle();

    // Account row and family row each show their own distinct chip.
    expect(find.text('Test 16'), findsOneWidget);
    expect(find.text('Test 17'), findsOneWidget);
    expect(find.text('T6'), findsOneWidget);
    expect(find.text('T7'), findsOneWidget);
    expect(find.text('T1'), findsNothing);
  });
}
