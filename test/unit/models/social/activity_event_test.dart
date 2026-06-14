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

  group('ActivityEvent.photoUrls getter (BUT-949)', () {
    ActivityEvent withExtra(Map<String, dynamic> extraData) => ActivityEvent(
          id: 'e1',
          actorId: 'a',
          actorDisplayName: 'A',
          type: ActivityEventType.cooked,
          recipeId: 'r',
          recipeTitle: 'T',
          extraData: extraData,
        );

    test('returns the album list as-is, filtering empty/blank entries', () {
      // feed_tab.dart gates the whole carousel on photoUrls.isNotEmpty, so a
      // blank entry slipping through would render a broken empty page.
      final event = withExtra({
        'photoUrls': ['a.jpg', '', '  ', 'b.jpg'],
      });

      expect(event.photoUrls, equals(['a.jpg', 'b.jpg']));
    });

    test('falls back to the legacy singular photoUrl as a one-element list',
        () {
      // Events written before albums existed only carry the singular cover —
      // the carousel must still render that one photo.
      final event = withExtra({'photoUrl': 'cover.jpg'});

      expect(event.photoUrls, equals(['cover.jpg']));
    });

    test('returns const [] when neither photoUrls nor photoUrl is present', () {
      // A no-photo event (e.g. a share/ping) must report an empty album so the
      // feed suppresses the carousel entirely.
      expect(withExtra(const {}).photoUrls, isEmpty);
    });

    test('falls back to the cover when photoUrls is present but all-blank', () {
      // A corrupt/empty list must not shadow a valid legacy cover.
      final event = withExtra({
        'photoUrls': ['', '  '],
        'photoUrl': 'cover.jpg',
      });

      expect(event.photoUrls, equals(['cover.jpg']));
    });
  });
}
