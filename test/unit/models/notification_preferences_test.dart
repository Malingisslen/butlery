/// Unit tests for NotificationPreferences.
library;

import 'dart:convert';

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

    // A category or type the factory forgets is not merely "off by default":
    // isEnabled() reads a missing key as false and defaults() is what every new
    // user and every corrupt-cache fallback gets, so the whole notification
    // class is dead until someone edits the map. The two sides of this
    // assertion come from independent sources — the hand-written literal in
    // defaults() and the enum declaration — so adding an enum value without
    // touching the factory reddens it.
    test('supplies a value for every category and every type', () {
      final p = NotificationPreferences.defaults();
      expect(
        p.categorySettings.keys.toSet(),
        NotificationCategory.values.toSet(),
      );
      expect(p.typeSettings.keys.toSet(), NotificationType.values.toSet());
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
      // BUT-1783: the removed switches must not come back in the write. The
      // repository's own suite asserts this too; it is mirrored here because
      // this is the contract of the model, and a tidy-up of that suite would
      // otherwise take the only proof with it. Key PRESENCE, not value — a
      // dropped field and a null-valued field both read back as null.
      expect(payload.containsKey('soundEnabled'), isFalse);
      expect(payload.containsKey('vibrationEnabled'), isFalse);
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
    test(
      'reads a real document snapshot, ignoring BUT-1783 legacy keys',
      () async {
        final firestore = FakeFirebaseFirestore();
        // fake_cloud_firestore doesn't accept FieldValue.serverTimestamp(),
        // so seed with a real Timestamp + the string-keyed enum-name maps
        // that toFirestore() produces.
        //
        // `soundEnabled`/`vibrationEnabled` are deliberately still in this
        // fixture: `SetOptions(merge: true)` never deletes a key the writer
        // stops sending, so every document written before BUT-1783 carries
        // them for good, and the parse must ignore them rather than fail.
        //
        // Every value the model still PARSES differs from defaults() on
        // purpose (the two legacy keys are the pre-removal defaults, which
        // nothing reads any more). With defaults
        // as the fixture, a reader that saw an unrecognised key and bailed to
        // defaults() would pass this test — which is the exact failure the
        // name claims to exclude.
        await firestore.collection('prefs').doc('alice').set({
          'enabled': false,
          'categorySettings': const <String, dynamic>{},
          'typeSettings': const <String, dynamic>{},
          'allowBatching': false,
          'digestFrequency': 'weekly',
          'quietHoursStart': {'hour': 21, 'minute': 15},
          'quietHoursEnd': {'hour': 6, 'minute': 45},
          'soundEnabled': true,
          'vibrationEnabled': true,
          'lastUpdated': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        });
        final doc = await firestore.collection('prefs').doc('alice').get();
        final p = NotificationPreferences.fromFirestore(doc);

        expect(p.enabled, isFalse);
        expect(p.allowBatching, isFalse);
        expect(p.digestFrequency, 'weekly');
        expect(p.quietHoursStart, const TimeOfDay(hour: 21, minute: 15));
        expect(p.quietHoursEnd, const TimeOfDay(hour: 6, minute: 45));
      },
    );

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

  group('toJson / fromJson round trip (BUT-1782)', () {
    test('non-default settings survive the round trip unchanged', () {
      final original = NotificationPreferences(
        enabled: false,
        categorySettings: const {
          NotificationCategory.friends: false,
          NotificationCategory.recipes: true,
          NotificationCategory.collaboration: false,
          NotificationCategory.shopping: true,
          NotificationCategory.messaging: false,
          NotificationCategory.social: true,
          NotificationCategory.system: true,
        },
        typeSettings: const {
          NotificationType.immediate: false,
          NotificationType.batchable: false,
          NotificationType.silent: true,
          NotificationType.digest: true,
          NotificationType.optional: true,
        },
        allowBatching: false,
        digestFrequency: 'weekly',
        quietHoursStart: const TimeOfDay(hour: 21, minute: 15),
        quietHoursEnd: const TimeOfDay(hour: 6, minute: 45),
        lastUpdated: DateTime.utc(2026, 3, 4, 5, 6, 7),
      );

      final restored = NotificationPreferences.fromJson(original.toJson());

      expect(restored.enabled, isFalse);
      expect(restored.allowBatching, isFalse);
      expect(restored.digestFrequency, 'weekly');
      expect(restored.quietHoursStart, const TimeOfDay(hour: 21, minute: 15));
      expect(restored.quietHoursEnd, const TimeOfDay(hour: 6, minute: 45));
      expect(restored.categorySettings, original.categorySettings);
      expect(restored.typeSettings, original.typeSettings);
      expect(restored.lastUpdated, DateTime.utc(2026, 3, 4, 5, 6, 7));
    });

    test('toJson emits a real JSON object, not the old empty-object stub', () {
      final json = NotificationPreferences.defaults().toJson();
      expect(json, isNot('{}'));

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['enabled'], isTrue);
      expect(decoded['digestFrequency'], 'never');
      // The server sentinel must never reach local storage.
      expect(decoded['lastUpdated'], isA<String>());
      expect(
        (decoded['categorySettings'] as Map)['NotificationCategory.shopping'],
        isFalse,
      );
    });

    test('null quiet hours round trip as null', () {
      final original = NotificationPreferences(
        enabled: true,
        categorySettings: const {NotificationCategory.system: true},
        typeSettings: const {NotificationType.immediate: true},
        allowBatching: true,
        digestFrequency: 'never',
        lastUpdated: DateTime.utc(2026),
      );

      final restored = NotificationPreferences.fromJson(original.toJson());
      expect(restored.quietHoursStart, isNull);
      expect(restored.quietHoursEnd, isNull);
    });

    // Production never holds a UTC-flagged lastUpdated: defaults() stamps
    // clock.now() (local) and the Firestore path arrives via Timestamp.toDate().
    // A DateTime.utc fixture makes toJson's .toUtc() a byte-for-byte no-op, so
    // the instant-preserving contract is only asserted from a local fixture.
    test(
      'a local lastUpdated is stored as a UTC instant, not a wall clock',
      () {
        final localStamp = DateTime(2026, 3, 4, 5, 6, 7);
        final original = NotificationPreferences(
          enabled: true,
          categorySettings: const {NotificationCategory.system: true},
          typeSettings: const {NotificationType.immediate: true},
          allowBatching: true,
          digestFrequency: 'never',
          lastUpdated: localStamp,
        );

        final json = original.toJson();
        expect(jsonDecode(json)['lastUpdated'] as String, endsWith('Z'));

        final restored = NotificationPreferences.fromJson(json);
        expect(restored.lastUpdated.isUtc, isTrue);
        expect(restored.lastUpdated.isAtSameMomentAs(localStamp), isTrue);
      },
    );

    // Documents the forward-compatibility consequence of reading the local copy
    // for real: a key the cache predates comes back OFF, not at its default.
    test('a category key absent from the stored copy reads back as off', () {
      final stored =
          jsonDecode(NotificationPreferences.defaults().toJson())
              as Map<String, dynamic>;
      (stored['categorySettings'] as Map).remove(
        'NotificationCategory.friends',
      );

      final restored = NotificationPreferences.fromJson(jsonEncode(stored));

      // defaults() has friends: true; the stored copy no longer says so.
      expect(restored.categorySettings[NotificationCategory.friends], isFalse);
      // Control: the copy was parsed, not silently replaced by defaults().
      expect(restored.categorySettings[NotificationCategory.system], isTrue);
      expect(restored.categorySettings[NotificationCategory.shopping], isFalse);
    });

    // BUT-1799. `fromJson` answering "{}" with defaults() is the deliberate,
    // tested contract above — but a CACHE caller must be able to tell that
    // apart from a genuine all-defaults user, or it caches the defaults and
    // the next toggle persists them over the user's real settings. Every
    // existing install has the literal "{}" in this slot from the old toJson()
    // stub, so this is the live path, not a hypothetical.
    group('tryFromJson (the nullable door for cache callers)', () {
      test('returns null for the legacy stub value "{}"', () {
        expect(NotificationPreferences.tryFromJson('{}'), isNull);
      });

      test('returns null when a settings map is the wrong TYPE', () {
        expect(
          NotificationPreferences.tryFromJson(
            jsonEncode({'categorySettings': 'corrupt', 'typeSettings': {}}),
          ),
          isNull,
        );
        expect(
          NotificationPreferences.tryFromJson(
            jsonEncode({'categorySettings': {}, 'typeSettings': 'corrupt'}),
          ),
          isNull,
        );
      });

      test('returns null for junk and for a non-object payload', () {
        expect(NotificationPreferences.tryFromJson('not json at all'), isNull);
        expect(NotificationPreferences.tryFromJson('[1,2,3]'), isNull);
      });

      test('round-trips a REAL saved copy without losing the settings', () {
        final stored =
            jsonDecode(NotificationPreferences.defaults().toJson())
                as Map<String, dynamic>;
        (stored['categorySettings'] as Map)['NotificationCategory.shopping'] =
            false;

        final restored = NotificationPreferences.tryFromJson(
          jsonEncode(stored),
        );
        expect(restored, isNotNull);
        // The distinguishing bit: a user who really turned shopping off must
        // survive, or this guard would be trading one silent reset for another.
        expect(
          restored!.categorySettings[NotificationCategory.shopping],
          isFalse,
        );
        expect(
          restored.categorySettings[NotificationCategory.system],
          isTrue,
        );
      });
    });

    test('legacy stub value "{}" maps to defaults, not all-categories-off', () {
      final p = NotificationPreferences.fromJson('{}');
      expect(p.enabled, isTrue);
      expect(p.allowBatching, isTrue);
      expect(p.categorySettings[NotificationCategory.friends], isTrue);
      expect(p.categorySettings[NotificationCategory.system], isTrue);
      expect(p.quietHoursStart, const TimeOfDay(hour: 22, minute: 0));
    });

    // The shape guard is two clauses, one per settings map, and a fixture that
    // corrupts both cannot tell them apart. With either clause removed the blob
    // clears hasRequiredFields (a String is present and non-null), safeBool then
    // reads every key off it as false, and the user silently loses every
    // notification of that kind — then writes the opt-out back on the next
    // settings save. Verified 2026-08-01: without the guard this fixture yields
    // friends=false/system=false instead of defaults().
    test('a non-Map settings blob falls back to defaults, per field', () {
      final wellShaped =
          jsonDecode(NotificationPreferences.defaults().toJson())
              as Map<String, dynamic>;

      for (final corruptField in const ['categorySettings', 'typeSettings']) {
        final stored = Map<String, dynamic>.from(wellShaped)
          ..[corruptField] = 'corrupt'
          // Non-default values outside the settings maps: if either survives,
          // the blob was parsed rather than discarded.
          ..['enabled'] = false
          ..['digestFrequency'] = 'weekly';

        final p = NotificationPreferences.fromJson(jsonEncode(stored));

        expect(p.enabled, isTrue, reason: corruptField);
        expect(p.digestFrequency, 'never', reason: corruptField);
        // defaults() says friends on; an all-off parse of the blob says off.
        expect(
          p.categorySettings[NotificationCategory.friends],
          isTrue,
          reason: corruptField,
        );
        expect(
          p.typeSettings[NotificationType.immediate],
          isTrue,
          reason: corruptField,
        );
      }
    });

    test('corrupt local copy throws instead of masquerading as defaults', () {
      expect(
        () => NotificationPreferences.fromJson('not json at all'),
        throwsFormatException,
      );
      expect(
        () => NotificationPreferences.fromJson('[1,2,3]'),
        throwsFormatException,
      );
    });
  });
}
