/// Direct unit tests for [CookEvent] (BUT-1149 coverage burndown — previously
/// zero direct coverage).
///
/// One "user cooked this recipe" row, stored at
/// recipe_cook_events/{userId}/events/{eventId}. Covers toFirestore (document
/// fields only — userId is in the path, id is the doc id) and fromFirestore: id
/// from the doc, userId from the grandparent path segment, the epoch fallback
/// for a missing date (keeps a malformed doc out of recency windows), and
/// tolerance of a non-Timestamp date shape.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cook_event.dart';

void main() {
  test('toFirestore carries only recipeId + cookedAt', () {
    final e = CookEvent(
      id: 'evt1',
      userId: 'user1',
      recipeId: 'r1',
      cookedAt: DateTime.utc(2026, 1, 5),
    );
    final json = e.toFirestore();
    expect(json.keys, containsAll(<String>['recipeId', 'cookedAt']));
    expect(json.containsKey('userId'), isFalse);
    expect(json.containsKey('id'), isFalse);
  });

  group('fromFirestore', () {
    Future<CookEvent> readEvent(
      FakeFirebaseFirestore fs,
      String userId,
      String eventId,
      Map<String, dynamic> data,
    ) async {
      final ref = fs
          .collection('recipe_cook_events')
          .doc(userId)
          .collection('events')
          .doc(eventId);
      await ref.set(data);
      return CookEvent.fromFirestore(await ref.get());
    }

    test(
      'pulls id from the doc and userId from the grandparent path',
      () async {
        final e = await readEvent(FakeFirebaseFirestore(), 'user1', 'evt1', {
          'recipeId': 'r1',
          'cookedAt': DateTime.utc(2026, 1, 5),
        });
        expect(e.id, 'evt1');
        expect(e.userId, 'user1');
        expect(e.recipeId, 'r1');
        expect(e.cookedAt.isAtSameMomentAs(DateTime.utc(2026, 1, 5)), isTrue);
      },
    );

    test('falls back to the epoch for a missing date', () async {
      final e = await readEvent(FakeFirebaseFirestore(), 'user1', 'evt2', {
        'recipeId': 'r1',
      });
      expect(
        e.cookedAt.isAtSameMomentAs(DateTime.fromMillisecondsSinceEpoch(0)),
        isTrue,
      );
    });

    test('tolerates a non-Timestamp (ISO string) date', () async {
      final e = await readEvent(FakeFirebaseFirestore(), 'user1', 'evt3', {
        'recipeId': 'r1',
        'cookedAt': '2026-01-05T00:00:00.000Z',
      });
      expect(e.cookedAt.isAtSameMomentAs(DateTime.utc(2026, 1, 5)), isTrue);
    });
  });
}
