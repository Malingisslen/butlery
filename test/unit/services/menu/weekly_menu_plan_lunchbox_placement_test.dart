/// BUT-2486: a lunchbox IS that day's lunch, so no placement path may put a
/// lunch dish on a day that has one — the calendar draws only the box there,
/// and a dish under it would be planned, shopped for and checked unseen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/week_template_apply.dart';
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

Recipe _recipe(String id) => Recipe(
  core: RecipeCore(
    id: id,
    title: id,
    description: '',
    ingredients: const ['x'],
    instructions: const ['y'],
    mealType: 'Lunch',
  ),
  type: RecipeType.personal,
);

WeeklyMenuPlanEntry _entry(DayOfWeek day, MealSlot slot, String id) =>
    WeeklyMenuPlanEntry.create(
      day: day,
      slot: slot,
      recipeId: id,
      recipeTitle: id,
    );

/// The lunch dishes [plan] holds on a day that also has a lunchbox.
List<WeeklyMenuPlanEntry> _hidden(WeeklyMenuPlan plan) => [
  for (final e in plan.entries)
    if (e.slot == MealSlot.lunch && plan.lunchboxes.containsKey(e.day)) e,
];

void main() {
  final mon = DateTime(2026, 4, 6);
  final nextMon = mon.add(const Duration(days: 7));

  late _MockRepo repo;
  late _MockUserService userService;
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
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'u');
    service = WeeklyMenuPlanService(repository: repo, userService: userService);
  });

  void stubWeek(DateTime weekStart, WeeklyMenuPlan? plan) {
    when(
      () => repo.fetchForWeek(userId: 'u', weekStart: weekStart),
    ).thenAnswer((_) async => plan);
  }

  WeeklyMenuPlan boxedWeek({
    DateTime? date,
    List<WeeklyMenuPlanEntry> entries = const [],
    Set<DayOfWeek> boxDays = const {DayOfWeek.mon},
  }) => WeeklyMenuPlan.empty(userId: 'u', date: date ?? mon).copyWith(
    entries: entries,
    lunchboxes: {for (final d in boxDays) d: _box},
  );

  WeeklyMenuPlan savedPlan() =>
      verify(() => repo.save(captureAny())).captured.single as WeeklyMenuPlan;

  test('a lunchbox makes its day\'s lunch occupied, and only the lunch', () {
    final week = boxedWeek();

    expect(week.isOccupied(DayOfWeek.mon, MealSlot.lunch), isTrue);
    expect(week.isOccupied(DayOfWeek.mon, MealSlot.middag), isFalse);
    expect(week.isOccupied(DayOfWeek.tue, MealSlot.lunch), isFalse);
  });

  group('addEntry', () {
    test('refuses a lunch dish on a box day and keeps the box', () {
      final week = boxedWeek();

      final result = service.addEntry(
        plan: week,
        day: DayOfWeek.mon,
        slot: MealSlot.lunch,
        recipe: _recipe('soup'),
      );

      expect(result, same(week));
    });

    test('still places the box day\'s middag', () {
      final week = boxedWeek();

      final result = service.addEntry(
        plan: week,
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipe: _recipe('stew'),
      );

      expect(result.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeId, 'stew');
      expect(result.lunchboxes.keys, [DayOfWeek.mon]);
    });
  });

  group('moving', () {
    test('moveEntry onto a box day\'s lunch is a no-op', () {
      final dish = _entry(DayOfWeek.tue, MealSlot.lunch, 'soup');
      final week = boxedWeek(entries: [dish]);

      final result = service.moveEntry(
        plan: week,
        entryId: dish.id,
        toDay: DayOfWeek.mon,
        toSlot: MealSlot.lunch,
      );

      expect(result, same(week));
    });

    test('bulkMoveEntries onto a box day\'s lunch moves nothing and saves '
        'nothing', () async {
      final a = _entry(DayOfWeek.tue, MealSlot.middag, 'a');
      final b = _entry(DayOfWeek.wed, MealSlot.ovrigt, 'b');
      stubWeek(mon, boxedWeek(entries: [a, b]));

      final moved = await service.bulkMoveEntries(
        weekStart: mon,
        entryIds: [a.id, b.id],
        toDay: DayOfWeek.mon,
        toSlot: MealSlot.lunch,
      );

      expect(moved, 0);
      verifyNever(() => repo.save(any()));
    });
  });

  test('bulkAssignRecipes skips a box day like an occupied one', () async {
    stubWeek(mon, boxedWeek());

    final result = await service.bulkAssignRecipes(
      weekStart: mon,
      startDay: DayOfWeek.mon,
      slot: MealSlot.lunch,
      recipes: [_recipe('soup')],
    );

    expect(result.added, 1);
    final saved = savedPlan();
    expect(_hidden(saved), isEmpty);
    expect(saved.entryAt(DayOfWeek.tue, MealSlot.lunch)?.recipeId, 'soup');
  });

  test('assignRecipeToTargets counts and saves only the targets that '
      'landed', () async {
    stubWeek(mon, boxedWeek());

    final placed = await service.assignRecipeToTargets(
      weekStart: mon,
      recipe: _recipe('soup'),
      targets: const [
        (day: DayOfWeek.mon, slot: MealSlot.lunch),
        (day: DayOfWeek.tue, slot: MealSlot.lunch),
      ],
    );

    expect(placed, 1);
    final saved = savedPlan();
    expect(_hidden(saved), isEmpty);
    expect(saved.lunchboxes.keys, [DayOfWeek.mon]);
  });

  test('assignRecipeToTargets with only a box day saves nothing', () async {
    stubWeek(mon, boxedWeek());

    final placed = await service.assignRecipeToTargets(
      weekStart: mon,
      recipe: _recipe('soup'),
      targets: const [(day: DayOfWeek.mon, slot: MealSlot.lunch)],
    );

    expect(placed, 0);
    verifyNever(() => repo.save(any()));
  });

  group('distributeFromGeneratedMenu', () {
    test('a generated lunch skips the box day', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'lunch': [_recipe('soup')],
        },
        weekStart: mon,
        existing: boxedWeek(),
        now: mon,
      );

      expect(_hidden(result.plan), isEmpty);
      expect(
        result.plan.entryAt(DayOfWeek.tue, MealSlot.lunch)?.recipeId,
        'soup',
      );
    });

    test('a lunch pin on a box day falls through to a free day', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'lunch': [_recipe('soup')],
        },
        weekStart: mon,
        existing: boxedWeek(),
        now: mon,
        dayPins: const [
          DayPin(
            weekdayIndex: 1,
            mealType: 'lunch',
            constraint: RecipeConstraint(count: 1),
          ),
        ],
      );

      expect(_hidden(result.plan), isEmpty);
      expect(
        result.plan.entryAt(DayOfWeek.tue, MealSlot.lunch)?.recipeId,
        'soup',
      );
    });

    test('a week whose free lunches are all boxes overflows without '
        'blaming allergens', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'lunch': [_recipe('soup')],
        },
        weekStart: mon,
        existing: boxedWeek(boxDays: DayOfWeek.values.toSet()),
        now: mon,
      );

      expect(_hidden(result.plan), isEmpty);
      expect(result.overflow.map((r) => r.id), ['soup']);
      expect(result.overflowReason?.allergenBlocked, isFalse);
    });
  });

  test('copyWeek does not copy a lunch onto a destination box day', () async {
    stubWeek(
      mon,
      WeeklyMenuPlan.empty(userId: 'u', date: mon).copyWith(
        entries: [
          _entry(DayOfWeek.mon, MealSlot.lunch, 'soup'),
          _entry(DayOfWeek.mon, MealSlot.middag, 'stew'),
        ],
      ),
    );
    stubWeek(nextMon, boxedWeek(date: nextMon));

    final copied = await service.copyWeek(
      fromWeekStart: mon,
      toWeekStart: nextMon,
    );

    expect(copied, 1);
    final saved = savedPlan();
    expect(_hidden(saved), isEmpty);
    expect(saved.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeId, 'stew');
  });

  group('WeekTemplateApply', () {
    TemplateDish lunchDish(String id) => TemplateDish(
      entry: WeekTemplateEntry(
        day: DayOfWeek.mon,
        slot: MealSlot.lunch,
        recipeId: id,
        recipeTitle: id,
      ),
      state: TemplateDishState.unverified,
    );

    for (final mode in WeekTemplateApplyMode.values) {
      test('${mode.name} leaves a box day\'s lunch to the box', () {
        final result = WeekTemplateApply.apply(
          plan: boxedWeek(),
          dishes: [lunchDish('soup')],
          mode: mode,
        );

        expect(_hidden(result.plan), isEmpty);
        expect(result.addedEntryIds, isEmpty);
      });
    }

    test('undo does not return a replaced lunch under a box set since', () {
      final replaced = _entry(DayOfWeek.mon, MealSlot.lunch, 'old');
      final before = WeeklyMenuPlan.empty(
        userId: 'u',
        date: mon,
      ).copyWith(entries: [replaced]);
      final applied = WeekTemplateApply.apply(
        plan: before,
        dishes: [lunchDish('new')],
        mode: WeekTemplateApplyMode.replace,
      );
      final boxedSince = applied.plan.withLunchbox(DayOfWeek.mon, _box);

      final undone = WeekTemplateApply.undo(boxedSince, applied);

      expect(_hidden(undone), isEmpty);
      expect(undone.lunchboxes.keys, [DayOfWeek.mon]);
    });
  });
}
