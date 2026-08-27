/// Direct unit tests for [WeeklyMenuPlan] + companions (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Core weekly-plan model. Covers the MealSlot/DayOfWeek enums (isMulti,
/// isoWeekday, labels, fromName fallbacks, fromDateTime), WeeklyMenuPlanEntry
/// (create, map round-trip, copyWith, id equality), and WeeklyMenuPlan (the
/// empty factory, entryAt/entriesAt/isOccupied lookups, copyWith bumping
/// updatedAt, and the Firestore round-trip with schemaVersion default).
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';

void main() {
  group('MealSlot', () {
    test('isMulti only for övrigt', () {
      expect(MealSlot.ovrigt.isMulti, isTrue);
      expect(MealSlot.lunch.isMulti, isFalse);
      expect(MealSlot.middag.isMulti, isFalse);
    });

    test('displayLabel is the lowercase Swedish label', () {
      expect(MealSlot.lunch.displayLabel, 'lunch');
      expect(MealSlot.middag.displayLabel, 'middag');
      expect(MealSlot.ovrigt.displayLabel, 'övrigt');
    });

    test('fromName parses or falls back to middag', () {
      expect(MealSlot.fromName('lunch'), MealSlot.lunch);
      expect(MealSlot.fromName('bogus'), MealSlot.middag);
    });
  });

  group('DayOfWeek', () {
    test('isoWeekday maps Mon=1..Sun=7', () {
      expect(DayOfWeek.mon.isoWeekday, 1);
      expect(DayOfWeek.sun.isoWeekday, 7);
    });

    test('displayLabel is the 3-letter Swedish day', () {
      expect(DayOfWeek.mon.displayLabel, 'mån');
      expect(DayOfWeek.sun.displayLabel, 'sön');
      for (final d in DayOfWeek.values) {
        expect(d.displayLabel.trim(), isNotEmpty);
      }
    });

    test('fromDateTime maps a real date to its weekday', () {
      // 2026-01-05 is a Monday, 2026-01-11 a Sunday.
      expect(DayOfWeek.fromDateTime(DateTime.utc(2026, 1, 5)), DayOfWeek.mon);
      expect(DayOfWeek.fromDateTime(DateTime.utc(2026, 1, 11)), DayOfWeek.sun);
    });

    test('fromName parses or falls back to mon', () {
      expect(DayOfWeek.fromName('fri'), DayOfWeek.fri);
      expect(DayOfWeek.fromName('bogus'), DayOfWeek.mon);
    });
  });

  group('WeeklyMenuPlanEntry', () {
    test('create generates an id and sets fields', () {
      final e = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.middag,
        recipeId: 'r1',
        recipeTitle: 'Pasta',
      );
      expect(e.id, isNotEmpty);
      expect(e.day, DayOfWeek.mon);
      expect(e.recipeTitle, 'Pasta');
    });

    test('toMap → fromMap round-trips, omitting a null image', () {
      final e = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.fri,
        slot: MealSlot.ovrigt,
        recipeId: 'r2',
        recipeTitle: 'Kaka',
      );
      final map = e.toMap();
      expect(map.containsKey('recipeImageUrl'), isFalse);
      final restored = WeeklyMenuPlanEntry.fromMap(map);
      expect(restored.id, e.id);
      expect(restored.day, DayOfWeek.fri);
      expect(restored.slot, MealSlot.ovrigt);
      expect(restored.recipeId, 'r2');
    });

    test('copyWith changes day/slot, preserves identity + recipe', () {
      final e = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.lunch,
        recipeId: 'r1',
        recipeTitle: 'Soppa',
      );
      final moved = e.copyWith(day: DayOfWeek.tue, slot: MealSlot.middag);
      expect(moved.day, DayOfWeek.tue);
      expect(moved.slot, MealSlot.middag);
      expect(moved.id, e.id);
      expect(moved.recipeId, 'r1');
    });

    test('equality is by id', () {
      final a = WeeklyMenuPlanEntry.create(
        day: DayOfWeek.mon,
        slot: MealSlot.lunch,
        recipeId: 'r1',
        recipeTitle: 'A',
      );
      expect(a, equals(a.copyWith(day: DayOfWeek.sun)));
    });
  });

  group('WeeklyMenuPlan', () {
    WeeklyMenuPlanEntry entry(DayOfWeek d, MealSlot s, String id) =>
        WeeklyMenuPlanEntry(
          id: id,
          day: d,
          slot: s,
          recipeId: 'r-$id',
          recipeTitle: 't-$id',
        );

    WeeklyMenuPlan planWith(List<WeeklyMenuPlanEntry> entries) =>
        WeeklyMenuPlan(
          id: 'u1_2026-W02',
          userId: 'u1',
          weekStartDate: DateTime.utc(2026, 1, 5),
          entries: entries,
          createdAt: DateTime.utc(2026, 1, 5),
          updatedAt: DateTime.utc(2026, 1, 5),
        );

    test('empty starts on a Monday with no entries (clock-pinned)', () {
      // `expect(plan.createdAt, t)` below is a GUARD, not a detail, and
      // `weekly-menu-plans-rules.test.ts` names this test as what holds it:
      // W2 asserts that a plan built here cannot overwrite a stored week,
      // which is true only while this factory stamps a fresh `createdAt`.
      // W2 builds its body from a literal, so it cannot catch that changing.
      // The group model test carries the same guard for its own factory.
      final t = DateTime.utc(2026, 1, 7); // the clock: a Wednesday
      // A DIFFERENT instant in the same ISO week. Passing the clock instant as
      // `date` too would let a `createdAt: date` mutant survive a test named
      // for the clock. Mirrors the group model test.
      final target = DateTime.utc(2026, 1, 9);
      withClock(Clock.fixed(t), () {
        final plan = WeeklyMenuPlan.empty(userId: 'u1', date: target);
        expect(plan.userId, 'u1');
        expect(plan.id, contains('u1'));
        expect(plan.weekStartDate.weekday, DateTime.monday);
        expect(plan.entries, isEmpty);
        expect(plan.createdAt, t);
        expect(plan.updatedAt, t);
        expect(plan.schemaVersion, 1);
      });
    });

    test('entryAt / isOccupied find a single-slot entry', () {
      final plan = planWith([entry(DayOfWeek.mon, MealSlot.middag, 'e1')]);
      expect(plan.entryAt(DayOfWeek.mon, MealSlot.middag)?.id, 'e1');
      expect(plan.entryAt(DayOfWeek.tue, MealSlot.middag), isNull);
      expect(plan.isOccupied(DayOfWeek.mon, MealSlot.middag), isTrue);
      expect(plan.isOccupied(DayOfWeek.tue, MealSlot.lunch), isFalse);
    });

    test('entriesAt returns all entries in a multi slot', () {
      final plan = planWith([
        entry(DayOfWeek.mon, MealSlot.ovrigt, 'a'),
        entry(DayOfWeek.mon, MealSlot.ovrigt, 'b'),
        entry(DayOfWeek.mon, MealSlot.lunch, 'c'),
      ]);
      final ovrigt = plan.entriesAt(DayOfWeek.mon, MealSlot.ovrigt);
      expect(ovrigt.map((e) => e.id), ['a', 'b']);
    });

    test('isEmpty / isNotEmpty', () {
      expect(planWith([]).isEmpty, isTrue);
      expect(
        planWith([entry(DayOfWeek.mon, MealSlot.lunch, 'x')]).isNotEmpty,
        isTrue,
      );
    });

    test('copyWith bumps updatedAt to now and keeps createdAt', () {
      final base = planWith([]);
      final t = DateTime.utc(2026, 2, 1);
      withClock(Clock.fixed(t), () {
        final updated = base.copyWith(
          entries: [entry(DayOfWeek.wed, MealSlot.lunch, 'z')],
        );
        expect(updated.updatedAt, t);
        expect(updated.createdAt, base.createdAt);
        expect(updated.entries, hasLength(1));
      });
    });

    test('toFirestore → fromMap round-trips', () {
      final plan = planWith([entry(DayOfWeek.mon, MealSlot.middag, 'e1')]);
      final restored = WeeklyMenuPlan.fromMap(
        'u1_2026-W02',
        plan.toFirestore(),
      );
      expect(restored.id, 'u1_2026-W02');
      expect(restored.userId, 'u1');
      expect(restored.entries, hasLength(1));
      expect(restored.schemaVersion, 1);
      expect(
        restored.weekStartDate.isAtSameMomentAs(DateTime.utc(2026, 1, 5)),
        isTrue,
      );
    });

    test('fromMap defaults schemaVersion to 1 when absent', () {
      final restored = WeeklyMenuPlan.fromMap('id', {
        'userId': 'u1',
        'weekStartDate': '2026-01-05T00:00:00.000Z',
        'createdAt': '2026-01-05T00:00:00.000Z',
        'updatedAt': '2026-01-05T00:00:00.000Z',
        'entries': const [],
      });
      expect(restored.schemaVersion, 1);
      expect(restored.entries, isEmpty);
    });
  });

  group('WeeklyMenuPlan per-slot presence (BUT-1611)', () {
    WeeklyMenuPlan planWithPresence(
      Map<DayOfWeek, Map<MealSlot, List<String>>> presence,
    ) => WeeklyMenuPlan(
      id: 'u1_2026-W02',
      userId: 'u1',
      weekStartDate: DateTime.utc(2026, 1, 5),
      entries: const [],
      createdAt: DateTime.utc(2026, 1, 5),
      updatedAt: DateTime.utc(2026, 1, 5),
      presenceBySlot: presence,
    );

    test('presence round-trips through Firestore serialization', () {
      // Intent: the per-(day, slot) selection a user makes must come back
      // exactly — including a diner home for middag but away at lunch on the
      // same day, and an explicitly-emptied slot ("nobody home"), which is a
      // real selection distinct from an unset slot.
      final plan = planWithPresence({
        DayOfWeek.mon: {
          MealSlot.lunch: ['m1'],
          MealSlot.middag: ['m1', 'm2'],
        },
        DayOfWeek.fri: {MealSlot.lunch: []},
      });
      final restored = WeeklyMenuPlan.fromMap(
        'u1_2026-W02',
        plan.toFirestore(),
      );
      expect(restored.presentMemberIdsFor(DayOfWeek.mon, MealSlot.lunch), [
        'm1',
      ]);
      expect(restored.presentMemberIdsFor(DayOfWeek.mon, MealSlot.middag), [
        'm1',
        'm2',
      ]);
      expect(
        restored.presentMemberIdsFor(DayOfWeek.fri, MealSlot.lunch),
        isEmpty,
      );
      expect(
        restored.presentMemberIdsFor(DayOfWeek.mon, MealSlot.ovrigt),
        isNull,
      );
      expect(
        restored.presentMemberIdsFor(DayOfWeek.tue, MealSlot.lunch),
        isNull,
      );
    });

    test('docs saved before the field parse to no presence', () {
      final legacy = planWithPresence(const {});
      final map = legacy.toFirestore();
      expect(map.containsKey('presenceBySlot'), isFalse);
      final restored = WeeklyMenuPlan.fromMap('u1_2026-W02', map);
      expect(restored.presenceBySlot, isEmpty);
      expect(
        restored.presentMemberIdsFor(DayOfWeek.mon, MealSlot.lunch),
        isNull,
      );
    });

    test('malformed presence values are dropped, not corrupted', () {
      final restored = WeeklyMenuPlan.fromMap('u1_2026-W02', {
        ...planWithPresence(const {}).toFirestore(),
        'presenceBySlot': {
          'mon': {
            'lunch': ['m1', 42],
            'notaslot': ['m9'],
            'middag': 'not-a-list',
          },
          'notaday': {
            'lunch': ['m9'],
          },
          'tue': 'not-a-map',
        },
      });
      expect(restored.presentMemberIdsFor(DayOfWeek.mon, MealSlot.lunch), [
        'm1',
      ]);
      expect(
        restored.presentMemberIdsFor(DayOfWeek.mon, MealSlot.middag),
        isNull,
      );
      expect(
        restored.presentMemberIdsFor(DayOfWeek.tue, MealSlot.lunch),
        isNull,
      );
      expect(restored.presenceBySlot.keys, [DayOfWeek.mon]);
    });

    test('copyWith(entries:) preserves the presence map', () {
      // Intent: every existing plan mutation (add/move/clear entries) goes
      // through copyWith — a presence selection must survive them all.
      final plan = planWithPresence({
        DayOfWeek.wed: {
          MealSlot.middag: ['m1'],
        },
      });
      final mutated = plan.copyWith(entries: const []);
      expect(mutated.presentMemberIdsFor(DayOfWeek.wed, MealSlot.middag), [
        'm1',
      ]);
    });
  });
}
