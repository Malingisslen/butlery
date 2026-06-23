/// Unit tests for NotificationPreferences.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/notifications/notification_types.dart';

void main() {
  group('defaults factory', () {
    test('master toggle on; sensible per-category + per-type defaults', () {
      final p = NotificationPreferences.defaults();
      expect(p.enabled, isTrue);
      expect(p.allowBatching, isTrue);
      expect(p.soundEnabled, isTrue);
      expect(p.vibrationEnabled, isTrue);
      expect(p.digestFrequency, 'never');
      expect(p.quietHoursStart, const TimeOfDay(hour: 22, minute: 0));
      expect(p.quietHoursEnd, const TimeOfDay(hour: 8, minute: 0));

      // Per-category defaults
      expect(p.categorySettings[NotificationCategory.friends], isTrue);
      expect(p.categorySettings[NotificationCategory.recipes], isTrue);
      expect(p.categorySettings[NotificationCategory.shopping], isFalse);
      expect(p.categorySettings[NotificationCategory.social], isFalse);
      expect(p.categorySettings[NotificationCategory.system], isTrue);

      // Per-type defaults
      expect(p.typeSettings[NotificationType.immediate], isTrue);
      expect(p.typeSettings[NotificationType.batchable], isTrue);
      expect(p.typeSettings[NotificationType.silent], isTrue);
      expect(p.typeSettings[NotificationType.digest], isFalse);
      expect(p.typeSettings[NotificationType.optional], isFalse);
    });

    test('lastUpdated stamps via clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23)), () {
        expect(
          NotificationPreferences.defaults().lastUpdated,
          DateTime.utc(2026, 5, 23),
        );
      });
    });
  });

  group('isEnabled', () {
    test('returns false when master toggle is off', () {
      final p = NotificationPreferences(
        enabled: false,
        categorySettings: const {NotificationCategory.friends: true},
        typeSettings: const {NotificationType.immediate: true},
        allowBatching: true,
        digestFrequency: 'never',
        soundEnabled: true,
        vibrationEnabled: true,
        lastUpdated: DateTime.utc(2026, 1, 1),
      );
      expect(
        p.isEnabled(NotificationCategory.friends, NotificationType.immediate),
        isFalse,
      );
    });

    test('returns true only when BOTH category AND type are on', () {
      final p = NotificationPreferences(
        enabled: true,
        categorySettings: const {
          NotificationCategory.friends: true,
          NotificationCategory.shopping: false,
        },
        typeSettings: const {
          NotificationType.immediate: true,
          NotificationType.digest: false,
        },
        allowBatching: true,
        digestFrequency: 'never',
        soundEnabled: true,
        vibrationEnabled: true,
        lastUpdated: DateTime.utc(2026, 1, 1),
      );

      expect(
        p.isEnabled(NotificationCategory.friends, NotificationType.immediate),
        isTrue,
      );
      // category off
      expect(
        p.isEnabled(NotificationCategory.shopping, NotificationType.immediate),
        isFalse,
      );
      // type off
      expect(
        p.isEnabled(NotificationCategory.friends, NotificationType.digest),
        isFalse,
      );
    });

    test('missing category in map → treated as disabled', () {
      final p = NotificationPreferences(
        enabled: true,
        categorySettings: const {}, // empty
        typeSettings: const {NotificationType.immediate: true},
        allowBatching: true,
        digestFrequency: 'never',
        soundEnabled: true,
        vibrationEnabled: true,
        lastUpdated: DateTime.utc(2026, 1, 1),
      );
      expect(
        p.isEnabled(NotificationCategory.friends, NotificationType.immediate),
        isFalse,
      );
    });
  });

  group('toFirestore', () {
    test('emits serverTimestamp() for lastUpdated', () {
      final payload = NotificationPreferences.defaults().toFirestore();
      expect(payload['lastUpdated'], isA<FieldValue>());
      expect(payload['enabled'], isTrue);
      expect(payload['allowBatching'], isTrue);
      expect(payload['digestFrequency'], 'never');
    });

    test('converts enum maps to string-keyed maps', () {
      final payload = NotificationPreferences.defaults().toFirestore();
      final cats = payload['categorySettings'] as Map;
      // Keys are enum.toString() — should contain "NotificationCategory.friends"
      expect(cats.keys, anyElement(contains('NotificationCategory.friends')));
    });

    test('null quietHours → null in payload', () {
      final p = NotificationPreferences(
        enabled: true,
        categorySettings: const {},
        typeSettings: const {},
        allowBatching: true,
        digestFrequency: 'never',
        soundEnabled: true,
        vibrationEnabled: true,
        lastUpdated: DateTime.utc(2026, 1, 1),
      );
      final payload = p.toFirestore();
      expect(payload['quietHoursStart'], isNull);
      expect(payload['quietHoursEnd'], isNull);
    });

    test('non-null quietHours → {hour, minute} map', () {
      final p = NotificationPreferences.defaults();
      final payload = p.toFirestore();
      expect(payload['quietHoursStart'], {'hour': 22, 'minute': 0});
      expect(payload['quietHoursEnd'], {'hour': 8, 'minute': 0});
    });
  });

  group('fromFirestore / fromMap', () {
    test('reads a real document snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      // fake_cloud_firestore doesn't accept FieldValue.serverTimestamp(),
      // so seed with a real Timestamp + the string-keyed enum-name maps
      // that toFirestore() produces.
      await firestore.collection('prefs').doc('alice').set({
        'enabled': true,
        'categorySettings': const <String, dynamic>{},
        'typeSettings': const <String, dynamic>{},
        'allowBatching': true,
        'digestFrequency': 'never',
        'quietHoursStart': {'hour': 22, 'minute': 0},
        'quietHoursEnd': {'hour': 8, 'minute': 0},
        'soundEnabled': true,
        'vibrationEnabled': true,
        'lastUpdated': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      final doc = await firestore.collection('prefs').doc('alice').get();
      final p = NotificationPreferences.fromFirestore(doc);

      expect(p.enabled, isTrue);
      expect(p.allowBatching, isTrue);
      expect(p.digestFrequency, 'never');
      expect(p.quietHoursStart, const TimeOfDay(hour: 22, minute: 0));
    });

    test('fromMap safe defaults when fields missing', () {
      final p = NotificationPreferences.fromMap('id', {});
      expect(p.enabled, isTrue); // default true
      expect(p.allowBatching, isTrue);
      expect(p.digestFrequency, 'never');
      expect(p.quietHoursStart, isNull);
      expect(p.quietHoursEnd, isNull);
    });

    test('fromMap honors explicit raw DateTime lastUpdated', () {
      final dt = DateTime.utc(2026, 5, 1);
      final p = NotificationPreferences.fromMap('id', {'lastUpdated': dt});
      expect(p.lastUpdated, dt);
    });

    test('parseTimeOfDay handles {hour, minute} maps', () {
      final p = NotificationPreferences.fromMap('id', {
        'quietHoursStart': {'hour': 23, 'minute': 30},
      });
      expect(p.quietHoursStart, const TimeOfDay(hour: 23, minute: 30));
    });
  });

  group('toJson / fromJson (stub)', () {
    test('toJson is currently a stub returning empty object string', () {
      expect(NotificationPreferences.defaults().toJson(), '{}');
    });

    test('fromJson returns defaults (stub)', () {
      final p = NotificationPreferences.fromJson('{}');
      // Stub: equivalent to defaults() — verify a known default field.
      expect(p.enabled, isTrue);
      expect(p.allowBatching, isTrue);
    });
  });
}
