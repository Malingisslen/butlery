/// P5-U23/U24: the week menu's overflow tray at the service layer.
///
/// U23 (produktregler.md:1125, § 22.6): the tray says WHY the rest did not
/// fit. The distribution result carries the reason (which week had no room,
/// and whether passed days were skipped) and the meal type each overflowed
/// recipe was generated for, so the tray can offer next week.
///
/// U24 (produktregler.md:164-172; Q-A11): the tray is kept on the device, per
/// person, 30 days from its last change, and deleted when emptied or at a
/// manual logout ([WeeklyMenuOverflowTrayStore.clearAll]; PQ-12 = A).
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/user_service.dart';

class _MockRepo extends Mock implements WeeklyMenuPlanRepository {}

class _MockUserService extends Mock implements UserService {}

Recipe _recipe(String label) => Recipe.personal(
  title: 'Recept $label',
  description: '',
  ingredients: const [],
  instructions: const [],
  mealType: 'middag',
);

WeeklyMenuOverflowTraySnapshot _snapshot({
  List<String> ids = const ['r1', 'r2'],
  DateTime? savedAt,
}) => WeeklyMenuOverflowTraySnapshot(
  recipeIds: ids,
  mealTypes: {for (final id in ids) id: 'middag'},
  total: 5,
  savedAt: savedAt ?? DateTime(2026, 9, 1),
  reason: WeeklyMenuOverflowReason(
    weekStart: DateTime(2026, 7, 27),
    pastDaysSkipped: true,
  ),
);

void main() {
  group('distributeFromGeneratedMenu: the overflow says why (P5-U23)', () {
    late WeeklyMenuPlanService service;

    setUp(() {
      final users = _MockUserService();
      when(() => users.currentUserProfile).thenReturn(null);
      service = WeeklyMenuPlanService(
        repository: _MockRepo(),
        userService: users,
      );
    });

    test('a full future week gives its week and no passed days', () {
      final monday = DateTime(2026, 4, 13);
      final recipes = [for (var i = 0; i < 9; i++) _recipe('$i')];

      final result = service.distributeFromGeneratedMenu(
        generated: {'middag': recipes},
        weekStart: monday,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: monday),
        now: DateTime(2026, 4, 1),
      );

      expect(result.overflow, hasLength(2));
      expect(result.overflowReason, isNotNull);
      expect(result.overflowReason!.weekStart, monday);
      expect(result.overflowReason!.pastDaysSkipped, isFalse);
      expect(result.overflowReason!.nextWeekOffered, isTrue);
      expect(
        result.overflowReason!.nextWeekStart,
        monday.add(const Duration(days: 7)),
      );
      // Each overflowed recipe keeps the meal type it was generated for.
      expect(result.overflowMealTypes, {
        for (final r in result.overflow) r.id: 'middag',
      });
    });

    test('in the current week, passed days are part of the reason', () {
      final monday = DateTime(2026, 4, 13);
      final wednesday = DateTime(2026, 4, 15, 12);
      final recipes = [for (var i = 0; i < 6; i++) _recipe('$i')];

      final result = service.distributeFromGeneratedMenu(
        generated: {'middag': recipes},
        weekStart: monday,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: monday),
        now: wednesday,
      );

      // Wednesday to Sunday is five places; one does not fit.
      expect(result.overflow, hasLength(1));
      expect(result.overflowReason!.pastDaysSkipped, isTrue);
    });

    test('no overflow means no reason', () {
      final monday = DateTime(2026, 4, 13);
      final result = service.distributeFromGeneratedMenu(
        generated: {
          'middag': [_recipe('a')],
        },
        weekStart: monday,
        existing: WeeklyMenuPlan.empty(userId: 'u', date: monday),
        now: DateTime(2026, 4, 1),
      );

      expect(result.overflow, isEmpty);
      expect(result.overflowReason, isNull);
      expect(result.overflowMealTypes, isEmpty);
    });
  });

  group('WeeklyMenuOverflowTrayStore (P5-U24)', () {
    late WeeklyMenuOverflowTrayStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({'unrelated': 'kept'});
      store = WeeklyMenuOverflowTrayStore();
    });

    test('keeps the tray per person, and brings it back whole', () async {
      await withClock(Clock.fixed(DateTime(2026, 9, 2)), () async {
        await store.save('malin', _snapshot());

        final back = await store.load('malin');
        expect(back, isNotNull);
        expect(back!.recipeIds, ['r1', 'r2']);
        expect(back.mealTypes, {'r1': 'middag', 'r2': 'middag'});
        expect(back.total, 5);
        expect(back.reason!.weekStart, DateTime(2026, 7, 27));
        expect(back.reason!.pastDaysSkipped, isTrue);

        // Another account on the same device never sees it.
        expect(await store.load('johan'), isNull);
      });
    });

    test('lives 30 days from the last change, then is deleted', () async {
      final saved = DateTime(2026, 9, 1, 8);
      await store.save('malin', _snapshot(savedAt: saved));

      await withClock(
        Clock.fixed(saved.add(const Duration(days: 30))),
        () async => expect(await store.load('malin'), isNotNull),
      );
      await withClock(
        Clock.fixed(saved.add(const Duration(days: 30, minutes: 1))),
        () async => expect(await store.load('malin'), isNull),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(WeeklyMenuOverflowTrayStore.keyFor('malin')),
        isFalse,
      );
    });

    test('an emptied tray is deleted, not kept as an empty one', () async {
      await store.save('malin', _snapshot());
      await store.save('malin', _snapshot(ids: const []));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(WeeklyMenuOverflowTrayStore.keyFor('malin')),
        isFalse,
      );
    });

    test(
      'clearAll (manual logout) deletes every tray and nothing else',
      () async {
        await store.save('malin', _snapshot());
        await store.save('johan', _snapshot());

        await WeeklyMenuOverflowTrayStore.clearAll();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where(
            (k) => k.startsWith(WeeklyMenuOverflowTrayStore.keyPrefix),
          ),
          isEmpty,
        );
        expect(prefs.getString('unrelated'), 'kept');
      },
    );

    test(
      "clearAll for the person logging out keeps another account's tray",
      () async {
        await store.save('malin', _snapshot());
        await store.save('johan', _snapshot());

        await WeeklyMenuOverflowTrayStore.clearAll(userId: 'malin');

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(WeeklyMenuOverflowTrayStore.keyFor('malin')),
          isNull,
        );
        expect(
          prefs.getString(WeeklyMenuOverflowTrayStore.keyFor('johan')),
          isNotNull,
        );
        expect(prefs.getString('unrelated'), 'kept');
      },
    );

    test('unreadable data is dropped instead of breaking the tray', () async {
      SharedPreferences.setMockInitialValues({
        WeeklyMenuOverflowTrayStore.keyFor('malin'): '{not json',
      });

      expect(await WeeklyMenuOverflowTrayStore().load('malin'), isNull);
    });
  });
}
