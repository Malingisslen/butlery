/// Unit tests for InteractionMetadata.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/metadata/interaction_metadata.dart';

void main() {
  group('toFirestore', () {
    test(
      'emits user + timestamp + interactionType + optional value/comment',
      () {
        final i = InteractionMetadata(
          userId: 'alice',
          interactedAt: DateTime.utc(2026, 1, 1),
          interactionType: 'rating',
          value: 4.5,
          comment: 'great',
        );
        final payload = i.toFirestore();
        expect(payload['userId'], 'alice');
        expect(payload['interactionType'], 'rating');
        expect(payload['value'], 4.5);
        expect(payload['comment'], 'great');
      },
    );

    test('omits value when null', () {
      final i = InteractionMetadata(
        userId: 'a',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'like',
      );
      expect(i.toFirestore().containsKey('value'), isFalse);
    });

    test('omits comment when null', () {
      final i = InteractionMetadata(
        userId: 'a',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'like',
      );
      expect(i.toFirestore().containsKey('comment'), isFalse);
    });
  });

  group('fromFirestore', () {
    test('reads all fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('i').doc('alice').set({
        'userId': 'alice',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'interactionType': 'rating',
        'value': 4.5,
        'comment': 'great',
      });
      final doc = await firestore.collection('i').doc('alice').get();
      final i = InteractionMetadata.fromFirestore(doc);
      expect(i.userId, 'alice');
      expect(i.interactionType, 'rating');
      expect(i.value, 4.5);
      expect(i.comment, 'great');
    });

    test('value + comment null when missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('i').doc('alice').set({
        'userId': 'alice',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'interactionType': 'like',
      });
      final doc = await firestore.collection('i').doc('alice').get();
      final i = InteractionMetadata.fromFirestore(doc);
      expect(i.value, isNull);
      expect(i.comment, isNull);
    });
  });

  group('equality', () {
    test('same all-fields → equal', () {
      final a = InteractionMetadata(
        userId: 'alice',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'rating',
        value: 5.0,
        comment: 'wow',
      );
      final b = InteractionMetadata(
        userId: 'alice',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'rating',
        value: 5.0,
        comment: 'wow',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different value → unequal', () {
      final a = InteractionMetadata(
        userId: 'a',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'rating',
        value: 3.0,
      );
      final b = InteractionMetadata(
        userId: 'a',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'rating',
        value: 4.0,
      );
      expect(a, isNot(b));
    });

    test('identical short-circuit', () {
      final i = InteractionMetadata(
        userId: 'a',
        interactedAt: DateTime.utc(2026, 1, 1),
        interactionType: 'like',
      );
      expect(i == i, isTrue);
    });
  });

  test('toString includes userId + interactionType + value', () {
    final s = InteractionMetadata(
      userId: 'alice',
      interactedAt: DateTime.utc(2026, 1, 1),
      interactionType: 'rating',
      value: 4.5,
    ).toString();
    expect(s, contains('alice'));
    expect(s, contains('rating'));
    expect(s, contains('4.5'));
  });
}
