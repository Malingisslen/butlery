/// BUT-1611 acceptance criterion 5: "kopiera veckan carries presence forward".
///
/// `copyWeek` runs through the auth-gated `executeServiceOperation`, so unlike
/// the targeted presence writers (which use the repository directly) it needs
/// the DI `ServiceLocator` initialized with an authenticated `AuthRepository`.
/// This isolated file wires that harness rather than bolting it onto the
/// raw-mock service suite.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

class _FakeWeeklyMenuPlan extends Fake implements WeeklyMenuPlan {}

UserProfile _profile(String uid) => UserProfile(
  uid: uid,
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
);

void main() {
  final mon = DateTime(2026, 4, 6);

  late _MockRepo repo;
  late _MockUserService userService;
  late WeeklyMenuPlanService service;

  setUpAll(() async {
    // Wires the PRODUCTION ServiceLocator, which executeServiceOperation's
    // auth check reads (not the injected repo).
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakeWeeklyMenuPlan());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    repo = _MockRepo();
    userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(_profile('u'));
    when(() => repo.save(any())).thenAnswer((_) async {});
    // executeServiceOperation checks ServiceLocator's AuthRepository.
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(
      repository: repo,
      userService: userService,
    );
  });

  test(
    'copyWeek carries the source week\'s presence into the new week',
    () async {
      final nextMon = mon.add(const Duration(days: 7));
      final source = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
        entries: [
          WeeklyMenuPlanEntry.create(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipeId: 'r1',
            recipeTitle: 'R1',
          ),
        ],
        presenceBySlot: {
          DayOfWeek.mon: {
            MealSlot.middag: ['m1'],
          },
        },
      );
      // copyWeek fetches the source week first, then the (empty) dest week.
      var fetchCall = 0;
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => fetchCall++ == 0 ? source : null);

      await service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon);

      final saved =
          verify(() => repo.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      expect(saved.presentMemberIdsFor(DayOfWeek.mon, MealSlot.middag), ['m1']);
    },
  );

  test(
    'on a (day, slot) both weeks hold, the destination selection wins',
    () async {
      final nextMon = mon.add(const Duration(days: 7));
      // BOTH weeks carry an explicit Monday-lunch selection — the copy must NOT
      // overwrite the destination's. This is the assertion that pins the
      // dest-wins branch of _mergePresenceForward; a source that only added
      // non-overlapping slots would pass even if dest-wins were deleted.
      final source = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
        entries: [
          WeeklyMenuPlanEntry.create(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipeId: 'r1',
            recipeTitle: 'R1',
          ),
        ],
        presenceBySlot: {
          DayOfWeek.mon: {
            MealSlot.lunch: ['m1'], // conflicts with dest's lunch
            MealSlot.middag: ['m1'], // dest lacks this → should copy in
          },
        },
      );
      final dest = WeeklyMenuPlan.empty(userId: 'u', date: nextMon).copyWith(
        presenceBySlot: {
          DayOfWeek.mon: {
            MealSlot.lunch: ['m9'],
          },
        },
      );
      var fetchCall = 0;
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => fetchCall++ == 0 ? source : dest);

      await service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon);

      final saved =
          verify(() => repo.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      // Overlapping slot: dest keeps its own selection.
      expect(saved.presentMemberIdsFor(DayOfWeek.mon, MealSlot.lunch), ['m9']);
      // Non-overlapping slot: source fills the gap.
      expect(saved.presentMemberIdsFor(DayOfWeek.mon, MealSlot.middag), ['m1']);
    },
  );

  test('presence-only source week (no menu yet) still carries forward', () async {
    // Acceptance criterion 5 edge: presence is set BEFORE any recipe is placed,
    // then the week is copied. The presence must survive even though the source
    // has zero entries.
    final nextMon = mon.add(const Duration(days: 7));
    final source = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
      presenceBySlot: {
        DayOfWeek.tue: {
          MealSlot.lunch: ['m1'],
        },
      },
    );
    var fetchCall = 0;
    when(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).thenAnswer((_) async => fetchCall++ == 0 ? source : null);

    await service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon);

    final saved =
        verify(() => repo.save(captureAny())).captured.single as WeeklyMenuPlan;
    expect(saved.presentMemberIdsFor(DayOfWeek.tue, MealSlot.lunch), ['m1']);
  });
}
