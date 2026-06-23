/// Unit tests for EngagementMetadata.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/metadata/engagement_metadata.dart';

void main() {
  group('toFirestore', () {
    test('emits user + timestamp + action + targetId when set', () {
      final e = EngagementMetadata(
        userId: 'alice',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'import',
        targetId: 'recipe-1',
      );
      final payload = e.toFirestore();
      expect(payload['userId'], 'alice');
      expect(payload['action'], 'import');
      expect(payload['targetId'], 'recipe-1');
    });

    test('omits targetId when null', () {
      final e = EngagementMetadata(
        userId: 'alice',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'join',
      );
      expect(e.toFirestore().containsKey('targetId'), isFalse);
    });
  });

  group('fromFirestore', () {
    test('reads userId + timestamp + action + targetId', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('e').doc('alice').set({
        'userId': 'alice',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'action': 'import',
        'targetId': 'r1',
      });
      final doc = await firestore.collection('e').doc('alice').get();
      final e = EngagementMetadata.fromFirestore(doc);
      expect(e.userId, 'alice');
      expect(e.action, 'import');
      expect(e.targetId, 'r1');
      expect(e.engagedAt.toUtc(), DateTime.utc(2026, 1, 1));
    });

    test(
      'safe-default for missing action; targetId null when absent',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('e').doc('alice').set({
          'userId': 'alice',
          'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        });
        final doc = await firestore.collection('e').doc('alice').get();
        final e = EngagementMetadata.fromFirestore(doc);
        expect(e.action, '');
        expect(e.targetId, isNull);
      },
    );
  });

  group('equality', () {
    test('same all-fields → equal', () {
      final a = EngagementMetadata(
        userId: 'alice',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'import',
        targetId: 'r1',
      );
      final b = EngagementMetadata(
        userId: 'alice',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'import',
        targetId: 'r1',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different action → unequal', () {
      final a = EngagementMetadata(
        userId: 'alice',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'import',
      );
      final b = EngagementMetadata(
        userId: 'alice',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'join',
      );
      expect(a, isNot(b));
    });

    test('different targetId → unequal', () {
      final a = EngagementMetadata(
        userId: 'a',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'import',
        targetId: 'r1',
      );
      final b = EngagementMetadata(
        userId: 'a',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'import',
        targetId: 'r2',
      );
      expect(a, isNot(b));
    });

    test('identical short-circuit', () {
      final e = EngagementMetadata(
        userId: 'a',
        engagedAt: DateTime.utc(2026, 1, 1),
        action: 'x',
      );
      expect(e == e, isTrue);
    });
  });

  test('toString includes userId + action + targetId', () {
    final s = EngagementMetadata(
      userId: 'alice',
      engagedAt: DateTime.utc(2026, 1, 1),
      action: 'import',
      targetId: 'r1',
    ).toString();
    expect(s, contains('alice'));
    expect(s, contains('import'));
    expect(s, contains('r1'));
  });
}
