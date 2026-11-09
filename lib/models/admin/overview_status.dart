import 'package:butlery/models/admin/anomaly_report.dart';

/// Admin tab a finding on the overview points the operator to.
enum OverviewTarget { import, parsing, feedback }

enum OverviewFindingKind { anomalies, importFailures }

/// One thing on the overview that needs the operator's attention. [number] is
/// the anomaly count for [OverviewFindingKind.anomalies] and the failure
/// percentage for [OverviewFindingKind.importFailures].
class OverviewFinding {
  final OverviewFindingKind kind;
  final OverviewTarget target;
  final int number;
  const OverviewFinding(this.kind, this.target, this.number);
}

/// Below this many import attempts a failure rate is too noisy to act on.
const int overviewMinImportAttempts = 10;

/// An import failure rate strictly above this percentage is flagged.
const int overviewImportFailurePercent = 20;

/// Turns the nightly anomaly report and the import counts into the findings
/// the overview shows. An empty list means all clear.
List<OverviewFinding> assessOverview({
  required AnomalyReport anomalies,
  required int importSuccess,
  required int importFailure,
}) {
  final findings = <OverviewFinding>[];
  if (anomalies.hasAnomalies) {
    findings.add(
      OverviewFinding(
        OverviewFindingKind.anomalies,
        OverviewTarget.import,
        anomalies.anomalies.length,
      ),
    );
  }
  final total = importSuccess + importFailure;
  if (total >= overviewMinImportAttempts) {
    final percent = (importFailure / total * 100).round();
    if (percent > overviewImportFailurePercent) {
      findings.add(
        OverviewFinding(
          OverviewFindingKind.importFailures,
          OverviewTarget.import,
          percent,
        ),
      );
    }
  }
  return findings;
}
