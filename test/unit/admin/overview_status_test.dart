import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/admin/anomaly_report.dart';
import 'package:butlery/models/admin/overview_status.dart';

final _now = DateTime(2026, 11, 9, 12);
const Object _unset = Object();
final _freshOps = OpsHeartbeat(_now.subtract(const Duration(days: 3)));

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
    Object? ops = _unset,
    int? invites = 0,
  }) => assessOverview(
    anomalies: anomalies,
    importSuccess: success,
    importFailure: failure,
    newFeedback: feedback,
    openProposals: proposals,
    ops: identical(ops, _unset) ? _freshOps : ops as OpsHeartbeat?,
    pendingInvites: invites,
    now: _now,
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
    expect(row(rows, OverviewTarget.ops).advice, OverviewAdvice.opsOk);
    expect(
      row(rows, OverviewTarget.guestList).advice,
      OverviewAdvice.guestNone,
    );
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

  test('scheduled jobs silent for 8 days need a look, 7 days is fine', () {
    OverviewRow ops(int days) => row(
      assess(ops: OpsHeartbeat(_now.subtract(Duration(days: days)))),
      OverviewTarget.ops,
    );
    expect(ops(7).status, OverviewStatus.ok);
    final stale = ops(overviewOpsSilenceDays);
    expect(stale.status, OverviewStatus.needsLook);
    expect(stale.advice, OverviewAdvice.opsStale);
    expect(stale.number, overviewOpsSilenceDays);
  });

  test('no receipt at all needs a look', () {
    final r = row(assess(ops: const OpsHeartbeat(null)), OverviewTarget.ops);
    expect(r.status, OverviewStatus.needsLook);
    expect(r.advice, OverviewAdvice.opsNone);
  });

  test('unused invitations are informational and never flag the overview', () {
    final r = row(assess(invites: 4), OverviewTarget.guestList);
    expect(r.status, OverviewStatus.ok);
    expect(r.advice, OverviewAdvice.guestPending);
    expect(r.number, 4);
  });

  test('failed ops and invitation reads are unavailable, never ok', () {
    final rows = assess(ops: null, invites: null);
    expect(row(rows, OverviewTarget.ops).status, OverviewStatus.unavailable);
    expect(
      row(rows, OverviewTarget.guestList).status,
      OverviewStatus.unavailable,
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
