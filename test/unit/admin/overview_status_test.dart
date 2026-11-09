import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/anomaly_report.dart';
import 'package:butlery/models/admin/overview_status.dart';

void main() {
  const calm = AnomalyReport.empty;
  const oneAnomaly = AnomalyReport(
    date: '2026-11-09',
    anomalies: [
      Anomaly(
        metric: 'recipes_total',
        today: 9,
        mean: 3,
        z: 4,
        direction: 'up',
      ),
    ],
  );

  test('calm report and healthy imports give no findings', () {
    expect(
      assessOverview(anomalies: calm, importSuccess: 95, importFailure: 5),
      isEmpty,
    );
  });

  test('an anomaly gives one anomalies finding with the count', () {
    final findings = assessOverview(
      anomalies: oneAnomaly,
      importSuccess: 95,
      importFailure: 5,
    );
    expect(findings, hasLength(1));
    expect(findings.single.kind, OverviewFindingKind.anomalies);
    expect(findings.single.number, 1);
  });

  test('a high failure rate gives an importFailures finding with percent', () {
    final findings = assessOverview(
      anomalies: calm,
      importSuccess: 60,
      importFailure: 40,
    );
    expect(findings, hasLength(1));
    expect(findings.single.kind, OverviewFindingKind.importFailures);
    expect(findings.single.number, 40);
  });

  test('too few attempts is never flagged', () {
    expect(
      assessOverview(anomalies: calm, importSuccess: 0, importFailure: 9),
      isEmpty,
    );
  });

  test('exactly the threshold is not flagged', () {
    expect(
      assessOverview(anomalies: calm, importSuccess: 80, importFailure: 20),
      isEmpty,
    );
  });
}
