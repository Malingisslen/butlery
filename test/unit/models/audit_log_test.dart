/// Unit tests for AuditLog (GDPR Article 30 records).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/audit_log.dart';

AuditLog _log({
  String id = 'log-1',
  String userId = 'alice',
  String operation = 'read',
  String resourceType = 'recipe',
  String? resourceId = 'r1',
  bool granted = true,
  DateTime? timestamp,
  Map<String, dynamic>? metadata,
}) {
  return AuditLog(
    id: id,
    userId: userId,
    operation: operation,
    resourceType: resourceType,
    resourceId: resourceId,
    granted: granted,
    timestamp: timestamp ?? DateTime.utc(2026, 1, 1, 10),
    metadata: metadata,
  );
}

void main() {
  group('toFirestore', () {
    test('emits serverTimestamp() sentinel for timestamp', () {
      final payload = _log().toFirestore();
      expect(payload['timestamp'], isA<FieldValue>());
      expect(payload['userId'], 'alice');
      expect(payload['operation'], 'read');
      expect(payload['resourceType'], 'recipe');
      expect(payload['resourceId'], 'r1');
      expect(payload['granted'], isTrue);
    });

    test('omits computed expireAt — server enforces retention by timestamp',
        () {
      // BUT-808: model deliberately has no expireAt field. The CF queries
      // on `timestamp` directly. Assert we don't accidentally re-introduce it.
      final payload = _log().toFirestore();
      expect(payload.containsKey('expireAt'), isFalse);
    });

    test('preserves null resourceId for bulk operations like readAll', () {
      final payload =
          _log(resourceId: null, operation: 'readAll').toFirestore();
      expect(payload['resourceId'], isNull);
      expect(payload['operation'], 'readAll');
    });

    test('preserves metadata when provided', () {
      final payload = _log(
        metadata: const {'ip': '127.0.0.1', 'device': 'iPhone'},
      ).toFirestore();
      expect(payload['metadata'], {'ip': '127.0.0.1', 'device': 'iPhone'});
    });
  });

  group('fromFirestore', () {
    test('reads from a real document snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('audit_logs').doc('l1').set({
        'userId': 'alice',
        'operation': 'read',
        'resourceType': 'recipe',
        'resourceId': 'r1',
        'granted': true,
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 10)),
        'metadata': {'ip': '127.0.0.1'},
      });
      final doc = await firestore.collection('audit_logs').doc('l1').get();
      final log = AuditLog.fromFirestore(doc);

      expect(log.id, 'l1');
      expect(log.userId, 'alice');
      expect(log.operation, 'read');
      expect(log.resourceType, 'recipe');
      expect(log.resourceId, 'r1');
      expect(log.granted, isTrue);
      expect(log.timestamp.toUtc(), DateTime.utc(2026, 1, 1, 10));
      expect(log.metadata, {'ip': '127.0.0.1'});
    });

    test('safe defaults for missing fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('audit_logs').doc('l1').set(
        <String, dynamic>{},
      );
      final doc = await firestore.collection('audit_logs').doc('l1').get();
      final log = AuditLog.fromFirestore(doc);

      expect(log.id, 'l1');
      expect(log.userId, '');
      expect(log.operation, '');
      expect(log.resourceType, '');
      expect(log.resourceId, isNull);
      expect(log.granted, isFalse); // safeBool default
      expect(log.metadata, isNull);
    });
  });

  group('JSON round-trip (for GDPR export)', () {
    test('toJson emits timestamp as ISO 8601 + preserves all fields', () {
      final original = _log(metadata: const {'ip': '127.0.0.1'});
      final json = original.toJson();
      expect(json['id'], original.id);
      expect(json['userId'], original.userId);
      expect(json['operation'], original.operation);
      expect(json['resourceType'], original.resourceType);
      expect(json['resourceId'], original.resourceId);
      expect(json['granted'], original.granted);
      expect(json['timestamp'], '2026-01-01T10:00:00.000Z');
      expect(json['metadata'], {'ip': '127.0.0.1'});
    });

    test('fromJson round-trips a toJson output', () {
      final original = _log(metadata: const {'k': 'v'});
      final restored = AuditLog.fromJson(original.toJson());
      expect(restored, original);
    });

    test('fromJson safe defaults for missing fields', () {
      final log = AuditLog.fromJson(<String, dynamic>{});
      expect(log.id, '');
      expect(log.userId, '');
      expect(log.granted, isFalse);
      expect(log.metadata, isNull);
    });
  });

  group('equality + hash', () {
    test('all-field equality — same fields → equal', () {
      final a = _log();
      final b = _log();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different id → unequal', () {
      expect(_log(id: 'a'), isNot(_log(id: 'b')));
    });

    test('different granted → unequal', () {
      expect(_log(granted: true), isNot(_log(granted: false)));
    });

    test('different resourceId → unequal', () {
      expect(_log(resourceId: 'r1'), isNot(_log(resourceId: 'r2')));
    });

    test('identical short-circuit', () {
      final a = _log();
      expect(a == a, isTrue);
    });
  });

  group('toString', () {
    test('includes resourceId when present', () {
      expect(_log().toString(), contains('recipe/r1'));
    });

    test('omits the "/resourceId" suffix when resourceId is null', () {
      expect(_log(resourceId: null).toString(), isNot(contains('/null')));
      expect(_log(resourceId: null).toString(), contains('resource: recipe,'));
    });

    test('shows granted state', () {
      expect(_log(granted: false).toString(), contains('granted: false'));
    });
  });
}
