/// Unit tests for UserConsent + ConsentPurposes.
///
/// GDPR Article 7 audit trail model — pin the field-by-field
/// serialization, the per-purpose enum accessor, the
/// hasRequiredConsents / needsRenewal gates, and the equality contract
/// on ConsentPurposes (all seven flags participate in ==).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/account/user_consent.dart';

ConsentPurposes _all(bool value) => ConsentPurposes(
  essentialServices: value,
  dataProcessing: value,
  analytics: value,
  marketing: value,
  socialFeatures: value,
  pushNotifications: value,
  aiProcessing: value,
);

void main() {
  group('ConsentPurposes.defaults', () {
    test('only essentialServices + dataProcessing enabled', () {
      final p = ConsentPurposes.defaults();
      expect(p.essentialServices, isTrue);
      expect(p.dataProcessing, isTrue);
      expect(p.analytics, isFalse);
      expect(p.marketing, isFalse);
      expect(p.socialFeatures, isFalse);
      expect(p.pushNotifications, isFalse);
      expect(p.aiProcessing, isFalse);
    });
  });

  group('ConsentPurposes.operator[]', () {
    test('returns the value for each ConsentPurpose', () {
      final p = _all(true);
      for (final purpose in ConsentPurpose.values) {
        expect(p[purpose], isTrue, reason: purpose.name);
      }
    });

    test('returns false for purposes the user did not consent to', () {
      final p = _all(false);
      for (final purpose in ConsentPurpose.values) {
        expect(p[purpose], isFalse, reason: purpose.name);
      }
    });
  });

  group('ConsentPurposes serialization', () {
    test('toMap keys match ConsentPurpose enum names', () {
      final map = ConsentPurposes.defaults().toMap();
      for (final p in ConsentPurpose.values) {
        expect(map.containsKey(p.name), isTrue, reason: p.name);
      }
    });

    test('fromMap round-trips via toMap', () {
      final original = _all(true);
      final restored = ConsentPurposes.fromMap(original.toMap());
      expect(restored, original);
    });

    test('fromMap defaults essential/dataProcessing to true when missing', () {
      final p = ConsentPurposes.fromMap(<String, dynamic>{});
      expect(p.essentialServices, isTrue);
      expect(p.dataProcessing, isTrue);
      // Non-essential flags default to false.
      expect(p.analytics, isFalse);
      expect(p.marketing, isFalse);
    });
  });

  group('ConsentPurposes equality + hash', () {
    test('identical → equal', () {
      final p = _all(true);
      expect(p == p, isTrue);
    });

    test('same values → equal', () {
      expect(_all(true), _all(true));
      expect(_all(true).hashCode, _all(true).hashCode);
    });

    test('one differing flag → unequal', () {
      final base = _all(true);
      final flipped = base.copyWith(analytics: false);
      expect(base, isNot(flipped));
    });
  });

  group('ConsentPurposes.copyWith', () {
    test('replaces only specified fields', () {
      final base = _all(false);
      final copy = base.copyWith(analytics: true, marketing: true);
      expect(copy.essentialServices, false);
      expect(copy.dataProcessing, false);
      expect(copy.analytics, true);
      expect(copy.marketing, true);
      expect(copy.aiProcessing, false);
    });
  });

  group('UserConsent', () {
    test('hasRequiredConsents requires both essential AND dataProcessing', () {
      final purposesYes = ConsentPurposes(
        essentialServices: true,
        dataProcessing: true,
      );
      final purposesNoDp = ConsentPurposes(
        essentialServices: true,
        dataProcessing: false,
      );

      final consent = UserConsent(
        userId: 'u',
        purposes: purposesYes,
        grantedAt: DateTime.utc(2026, 1, 1),
        consentVersion: 'v1',
        deviceInfo: 'iPhone',
      );
      expect(consent.hasRequiredConsents, isTrue);

      final missing = consent.copyWith(purposes: purposesNoDp);
      expect(missing.hasRequiredConsents, isFalse);
    });

    test('needsRenewal returns true when version differs', () {
      final c = UserConsent(
        userId: 'u',
        purposes: ConsentPurposes.defaults(),
        grantedAt: DateTime.utc(2026, 1, 1),
        consentVersion: 'v1',
        deviceInfo: 'iPhone',
      );
      expect(c.needsRenewal('v1'), isFalse);
      expect(c.needsRenewal('v2'), isTrue);
    });

    test('copyWith leaves untouched fields', () {
      final base = UserConsent(
        userId: 'u',
        purposes: ConsentPurposes.defaults(),
        grantedAt: DateTime.utc(2026, 1, 1),
        consentVersion: 'v1',
        deviceInfo: 'iPhone',
      );
      final newPurposes = base.purposes.copyWith(analytics: true);
      final copy = base.copyWith(
        purposes: newPurposes,
        updatedAt: DateTime.utc(2026, 5, 1),
      );
      expect(copy.userId, 'u');
      expect(copy.consentVersion, 'v1');
      expect(copy.deviceInfo, 'iPhone');
      expect(copy.purposes.analytics, isTrue);
      expect(copy.updatedAt, DateTime.utc(2026, 5, 1));
    });

    test('toFirestore + fromFirestore round-trip via fake firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final original = UserConsent(
        userId: 'alice',
        purposes: _all(true),
        grantedAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
        consentVersion: 'v2',
        ipAddress: '127.0.0.1',
        deviceInfo: 'iPhone 15',
      );
      await firestore
          .collection('consents')
          .doc('alice')
          .set(
            original.toFirestore(),
          );
      final doc = await firestore.collection('consents').doc('alice').get();
      final restored = UserConsent.fromFirestore(doc);

      expect(restored.userId, 'alice');
      expect(restored.consentVersion, 'v2');
      expect(restored.ipAddress, '127.0.0.1');
      expect(restored.deviceInfo, 'iPhone 15');
      expect(restored.grantedAt.toUtc(), DateTime.utc(2026, 1, 1));
      expect(restored.updatedAt!.toUtc(), DateTime.utc(2026, 5, 1));
      expect(restored.purposes, _all(true));
    });

    test('fromFirestore tolerates missing updatedAt + ipAddress', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('consents').doc('alice').set({
        'userId': 'alice',
        'purposes': ConsentPurposes.defaults().toMap(),
        'grantedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'consentVersion': 'v1',
        'deviceInfo': 'iPhone',
      });
      final doc = await firestore.collection('consents').doc('alice').get();
      final restored = UserConsent.fromFirestore(doc);
      expect(restored.updatedAt, isNull);
      expect(restored.ipAddress, isNull);
    });
  });
}
