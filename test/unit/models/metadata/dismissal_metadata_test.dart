/// Unit tests for DismissalMetadata.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/metadata/dismissal_metadata.dart';

void main() {
  group('toFirestore', () {
    test('emits userId + timestamp + reason when set', () {
      final d = DismissalMetadata(
        userId: 'alice',
        dismissedAt: DateTime.utc(2026, 1, 1),
        reason: 'not_interested',
      );
      final payload = d.toFirestore();
      expect(payload['userId'], 'alice');
      expect(payload['timestamp'], isA<DateTime>());
      expect(payload['reason'], 'not_interested');
    });

    test('omits reason key when null', () {
      final d = DismissalMetadata(
        userId: 'alice',
        dismissedAt: DateTime.utc(2026, 1, 1),
      );
      final payload = d.toFirestore();
      expect(payload.containsKey('reason'), isFalse);
    });
  });

  group('fromFirestore', () {
    test('reads userId + timestamp + reason', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('d').doc('alice').set({
        'userId': 'alice',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 10)),
        'reason': 'already_have',
      });
      final doc = await firestore.collection('d').doc('alice').get();
      final d = DismissalMetadata.fromFirestore(doc);
      expect(d.userId, 'alice');
      expect(d.dismissedAt.toUtc(), DateTime.utc(2026, 1, 1, 10));
      expect(d.reason, 'already_have');
    });

    test('reason null when missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('d').doc('alice').set({
        'userId': 'alice',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      final doc = await firestore.collection('d').doc('alice').get();
      expect(DismissalMetadata.fromFirestore(doc).reason, isNull);
    });
  });

  group('equality', () {
    test('same triple → equal', () {
      final a = DismissalMetadata(
        userId: 'alice',
        dismissedAt: DateTime.utc(2026, 1, 1),
        reason: 'x',
      );
      final b = DismissalMetadata(
        userId: 'alice',
        dismissedAt: DateTime.utc(2026, 1, 1),
        reason: 'x',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different reason → unequal', () {
      final a = DismissalMetadata(
        userId: 'a',
        dismissedAt: DateTime.utc(2026, 1, 1),
        reason: 'x',
      );
      final b = DismissalMetadata(
        userId: 'a',
        dismissedAt: DateTime.utc(2026, 1, 1),
        reason: 'y',
      );
      expect(a, isNot(b));
    });

    test('identical short-circuit', () {
      final d = DismissalMetadata(
        userId: 'a',
        dismissedAt: DateTime.utc(2026, 1, 1),
      );
      expect(d == d, isTrue);
    });
  });

  test('toString includes userId + reason', () {
    final s = DismissalMetadata(
      userId: 'alice',
      dismissedAt: DateTime.utc(2026, 1, 1),
      reason: 'x',
    ).toString();
    expect(s, contains('alice'));
    expect(s, contains('x'));
  });
}
