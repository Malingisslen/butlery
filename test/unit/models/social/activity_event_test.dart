/// Tests for the ActivityEventType enum extension (BUT-407).
///
/// Focus: new types (`addedIngredient`, `startedCooking`, `pinged`) serialize
/// via `.name`, deserialize round-trip, and older clients receiving unknown
/// event types still fall back to `cooked` (forward-compat guarantee).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/social/activity_event.dart';

void main() {
  group('ActivityEventType extension (BUT-407)', () {
    test('new types are present in .values', () {
      expect(ActivityEventType.values,
          contains(ActivityEventType.addedIngredient));
      expect(
          ActivityEventType.values, contains(ActivityEventType.startedCooking));
      expect(ActivityEventType.values, contains(ActivityEventType.pinged));
      // Existing types still there — no breaking removals.
      expect(ActivityEventType.values, contains(ActivityEventType.cooked));
      expect(ActivityEventType.values, contains(ActivityEventType.shared));
    });

    test('new types round-trip through .name / fromString', () {
      for (final type in [
        ActivityEventType.addedIngredient,
        ActivityEventType.startedCooking,
        ActivityEventType.pinged,
      ]) {
        expect(ActivityEventType.fromString(type.name), equals(type),
            reason: 'round-trip for ${type.name}');
      }
    });

    test('older clients receiving unknown future type fall back to cooked', () {
      expect(
        ActivityEventType.fromString('someFutureType'),
        equals(ActivityEventType.cooked),
      );
      expect(
        ActivityEventType.fromString(''),
        equals(ActivityEventType.cooked),
      );
    });

    test('ActivityEvent with pinged type round-trips via toFirestore/fromMap',
        () {
      final event = ActivityEvent.create(
        actorId: 'alice',
        actorDisplayName: 'Alice',
        type: ActivityEventType.pinged,
        recipeId: 'recipe-1',
        recipeTitle: 'Köttbullar',
        extraData: {'pingType': 'nudge', 'groupId': 'g-1'},
      );

      final map = event.toFirestore();
      expect(map['type'], equals('pinged'),
          reason: 'serialises via .name — matches existing wire format');

      final restored = ActivityEvent.fromMap(event.id, map);
      expect(restored.type, equals(ActivityEventType.pinged));
      expect(restored.actorId, equals('alice'));
      expect(restored.recipeTitle, equals('Köttbullar'));
      expect(restored.extraData['pingType'], equals('nudge'));
    });

    test(
        'ActivityEvent with startedCooking / addedIngredient survive round-trip',
        () {
      for (final type in [
        ActivityEventType.startedCooking,
        ActivityEventType.addedIngredient,
      ]) {
        final event = ActivityEvent.create(
          actorId: 'u',
          actorDisplayName: 'U',
          type: type,
          recipeId: 'r',
          recipeTitle: 'T',
        );
        final restored = ActivityEvent.fromMap(event.id, event.toFirestore());
        expect(restored.type, equals(type),
            reason: 'round-trip for ${type.name}');
      }
    });
  });
}
