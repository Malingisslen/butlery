import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  group('distributeFromGeneratedMenu — day pins vs occupied cells (BUT-1241)',
      () {
    test(
        'a pin targeting an occupied single slot does NOT double-stack — '
        'the recipe falls through to the chronological fill', () {
      // Friday middag is already taken (e.g. hand-placed in the manual
      // placement flow before "Placera resten automatiskt").
      final occupied = _emptyPlan(mon).copyWith(entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.fri,
          slot: MealSlot.middag,
          recipeId: 'manual-r',
          recipeTitle: 'Handplacerad',
        ),
      ]);

      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('pinned')],
        },
        weekStart: mon,
        existing: occupied,
        now: mon,
        dayPins: const [
          // tacofredag: Friday (ISO 5) middag, unconstrained tags so the
          // single generated recipe matches the pin.
          DayPin(
            weekdayIndex: 5,
            mealType: 'middag',
            constraint: RecipeConstraint(count: 1),
          ),
        ],
      );

      // No cell holds two entries...
      expect(
          result.plan.entriesAt(DayOfWeek.fri, MealSlot.middag), hasLength(1));
      // ...and the pinned recipe landed on the first free middag instead.
      expect(
        result.plan.entryAt(DayOfWeek.mon, MealSlot.middag)?.recipeTitle,
        'Recipe pinned',
      );
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

    test('restoreWeek REPLACES entries (does not merge with current)', () {
      // The service half of the undo contract. A copyWith(entries:) that did
      // entries.addAll(...) would silently double the plan on undo. Start from
      // a plan that already holds entry A, restore snapshot [B], and assert the
      // result is exactly [B] — A must be gone, not merged in.
      final entryA = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'a',
        recipeTitle: 'A',
      );
      final snapshotB = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.tue,
        slot: MealSlot.lunch,
        recipeId: 'b',
        recipeTitle: 'B',
      );
      final current = _emptyPlan(mon).copyWith(entries: [entryA]);

      final restored = service.restoreWeek(current, [snapshotB]);

      expect(restored.entries, [snapshotB]);
      expect(
        restored.entries.any((e) => e.recipeId == 'a'),
        isFalse,
        reason: 'restoreWeek must replace, not merge — a merge would resurrect '
            'the just-cleared entry A on undo.',
      );
    });
  });

  // BUT-1013: bulk-add semantics. The recipe-list selection bar now lets
  // users push N recipes onto the menu in a single action. The contract:
  // single-slot targets walk forward day-by-day and overflow past Sunday;
  // multi-slot targets stack everything at the start cell; nothing is
  // written when added==0; pre-existing single-slot occupants are replaced
  // (no duplicates) so the user can re-tap "add to menu" idempotently.
  group('bulkAssignRecipes — BUT-1013', () {
    setUpAll(() {
      registerFallbackValue(_FakeWeeklyMenuPlan());
    });

    setUp(() {
      when(() => userService.currentUserProfile).thenReturn(_profile('u'));
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => null);
      when(() => repo.save(any())).thenAnswer((_) async {});
    });

    test('single-slot Friday start: 10 dinners → added 3, overflowed 7',
        () async {
      // Proves the cursor-past-Sunday overflow path. Fri/Sat/Sun = 3 days
      // of capacity; everything after must land in overflowed, never silently
      // wrap to Monday.
      final recipes = List.generate(10, (i) => _recipe('r${i + 1}')).toList();

      final result = await service.bulkAssignRecipes(
        weekStart: mon,
        startDay: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipes: recipes,
      );

      expect(result.added, 3);
      expect(result.overflowed, 7);

      final captured = verify(() => repo.save(captureAny())).captured;
      expect(captured, hasLength(1)); // save called exactly once when added > 0
      final saved = captured.single as WeeklyMenuPlan;
      final placedDays = saved.entries
          .where((e) => e.slot == MealSlot.middag)
          .map((e) => e.day)
          .toList();
      expect(placedDays, [DayOfWeek.fri, DayOfWeek.sat, DayOfWeek.sun]);
    });

    test('single-slot Sunday start: 5 dinners → added 1, overflowed 4',
        () async {
      // Edge case: starting on the last possible day, only one fits.
      final recipes = List.generate(5, (i) => _recipe('r${i + 1}')).toList();

      final result = await service.bulkAssignRecipes(
        weekStart: mon,
        startDay: DayOfWeek.sun,
        slot: MealSlot.middag,
        recipes: recipes,
      );

      expect(result.added, 1);
      expect(result.overflowed, 4);
    });

    test('empty recipe list returns (0,0) without touching the repository',
        () async {
      // No save call when added == 0 — prevents wasted Firestore writes
      // when the UI invokes with an empty selection.
      final result = await service.bulkAssignRecipes(
        weekStart: mon,
        startDay: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipes: const [],
      );

      expect(result, (added: 0, overflowed: 0));
      verifyNever(() => repo.save(any()));
      verifyNever(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          ));
    });

    test(
        'single-slot: pre-existing entry at start day is PRESERVED; bulk skips occupied cells',
        () async {
      // BUT-1013 critical invariant (caught by Batch B code reviewer):
      // bulk-add-to-menu must NEVER silently overwrite an existing
      // single-slot entry. Placeholder on Monday remains; new recipes
      // walk forward and land on Tue + Wed.
      final placeholder = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'old-recipe',
        recipeTitle: 'Old',
      );
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer(
        (_) async => _emptyPlan(mon).copyWith(entries: [placeholder]),
      );

      final result = await service.bulkAssignRecipes(
        weekStart: mon,
        startDay: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipes: [_recipe('new1'), _recipe('new2')],
      );

      expect(result.added, 2);
      expect(result.overflowed, 0);

      final saved = verify(() => repo.save(captureAny())).captured.single
          as WeeklyMenuPlan;
      final monMid = saved.entriesAt(DayOfWeek.mon, MealSlot.middag);
      expect(monMid, hasLength(1), reason: 'Monday must keep the placeholder');
      expect(monMid.single.recipeTitle, 'Old',
          reason: 'Existing user placement must not be overwritten');
      expect(
        saved.entries.any((e) => e.id == placeholder.id),
        isTrue,
        reason: 'Placeholder id must be preserved verbatim',
      );

      // The two new recipes cascade onto the next two empty days.
      final tueMid = saved.entriesAt(DayOfWeek.tue, MealSlot.middag);
      final wedMid = saved.entriesAt(DayOfWeek.wed, MealSlot.middag);
      expect(tueMid, hasLength(1));
      expect(tueMid.single.recipeTitle, 'Recipe new1');
      expect(wedMid, hasLength(1));
      expect(wedMid.single.recipeTitle, 'Recipe new2');
    });

    test(
        'single-slot: skips multiple consecutive occupied cells then overflows',
        () async {
      // Stress the skip-cursor: Mon/Tue/Wed all booked → new recipes land
      // on Thu/Fri/Sat/Sun; recipe #5 overflows.
      final preBooked = [
        WeeklyMenuPlanEntry.create(
            day: DayOfWeek.mon,
            slot: MealSlot.middag,
            recipeId: 'r0a',
            recipeTitle: 'A'),
        WeeklyMenuPlanEntry.create(
            day: DayOfWeek.tue,
            slot: MealSlot.middag,
            recipeId: 'r0b',
            recipeTitle: 'B'),
        WeeklyMenuPlanEntry.create(
            day: DayOfWeek.wed,
            slot: MealSlot.middag,
            recipeId: 'r0c',
            recipeTitle: 'C'),
      ];
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer(
        (_) async => _emptyPlan(mon).copyWith(entries: preBooked),
      );

      final result = await service.bulkAssignRecipes(
        weekStart: mon,
        startDay: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipes: List.generate(5, (i) => _recipe('n${i + 1}')),
      );

      expect(result.added, 4);
      expect(result.overflowed, 1);
    });

    test('multi-slot övrigt Monday: 5 recipes stack at (Mon, övrigt)',
        () async {
      // Övrigt is the multi-recipe bucket — the bulk action must NOT walk
      // forward across days; everything piles onto the start cell.
      final recipes = List.generate(5, (i) => _recipe('r${i + 1}')).toList();

      final result = await service.bulkAssignRecipes(
        weekStart: mon,
        startDay: DayOfWeek.mon,
        slot: MealSlot.ovrigt,
        recipes: recipes,
      );

      expect(result.added, 5);
      expect(result.overflowed, 0);

      final saved = verify(() => repo.save(captureAny())).captured.single
          as WeeklyMenuPlan;
      final ovrigt = saved.entriesAt(DayOfWeek.mon, MealSlot.ovrigt);
      expect(ovrigt, hasLength(5));
      // Insertion order preserved.
      expect(
        ovrigt.map((e) => e.recipeTitle).toList(),
        ['Recipe r1', 'Recipe r2', 'Recipe r3', 'Recipe r4', 'Recipe r5'],
      );
    });

    test('throws StateError when no authenticated user', () async {
      when(() => userService.currentUserProfile).thenReturn(null);

      expect(
        () => service.bulkAssignRecipes(
          weekStart: mon,
          startDay: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipes: [_recipe('r1')],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // BUT-999: one recipe → many (day, slot) targets in ONE action. The core
  // contract is write-efficiency and atomicity-by-batching: no matter how
  // many targets the user picks, the repository sees exactly one save with
  // all placements already applied.
  group('assignRecipeToTargets — BUT-999', () {
    setUpAll(() {
      registerFallbackValue(_FakeWeeklyMenuPlan());
    });

    setUp(() {
      when(() => userService.currentUserProfile).thenReturn(_profile('u'));
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => null);
      when(() => repo.save(any())).thenAnswer((_) async {});
    });

    test('3 targets → ONE batched save containing all 3 entries', () async {
      final recipe = _recipe('tacos');

      final added = await service.assignRecipeToTargets(
        weekStart: mon,
        recipe: recipe,
        targets: const [
          (day: DayOfWeek.mon, slot: MealSlot.middag),
          (day: DayOfWeek.wed, slot: MealSlot.lunch),
          (day: DayOfWeek.fri, slot: MealSlot.ovrigt),
        ],
      );

      expect(added, 3);

      final captured = verify(() => repo.save(captureAny())).captured;
      expect(captured, hasLength(1),
          reason: 'N targets must produce exactly ONE save, never N writes');
      final saved = captured.single as WeeklyMenuPlan;
      expect(saved.entries, hasLength(3));
      expect(saved.entriesAt(DayOfWeek.mon, MealSlot.middag), hasLength(1));
      expect(saved.entriesAt(DayOfWeek.wed, MealSlot.lunch), hasLength(1));
      expect(saved.entriesAt(DayOfWeek.fri, MealSlot.ovrigt), hasLength(1));
      expect(
        saved.entries.every((e) => e.recipeTitle == 'Recipe tacos'),
        isTrue,
      );
    });

    test('single target regression: behaves like one addEntry + one save',
        () async {
      // The single-select path must be byte-for-byte the old behavior:
      // single-slot targets replace any existing occupant (addEntry
      // semantics — the user explicitly tapped that cell).
      final occupant = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.tue,
        slot: MealSlot.middag,
        recipeId: 'old',
        recipeTitle: 'Old',
      );
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer(
        (_) async => _emptyPlan(mon).copyWith(entries: [occupant]),
      );

      final added = await service.assignRecipeToTargets(
        weekStart: mon,
        recipe: _recipe('new'),
        targets: const [(day: DayOfWeek.tue, slot: MealSlot.middag)],
      );

      expect(added, 1);
      final captured = verify(() => repo.save(captureAny())).captured;
      expect(captured, hasLength(1));
      final saved = captured.single as WeeklyMenuPlan;
      final tueMid = saved.entriesAt(DayOfWeek.tue, MealSlot.middag);
      expect(tueMid, hasLength(1),
          reason: 'Single-slot replacement must not duplicate the cell');
      expect(tueMid.single.recipeTitle, 'Recipe new');
    });

    test('duplicate targets are applied once', () async {
      final added = await service.assignRecipeToTargets(
        weekStart: mon,
        recipe: _recipe('r'),
        targets: const [
          (day: DayOfWeek.mon, slot: MealSlot.ovrigt),
          (day: DayOfWeek.mon, slot: MealSlot.ovrigt),
        ],
      );

      expect(added, 1);
      final saved = verify(() => repo.save(captureAny())).captured.single
          as WeeklyMenuPlan;
      expect(saved.entriesAt(DayOfWeek.mon, MealSlot.ovrigt), hasLength(1),
          reason: 'A duplicated övrigt target must not stack twice');
    });

    test('empty targets returns 0 without touching the repository', () async {
      final added = await service.assignRecipeToTargets(
        weekStart: mon,
        recipe: _recipe('r'),
        targets: const [],
      );

      expect(added, 0);
      verifyNever(() => repo.save(any()));
      verifyNever(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          ));
    });

    test('throws StateError when no authenticated user', () async {
      when(() => userService.currentUserProfile).thenReturn(null);

      expect(
        () => service.assignRecipeToTargets(
          weekStart: mon,
          recipe: _recipe('r'),
          targets: const [(day: DayOfWeek.mon, slot: MealSlot.middag)],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // BUT-1043: bulk-move loops the in-memory moveEntry primitive over a
  // selection and persists ONCE. The contract: N entry ids → one save with
  // every present entry relocated to (toDay, toSlot); stale ids skipped;
  // empty selection touches nothing.
  group('bulkMoveEntries — BUT-1043', () {
    setUpAll(() {
      registerFallbackValue(_FakeWeeklyMenuPlan());
    });

    WeeklyMenuPlanEntry makeEntry({
      required String id,
      required DayOfWeek day,
      required MealSlot slot,
    }) {
      return WeeklyMenuPlanEntry(
        id: id,
        day: day,
        slot: slot,
        recipeId: 'r-$id',
        recipeTitle: 'Recipe $id',
      );
    }

    setUp(() {
      when(() => userService.currentUserProfile).thenReturn(_profile('u'));
      when(() => repo.save(any())).thenAnswer((_) async {});
    });

    test('moves every selected övrigt entry to one target with a single save',
        () async {
      // Three övrigt entries spread across days collapse onto Friday övrigt
      // in one persisted write — the realistic bulk-move case.
      final plan = _emptyPlan(mon).copyWith(entries: [
        makeEntry(id: 'e1', day: DayOfWeek.mon, slot: MealSlot.ovrigt),
        makeEntry(id: 'e2', day: DayOfWeek.tue, slot: MealSlot.ovrigt),
        makeEntry(id: 'e3', day: DayOfWeek.wed, slot: MealSlot.ovrigt),
      ]);
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => plan);

      final moved = await service.bulkMoveEntries(
        weekStart: mon,
        entryIds: ['e1', 'e2', 'e3'],
        toDay: DayOfWeek.fri,
        toSlot: MealSlot.ovrigt,
      );

      expect(moved, 3);
      final captured = verify(() => repo.save(captureAny())).captured;
      expect(captured, hasLength(1)); // one write, not three
      final saved = captured.single as WeeklyMenuPlan;
      final fri = saved.entriesAt(DayOfWeek.fri, MealSlot.ovrigt);
      expect(fri.map((e) => e.id).toSet(), {'e1', 'e2', 'e3'});
    });

    test('skips stale ids not present on the plan and counts only real moves',
        () async {
      final plan = _emptyPlan(mon).copyWith(entries: [
        makeEntry(id: 'e1', day: DayOfWeek.mon, slot: MealSlot.ovrigt),
      ]);
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => plan);

      final moved = await service.bulkMoveEntries(
        weekStart: mon,
        entryIds: ['e1', 'ghost-id'],
        toDay: DayOfWeek.thu,
        toSlot: MealSlot.ovrigt,
      );

      expect(moved, 1); // ghost-id silently skipped, not an error
    });

    test('empty selection returns 0 without touching the repository', () async {
      final moved = await service.bulkMoveEntries(
        weekStart: mon,
        entryIds: const [],
        toDay: DayOfWeek.mon,
        toSlot: MealSlot.middag,
      );

      expect(moved, 0);
      verifyNever(() => repo.save(any()));
      verifyNever(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          ));
    });

    test('all-stale selection saves nothing (no write for 0 real moves)',
        () async {
      final plan = _emptyPlan(mon).copyWith(entries: [
        makeEntry(id: 'e1', day: DayOfWeek.mon, slot: MealSlot.ovrigt),
      ]);
      when(() => repo.fetchForWeek(
            userId: any(named: 'userId'),
            weekStart: any(named: 'weekStart'),
          )).thenAnswer((_) async => plan);

      final moved = await service.bulkMoveEntries(
        weekStart: mon,
        entryIds: ['ghost-1', 'ghost-2'],
        toDay: DayOfWeek.thu,
        toSlot: MealSlot.ovrigt,
      );

      expect(moved, 0);
      verifyNever(() => repo.save(any()));
    });

    test('throws StateError when no authenticated user', () async {
      when(() => userService.currentUserProfile).thenReturn(null);

      expect(
        () => service.bulkMoveEntries(
          weekStart: mon,
          entryIds: ['e1'],
          toDay: DayOfWeek.mon,
          toSlot: MealSlot.middag,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
