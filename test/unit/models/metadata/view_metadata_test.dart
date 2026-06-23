/// Unit tests for ViewMetadata.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/metadata/view_metadata.dart';

void main() {
  test('toFirestore stamps timestamp from clock.now()', () {
    withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
      final v = ViewMetadata(
        userId: 'alice',
        viewedAt: DateTime.utc(2026, 1, 1),
      );
      final payload = v.toFirestore();
      expect(payload['userId'], 'alice');
      expect(payload['timestamp'], DateTime.utc(2026, 1, 1));
    });
  });

  test('fromFirestore parses userId + timestamp', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('views').doc('alice').set({
      'userId': 'alice',
      'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 10)),
    });
    final doc = await firestore.collection('views').doc('alice').get();
    final v = ViewMetadata.fromFirestore(doc);
    expect(v.userId, 'alice');
    expect(v.viewedAt.toUtc(), DateTime.utc(2026, 1, 1, 10));
  });

  group('equality + hash', () {
    test('same userId + viewedAt → equal', () {
      final a = ViewMetadata(
        userId: 'alice',
        viewedAt: DateTime.utc(2026, 1, 1),
      );
      final b = ViewMetadata(
        userId: 'alice',
        viewedAt: DateTime.utc(2026, 1, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different userId → unequal', () {
      expect(
        ViewMetadata(userId: 'a', viewedAt: DateTime.utc(2026, 1, 1)),
        isNot(ViewMetadata(userId: 'b', viewedAt: DateTime.utc(2026, 1, 1))),
      );
    });

    test('different viewedAt → unequal', () {
      expect(
        ViewMetadata(userId: 'a', viewedAt: DateTime.utc(2026, 1, 1)),
        isNot(ViewMetadata(userId: 'a', viewedAt: DateTime.utc(2026, 1, 2))),
      );
    });

    test('identical short-circuit', () {
      final v = ViewMetadata(
        userId: 'alice',
        viewedAt: DateTime.utc(2026, 1, 1),
      );
      expect(v == v, isTrue);
    });
  });

  test('toString includes userId + viewedAt', () {
    final v = ViewMetadata(userId: 'alice', viewedAt: DateTime.utc(2026, 1, 1));
    final s = v.toString();
    expect(s, contains('alice'));
    expect(s, contains('2026-01-01'));
  });
}
