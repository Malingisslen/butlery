/// BUT-2486 part 1: the lunchbox data model on the personal weekly menu.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tag_result.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

WeeklyMenuPlan _week({
  List<WeeklyMenuPlanEntry> entries = const [],
  Map<DayOfWeek, Lunchbox> lunchboxes = const {},
}) => WeeklyMenuPlan(
  id: 'u1_2026-W02',
  userId: 'u1',
  weekStartDate: DateTime.utc(2026, 1, 5),
  entries: entries,
  createdAt: DateTime.utc(2026, 1, 5),
  updatedAt: DateTime.utc(2026, 1, 5),
  lunchboxes: lunchboxes,
);

WeeklyMenuPlanEntry _entry(
  DayOfWeek day,
  MealSlot slot,
  String recipeId, {
  String? id,
}) => WeeklyMenuPlanEntry(
  id: id ?? 'e-${day.name}-${slot.name}',
  day: day,
  slot: slot,
  recipeId: recipeId,
  recipeTitle: 't-$recipeId',
);

WeeklyMenuPlan _roundTrip(WeeklyMenuPlan plan) =>
    WeeklyMenuPlan.fromMap(plan.id, plan.toFirestore());

void main() {
  const sameWeek = Lunchbox(
    source: LunchboxSource.leftovers,
    fromDay: DayOfWeek.mon,
    recipeId: 'ignored-by-same-week',
    recipeTitle: 'ignored',
    portions: 2,
    takerIds: ['a', 'b'],
  );
  const prevWeek = Lunchbox(
    source: LunchboxSource.leftovers,
    fromDay: DayOfWeek.sun,
    fromPreviousWeek: true,
    recipeId: 'r-prev',
    recipeTitle: 'Förra veckans gryta',
  );
  const prep = Lunchbox(
    source: LunchboxSource.prepDay,
    recipeId: 'r-prep',
    recipeTitle: 'Matlåda',
    portions: 3,
    takerIds: ['a'],
  );
  const suggested = Lunchbox(
    source: LunchboxSource.suggestion,
    recipeId: 'r-sugg',
    recipeTitle: 'Förslag',
  );

  group('lunchboxes on the week document', () {
    test('every source survives toFirestore -> fromMap', () {
      final back = _roundTrip(
        _week(
          lunchboxes: {
            DayOfWeek.tue: sameWeek,
            DayOfWeek.wed: prep,
            DayOfWeek.thu: suggested,
            DayOfWeek.mon: prevWeek,
          },
        ),
      ).lunchboxes;

      expect(back.keys.toSet(), {
        DayOfWeek.mon,
        DayOfWeek.tue,
        DayOfWeek.wed,
        DayOfWeek.thu,
      });
      expect(back[DayOfWeek.tue]!.source, LunchboxSource.leftovers);
      expect(back[DayOfWeek.tue]!.fromDay, DayOfWeek.mon);
      expect(back[DayOfWeek.tue]!.portions, 2);
      expect(back[DayOfWeek.tue]!.takerIds, ['a', 'b']);
      expect(back[DayOfWeek.wed]!.source, LunchboxSource.prepDay);
      expect(back[DayOfWeek.wed]!.recipeId, 'r-prep');
      expect(back[DayOfWeek.wed]!.recipeTitle, 'Matlåda');
      expect(back[DayOfWeek.wed]!.portions, 3);
      expect(back[DayOfWeek.thu]!.source, LunchboxSource.suggestion);
      expect(back[DayOfWeek.thu]!.recipeId, 'r-sugg');
      expect(back[DayOfWeek.mon]!.fromPreviousWeek, isTrue);
      expect(back[DayOfWeek.mon]!.recipeId, 'r-prev');
      expect(back[DayOfWeek.mon]!.fromDay, DayOfWeek.sun);
    });

    test('the field is omitted from the document when there are none', () {
      expect(_week().toFirestore().containsKey('lunchboxes'), isFalse);
    });

    test('a document saved before the field existed has no lunchboxes', () {
      final data = _week().toFirestore()..remove('lunchboxes');
      expect(WeeklyMenuPlan.fromMap('u1_2026-W02', data).lunchboxes, isEmpty);
    });

    test('an unknown source name parses as a suggestion keeping its dish', () {
      final data = _week(lunchboxes: {DayOfWeek.wed: prep}).toFirestore();
      final boxes = data['lunchboxes'] as Map<String, dynamic>;
      (boxes['wed'] as Map<String, dynamic>)['source'] = 'fromTheFuture';

      final box = WeeklyMenuPlan.fromMap(
        'u1_2026-W02',
        data,
      ).lunchboxes[DayOfWeek.wed]!;

      expect(box.source, LunchboxSource.suggestion);
      expect(box.recipeId, 'r-prep');
    });

    test('an unknown day key is skipped, not moved onto another day', () {
      final data = _week(lunchboxes: {DayOfWeek.wed: prep}).toFirestore();
      final boxes = data['lunchboxes'] as Map<String, dynamic>;
      boxes['someday'] = Map<String, dynamic>.from(boxes['wed'] as Map);

      final parsed = WeeklyMenuPlan.fromMap('u1_2026-W02', data).lunchboxes;

      expect(parsed.keys, [DayOfWeek.wed]);
    });

    test('portions below 1 parse as 1', () {
      final data = _week(lunchboxes: {DayOfWeek.wed: prep}).toFirestore();
      final boxes = data['lunchboxes'] as Map<String, dynamic>;
      (boxes['wed'] as Map<String, dynamic>)['portions'] = 0;

      expect(
        WeeklyMenuPlan.fromMap(
          'u1_2026-W02',
          data,
        ).lunchboxes[DayOfWeek.wed]!.portions,
        1,
      );
    });

    test('copyWith and nextRevision keep the lunchboxes', () {
      final week = _week(lunchboxes: {DayOfWeek.wed: prep});

      expect(week.copyWith(entries: const []).lunchboxes, {
        DayOfWeek.wed: prep,
      });
      expect(week.nextRevision().lunchboxes, {DayOfWeek.wed: prep});
    });

    test('copyWith can replace the lunchboxes', () {
      final week = _week(lunchboxes: {DayOfWeek.wed: prep});
      expect(week.copyWith(lunchboxes: const {}).lunchboxes, isEmpty);
    });
  });

  group('which dish a lunchbox holds', () {
    test('same-week leftovers store no dish on the document', () {
      final map = sameWeek.toMap();
      expect(map.containsKey('recipeId'), isFalse);
      expect(map.containsKey('recipeTitle'), isFalse);
      expect(map['fromDay'], 'mon');
    });

    test('same-week leftovers follow the middag on fromDay live', () {
      final box = sameWeek;
      final withPasta = _week(
        entries: [_entry(DayOfWeek.mon, MealSlot.middag, 'pasta')],
      );
      final withSoup = _week(
        entries: [_entry(DayOfWeek.mon, MealSlot.middag, 'soup')],
      );

      expect(box.recipeIdIn(withPasta), 'pasta');
      expect(box.recipeIdIn(withSoup), 'soup');
    });

    test('same-week leftovers from a day with no middag hold nothing', () {
      final onlyOtherDay = _week(
        entries: [
          _entry(DayOfWeek.tue, MealSlot.middag, 'pasta'),
          _entry(DayOfWeek.mon, MealSlot.lunch, 'lunch-dish'),
        ],
      );
      expect(sameWeek.recipeIdIn(onlyOtherDay), isNull);
    });

    test('leftovers from the previous week store and return their dish', () {
      final map = prevWeek.toMap();
      expect(map['recipeId'], 'r-prev');
      expect(map['recipeTitle'], 'Förra veckans gryta');
      // Another middag on Sunday must not be read as the dish.
      final plan = _week(
        entries: [_entry(DayOfWeek.sun, MealSlot.middag, 'this-week')],
      );
      expect(prevWeek.recipeIdIn(plan), 'r-prev');
    });

    test('prep-day and suggestion boxes return their stored dish', () {
      final plan = _week();
      expect(prep.recipeIdIn(plan), 'r-prep');
      expect(suggested.recipeIdIn(plan), 'r-sugg');
    });

    test('a box with no stored dish holds nothing', () {
      const empty = Lunchbox(source: LunchboxSource.prepDay, recipeId: '');
      expect(empty.recipeIdIn(_week()), isNull);
      expect(
        const Lunchbox(source: LunchboxSource.suggestion).recipeIdIn(_week()),
        isNull,
      );
    });
  });

  group('editing a week\'s lunchboxes', () {
    test('withLunchbox replaces that day\'s lunch dish and keeps the rest', () {
      final week = _week(
        entries: [
          _entry(DayOfWeek.wed, MealSlot.lunch, 'old-lunch'),
          _entry(DayOfWeek.thu, MealSlot.lunch, 'thu-lunch'),
          _entry(DayOfWeek.wed, MealSlot.middag, 'wed-middag'),
        ],
      );

      final next = week.withLunchbox(DayOfWeek.wed, prep);

      expect(next.lunchboxes[DayOfWeek.wed], prep);
      expect(next.entries.map((e) => e.recipeId), [
        'thu-lunch',
        'wed-middag',
      ]);
    });

    test('withLunchbox keeps the other days\' boxes', () {
      final week = _week(lunchboxes: {DayOfWeek.mon: prevWeek});
      final next = week.withLunchbox(DayOfWeek.wed, prep);
      expect(next.lunchboxes.keys.toSet(), {DayOfWeek.mon, DayOfWeek.wed});
    });

    test('withoutLunchbox removes only that day\'s box', () {
      final week = _week(
        lunchboxes: {DayOfWeek.mon: prevWeek, DayOfWeek.wed: prep},
      );
      expect(week.withoutLunchbox(DayOfWeek.wed).lunchboxes, {
        DayOfWeek.mon: prevWeek,
      });
    });

    test('withoutLunchboxesOf removes boxes storing the dish and keeps '
        'same-week leftovers', () {
      const otherPrep = Lunchbox(
        source: LunchboxSource.prepDay,
        recipeId: 'r-other',
      );
      // Same-week leftovers carry a recipeId in memory too; it must not
      // make the box a match.
      const leftoversNamingDish = Lunchbox(
        source: LunchboxSource.leftovers,
        fromDay: DayOfWeek.mon,
        recipeId: 'r-prep',
      );
      final week = _week(
        lunchboxes: {
          DayOfWeek.tue: prep,
          DayOfWeek.wed: suggested.copyForTest(recipeId: 'r-prep'),
          DayOfWeek.thu: otherPrep,
          DayOfWeek.fri: leftoversNamingDish,
          DayOfWeek.mon: prevWeek,
        },
      );

      final next = week.withoutLunchboxesOf('r-prep');

      expect(next.lunchboxes.keys.toSet(), {
        DayOfWeek.thu,
        DayOfWeek.fri,
        DayOfWeek.mon,
      });
    });
  });

  group('lunchboxes from the fridge or freezer', () {
    final stockBox = MealBox(
      id: 'box1',
      recipeId: 'r-stock',
      recipeTitle: 'Gryta i frysen',
      location: MealBoxLocation.freezer,
      storedOn: DateTime(2026, 1, 2),
      count: 4,
    );

    test('fromStock is stored as previous-week leftovers with the dish', () {
      final box = Lunchbox.fromStock(stockBox, portions: 2, takerIds: ['a']);
      final map = box.toMap();

      expect(map['source'], 'leftovers');
      expect(map['fromPreviousWeek'], isTrue);
      expect(map['recipeId'], 'r-stock');
      expect(map['recipeTitle'], 'Gryta i frysen');
      expect(map['portions'], 2);
      expect(box.isFromStock, isTrue);
    });

    test('mealBoxId, location and stored date survive the week document', () {
      final back = _roundTrip(
        _week(
          lunchboxes: {DayOfWeek.wed: Lunchbox.fromStock(stockBox)},
        ),
      ).lunchboxes[DayOfWeek.wed]!;

      expect(back.mealBoxId, 'box1');
      expect(back.mealBoxLocation, MealBoxLocation.freezer);
      expect(back.mealBoxStoredOn, DateTime(2026, 1, 2));
      expect(back.isFromStock, isTrue);
      expect(back.source, LunchboxSource.leftovers);
      expect(back.fromPreviousWeek, isTrue);
    });

    test('a box missing its stored date or its title is not from stock', () {
      final noDate = Lunchbox(
        source: LunchboxSource.leftovers,
        fromPreviousWeek: true,
        recipeTitle: 'Gryta',
        mealBoxId: 'box1',
      );
      final noTitle = Lunchbox(
        source: LunchboxSource.leftovers,
        fromPreviousWeek: true,
        mealBoxId: 'box1',
        mealBoxStoredOn: DateTime(2026, 1, 2),
      );

      expect(noDate.isFromStock, isFalse);
      expect(noTitle.isFromStock, isFalse);
    });

    test('a box whose id is not a plain document id is not from stock', () {
      final box = Lunchbox(
        source: LunchboxSource.leftovers,
        fromPreviousWeek: true,
        recipeTitle: 'Gryta',
        mealBoxId: 'a/b',
        mealBoxStoredOn: DateTime(2026, 1, 2),
      );

      expect(box.isFromStock, isFalse);
    });

    test('withoutLunchboxesOf keeps a stock box of the deleted recipe but '
        'removes a plain suggestion box of it', () {
      final week = _week(
        lunchboxes: {
          DayOfWeek.tue: Lunchbox.fromStock(stockBox),
          DayOfWeek.wed: const Lunchbox(
            source: LunchboxSource.suggestion,
            recipeId: 'r-stock',
            recipeTitle: 'Förslag',
          ),
        },
      );

      final next = week.withoutLunchboxesOf('r-stock');

      expect(next.lunchboxes.keys, [DayOfWeek.tue]);
    });
  });

  group('LunchboxSuitability', () {
    Recipe recipe({
      Set<String> autoTags = const {},
      TagOverrides? overrides,
      bool withTagResult = true,
    }) {
      final base = RecipeFactory.build(id: 'r1', title: 'r1');
      return Recipe(
        core: base.core.copyWith(
          tagResult: withTagResult
              ? TagResult(
                  tags: autoTags,
                  allergenStatus: const {},
                  dietaryStatus: const {},
                  coverage: 1.0,
                  generatedAt: DateTime(2026),
                )
              : null,
        ),
        type: base.type,
      ).copyWith(tagOverrides: overrides);
    }

    test('the automatic meal-prep tag suits', () {
      expect(
        LunchboxSuitability.suits(recipe(autoTags: {'meal-prep'})),
        isTrue,
      );
    });

    test('a user removing the tag overrides the automatic one', () {
      expect(
        LunchboxSuitability.suits(
          recipe(
            autoTags: {'meal-prep'},
            overrides: const TagOverrides(removedTags: {'meal-prep'}),
          ),
        ),
        isFalse,
      );
    });

    test('a user adding the tag suits without the automatic one', () {
      expect(
        LunchboxSuitability.suits(
          recipe(overrides: const TagOverrides(addedTags: {'meal-prep'})),
        ),
        isTrue,
      );
    });

    test('no tag and no override does not suit, with or without a tag '
        'result', () {
      expect(LunchboxSuitability.suits(recipe(autoTags: {'pasta'})), isFalse);
      expect(LunchboxSuitability.suits(recipe(withTagResult: false)), isFalse);
    });
  });
}

extension on Lunchbox {
  Lunchbox copyForTest({String? recipeId}) => Lunchbox(
    source: source,
    recipeId: recipeId ?? this.recipeId,
    recipeTitle: recipeTitle,
    fromDay: fromDay,
    fromPreviousWeek: fromPreviousWeek,
    portions: portions,
    takerIds: takerIds,
  );
}
