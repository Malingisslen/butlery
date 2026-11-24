/// BUT-2486 del 3: "Rensa veckan" and "Kopiera till nästa vecka" count only
/// dishes and presence, as before lunchboxes existed. A week holding only
/// boxes has nothing to clear or copy, and boxes never travel to another
/// week (a box's leftovers belong to the week it was planned in).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
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

const _box = Lunchbox(
  source: LunchboxSource.prepDay,
  recipeId: 'chili',
  recipeTitle: 'Chili',
);

void main() {
  final mon = DateTime(2026, 4, 6);
  final nextMon = mon.add(const Duration(days: 7));

  late _MockRepo repo;
  late _MockUserService userService;
  late WeeklyMenuPlanService service;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakeWeeklyMenuPlan());
    registerFallbackValue(<MealBoxTake>[]);
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    repo = _MockRepo();
    userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(
      UserProfile(
        uid: 'u',
        displayName: 'Test',
        email: 't@example.com',
        joinedAt: DateTime(2026, 1, 1),
        lastActiveAt: DateTime(2026, 1, 1),
      ),
    );
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(
      () => repo.saveWithMealBoxTakes(any(), any()),
    ).thenAnswer((_) async {});
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(repository: repo, userService: userService);
  });

  void stubWeek(DateTime weekStart, WeeklyMenuPlan? plan) {
    when(
      () => repo.fetchForWeek(userId: 'u', weekStart: weekStart),
    ).thenAnswer((_) async => plan);
  }

  WeeklyMenuPlanEntry dish(DayOfWeek day) => WeeklyMenuPlanEntry.create(
    day: day,
    slot: MealSlot.middag,
    recipeId: 'stew',
    recipeTitle: 'Gryta',
  );

  group('clearWeek', () {
    test('a week with only boxes is returned as it is', () {
      final week = WeeklyMenuPlan.empty(
        userId: 'u',
        date: mon,
      ).copyWith(lunchboxes: {DayOfWeek.tue: _box});

      expect(week.isEmpty, isTrue);
      expect(service.clearWeek(week), same(week));
    });

    test('clears the dishes and leaves the boxes', () {
      final week = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
        entries: [dish(DayOfWeek.mon)],
        lunchboxes: {DayOfWeek.tue: _box},
      );

      final cleared = service.clearWeek(week);

      expect(cleared.entries, isEmpty);
      expect(cleared.lunchboxes.keys, [DayOfWeek.tue]);
    });
  });

  group('copyWeek', () {
    test('a source week with only boxes copies nothing and reads no '
        'destination', () async {
      stubWeek(
        mon,
        WeeklyMenuPlan.empty(
          userId: 'u',
          date: mon,
        ).copyWith(lunchboxes: {DayOfWeek.tue: _box}),
      );

      expect(
        await service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon),
        0,
      );
      verifyNever(() => repo.fetchForWeek(userId: 'u', weekStart: nextMon));
      verifyNever(() => repo.save(any()));
    });

    test('copies the dishes but not the boxes, and keeps the destination\'s '
        'own boxes', () async {
      stubWeek(
        mon,
        WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
          entries: [dish(DayOfWeek.mon)],
          lunchboxes: {DayOfWeek.tue: _box},
        ),
      );
      stubWeek(
        nextMon,
        WeeklyMenuPlan.empty(
          userId: 'u',
          date: nextMon,
        ).copyWith(lunchboxes: {DayOfWeek.fri: _box}),
      );

      expect(
        await service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon),
        1,
      );

      final saved =
          verify(() => repo.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      expect(saved.entries, hasLength(1));
      expect(saved.lunchboxes.keys, [DayOfWeek.fri]);
    });
  });

  group('saveRevision and fridge boxes (BUT-2486 part 5)', () {
    final stockBox = MealBox(
      id: 'box1',
      recipeId: 'chili',
      recipeTitle: 'Chili',
      location: MealBoxLocation.fridge,
      storedOn: DateTime(2026, 4, 1),
      count: 3,
    );

    test('a stock lunch added since previous saves with one take and not '
        'through save', () async {
      final previous = WeeklyMenuPlan.empty(userId: 'u', date: mon);
      final plan = previous.copyWith(
        lunchboxes: {DayOfWeek.tue: Lunchbox.fromStock(stockBox, portions: 2)},
      );

      await service.saveRevision(plan, previous: previous);

      final captured =
          verify(
                () => repo.saveWithMealBoxTakes(plan, captureAny()),
              ).captured.single
              as List<MealBoxTake>;
      expect(captured, hasLength(1));
      expect(captured.single.boxId, 'box1');
      expect(captured.single.key, '2026-04-07');
      expect(captured.single.portions, 2);
      verifyNever(() => repo.save(any()));
    });

    test(
      'without previous nothing is compared, even with a stock lunch',
      () async {
        final plan = WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
          lunchboxes: {DayOfWeek.tue: Lunchbox.fromStock(stockBox)},
        );

        await service.saveRevision(plan);

        verify(() => repo.save(plan)).called(1);
        verifyNever(() => repo.saveWithMealBoxTakes(any(), any()));
      },
    );

    test('with previous but no stock change it saves the plain way', () async {
      final previous = WeeklyMenuPlan.empty(
        userId: 'u',
        date: mon,
      ).copyWith(lunchboxes: {DayOfWeek.tue: Lunchbox.fromStock(stockBox)});
      final plan = previous.copyWith(
        lunchboxes: {...previous.lunchboxes, DayOfWeek.wed: _box},
      );

      await service.saveRevision(plan, previous: previous);

      verify(() => repo.save(plan)).called(1);
      verifyNever(() => repo.saveWithMealBoxTakes(any(), any()));
    });
  });
}
