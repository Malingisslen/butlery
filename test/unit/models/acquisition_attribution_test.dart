/// Unit tests for AcquisitionAttribution.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/acquisition_attribution.dart';

void main() {
  group('constructor', () {
    test('preserves all fields', () {
      final attr = AcquisitionAttribution(
        source: 'instagram',
        medium: 'social',
        campaign: 'cooking_week',
        firstSeenAt: DateTime.utc(2026, 1, 1),
      );
      expect(attr.source, 'instagram');
      expect(attr.medium, 'social');
      expect(attr.campaign, 'cooking_week');
      expect(attr.firstSeenAt, DateTime.utc(2026, 1, 1));
    });

    test('firstSeenAt is optional', () {
      const attr = AcquisitionAttribution(
        source: 'x',
        medium: 'y',
        campaign: 'z',
      );
      expect(attr.firstSeenAt, isNull);
    });
  });

  group('toFirestore', () {
    test('emits serverTimestamp() sentinel for firstSeenAt', () {
      const attr = AcquisitionAttribution(
        source: 'instagram',
        medium: 'social',
        campaign: 'cooking_week',
      );
      final payload = attr.toFirestore();
      expect(payload['source'], 'instagram');
      expect(payload['medium'], 'social');
      expect(payload['campaign'], 'cooking_week');
      expect(payload['firstSeenAt'], isA<FieldValue>());
    });
  });

  group('fromFirestore', () {
    test('round-trips through fake firestore with a real Timestamp', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attr').doc('u1').set({
        'source': 'google',
        'medium': 'cpc',
        'campaign': 'launch',
        'firstSeenAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });

      final doc = await firestore.collection('attr').doc('u1').get();
      final restored = AcquisitionAttribution.fromFirestore(doc);

      expect(restored.source, 'google');
      expect(restored.medium, 'cpc');
      expect(restored.campaign, 'launch');
      expect(restored.firstSeenAt!.toUtc(), DateTime.utc(2026, 1, 1));
    });

    test('safe defaults for missing string fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attr').doc('u1').set(<String, dynamic>{});
      final doc = await firestore.collection('attr').doc('u1').get();

      final restored = AcquisitionAttribution.fromFirestore(doc);
      expect(restored.source, '');
      expect(restored.medium, '');
      expect(restored.campaign, '');
      expect(restored.firstSeenAt, isNull);
    });

    test('firstSeenAt is null when not a Timestamp', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('attr').doc('u1').set({
        'source': 'x',
        'medium': 'y',
        'campaign': 'z',
        'firstSeenAt': 'not-a-timestamp',
      });
      final doc = await firestore.collection('attr').doc('u1').get();
      final restored = AcquisitionAttribution.fromFirestore(doc);
      expect(restored.firstSeenAt, isNull);
    });
  });
}
