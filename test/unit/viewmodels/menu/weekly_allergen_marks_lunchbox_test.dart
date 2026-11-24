/// BUT-2486 del 3: the calendar's verdict on each lunchbox. A box is judged
/// only by an allergen answer read for the week as it is now, so while one is
/// on its way, after a failed read, or when the dish cannot be found, the box
/// is "ej bedömd" — never drawn as safe.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu/meal_allergen_scope.dart';
import 'package:butlery/viewmodels/menu/weekly_allergen_marks.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

const _nuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);

Recipe _dish(String id, TriState nuts) {
  final base = RecipeFactory.build(id: id, title: id);
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: {'nötter': nuts},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

WeeklyMenuPlan _week(Map<DayOfWeek, Lunchbox> boxes) => WeeklyMenuPlan.empty(
  userId: 'u1',
  date: DateTime(2026, 3, 2),
).copyWith(lunchboxes: boxes);

const _nutBox = Lunchbox(
  source: LunchboxSource.prepDay,
  recipeId: 'nuts',
  takerIds: ['kid'],
);
const _freeBox = Lunchbox(
  source: LunchboxSource.suggestion,
  recipeId: 'free',
  takerIds: ['kid'],
);

void main() {
  final dishes = {
    'nuts': _dish('nuts', TriState.contains),
    'free': _dish('free', TriState.free),
  };

  late List<Completer<MealAllergenScope>> reads;
  late WeeklyAllergenMarks marks;

  setUp(() {
    reads = [];
    marks = WeeklyAllergenMarks(
      resolve: (_) {
        final read = Completer<MealAllergenScope>();
        reads.add(read);
        return read.future;
      },
      recipeFor: (id) => dishes[id],
      onChanged: () {},
      scopeOn: () => true,
    );
  });

  /// The kid taking the box avoids nuts; nobody else does.
  MealAllergenScope kidAvoidsNuts(Iterable<DayOfWeek> days) =>
      MealAllergenScope(
        household: UserAllergenPreferences.none,
        byLunchbox: {
          for (final d in days) d: const LunchboxTakerPrefs(_nuts, alone: true),
        },
      );

  test(
    'every box is unjudged until the first answer arrives, then judged',
    () async {
      final week = _week({DayOfWeek.tue: _nutBox, DayOfWeek.wed: _freeBox});
      marks.refresh(week);
      expect(
        marks.lunchboxVerdict(week, DayOfWeek.tue),
        LunchboxVerdict.unjudged,
      );
      expect(
        marks.lunchboxVerdict(week, DayOfWeek.wed),
        LunchboxVerdict.unjudged,
      );

      reads.single.complete(kidAvoidsNuts([DayOfWeek.tue, DayOfWeek.wed]));
      await pumpEventQueue();
      marks.refresh(week);

      expect(
        marks.lunchboxVerdict(week, DayOfWeek.tue),
        LunchboxVerdict.unsafe,
      );
      expect(marks.lunchboxVerdict(week, DayOfWeek.wed), LunchboxVerdict.safe);
      expect(marks.lunchboxVerdict(week, DayOfWeek.thu), isNull);
    },
  );

  test('a dish missing from the library is unjudged, not safe', () async {
    final week = _week({
      DayOfWeek.tue: const Lunchbox(
        source: LunchboxSource.prepDay,
        recipeId: 'gone',
        takerIds: ['kid'],
      ),
    });
    marks.refresh(week);
    reads.single.complete(kidAvoidsNuts([DayOfWeek.tue]));
    await pumpEventQueue();
    marks.refresh(week);

    expect(
      marks.lunchboxVerdict(week, DayOfWeek.tue),
      LunchboxVerdict.unjudged,
    );
  });

  test('a failed re-read leaves every box unjudged rather than keeping the '
      'last answer', () async {
    final week = _week({DayOfWeek.wed: _freeBox});
    marks.refresh(week);
    reads.single.complete(kidAvoidsNuts([DayOfWeek.wed]));
    await pumpEventQueue();
    marks.refresh(week);
    expect(marks.lunchboxVerdict(week, DayOfWeek.wed), LunchboxVerdict.safe);

    marks.invalidate();
    marks.refresh(week);
    reads.last.completeError(Exception('offline'));
    await pumpEventQueue();
    marks.refresh(week);

    expect(reads, hasLength(2));
    expect(
      marks.lunchboxVerdict(week, DayOfWeek.wed),
      LunchboxVerdict.unjudged,
    );
  });

  test('a changed box is unjudged until its own answer arrives, so the old '
      "takers' verdict never stands in for the new ones", () async {
    final before = _week({DayOfWeek.wed: _freeBox});
    marks.refresh(before);
    reads.single.complete(kidAvoidsNuts([DayOfWeek.wed]));
    await pumpEventQueue();
    marks.refresh(before);
    expect(marks.lunchboxVerdict(before, DayOfWeek.wed), LunchboxVerdict.safe);

    final after = _week({
      DayOfWeek.wed: const Lunchbox(
        source: LunchboxSource.suggestion,
        recipeId: 'free',
        takerIds: ['grandma'],
      ),
    });
    marks.refresh(after);

    expect(reads, hasLength(2));
    expect(
      marks.lunchboxVerdict(after, DayOfWeek.wed),
      LunchboxVerdict.unjudged,
    );
  });

  test('a week that changes and comes back before the new answer lands is '
      'unjudged, not judged by the takerless stand-in', () async {
    final week = _week({DayOfWeek.tue: _nutBox});
    marks.refresh(week);
    // Scoped by meal too, so the stand-in drops the takers' answer.
    reads.single.complete(
      MealAllergenScope(
        household: UserAllergenPreferences.none,
        byMeal: {
          (DayOfWeek.mon, MealSlot.middag): UserAllergenPreferences.none,
        },
        byLunchbox: {
          DayOfWeek.tue: const LunchboxTakerPrefs(_nuts, alone: true),
        },
      ),
    );
    await pumpEventQueue();
    marks.refresh(week);
    expect(marks.lunchboxVerdict(week, DayOfWeek.tue), LunchboxVerdict.unsafe);

    // "Ingen matlåda", then Ångra, before the read for the boxless week.
    marks.refresh(_week(const {}));
    marks.refresh(week);

    expect(
      marks.lunchboxVerdict(week, DayOfWeek.tue),
      LunchboxVerdict.unjudged,
    );
  });

  group('the scope key', () {
    final base = _week({DayOfWeek.tue: _nutBox});
    String key(WeeklyMenuPlan p) =>
        WeeklyAllergenMarks.keyFor(p, scopeOn: true);

    test('changes when a box is added, moved, or changes source, dish or '
        'takers', () {
      final variants = [
        _week(const {}),
        base,
        _week({DayOfWeek.wed: _nutBox}),
        _week({
          DayOfWeek.tue: const Lunchbox(
            source: LunchboxSource.suggestion,
            recipeId: 'nuts',
            takerIds: ['kid'],
          ),
        }),
        _week({
          DayOfWeek.tue: const Lunchbox(
            source: LunchboxSource.prepDay,
            recipeId: 'free',
            takerIds: ['kid'],
          ),
        }),
        _week({
          DayOfWeek.tue: const Lunchbox(
            source: LunchboxSource.prepDay,
            recipeId: 'nuts',
            takerIds: ['kid', 'mom'],
          ),
        }),
      ];
      expect(variants.map(key).toSet(), hasLength(variants.length));
    });

    test('does not change with the order takers were ticked in, or with the '
        'number of boxes', () {
      final reordered = _week({
        DayOfWeek.tue: const Lunchbox(
          source: LunchboxSource.prepDay,
          recipeId: 'nuts',
          portions: 4,
          takerIds: ['mom', 'kid'],
        ),
      });
      final sorted = _week({
        DayOfWeek.tue: const Lunchbox(
          source: LunchboxSource.prepDay,
          recipeId: 'nuts',
          takerIds: ['kid', 'mom'],
        ),
      });
      expect(key(reordered), key(sorted));
    });

    test('same-week leftovers key on the middag they follow', () {
      const box = Lunchbox(
        source: LunchboxSource.leftovers,
        fromDay: DayOfWeek.mon,
      );
      WeeklyMenuPlan withMiddag(String recipeId) =>
          _week({DayOfWeek.tue: box}).copyWith(
            entries: [
              WeeklyMenuPlanEntry.create(
                day: DayOfWeek.mon,
                slot: MealSlot.middag,
                recipeId: recipeId,
                recipeTitle: recipeId,
              ),
            ],
          );
      expect(key(withMiddag('nuts')), isNot(key(withMiddag('free'))));
    });
  });
}
