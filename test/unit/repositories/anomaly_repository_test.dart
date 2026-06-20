/// Tests for AnomalyRepository — reads the latest `analytics/anomalies/daily/
/// {date}` doc for the banner. Must return the newest report, parse the
/// anomalies list, and degrade to empty on no-data / error.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/anomaly_repository.dart';

import '../../test_support/base_unit_test.dart';

Future<void> _seed(
  FakeFirebaseFirestore db,
  String date,
  List<Map<String, dynamic>> anomalies,
) async {
  await db
      .collection('analytics')
      .doc('anomalies')
      .collection('daily')
      .doc(date)
      .set({'date': date, 'anomalies': anomalies});
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  test('returns the newest report and parses its anomalies', () async {
    final db = FakeFirebaseFirestore();
    await _seed(db, '2026-06-18', []);
    await _seed(db, '2026-06-20', [
      {
        'metric': 'recipes_total',
        'today': 50,
        'mean': 10,
        'z': 4.2,
        'direction': 'up',
      },
    ]);

    final report = await AnomalyRepository(firestore: db).getLatest();

    expect(report.date, '2026-06-20'); // newest by doc id
    expect(report.hasAnomalies, isTrue);
    expect(report.anomalies.single.metric, 'recipes_total');
    expect(report.anomalies.single.isUp, isTrue);
    expect(report.anomalies.single.z, 4.2);
  });

  test('no anomaly docs yields an empty report', () async {
    final report =
        await AnomalyRepository(firestore: FakeFirebaseFirestore()).getLatest();
    expect(report.hasAnomalies, isFalse);
    expect(report.anomalies, isEmpty);
  });

  test('a report with an empty anomalies list has no anomalies', () async {
    final db = FakeFirebaseFirestore();
    await _seed(db, '2026-06-20', []);
    final report = await AnomalyRepository(firestore: db).getLatest();
    expect(report.hasAnomalies, isFalse);
  });
}
