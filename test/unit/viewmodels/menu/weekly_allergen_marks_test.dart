/// BUT-2362: the calendar's allergen marks follow the week and who is home,
/// and while a changed week is read again they lean towards marking.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/weekly_allergen_marks.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

const _nuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);

Recipe _nutDish() {
  final base = RecipeFactory.build(id: 'nuts', title: 'nuts');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: const {'nötter': TriState.contains},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

void main() {
  final dish = _nutDish();
  final entry = WeeklyMenuPlanEntry.create(
    day: DayOfWeek.tue,
    slot: MealSlot.middag,
    recipeId: 'nuts',
    recipeTitle: 'nuts',
  );
  final week = WeeklyMenuPlan.empty(
    userId: 'u1',
    date: DateTime(2026, 3, 2),
  ).copyWith(entries: [entry]);
  final kidAway = WeeklyMenuPlanService.withPresence(
    plan: week,
    day: DayOfWeek.tue,
    slots: [MealSlot.middag],
    memberIds: ['mom'],
    awayMemberIds: ['kid'],
  );

  late List<Completer<MealAllergenScope>> reads;
  late int changes;
  late WeeklyAllergenMarks marks;

  setUp(() {
    reads = [];
    changes = 0;
    marks = WeeklyAllergenMarks(
      resolve: (_) {
        final read = Completer<MealAllergenScope>();
        reads.add(read);
        return read.future;
      },
      recipeFor: (id) => id == 'nuts' ? dish : null,
      onChanged: () => changes++,
      scopeOn: () => true,
    );
  });

  MealAllergenScope kidAwayScope() => MealAllergenScope(
    household: _nuts,
    byMeal: {(DayOfWeek.tue, MealSlot.middag): UserAllergenPreferences.none},
  );

  test('nothing is marked before the first read, then the marks arrive '
      'with a change', () async {
    marks.refresh(week);
    expect(marks.isUnsafe(entry.id), isFalse);

    reads.single.complete(MealAllergenScope(household: _nuts));
    await pumpEventQueue();
    marks.refresh(week);

    expect(changes, 1);
    expect(marks.isUnsafe(entry.id), isTrue);
  });

  test('a dish is unmarked while the one who reacts is away', () async {
    marks.refresh(kidAway);
    reads.single.complete(kidAwayScope());
    await pumpEventQueue();
    marks.refresh(kidAway);

    expect(marks.isUnsafe(entry.id), isFalse);
  });

  test('when who is home changes, the meal is judged for the whole household '
      'until the new read arrives', () async {
    marks.refresh(kidAway);
    reads.single.complete(kidAwayScope());
    await pumpEventQueue();
    marks.refresh(kidAway);
    expect(marks.isUnsafe(entry.id), isFalse);

    // The kid is back home for Tuesday middag.
    marks.refresh(week);

    expect(reads, hasLength(2));
    expect(marks.isUnsafe(entry.id), isTrue);
  });

  test('the same week is not read again until it is invalidated', () async {
    marks.refresh(week);
    reads.single.complete(MealAllergenScope(household: _nuts));
    await pumpEventQueue();
    marks.refresh(week);
    marks.refresh(week);
    expect(reads, hasLength(1));

    marks.invalidate();
    marks.refresh(week);
    expect(reads, hasLength(2));
  });

  test('a read that lands after dispose changes nothing', () async {
    marks.refresh(week);
    marks.dispose();
    reads.single.complete(MealAllergenScope(household: _nuts));
    await pumpEventQueue();

    expect(changes, 0);
  });

  test('invalidating while a read is out drops that read and starts a fresh '
      'one', () async {
    marks.refresh(week);
    marks.invalidate();
    marks.refresh(week);
    expect(reads, hasLength(2));

    // The older read answers with allergens nobody has any more.
    reads.first.complete(MealAllergenScope(household: _nuts));
    await pumpEventQueue();
    marks.refresh(week);
    expect(changes, 0);
    expect(marks.isUnsafe(entry.id), isFalse);

    reads.last.complete(
      MealAllergenScope(household: UserAllergenPreferences.none),
    );
    await pumpEventQueue();
    expect(changes, 1);
  });

  test('a failed read is not retried on every refresh, only after '
      'invalidate', () async {
    marks.refresh(week);
    reads.single.completeError(StateError('offline'));
    await pumpEventQueue();
    marks.refresh(week);
    marks.refresh(week);
    expect(reads, hasLength(1));

    marks.invalidate();
    marks.refresh(week);
    expect(reads, hasLength(2));
  });

  test('a read out when the marks are invalidated is dropped even when no '
      'week follows', () async {
    marks.refresh(week);
    marks.invalidate();
    // The week could not be read again.
    marks.refresh(null);
    reads.single.complete(MealAllergenScope(household: _nuts));
    await pumpEventQueue();
    expect(changes, 0);

    marks.refresh(week);
    expect(reads, hasLength(2));
  });

  test('refreshing while a read is out does not start another', () async {
    marks.refresh(week);
    marks.refresh(week);
    marks.refresh(week);

    expect(reads, hasLength(1));
  });

  test('turning the per-meal choice on or off reads the scope again', () async {
    var on = false;
    final toggled = WeeklyAllergenMarks(
      resolve: (_) {
        final read = Completer<MealAllergenScope>();
        reads.add(read);
        return read.future;
      },
      recipeFor: (id) => id == 'nuts' ? dish : null,
      onChanged: () => changes++,
      scopeOn: () => on,
    );
    toggled.refresh(week);
    reads.single.complete(MealAllergenScope(household: _nuts));
    await pumpEventQueue();
    toggled.refresh(week);
    expect(reads, hasLength(1));

    on = true;
    toggled.refresh(week);

    expect(reads, hasLength(2));
  });
}
