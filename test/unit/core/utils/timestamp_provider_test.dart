/// Direct unit tests for [TimestampProvider] implementations (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// The abstraction exists so tests can avoid FakeFirebaseFirestore's lack of
/// FieldValue-sentinel support. The behavior worth pinning: the test provider
/// returns a concrete clock-driven Timestamp, while the production provider
/// returns a FieldValue sentinel.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/timestamp_provider.dart';

void main() {
  test('ServerTimestampProvider returns a FieldValue sentinel', () {
    expect(
      const ServerTimestampProvider().serverTimestamp(),
      isA<FieldValue>(),
    );
  });

  test('TestTimestampProvider returns a clock-driven Timestamp', () {
    final t = DateTime.utc(2026, 1, 1);
    withClock(Clock.fixed(t), () {
      final ts = const TestTimestampProvider().serverTimestamp();
      expect(ts, isA<Timestamp>());
      expect((ts as Timestamp).toDate().isAtSameMomentAs(t), isTrue);
    });
  });
}
