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
  test('toFirestore carries only recipeId + cookedAt when no attendees', () {
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
    // Empty attendance keeps the historical two-field shape.
    expect(json.containsKey('attendeeMemberIds'), isFalse);
  });

  test('toFirestore includes attendeeMemberIds only when non-empty', () {
    final e = CookEvent(
      id: 'evt1',
      userId: 'user1',
      recipeId: 'r1',
      cookedAt: DateTime.utc(2026, 1, 5),
      attendeeMemberIds: const ['liam', 'user1'],
    );
    expect(e.toFirestore()['attendeeMemberIds'], ['liam', 'user1']);
  });

  test('toFirestore writes the after-cook details only when set', () {
    final bare = CookEvent(
      id: 'e',
      userId: 'u',
      recipeId: 'r1',
      cookedAt: DateTime.utc(2026, 1, 5),
    ).toFirestore();
    for (final key in ['rating', 'note', 'snapId']) {
      expect(bare.containsKey(key), isFalse, reason: key);
    }

    final full = CookEvent(
      id: 'e',
      userId: 'u',
      recipeId: 'r1',
      cookedAt: DateTime.utc(2026, 1, 5),
      rating: 4,
      note: 'mer lime',
      snapId: 'snap-1',
    ).toFirestore();
    expect(full['rating'], 4);
    expect(full['note'], 'mer lime');
    expect(full['snapId'], 'snap-1');
  });

  test(
    'fromFirestore reads the after-cook details, null when absent',
    () async {
      final fs = FakeFirebaseFirestore();
      final col = fs.collection('recipe_cook_events/u/events');
      await col.doc('a').set({
        'recipeId': 'r1',
        'cookedAt': DateTime.utc(2026, 1, 5),
        'rating': 5,
        'note': 'bra',
      });
      await col.doc('b').set({
        'recipeId': 'r1',
        'cookedAt': DateTime.utc(2026, 1, 5),
      });
      final a = CookEvent.fromFirestore(await col.doc('a').get());
      final b = CookEvent.fromFirestore(await col.doc('b').get());
      expect((a.rating, a.note, a.snapId), (5, 'bra', null));
      expect((b.rating, b.note, b.snapId), (null, null, null));
    },
  );

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

    test(
      'defaults attendeeMemberIds to empty when the field is absent',
      () async {
        final e = await readEvent(FakeFirebaseFirestore(), 'user1', 'evt4', {
          'recipeId': 'r1',
          'cookedAt': DateTime.utc(2026, 1, 5),
        });
        expect(e.attendeeMemberIds, isEmpty);
      },
    );

    test('round-trips a stored attendeeMemberIds list', () async {
      final e = await readEvent(FakeFirebaseFirestore(), 'user1', 'evt5', {
        'recipeId': 'r1',
        'cookedAt': DateTime.utc(2026, 1, 5),
        'attendeeMemberIds': ['liam', 'emma'],
      });
      expect(e.attendeeMemberIds, ['liam', 'emma']);
    });
  });
}
