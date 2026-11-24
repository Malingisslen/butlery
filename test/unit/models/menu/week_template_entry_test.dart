// BUT-2522: a week template is stored on a `menus` document whose rules bound
// nothing, so what comes back is parsed as untrusted, and the fields survive
// both the Firestore and the cache round trip.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/shared_menu.dart';

WeeklyMenuPlanEntry _entry(DayOfWeek day, MealSlot slot, String recipeId) =>
    WeeklyMenuPlanEntry.create(
      day: day,
      slot: slot,
      recipeId: recipeId,
      recipeTitle: 'Titel $recipeId',
    );

void main() {
  group('WeekTemplateEntry.fromPlan', () {
    test('stores the week in day and meal order, without ids that name '
        'another path', () {
      final plan = WeeklyMenuPlan.empty(userId: 'u', date: DateTime(2026, 4, 6))
          .copyWith(
            entries: [
              _entry(DayOfWeek.wed, MealSlot.middag, 'c'),
              _entry(DayOfWeek.mon, MealSlot.middag, 'b'),
              _entry(DayOfWeek.mon, MealSlot.lunch, 'a'),
              _entry(DayOfWeek.tue, MealSlot.middag, 'x/y'),
            ],
          );

      final entries = WeekTemplateEntry.fromPlan(plan);

      expect(entries.map((e) => e.recipeId), ['a', 'b', 'c']);
      expect(entries.first.recipeTitle, 'Titel a');
    });
  });

  group('WeekTemplateEntry.listFrom', () {
    test('drops malformed entries instead of throwing', () {
      final parsed = WeekTemplateEntry.listFrom([
        {
          'day': 'mon',
          'slot': 'middag',
          'recipeId': 'ok',
          'recipeTitle': 'Laxpasta',
        },
        {'day': 'someday', 'slot': 'middag', 'recipeId': 'r1'},
        {'day': 'mon', 'slot': 'brunch', 'recipeId': 'r2'},
        {'day': 'mon', 'slot': 'middag', 'recipeId': '../users/other'},
        {'day': 'mon', 'slot': 'middag', 'recipeId': ''},
        {'day': 'mon', 'slot': 'middag', 'recipeId': 42},
        'not a map',
        null,
      ]);

      expect(parsed, [
        const WeekTemplateEntry(
          day: DayOfWeek.mon,
          slot: MealSlot.middag,
          recipeId: 'ok',
          recipeTitle: 'Laxpasta',
        ),
      ]);
    });

    test('a non-list value reads as no entries', () {
      expect(WeekTemplateEntry.listFrom('nope'), isEmpty);
      expect(WeekTemplateEntry.listFrom(null), isEmpty);
    });

    test('caps the number of entries and the title length', () {
      final raw = [
        for (var i = 0; i < WeekTemplateEntry.maxEntries + 10; i++)
          {
            'day': 'mon',
            'slot': 'ovrigt',
            'recipeId': 'r$i',
            'recipeTitle': 'x' * (WeekTemplateEntry.maxTitleLength + 50),
          },
      ];

      final parsed = WeekTemplateEntry.listFrom(raw);

      expect(parsed, hasLength(WeekTemplateEntry.maxEntries));
      expect(
        parsed.first.recipeTitle.length,
        WeekTemplateEntry.maxTitleLength,
      );
    });

    test('an id longer than the cap is dropped', () {
      final parsed = WeekTemplateEntry.listFrom([
        {
          'day': 'mon',
          'slot': 'middag',
          'recipeId': 'a' * (WeekTemplateEntry.maxRecipeIdLength + 1),
        },
      ]);
      expect(parsed, isEmpty);
    });
  });

  group('SharedMenu template fields', () {
    final entries = [
      const WeekTemplateEntry(
        day: DayOfWeek.fri,
        slot: MealSlot.middag,
        recipeId: 'pizza',
        recipeTitle: 'Pizza',
      ),
    ];

    SharedMenu template() => SharedMenu(
      id: 'm1',
      sharedByUserId: 'u',
      sharedByDisplayName: 'Malin',
      menuTitle: 'Sommarveckan',
      menuSnapshot: const {},
      templateKind: SharedMenu.weekTemplateKind,
      templateEntries: entries,
    );

    test('survive the Firestore round trip', () {
      final data = template().toFirestore();
      expect(data['templateKind'], 'week');
      expect(data['templateEntries'], [
        {
          'day': 'fri',
          'slot': 'middag',
          'recipeId': 'pizza',
          'recipeTitle': 'Pizza',
        },
      ]);

      final read = SharedMenu.fromMap('m1', data);
      expect(read.isWeekTemplate, isTrue);
      expect(read.templateEntries, entries);
      expect(read.totalRecipeCount, 0);
    });

    test('survive the cache round trip and copyWith', () {
      final read = SharedMenu.fromJson(template().toJson());
      expect(read.isWeekTemplate, isTrue);
      expect(read.templateEntries, entries);

      final copied = read.copyWith(viewCount: 3);
      expect(copied.isWeekTemplate, isTrue);
      expect(copied.templateEntries, entries);
    });

    test('a saved menu writes neither field and is not a template', () {
      final menu = SharedMenu(
        id: 'm2',
        sharedByUserId: 'u',
        sharedByDisplayName: 'Malin',
        menuTitle: 'Meny',
        menuSnapshot: const {},
      );
      final data = menu.toFirestore();
      expect(data.containsKey('templateKind'), isFalse);
      expect(data.containsKey('templateEntries'), isFalse);
      expect(SharedMenu.fromMap('m2', data).isWeekTemplate, isFalse);
    });
  });
}
