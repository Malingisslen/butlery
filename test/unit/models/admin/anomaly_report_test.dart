/// Direct unit tests for [Anomaly] / [AnomalyReport] (BUT-1149 coverage burndown
/// — previously zero direct coverage).
///
/// Pure models for the nightly anomaly-detection report. Covers Anomaly.isUp,
/// Anomaly.fromMap defaults, the AnomalyReport.empty sentinel + hasAnomalies,
/// and fromFirestore (date falls back to the doc id; non-map / non-list entries
/// are dropped rather than throwing).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/anomaly_report.dart';

void main() {
  group('Anomaly', () {
    test('isUp reflects the direction', () {
      const up = Anomaly(
        metric: 'm',
        today: 5,
        mean: 1,
        z: 4,
        direction: 'up',
      );
      const down = Anomaly(
        metric: 'm',
        today: 0,
        mean: 5,
        z: -4,
        direction: 'down',
      );
      expect(up.isUp, isTrue);
      expect(down.isUp, isFalse);
    });

    test('fromMap reads fields and coerces z to double', () {
      final a = Anomaly.fromMap({
        'metric': 'recipes_total',
        'today': 10,
        'mean': 4,
        'z': 3, // int → double
        'direction': 'up',
      });
      expect(a.metric, 'recipes_total');
      expect(a.today, 10);
      expect(a.mean, 4);
      expect(a.z, 3.0);
      expect(a.z, isA<double>());
    });

    test('fromMap applies defaults for a missing/empty map', () {
      final a = Anomaly.fromMap(const {});
      expect(a.metric, 'unknown');
      expect(a.today, 0);
      expect(a.mean, 0);
      expect(a.z, 0.0);
      expect(a.direction, 'up');
    });
  });

  group('AnomalyReport', () {
    test('empty sentinel has no date and no anomalies', () {
      expect(AnomalyReport.empty.date, '');
      expect(AnomalyReport.empty.anomalies, isEmpty);
      expect(AnomalyReport.empty.hasAnomalies, isFalse);
    });

    test('hasAnomalies is true once there is at least one', () {
      const r = AnomalyReport(
        date: '2026-01-01',
        anomalies: [
          Anomaly(metric: 'm', today: 1, mean: 0, z: 5, direction: 'up'),
        ],
      );
      expect(r.hasAnomalies, isTrue);
    });

    test('fromFirestore parses anomalies, dropping non-map entries', () {
      final r = AnomalyReport.fromFirestore('2026-01-02', {
        'anomalies': [
          {'metric': 'a', 'today': 2, 'mean': 1, 'z': 4, 'direction': 'up'},
          'garbage', // dropped
          42, // dropped
        ],
      });
      expect(r.date, '2026-01-02');
      expect(r.anomalies, hasLength(1));
      expect(r.anomalies.first.metric, 'a');
    });

    test('fromFirestore falls back to the id for a missing date', () {
      final r = AnomalyReport.fromFirestore('doc-id', const {});
      expect(r.date, 'doc-id');
      expect(r.anomalies, isEmpty);
    });

    test('fromFirestore yields no anomalies when the field is not a list', () {
      final r = AnomalyReport.fromFirestore('d', {'anomalies': 'nope'});
      expect(r.anomalies, isEmpty);
    });
  });
}
