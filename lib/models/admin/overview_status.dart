import 'package:butlery/models/admin/anomaly_report.dart';

/// The admin tabs the overview has a row for, in tab order after the overview.
enum OverviewTarget {
  feedback,
  proposals,
  import,
  parsing,
  ops,
  engagement,
  recipes,
  ingredients,
  tagRules,
  guestList,
}

/// How a tab looks right now. [noSignal] is for tabs where nothing can be
/// measured cheaply and honestly, so the row never claims more than that.
enum OverviewStatus { ok, needsLook, unavailable, noSignal }

/// Which sentence a row shows.
enum OverviewAdvice {
  feedbackNew,
  feedbackOk,
  proposalsOpen,
  proposalsOk,
  importFailures,
  importAnomalies,
  importOk,
  opsStale,
  opsNone,
  opsOk,
  guestPending,
  guestNone,
  noSignal,
  unavailable,
}

/// One row on the overview. [number] is the count or percentage the sentence
/// names, and [atLeast] says the count hit the read limit, so more may wait.
class OverviewRow {
  final OverviewTarget target;
  final OverviewStatus status;
  final OverviewAdvice advice;
  final int number;
  final bool atLeast;
  const OverviewRow(
    this.target,
    this.status,
    this.advice, {
    this.number = 0,
    this.atLeast = false,
  });
}

/// Below this many import attempts a failure rate is too noisy to act on.
const int overviewMinImportAttempts = 10;

/// An import failure rate strictly above this percentage is flagged.
const int overviewImportFailurePercent = 20;

/// How many feedback entries the overview reads; a result this long means more
/// may be waiting.
const int overviewFeedbackReadLimit = 50;

/// How many open proposals the overview reads.
const int overviewProposalReadLimit = 500;

const int overviewOpsSilenceDays = 8;

/// When the newest scheduled-job receipt was written; [lastReceiptAt] is null
/// when no receipt exists at all.
class OpsHeartbeat {
  final DateTime? lastReceiptAt;
  const OpsHeartbeat(this.lastReceiptAt);
}

/// Tabs with no cheap, honest signal: their row says nothing needs doing and
/// links to the tab.
const List<OverviewTarget> overviewNoSignalTargets = [
  OverviewTarget.parsing,
  OverviewTarget.engagement,
  OverviewTarget.recipes,
  OverviewTarget.ingredients,
  OverviewTarget.tagRules,
];

/// Turns what the overview could read into one row per tab. A null input means
/// that read failed; such a row is [OverviewStatus.unavailable] and is never
/// shown as ok.
List<OverviewRow> assessOverview({
  required AnomalyReport? anomalies,
  required int? importSuccess,
  required int? importFailure,
  required int? newFeedback,
  required int? openProposals,
  required OpsHeartbeat? ops,
  required int? pendingInvites,
  required DateTime now,
}) {
  OverviewRow noSignal(OverviewTarget t) =>
      OverviewRow(t, OverviewStatus.noSignal, OverviewAdvice.noSignal);
  return [
    _countRow(
      OverviewTarget.feedback,
      newFeedback,
      overviewFeedbackReadLimit,
      OverviewAdvice.feedbackNew,
      OverviewAdvice.feedbackOk,
    ),
    _countRow(
      OverviewTarget.proposals,
      openProposals,
      overviewProposalReadLimit,
      OverviewAdvice.proposalsOpen,
      OverviewAdvice.proposalsOk,
    ),
    _importRow(anomalies, importSuccess, importFailure),
    noSignal(OverviewTarget.parsing),
    _opsRow(ops, now),
    noSignal(OverviewTarget.engagement),
    noSignal(OverviewTarget.recipes),
    noSignal(OverviewTarget.ingredients),
    noSignal(OverviewTarget.tagRules),
    _guestRow(pendingInvites),
  ];
}

OverviewRow _opsRow(OpsHeartbeat? ops, DateTime now) {
  const target = OverviewTarget.ops;
  if (ops == null) {
    return const OverviewRow(
      target,
      OverviewStatus.unavailable,
      OverviewAdvice.unavailable,
    );
  }
  final last = ops.lastReceiptAt;
  if (last == null) {
    return const OverviewRow(
      target,
      OverviewStatus.needsLook,
      OverviewAdvice.opsNone,
    );
  }
  final days = now.difference(last).inDays;
  if (days >= overviewOpsSilenceDays) {
    return OverviewRow(
      target,
      OverviewStatus.needsLook,
      OverviewAdvice.opsStale,
      number: days,
    );
  }
  return const OverviewRow(target, OverviewStatus.ok, OverviewAdvice.opsOk);
}

// Informational, not a to-do: an invitation waiting to be used needs nothing
// from the admin, so it never turns the overview red.
OverviewRow _guestRow(int? pending) {
  const target = OverviewTarget.guestList;
  if (pending == null) {
    return const OverviewRow(
      target,
      OverviewStatus.unavailable,
      OverviewAdvice.unavailable,
    );
  }
  if (pending == 0) {
    return const OverviewRow(
      target,
      OverviewStatus.ok,
      OverviewAdvice.guestNone,
    );
  }
  return OverviewRow(
    target,
    OverviewStatus.ok,
    OverviewAdvice.guestPending,
    number: pending,
  );
}

OverviewRow _countRow(
  OverviewTarget target,
  int? count,
  int readLimit,
  OverviewAdvice waiting,
  OverviewAdvice none,
) {
  if (count == null) {
    return OverviewRow(
      target,
      OverviewStatus.unavailable,
      OverviewAdvice.unavailable,
    );
  }
  if (count == 0) return OverviewRow(target, OverviewStatus.ok, none);
  return OverviewRow(
    target,
    OverviewStatus.needsLook,
    waiting,
    number: count,
    atLeast: count >= readLimit,
  );
}

OverviewRow _importRow(
  AnomalyReport? anomalies,
  int? importSuccess,
  int? importFailure,
) {
  const target = OverviewTarget.import;
  if (importSuccess != null && importFailure != null) {
    final total = importSuccess + importFailure;
    if (total >= overviewMinImportAttempts) {
      final percent = (importFailure / total * 100).round();
      if (percent > overviewImportFailurePercent) {
        return OverviewRow(
          target,
          OverviewStatus.needsLook,
          OverviewAdvice.importFailures,
          number: percent,
        );
      }
    }
  }
  if (anomalies != null && anomalies.hasAnomalies) {
    return OverviewRow(
      target,
      OverviewStatus.needsLook,
      OverviewAdvice.importAnomalies,
      number: anomalies.anomalies.length,
    );
  }
  if (anomalies == null || importSuccess == null || importFailure == null) {
    return const OverviewRow(
      target,
      OverviewStatus.unavailable,
      OverviewAdvice.unavailable,
    );
  }
  return const OverviewRow(target, OverviewStatus.ok, OverviewAdvice.importOk);
}
