// BUT-1625: MealDislikes decides, per (day, slot), whether someone who is
// home dislikes a dish. Presence unset = everyone, presence empty = nobody,
// and övrigt always counts the whole household.

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

const _parent = 'parent';
const _kid = 'kid';

Recipe _dish(
  String id, {
  String mealType = 'middag',
  List<String> ingredients = const ['1 gul lök, hackad', '400 g pasta'],
}) => RecipeFactory.build(
  id: id,
  title: id,
  mealType: mealType,
  ingredients: ingredients,
);

Recipe _plainDish(String id, {String mealType = 'middag'}) =>
    _dish(id, mealType: mealType, ingredients: const ['400 g pasta']);

WeeklyMenuPlan _plan({
  Map<DayOfWeek, Map<MealSlot, List<String>>> presence = const {},
}) => WeeklyMenuPlan(
  id: 'u_2026-W15',
  userId: 'u',
  weekStartDate: DateTime(2026, 4, 6),
  entries: const [],
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  presenceBySlot: presence,
);

MealDislikes _kidDislikesOnion(WeeklyMenuPlan? plan) => MealDislikes(
  dislikesByMember: {
    _kid: {'lök'},
    _parent: <String>{},
  },
  plan: plan,
);

void main() {
  group('avoids', () {
    test('with no presence set, everyone is home: the dish is avoided', () {
      final dislikes = _kidDislikesOnion(_plan());
      expect(dislikes.avoids(_dish('a'), DayOfWeek.mon, MealSlot.middag), true);
      expect(dislikes.avoids(_dish('a'), DayOfWeek.mon, MealSlot.lunch), true);
    });

    test('a plan-less MealDislikes also treats everyone as home', () {
      expect(
        _kidDislikesOnion(
          null,
        ).avoids(_dish('a'), DayOfWeek.sun, MealSlot.middag),
        true,
      );
    });

    test('a dish nobody dislikes is never avoided', () {
      expect(
        _kidDislikesOnion(_plan()).avoids(
          _plainDish('p'),
          DayOfWeek.mon,
          MealSlot.middag,
        ),
        false,
      );
    });

    test('a member away on that slot does not make the dish avoided', () {
      final dislikes = _kidDislikesOnion(
        _plan(
          presence: {
            DayOfWeek.tue: {
              MealSlot.middag: [_parent],
            },
          },
        ),
      );
      expect(
        dislikes.avoids(_dish('a'), DayOfWeek.tue, MealSlot.middag),
        false,
      );
      // Same plan, other day: no selection there, so the kid is home.
      expect(dislikes.avoids(_dish('a'), DayOfWeek.wed, MealSlot.middag), true);
    });

    test('presence is read per slot: away at middag still counts at lunch', () {
      final dislikes = _kidDislikesOnion(
        _plan(
          presence: {
            DayOfWeek.tue: {
              MealSlot.middag: [_parent],
            },
          },
        ),
      );
      expect(dislikes.avoids(_dish('a'), DayOfWeek.tue, MealSlot.lunch), true);
    });

    test('the dislike belongs to the member who is home, not just anyone', () {
      final dislikes = MealDislikes(
        dislikesByMember: {
          _kid: {'lök'},
          _parent: {'svamp'},
        },
        plan: _plan(
          presence: {
            DayOfWeek.mon: {
              MealSlot.middag: [_parent],
            },
          },
        ),
      );
      final onion = _dish('onion');
      final mushroom = _dish('mushroom', ingredients: ['250 g champinjoner']);
      expect(dislikes.avoids(onion, DayOfWeek.mon, MealSlot.middag), false);
      expect(dislikes.avoids(mushroom, DayOfWeek.mon, MealSlot.middag), true);
    });

    test('an explicitly empty presence means nobody is home: not avoided', () {
      final dislikes = _kidDislikesOnion(
        _plan(
          presence: {
            DayOfWeek.mon: {MealSlot.middag: <String>[]},
          },
        ),
      );
      expect(
        dislikes.avoids(_dish('a'), DayOfWeek.mon, MealSlot.middag),
        false,
      );
    });

    test('övrigt counts every member even when presence excludes them', () {
      // Presence for lunch and middag both exclude the kid.
      final dislikes = _kidDislikesOnion(
        _plan(
          presence: {
            DayOfWeek.mon: {
              MealSlot.lunch: [_parent],
              MealSlot.middag: [_parent],
            },
          },
        ),
      );
      final snack = _dish('snack', mealType: 'dessert');
      expect(dislikes.avoids(snack, DayOfWeek.mon, MealSlot.ovrigt), true);
    });

    test('övrigt ignores even an explicit övrigt presence entry', () {
      // The app never writes presence for övrigt; the model would still
      // carry it, and övrigt must keep counting the whole household.
      final dislikes = _kidDislikesOnion(
        _plan(
          presence: {
            DayOfWeek.mon: {
              MealSlot.ovrigt: [_parent],
            },
          },
        ),
      );
      final snack = _dish('snack', mealType: 'dessert');
      expect(dislikes.avoids(snack, DayOfWeek.mon, MealSlot.ovrigt), true);
    });

    test('övrigt is not avoided when the dish is not disliked', () {
      expect(
        _kidDislikesOnion(_plan()).avoids(
          _plainDish('snack', mealType: 'dessert'),
          DayOfWeek.mon,
          MealSlot.ovrigt,
        ),
        false,
      );
    });

    test('members with an empty dislike set contribute nothing', () {
      final dislikes = MealDislikes(
        dislikesByMember: {
          _kid: <String>{},
          _parent: <String>{},
        },
        plan: _plan(),
      );
      expect(dislikes.isEmpty, true);
      expect(
        dislikes.avoids(_dish('a'), DayOfWeek.mon, MealSlot.middag),
        false,
      );
    });
  });

  group('MealDislikes.none', () {
    test('never avoids and never calls anything unplaceable', () {
      final none = MealDislikes.none;
      expect(none.isEmpty, true);
      for (final day in DayOfWeek.values) {
        for (final slot in MealSlot.values) {
          expect(none.avoids(_dish('a'), day, slot), false);
        }
      }
      expect(none.unplaceable(_dish('a')), false);
      expect(none.unplaceableIds([_dish('a')]), isEmpty);
    });
  });

  group('unplaceable', () {
    Map<DayOfWeek, Map<MealSlot, List<String>>> kidAway(
      DayOfWeek day,
      MealSlot slot,
    ) => {
      day: {
        slot: [_parent],
      },
    };

    test('a dish every home-day dislikes cannot be placed', () {
      expect(_kidDislikesOnion(_plan()).unplaceable(_dish('a')), true);
    });

    test('one day the member is away makes it placeable', () {
      final dislikes = _kidDislikesOnion(
        _plan(presence: kidAway(DayOfWeek.thu, MealSlot.middag)),
      );
      expect(dislikes.unplaceable(_dish('a')), false);
    });

    test('an away day before fromDay does not count', () {
      final dislikes = _kidDislikesOnion(
        _plan(presence: kidAway(DayOfWeek.tue, MealSlot.middag)),
      );
      expect(dislikes.unplaceable(_dish('a')), false);
      expect(dislikes.unplaceable(_dish('a'), fromDay: DayOfWeek.tue), false);
      expect(dislikes.unplaceable(_dish('a'), fromDay: DayOfWeek.wed), true);
    });

    test('an away day on the last day is still reached from any fromDay', () {
      final dislikes = _kidDislikesOnion(
        _plan(presence: kidAway(DayOfWeek.sun, MealSlot.middag)),
      );
      expect(dislikes.unplaceable(_dish('a'), fromDay: DayOfWeek.sat), false);
    });

    test('a lunch dish is judged on lunch meals, not middag meals', () {
      final dislikes = _kidDislikesOnion(
        _plan(presence: kidAway(DayOfWeek.wed, MealSlot.middag)),
      );
      expect(dislikes.unplaceable(_dish('lunch', mealType: 'lunch')), true);
      expect(dislikes.unplaceable(_dish('dinner', mealType: 'middag')), false);
    });

    test('a middag dish is judged on middag meals, not lunch meals', () {
      final dislikes = _kidDislikesOnion(
        _plan(presence: kidAway(DayOfWeek.wed, MealSlot.lunch)),
      );
      expect(dislikes.unplaceable(_dish('dinner', mealType: 'middag')), true);
      expect(dislikes.unplaceable(_dish('lunch', mealType: 'lunch')), false);
    });
  });

  group('unplaceableIds', () {
    test('names only the disliked, unplaceable dishes of the pool', () {
      final dislikes = _kidDislikesOnion(_plan());
      final pool = [
        _dish('onion-dinner'),
        _plainDish('plain-dinner'),
        _dish('onion-lunch', mealType: 'lunch'),
      ];
      expect(dislikes.unplaceableIds(pool), {'onion-dinner', 'onion-lunch'});
    });

    test('honours fromDay', () {
      final dislikes = _kidDislikesOnion(
        _plan(
          presence: {
            DayOfWeek.mon: {
              MealSlot.middag: [_parent],
            },
          },
        ),
      );
      final pool = [_dish('onion-dinner')];
      expect(dislikes.unplaceableIds(pool), isEmpty);
      expect(dislikes.unplaceableIds(pool, fromDay: DayOfWeek.tue), {
        'onion-dinner',
      });
    });

    test('an empty pool yields nothing', () {
      expect(_kidDislikesOnion(_plan()).unplaceableIds(const []), isEmpty);
    });
  });
}
