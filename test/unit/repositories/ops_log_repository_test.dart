import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/ops_log_repository.dart';

void main() {
  group('OpsLogRepository.getLatestReceiptAt', () {
    test('is null when there are no system events', () async {
      final repo = OpsLogRepository(firestore: FakeFirebaseFirestore());
      expect(await repo.getLatestReceiptAt(), isNull);
    });

    test('returns the newest executedAt, whatever the event type', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('system_events').add({
        'type': 'system_events_cleanup',
        'executedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
      });
      await db.collection('system_events').add({
        'type': 'ingredient_sync',
        'executedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 5)),
      });
      final repo = OpsLogRepository(firestore: db);
      expect(
        (await repo.getLatestReceiptAt())!.toUtc(),
        DateTime.utc(2026, 11, 5),
      );
    });

    test('a newest row without a timestamp throws, not "none"', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('system_events').add({
        'type': 'broken',
        'executedAt': 'yesterday',
      });
      final repo = OpsLogRepository(firestore: db);
      await expectLater(repo.getLatestReceiptAt(), throwsStateError);
    });
  });
}
