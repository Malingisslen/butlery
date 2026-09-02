/// BUT-1611 acceptance criterion 5: "kopiera veckan carries presence forward".
///
/// This isolated file wires a DI `ServiceLocator` harness with an authenticated
/// `AuthRepository`, rather than bolting it onto the raw-mock service suite.
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
    // Wires the PRODUCTION ServiceLocator (not the injected repo).
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
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(
      repository: repo,
      userService: userService,
    );
  });

  // BUT-1962: `copyWeek` kept its save INSIDE `executeServiceOperation` after
  // the other writes were moved out, so a refused copy came back as 0 — which
  // the UI renders as "everything was already there".
  test(
    'copyWeek propagates a refusal rather than reporting 0 copied',
    () async {
      final nextMon = mon.add(const Duration(days: 7));
      final source = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
        entries: [
          WeeklyMenuPlanEntry.create(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipeId: 'r-copy',
            recipeTitle: 'Tacos',
          ),
        ],
      );
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer(
        (inv) async => inv.namedArguments[#weekStart] == mon ? source : null,
      );
      when(
        () => repo.save(any()),
      ).thenThrow(StateError('refused by the repository'));

      await expectLater(
        () => service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon),
        throwsA(isA<StateError>()),
      );
    },
  );

  // BUT-1972: the two READS were still inside `executeServiceOperation`, which
  // turns a throw into `null` — `copyWeek` then returned 0 and the view showed
  // "Inget kopierades – allt finns redan nästa vecka", a success message for a
  // week that was never read. The two reads are separate seams: the source read
  // decides whether there is anything to copy at all, the destination read
  // decides what is already there, and only the second one runs with a plan in
  // hand. A hoist that only moved the first would leave the second swallowing.
  test('a throwing SOURCE-week read reaches the caller', () async {
    final nextMon = mon.add(const Duration(days: 7));
    when(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).thenAnswer((_) async => throw StateError('source read refused'));

    await expectLater(
      () => service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon),
      throwsA(isA<StateError>()),
    );
    verifyNever(() => repo.save(any()));
  });

  test('a throwing DESTINATION-week read reaches the caller', () async {
    final nextMon = mon.add(const Duration(days: 7));
    final source = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
      entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'r-copy',
          recipeTitle: 'Tacos',
        ),
      ],
    );
    // The SOURCE read succeeds; only the destination read throws.
    when(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).thenAnswer((inv) async {
      if (inv.namedArguments[#weekStart] == mon) return source;
      throw StateError('destination read refused');
    });

    await expectLater(
      () => service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon),
      throwsA(isA<StateError>()),
    );
    verifyNever(() => repo.save(any()));
  });

  // The ORDERING pin. An EMPTY source week short-circuits before the
  // destination is read at all, so a destination read that would throw is never
  // reached and the honest answer — 0, "inget att kopiera" — survives.
  //
  // Without it the emptiness check can drift below the destination fetch (it
  // did, during BUT-1972's hoist, and the `integration-reviewer` and
  // `code-reviewer` gates both caught it): the user then gets an ERROR for a
  // cleared week, which is the inverse of the defect BUT-1972 exists to fix.
  // The throw tests above cannot see that — their source week has entries, so
  // they reach the destination read either way.
  test('an EMPTY source week never reads the destination', () async {
    final nextMon = mon.add(const Duration(days: 7));
    final emptySource = WeeklyMenuPlan.empty(userId: 'u', date: mon);
    when(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).thenAnswer((inv) async {
      if (inv.namedArguments[#weekStart] == mon) return emptySource;
      throw StateError('destination read must never be reached');
    });

    final copied = await service.copyWeek(
      fromWeekStart: mon,
      toWeekStart: nextMon,
    );

    expect(copied, 0);
    verifyNever(() => repo.save(any()));
    // The destination fetch is the thing under test: exactly one read.
    verify(
      () => repo.fetchForWeek(
        userId: any(named: 'userId'),
        weekStart: any(named: 'weekStart'),
      ),
    ).called(1);
  });

  // The control that must not regress (BUT-1961): offline, `fetchForWeek`
  // passes `acceptCachedAbsence`, so a `null` source week is a TRUE "nothing to
  // copy" — it must keep returning 0 and its success message, not throw.
  test(
    'a source week that reads as null still returns 0 and does not throw',
    () async {
      final nextMon = mon.add(const Duration(days: 7));
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer((_) async => null);

      final copied = await service.copyWeek(
        fromWeekStart: mon,
        toWeekStart: nextMon,
      );

      expect(copied, 0);
      verifyNever(() => repo.save(any()));
    },
  );

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
