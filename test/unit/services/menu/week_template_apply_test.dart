// BUT-2522: putting a week template on a week. "Fyll tomma platser" touches
// only empty places, "Ersätt allt" only the places the template covers, a
// deleted recipe is never placed, and undo gives back exactly what changed.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/week_template_apply.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

final _week = DateTime(2026, 4, 6);

WeeklyMenuPlan _plan(List<WeeklyMenuPlanEntry> entries) =>
    WeeklyMenuPlan.empty(userId: 'u', date: _week).copyWith(entries: entries);

WeeklyMenuPlanEntry _planned(DayOfWeek day, MealSlot slot, String id) =>
    WeeklyMenuPlanEntry.create(
      day: day,
      slot: slot,
      recipeId: id,
      recipeTitle: id,
    );

TemplateDish _dish(
  DayOfWeek day,
  MealSlot slot,
  String id, {
  TemplateDishState state = TemplateDishState.found,
  String? currentTitle,
}) => TemplateDish(
  entry: WeekTemplateEntry(
    day: day,
    slot: slot,
    recipeId: id,
    recipeTitle: 'sparat $id',
  ),
  state: state,
  recipe: state == TemplateDishState.found
      ? RecipeFactory.build(id: id, title: currentTitle ?? id)
      : null,
);

List<String> _at(WeeklyMenuPlan plan, DayOfWeek day, MealSlot slot) => [
  for (final e in plan.entries)
    if (e.day == day && e.slot == slot) e.recipeId,
];

void main() {
  const mon = DayOfWeek.mon;
  const tue = DayOfWeek.tue;
  const wed = DayOfWeek.wed;
  const middag = MealSlot.middag;
  const ovrigt = MealSlot.ovrigt;

  group('fillEmpty', () {
    test('fills only places with nothing planned', () {
      final plan = _plan([_planned(mon, middag, 'kvar')]);
      final result = WeekTemplateApply.apply(
        plan: plan,
        dishes: [_dish(mon, middag, 'lax'), _dish(tue, middag, 'tacos')],
        mode: WeekTemplateApplyMode.fillEmpty,
      );

      expect(_at(result.plan, mon, middag), ['kvar']);
      expect(_at(result.plan, tue, middag), ['tacos']);
      expect(result.addedEntryIds, hasLength(1));
      expect(result.removedEntries, isEmpty);
    });

    test('övrigt holds several dishes, so only the same recipe is skipped', () {
      final plan = _plan([_planned(mon, ovrigt, 'bullar')]);
      final result = WeekTemplateApply.apply(
        plan: plan,
        dishes: [_dish(mon, ovrigt, 'bullar'), _dish(mon, ovrigt, 'smoothie')],
        mode: WeekTemplateApplyMode.fillEmpty,
      );

      expect(_at(result.plan, mon, ovrigt), ['bullar', 'smoothie']);
    });
  });

  group('replace', () {
    test('overwrites the places the template covers and leaves the rest', () {
      final kept = _planned(wed, middag, 'onsdag');
      final replaced = _planned(mon, middag, 'gammal');
      final plan = _plan([replaced, kept]);

      final result = WeekTemplateApply.apply(
        plan: plan,
        dishes: [_dish(mon, middag, 'lax')],
        mode: WeekTemplateApplyMode.replace,
      );

      expect(_at(result.plan, mon, middag), ['lax']);
      expect(_at(result.plan, wed, middag), ['onsdag']);
      expect(result.removedEntries.map((e) => e.id), [replaced.id]);
    });

    test('a missing recipe does not clear the place it would have taken', () {
      final plan = _plan([_planned(mon, middag, 'kvar')]);
      final result = WeekTemplateApply.apply(
        plan: plan,
        dishes: [
          _dish(mon, middag, 'raderad', state: TemplateDishState.missing),
        ],
        mode: WeekTemplateApplyMode.replace,
      );

      expect(_at(result.plan, mon, middag), ['kvar']);
      expect(result.missingCount, 1);
      expect(result.changed, isFalse);
    });

    test('replaces every övrigt dish of that day once', () {
      final plan = _plan([_planned(mon, ovrigt, 'gammal')]);
      final result = WeekTemplateApply.apply(
        plan: plan,
        dishes: [_dish(mon, ovrigt, 'a'), _dish(mon, ovrigt, 'b')],
        mode: WeekTemplateApplyMode.replace,
      );

      expect(_at(result.plan, mon, ovrigt), ['a', 'b']);
      expect(result.removedEntries, hasLength(1));
    });
  });

  group('names', () {
    test('a renamed recipe is placed under its current title, an unreadable '
        'one under the saved title, and a deleted one not at all', () {
      final result = WeekTemplateApply.apply(
        plan: _plan(const []),
        dishes: [
          _dish(mon, middag, 'r1', currentTitle: 'Nytt namn'),
          _dish(tue, middag, 'r2', state: TemplateDishState.unverified),
          _dish(wed, middag, 'r3', state: TemplateDishState.missing),
        ],
        mode: WeekTemplateApplyMode.fillEmpty,
      );

      final titles = {
        for (final e in result.plan.entries) e.recipeId: e.recipeTitle,
      };
      expect(titles, {'r1': 'Nytt namn', 'r2': 'sparat r2'});
      expect(result.missingCount, 1);
    });
  });

  group('overlaps', () {
    test('true only when a dish would land on a taken place', () {
      final plan = _plan([_planned(mon, middag, 'x')]);
      expect(
        WeekTemplateApply.overlaps(plan, [_dish(tue, middag, 'a')]),
        isFalse,
      );
      expect(
        WeekTemplateApply.overlaps(plan, [_dish(mon, middag, 'a')]),
        isTrue,
      );
      expect(
        WeekTemplateApply.overlaps(plan, [
          _dish(mon, middag, 'a', state: TemplateDishState.missing),
        ]),
        isFalse,
      );
    });
  });

  group('undo', () {
    test('removes what was added, restores what was replaced, keeps later '
        'edits to other places', () {
      final replaced = _planned(mon, middag, 'gammal');
      final result = WeekTemplateApply.apply(
        plan: _plan([replaced]),
        dishes: [_dish(mon, middag, 'lax'), _dish(tue, middag, 'tacos')],
        mode: WeekTemplateApplyMode.replace,
      );
      final later = _planned(wed, middag, 'senare');
      final current = result.plan.copyWith(
        entries: [...result.plan.entries, later],
      );

      final undone = WeekTemplateApply.undo(current, result);

      expect(undone.entries.map((e) => e.id).toSet(), {replaced.id, later.id});
    });

    test('a replaced dish does not return to a place filled again since', () {
      final replaced = _planned(mon, middag, 'gammal');
      final result = WeekTemplateApply.apply(
        plan: _plan([replaced]),
        dishes: [_dish(mon, middag, 'lax')],
        mode: WeekTemplateApplyMode.replace,
      );
      final refilled = _planned(mon, middag, 'nytt');
      final current = result.plan.copyWith(
        entries: [
          for (final e in result.plan.entries)
            if (!result.addedEntryIds.contains(e.id)) e,
          refilled,
        ],
      );

      final undone = WeekTemplateApply.undo(current, result);

      expect(_at(undone, mon, middag), ['nytt']);
    });
  });
}
