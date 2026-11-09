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

  List<OverviewRow> assess({
    AnomalyReport? anomalies = calm,
    int? success = 95,
    int? failure = 5,
    int? feedback = 0,
    int? proposals = 0,
  }) => assessOverview(
    anomalies: anomalies,
    importSuccess: success,
    importFailure: failure,
    newFeedback: feedback,
    openProposals: proposals,
  );

  OverviewRow row(List<OverviewRow> rows, OverviewTarget t) =>
      rows.singleWhere((r) => r.target == t);

  test('one row per tab, in tab order', () {
    expect(assess().map((r) => r.target).toList(), [
      OverviewTarget.feedback,
      OverviewTarget.proposals,
      OverviewTarget.import,
      OverviewTarget.parsing,
      OverviewTarget.ops,
      OverviewTarget.engagement,
      OverviewTarget.recipes,
      OverviewTarget.ingredients,
      OverviewTarget.tagRules,
      OverviewTarget.guestList,
    ]);
  });

  test('calm data: measured tabs ok, the rest noSignal', () {
    final rows = assess();
    expect(row(rows, OverviewTarget.feedback).status, OverviewStatus.ok);
    expect(row(rows, OverviewTarget.proposals).status, OverviewStatus.ok);
    expect(row(rows, OverviewTarget.import).status, OverviewStatus.ok);
    for (final t in overviewNoSignalTargets) {
      expect(row(rows, t).status, OverviewStatus.noSignal);
    }
  });

  test('new feedback needs a look, with the count', () {
    final r = row(assess(feedback: 3), OverviewTarget.feedback);
    expect(r.status, OverviewStatus.needsLook);
    expect(r.advice, OverviewAdvice.feedbackNew);
    expect(r.number, 3);
    expect(r.atLeast, isFalse);
  });

  test('feedback at the read limit says at least', () {
    final r = row(
      assess(feedback: overviewFeedbackReadLimit),
      OverviewTarget.feedback,
    );
    expect(r.atLeast, isTrue);
    expect(
      row(
        assess(feedback: overviewFeedbackReadLimit - 1),
        OverviewTarget.feedback,
      ).atLeast,
      isFalse,
    );
  });

  test('open proposals need a look, at the limit says at least', () {
    final r = row(assess(proposals: 2), OverviewTarget.proposals);
    expect(r.status, OverviewStatus.needsLook);
    expect(r.advice, OverviewAdvice.proposalsOpen);
    expect(
      row(
        assess(proposals: overviewProposalReadLimit),
        OverviewTarget.proposals,
      ).atLeast,
      isTrue,
    );
  });

  test('an anomaly needs a look on the import row', () {
    final r = row(assess(anomalies: oneAnomaly), OverviewTarget.import);
    expect(r.status, OverviewStatus.needsLook);
    expect(r.advice, OverviewAdvice.importAnomalies);
    expect(r.number, 1);
  });

  test('a high failure rate beats an anomaly and names the percent', () {
    final r = row(
      assess(anomalies: oneAnomaly, success: 60, failure: 40),
      OverviewTarget.import,
    );
    expect(r.advice, OverviewAdvice.importFailures);
    expect(r.number, 40);
  });

  test('too few import attempts is never flagged', () {
    expect(
      row(assess(success: 0, failure: 9), OverviewTarget.import).status,
      OverviewStatus.ok,
    );
  });

  test('exactly 10 attempts is judged, exactly the threshold is ok', () {
    expect(
      row(assess(success: 7, failure: 3), OverviewTarget.import).advice,
      OverviewAdvice.importFailures,
    );
    expect(
      row(assess(success: 80, failure: 20), OverviewTarget.import).status,
      OverviewStatus.ok,
    );
  });

  test('a failed read is unavailable, never ok', () {
    final rows = assess(
      anomalies: null,
      success: null,
      feedback: null,
      proposals: null,
    );
    expect(
      row(rows, OverviewTarget.feedback).status,
      OverviewStatus.unavailable,
    );
    expect(
      row(rows, OverviewTarget.proposals).status,
      OverviewStatus.unavailable,
    );
    expect(row(rows, OverviewTarget.import).status, OverviewStatus.unavailable);
  });

  test(
    'a failed anomaly read is unavailable, but a known failure still shows',
    () {
      expect(
        row(assess(anomalies: null), OverviewTarget.import).status,
        OverviewStatus.unavailable,
      );
      final r = row(
        assess(anomalies: null, success: 60, failure: 40),
        OverviewTarget.import,
      );
      expect(r.status, OverviewStatus.needsLook);
    },
  );
}
