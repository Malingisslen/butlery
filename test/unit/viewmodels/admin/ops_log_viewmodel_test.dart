/// Tests for the admin ops-log tab: OpsEvent.fromFirestore must normalize the
/// differing system_events shapes (totalDeleted vs deletionAuditDeletedCount,
/// missing fields), and OpsLogViewModel must surface events newest-first,
/// derive last-run, and degrade to empty/error without crashing.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/ops_event.dart';
import 'package:butlery/repositories/ops_log_repository.dart';
import 'package:butlery/viewmodels/admin/ops_log_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _FakeOpsLogRepository extends OpsLogRepository {
  _FakeOpsLogRepository(this._events)
      : super(firestore: FakeFirebaseFirestore());

  final List<OpsEvent> _events;
  bool throwOnLoad = false;

  @override
  Future<List<OpsEvent>> getRecentEvents({int limit = 50}) async {
    if (throwOnLoad) throw Exception('boom');
    return _events;
  }
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('OpsEvent.fromFirestore normalization', () {
    test('prefers totalDeleted, then deletionAuditDeletedCount', () {
      final a = OpsEvent.fromFirestore({
        'type': 'notification_cleanup',
        'totalDeleted': 12,
        'deletionAuditDeletedCount': 99, // ignored when totalDeleted present
        'executedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 15, 4)),
      });
      expect(a.type, 'notification_cleanup');
      expect(a.deletedCount, 12);
      // Timestamp.toDate() yields local time — compare the instant, not the zone.
      expect(
          a.executedAt!.isAtSameMomentAs(DateTime.utc(2026, 6, 15, 4)), isTrue);

      final b = OpsEvent.fromFirestore({
        'type': 'audit_cleanup',
        'deletionAuditDeletedCount': 7,
      });
      expect(b.deletedCount, 7);
      expect(b.executedAt, isNull);
    });

    test('missing count and type degrade to null / unknown', () {
      final e = OpsEvent.fromFirestore({});
      expect(e.type, 'unknown');
      expect(e.deletedCount, isNull);
      expect(e.executedAt, isNull);
    });

    test('non-Timestamp executedAt and non-num count degrade to null', () {
      final e = OpsEvent.fromFirestore({
        'type': 'x',
        'executedAt': '2026-01-01', // string, not a Timestamp
        'totalDeleted': 'lots', // string, not a num
      });
      expect(e.executedAt, isNull);
      expect(e.deletedCount, isNull);
    });
  });

  group('OpsLogViewModel', () {
    OpsEvent ev(String type, DateTime when) =>
        OpsEvent(type: type, executedAt: when, deletedCount: 1);

    test('surfaces events and derives last run from the first (newest)',
        () async {
      final vm = OpsLogViewModel(
        repository: _FakeOpsLogRepository([
          ev('notification_cleanup', DateTime.utc(2026, 6, 15, 4)),
          ev('audit_cleanup', DateTime.utc(2026, 6, 8, 3)),
        ]),
      );
      await vm.load();
      expect(vm.eventCount, 2);
      expect(vm.lastRun, DateTime.utc(2026, 6, 15, 4));
      vm.dispose();
    });

    test('no events is a clean empty state, not a crash', () async {
      final vm = OpsLogViewModel(repository: _FakeOpsLogRepository(const []));
      await vm.load();
      expect(vm.events, isEmpty);
      expect(vm.lastRun, isNull);
      expect(vm.error, isNull);
      vm.dispose();
    });

    test('load failure sets error state', () async {
      final repo = _FakeOpsLogRepository(const [])..throwOnLoad = true;
      final vm = OpsLogViewModel(repository: repo);
      await vm.load();
      expect(vm.error, isNotNull);
      expect(vm.events, isEmpty);
      vm.dispose();
    });

    test('refresh reloads (the refresh button entry point)', () async {
      final repo = _FakeOpsLogRepository([
        ev('cache_cleanup', DateTime.utc(2026, 6, 1)),
      ]);
      final vm = OpsLogViewModel(repository: repo);
      await vm.refresh();
      expect(vm.eventCount, 1);
      vm.dispose();
    });
  });
}
