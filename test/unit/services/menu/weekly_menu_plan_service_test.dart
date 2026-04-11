import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

Recipe _recipe(String label) {
  // The distribution tests don't assert on `recipe.id`, only on the
  // resulting entry count / placement, so Recipe.personal (which mints a
  // fresh id) is sufficient.
  return Recipe.personal(
    title: 'Recipe $label',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'middag',
  );
}

WeeklyMenuPlan _emptyPlan(DateTime weekStart) {
  return WeeklyMenuPlan.empty(userId: 'u', date: weekStart);
}

void main() {
  // Monday of week 15, 2026.
  final mon = DateTime(2026, 4, 6);

  late _MockRepo repo;
  late _MockUserService userService;
  late WeeklyMenuPlanService service;

  setUp(() {
    repo = _MockRepo();
    userService = _MockUserService();
    // UserService is only consulted for the empty-plan fallback when
    // `existing` is null; the distribution tests always pass an explicit
    // plan, so a null profile is fine.
    when(() => userService.currentUserProfile).thenReturn(null);
    service = WeeklyMenuPlanService(
      repository: repo,
      userService: userService,
    );
  });

  group('distributeFromGeneratedMenu — lunch/middag chronological fill', () {
    test('Mon anchor: 3 dinners land on Mon/Tue/Wed', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('r1'), _recipe('r2'), _recipe('r3')],
        },
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(result.overflow, isEmpty);
      expect(result.plan.entries, hasLength(3));
      expect(
        result.plan.entries.map((e) => e.day).toList(),
        [DayOfWeek.mon, DayOfWeek.tue, DayOfWeek.wed],
      );
      expect(
        result.plan.entries.every((e) => e.slot == MealSlot.middag),
        isTrue,
      );
    });

    test('Wed anchor (today-anchored): 3 dinners land on Wed/Thu/Fri', () {
      final wed = DateTime(2026, 4, 8, 10);
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('r1'), _recipe('r2'), _recipe('r3')],
        },
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: wed,
      );

      expect(
        result.plan.entries.map((e) => e.day).toList(),
        [DayOfWeek.wed, DayOfWeek.thu, DayOfWeek.fri],
      );
      expect(result.overflow, isEmpty);
    });

    test('Future week starts from Monday even when today is Wed', () {
      final nextMon = mon.add(const Duration(days: 7));
      final wed = DateTime(2026, 4, 8, 10);
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('r1'), _recipe('r2')],
        },
        weekStart: nextMon,
        existing: _emptyPlan(nextMon),
        now: wed,
      );

      expect(
        result.plan.entries.map((e) => e.day).toList(),
        [DayOfWeek.mon, DayOfWeek.tue],
      );
    });

    test('Exact fit: 5 dinners fill Mon–Fri, no overflow', () {
      final recipes = List.generate(5, (i) => _recipe('r${i + 1}')).toList();
      final result = service.distributeFromGeneratedMenu(
        generated: {'middag': recipes},
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(result.plan.entries, hasLength(5));
      expect(result.overflow, isEmpty);
    });

    test('Overflow: 10 dinners fill 7 days, 3 land in overflow', () {
      final recipes = List.generate(10, (i) => _recipe('r${i + 1}')).toList();
      final result = service.distributeFromGeneratedMenu(
        generated: {'middag': recipes},
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(result.plan.entries, hasLength(7));
      expect(result.overflow, hasLength(3));
    });

    test('Pre-existing middag blocks that day, distribution skips it', () {
      final existing = _emptyPlan(mon).copyWith(entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.tue,
          slot: MealSlot.middag,
          recipeId: 'already-here',
          recipeTitle: 'Already Here',
        ),
      ]);
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('r1'), _recipe('r2')],
        },
        weekStart: mon,
        existing: existing,
        now: mon,
      );

      final middagDays = result.plan.entries
          .where((e) => e.slot == MealSlot.middag)
          .map((e) => e.day)
          .toList();
      expect(middagDays, containsAll([DayOfWeek.mon, DayOfWeek.wed]));
      expect(middagDays, contains(DayOfWeek.tue)); // pre-existing stays
      expect(result.overflow, isEmpty);
    });

    test('Sunday anchor: only Sunday slot available, rest overflow', () {
      final sun = DateTime(2026, 4, 12, 10);
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('r1'), _recipe('r2'), _recipe('r3')],
        },
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: sun,
      );

      final placed =
          result.plan.entries.where((e) => e.slot == MealSlot.middag).toList();
      expect(placed, hasLength(1));
      expect(placed.single.day, DayOfWeek.sun);
      expect(result.overflow, hasLength(2));
    });
  });

  group('distributeFromGeneratedMenu — övrigt multi-slot', () {
    test('"snack" mealType routes to övrigt (slot rename end-to-end)', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'snack': [_recipe('r1')],
        },
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(result.plan.entries, hasLength(1));
      expect(result.plan.entries.single.slot, MealSlot.ovrigt);
      expect(result.plan.entries.single.day, DayOfWeek.mon);
    });

    test('"frukost" also routes to övrigt', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'frukost': [_recipe('r1'), _recipe('r2')],
        },
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(result.plan.entries, hasLength(2));
      expect(
        result.plan.entries.every((e) => e.slot == MealSlot.ovrigt),
        isTrue,
      );
    });

    test('Multiple dessert-type recipes stack one-per-day across the week', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'dessert': [
            _recipe('d1'),
            _recipe('d2'),
            _recipe('d3'),
          ],
        },
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(
        result.plan.entries.map((e) => e.day).toList(),
        [DayOfWeek.mon, DayOfWeek.tue, DayOfWeek.wed],
      );
      expect(result.overflow, isEmpty);
    });
  });

  group('distributeFromGeneratedMenu — empty input', () {
    test('Empty generated map produces empty plan + empty overflow', () {
      final result = service.distributeFromGeneratedMenu(
        generated: {},
        weekStart: mon,
        existing: _emptyPlan(mon),
        now: mon,
      );

      expect(result.plan.entries, isEmpty);
      expect(result.overflow, isEmpty);
    });
  });

  group('addEntry / moveEntry / removeEntry / clearWeek', () {
    test('addEntry on lunch replaces existing single-slot entry', () {
      final existing = _emptyPlan(mon).copyWith(entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.mon,
          slot: MealSlot.lunch,
          recipeId: 'old',
          recipeTitle: 'Old',
        ),
      ]);
      final updated = service.addEntry(
        plan: existing,
        day: DayOfWeek.mon,
        slot: MealSlot.lunch,
        recipe: _recipe('new'),
      );

      final lunchEntries = updated.entries
          .where((e) => e.day == DayOfWeek.mon && e.slot == MealSlot.lunch)
          .toList();
      expect(lunchEntries, hasLength(1));
      expect(lunchEntries.single.recipeTitle, 'Recipe new');
    });

    test('addEntry on övrigt appends (multi-slot)', () {
      final existing = _emptyPlan(mon).copyWith(entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.mon,
          slot: MealSlot.ovrigt,
          recipeId: 'first',
          recipeTitle: 'First',
        ),
      ]);
      final updated = service.addEntry(
        plan: existing,
        day: DayOfWeek.mon,
        slot: MealSlot.ovrigt,
        recipe: _recipe('second'),
      );

      final ovrigtEntries = updated.entries
          .where((e) => e.day == DayOfWeek.mon && e.slot == MealSlot.ovrigt)
          .toList();
      expect(ovrigtEntries, hasLength(2));
    });

    test('moveEntry self-drop returns identical plan (no-op)', () {
      final entry = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'r',
        recipeTitle: 'R',
      );
      final existing = _emptyPlan(mon).copyWith(entries: [entry]);
      final updated = service.moveEntry(
        plan: existing,
        entryId: entry.id,
        toDay: DayOfWeek.mon,
        toSlot: MealSlot.middag,
      );

      expect(identical(updated, existing), isTrue);
    });

    test('moveEntry to occupied single-slot target swaps', () {
      final source = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'a',
        recipeTitle: 'A',
      );
      final target = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.wed,
        slot: MealSlot.middag,
        recipeId: 'b',
        recipeTitle: 'B',
      );
      final existing = _emptyPlan(mon).copyWith(entries: [source, target]);
      final updated = service.moveEntry(
        plan: existing,
        entryId: source.id,
        toDay: DayOfWeek.wed,
        toSlot: MealSlot.middag,
      );

      final monMid = updated.entries
          .where((e) => e.day == DayOfWeek.mon && e.slot == MealSlot.middag)
          .toList();
      final wedMid = updated.entries
          .where((e) => e.day == DayOfWeek.wed && e.slot == MealSlot.middag)
          .toList();
      expect(monMid, hasLength(1));
      expect(monMid.single.recipeId, 'b'); // target moved to source's old spot
      expect(wedMid, hasLength(1));
      expect(wedMid.single.recipeId, 'a');
    });

    test('removeEntry with missing id returns identical plan (no-op)', () {
      final existing = _emptyPlan(mon);
      final updated = service.removeEntry(
        plan: existing,
        entryId: 'does-not-exist',
      );
      expect(identical(updated, existing), isTrue);
    });

    test('clearWeek on empty plan returns identical plan', () {
      final existing = _emptyPlan(mon);
      final updated = service.clearWeek(existing);
      expect(identical(updated, existing), isTrue);
    });

    test('clearWeek drops all entries', () {
      final existing = _emptyPlan(mon).copyWith(entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'r',
          recipeTitle: 'R',
        ),
      ]);
      final updated = service.clearWeek(existing);
      expect(updated.entries, isEmpty);
    });
  });
}
