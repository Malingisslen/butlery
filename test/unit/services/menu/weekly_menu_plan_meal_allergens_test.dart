/// BUT-2362: the weekly plan's side of allergens per meal — who was marked
/// away is stored beside every presence selection and travels with it, and
/// placement only puts a dish where the caller's guard allows it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
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

Recipe _recipe(String title, {String mealType = 'middag'}) => Recipe.personal(
  title: title,
  description: '',
  ingredients: const [],
  instructions: const [],
  mealType: mealType,
);

void main() {
  // Monday of week 15, 2026.
  final mon = DateTime(2026, 4, 6);

  late _MockRepo repo;
  late WeeklyMenuPlanService service;

  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    registerFallbackValue(_FakeWeeklyMenuPlan());
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  setUp(() {
    repo = _MockRepo();
    final userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(_profile('u'));
    when(() => repo.save(any())).thenAnswer((_) async {});
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(repository: repo, userService: userService);
  });

  WeeklyMenuPlan empty() => WeeklyMenuPlan.empty(userId: 'u', date: mon);

  group('who was away is stored with the selection', () {
    test('a selection stores the rest of the roster as away', () {
      final plan = WeeklyMenuPlanService.withPresence(
        plan: empty(),
        day: DayOfWeek.tue,
        slots: kPresenceSlots,
        memberIds: ['mom'],
        awayMemberIds: ['kid'],
      );

      for (final slot in kPresenceSlots) {
        expect(plan.awayBySlot[DayOfWeek.tue]?[slot], ['kid']);
        expect(plan.allergenAwayIdsFor(DayOfWeek.tue, slot), {'kid'});
      }
    });

    test('clearing a selection clears its away list too', () {
      final set = WeeklyMenuPlanService.withPresence(
        plan: empty(),
        day: DayOfWeek.tue,
        slots: [MealSlot.middag],
        memberIds: ['mom'],
        awayMemberIds: ['kid'],
      );
      final cleared = WeeklyMenuPlanService.withPresence(
        plan: set,
        day: DayOfWeek.tue,
        slots: [MealSlot.middag],
        memberIds: null,
        awayMemberIds: ['kid'],
      );

      expect(cleared.awayBySlot, isEmpty);
      expect(cleared.presenceBySlot, isEmpty);
    });

    test('a new selection without anyone away drops the old away list', () {
      final set = WeeklyMenuPlanService.withPresence(
        plan: empty(),
        day: DayOfWeek.tue,
        slots: [MealSlot.middag],
        memberIds: ['mom'],
        awayMemberIds: ['kid'],
      );
      final next = WeeklyMenuPlanService.withPresence(
        plan: set,
        day: DayOfWeek.tue,
        slots: [MealSlot.middag],
        memberIds: ['mom', 'kid'],
      );

      expect(next.awayBySlot, isEmpty);
      expect(next.allergenAwayIdsFor(DayOfWeek.tue, MealSlot.middag), isEmpty);
    });

    test('copying a week brings the away list of every slot it fills, and '
        'keeps the destination\'s own', () async {
      final nextMon = mon.add(const Duration(days: 7));
      final source = WeeklyMenuPlanService.withPresence(
        plan: WeeklyMenuPlanService.withPresence(
          plan: empty(),
          day: DayOfWeek.tue,
          slots: [MealSlot.middag],
          memberIds: ['mom'],
          awayMemberIds: ['kid'],
        ),
        day: DayOfWeek.wed,
        slots: [MealSlot.middag],
        memberIds: ['mom'],
        awayMemberIds: ['kid'],
      );
      final dest = WeeklyMenuPlanService.withPresence(
        plan: WeeklyMenuPlan.empty(userId: 'u', date: nextMon),
        day: DayOfWeek.wed,
        slots: [MealSlot.middag],
        memberIds: ['kid'],
        awayMemberIds: ['mom'],
      );
      when(
        () => repo.fetchForWeek(
          userId: any(named: 'userId'),
          weekStart: any(named: 'weekStart'),
        ),
      ).thenAnswer(
        (inv) async => inv.namedArguments[#weekStart] == mon ? source : dest,
      );

      await service.copyWeek(fromWeekStart: mon, toWeekStart: nextMon);

      final saved =
          verify(() => repo.save(captureAny())).captured.single
              as WeeklyMenuPlan;
      expect(saved.awayBySlot[DayOfWeek.tue]?[MealSlot.middag], ['kid']);
      expect(saved.awayBySlot[DayOfWeek.wed]?[MealSlot.middag], ['mom']);
    });
  });

  group('distributeFromGeneratedMenu with an allergen guard', () {
    // Nuts may only go where the kid is away: Thursday middag.
    bool onlyThursday(Recipe recipe, DayOfWeek day, MealSlot slot) =>
        !recipe.title.startsWith('nut') ||
        (day == DayOfWeek.thu && slot == MealSlot.middag);

    test('a dish skips the free days it is refused on and takes the first '
        'one it is allowed on', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('nut stew'), _recipe('soup')],
        },
        weekStart: mon,
        existing: empty(),
        now: mon,
        allowedAt: onlyThursday,
      );

      final byTitle = {
        for (final e in result.plan.entries) e.recipeTitle: e.day,
      };
      expect(byTitle['nut stew'], DayOfWeek.thu);
      expect(byTitle['soup'], DayOfWeek.mon);
      expect(result.overflow, isEmpty);
    });

    test('a dish no free day allows goes to the tray, and the tray says it '
        'stayed out for allergens', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('nut stew'), _recipe('nut pie')],
        },
        weekStart: mon,
        existing: empty(),
        now: mon,
        allowedAt: onlyThursday,
      );

      expect(result.plan.entries.map((e) => e.recipeTitle), ['nut stew']);
      expect(result.overflow.map((r) => r.title), ['nut pie']);
      expect(result.overflowReason?.allergenBlocked, isTrue);
    });

    test('a full week is not reported as an allergen block', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [for (var i = 0; i < 8; i++) _recipe('soup $i')],
        },
        weekStart: mon,
        existing: empty(),
        now: mon,
        allowedAt: onlyThursday,
      );

      expect(result.overflow, hasLength(1));
      expect(result.overflowReason?.allergenBlocked, isFalse);
    });

    test('an övrigt dish the guard refuses goes to the tray and frees its '
        'day for the next one', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'mellanmål': [
            _recipe('nut bar', mealType: 'mellanmål'),
            _recipe('fruit', mealType: 'mellanmål'),
          ],
        },
        weekStart: mon,
        existing: empty(),
        now: mon,
        allowedAt: (recipe, day, slot) => !recipe.title.startsWith('nut'),
      );

      expect(result.plan.entries.single.recipeTitle, 'fruit');
      expect(result.plan.entries.single.day, DayOfWeek.mon);
      expect(result.overflow.single.title, 'nut bar');
      expect(result.overflowReason?.allergenBlocked, isTrue);
    });

    test('a day pin the guard refuses is skipped, and the dish falls through '
        'to a day it is allowed on', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('nut stew')],
        },
        weekStart: mon,
        existing: empty(),
        now: mon,
        dayPins: const [
          DayPin(
            weekdayIndex: 5,
            mealType: 'middag',
            constraint: RecipeConstraint(count: 1),
          ),
        ],
        allowedAt: onlyThursday,
      );

      expect(result.plan.entries.single.day, DayOfWeek.thu);
    });

    test('without a guard placement is as before', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('nut stew')],
        },
        weekStart: mon,
        existing: empty(),
        now: mon,
      );

      expect(result.plan.entries.single.day, DayOfWeek.mon);
    });
  });

  test('the tray keeps "stayed out for allergens" when it is stored and when '
      'it moves on a week', () {
    final reason = WeeklyMenuOverflowReason(
      weekStart: mon,
      allergenBlocked: true,
    );

    expect(
      WeeklyMenuOverflowReason.fromJson(reason.toJson())?.allergenBlocked,
      isTrue,
    );
    expect(reason.copyWith(nextWeekOffered: false).allergenBlocked, isTrue);
    expect(reason, isNot(WeeklyMenuOverflowReason(weekStart: mon)));
  });
}
