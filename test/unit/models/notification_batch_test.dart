/// Unit tests for NotificationBatch + NotificationTemplateSerializer.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/notification_batch.dart';
import 'package:butlery/services/notifications/notification_types.dart';

NotificationTemplate _template({
  String title = 'Hej',
  String body = 'Något hände',
  Map<String, dynamic>? data,
  String? imageUrl,
  List<NotificationAction>? actions,
}) {
  return NotificationTemplate(
    title: title,
    body: body,
    data: data ?? const {},
    imageUrl: imageUrl,
    actions: actions,
  );
}

void main() {
  group('toMap + fromMap round-trip', () {
    test('round-trips a batch with a simple template', () {
      final batch = NotificationBatch(
        batchKey: 'social_recipe_share_alice',
        userId: 'alice',
        notifications: [
          _template(title: 'Bob delade', body: 'ett recept'),
        ],
        createdAt: DateTime.utc(2026, 1, 1, 10),
        scheduledFor: DateTime.utc(2026, 1, 1, 10, 30),
      );

      final map = batch.toMap();
      expect(map['batchKey'], 'social_recipe_share_alice');
      expect(map['userId'], 'alice');
      expect(map['notifications'], hasLength(1));
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['scheduledFor'], isA<Timestamp>());

      final restored = NotificationBatch.fromMap('doc-id', map);
      expect(restored.batchKey, batch.batchKey);
      expect(restored.userId, batch.userId);
      expect(restored.notifications, hasLength(1));
      expect(restored.notifications.single.title, 'Bob delade');
      expect(restored.notifications.single.body, 'ett recept');
      expect(restored.createdAt.toUtc(), DateTime.utc(2026, 1, 1, 10));
      expect(restored.scheduledFor.toUtc(), DateTime.utc(2026, 1, 1, 10, 30));
    });

    test('round-trips a batch with actions', () {
      final batch = NotificationBatch(
        batchKey: 'k',
        userId: 'u',
        notifications: [
          _template(
            actions: const [
              NotificationAction(id: 'a1', title: 'Acceptera'),
              NotificationAction(id: 'a2', title: 'Avvisa', data: {'k': 'v'}),
            ],
          ),
        ],
        createdAt: DateTime.utc(2026, 1, 1),
        scheduledFor: DateTime.utc(2026, 1, 1),
      );

      final restored = NotificationBatch.fromMap('id', batch.toMap());
      final actions = restored.notifications.single.actions!;
      expect(actions, hasLength(2));
      expect(actions[0].id, 'a1');
      expect(actions[0].title, 'Acceptera');
      expect(actions[0].data, isNull);
      expect(actions[1].id, 'a2');
      expect(actions[1].data, {'k': 'v'});
    });

    test('round-trips an empty notifications list', () {
      final batch = NotificationBatch(
        batchKey: 'k',
        userId: 'u',
        notifications: const [],
        createdAt: DateTime.utc(2026, 1, 1),
        scheduledFor: DateTime.utc(2026, 1, 1),
      );
      final restored = NotificationBatch.fromMap('id', batch.toMap());
      expect(restored.notifications, isEmpty);
    });
  });

  group('fromMap edge cases', () {
    test('missing keys fall back to safe defaults', () {
      final batch = NotificationBatch.fromMap('doc-id', {});
      expect(batch.batchKey, '');
      expect(batch.userId, '');
      expect(batch.notifications, isEmpty);
      expect(batch.createdAt, isA<DateTime>()); // clock.now() fallback
    });

    test('createdAt + scheduledFor accept raw DateTime', () {
      final dt = DateTime.utc(2026, 5, 1);
      final batch = NotificationBatch.fromMap('id', {
        'batchKey': 'k',
        'userId': 'u',
        'notifications': const <Map<String, dynamic>>[],
        'createdAt': dt,
        'scheduledFor': dt,
      });
      expect(batch.createdAt, dt);
      expect(batch.scheduledFor, dt);
    });
  });

  group('fromFirestore', () {
    test('reads from a real document snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('notification_batches').doc('b1').set({
        'batchKey': 'k1',
        'userId': 'u1',
        'notifications': [
          {
            'title': 'T',
            'body': 'B',
            'data': <String, dynamic>{},
          },
        ],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'scheduledFor': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 1)),
      });
      final doc =
          await firestore.collection('notification_batches').doc('b1').get();

      final batch = NotificationBatch.fromFirestore(doc);
      expect(batch.batchKey, 'k1');
      expect(batch.userId, 'u1');
      expect(batch.notifications.single.title, 'T');
      expect(batch.createdAt.toUtc(), DateTime.utc(2026, 1, 1));
    });
  });

  group('NotificationTemplateSerializer.fromMap', () {
    test('parses title/body/data', () {
      final tpl = NotificationTemplateSerializer.fromMap({
        'title': 'T',
        'body': 'B',
        'data': {'k': 'v'},
      });
      expect(tpl.title, 'T');
      expect(tpl.body, 'B');
      expect(tpl.data, {'k': 'v'});
      expect(tpl.imageUrl, isNull);
      expect(tpl.actions, isNull);
    });

    test('actions defaults to null when empty list provided', () {
      final tpl = NotificationTemplateSerializer.fromMap({
        'title': 'T',
        'body': 'B',
        'data': const <String, dynamic>{},
        'actions': const [],
      });
      expect(tpl.actions, isNull); // empty list → null per impl
    });
  });

  group('NotificationTemplateExtension.toMap', () {
    test('omits actions when null', () {
      final map = _template().toMap();
      expect(map['actions'], isNull);
    });

    test('serializes actions when present', () {
      final map = _template(
        actions: const [
          NotificationAction(id: 'a1', title: 'Acceptera'),
        ],
      ).toMap();
      expect(map['actions'], [
        {'id': 'a1', 'title': 'Acceptera', 'data': null},
      ]);
    });
  });
}
