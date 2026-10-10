import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_report.dart';

/// The plain-words outcome of a report. Describes the reported item only,
/// never the person behind it.
String reportOutcomeText(
  AppLocalizations l10n,
  ReportStatus status,
  ModeratorDecision? decision,
) {
  switch (decision) {
    case ModeratorDecision.contentRemoved:
      return l10n.myReportsOutcomeContentRemoved;
    case ModeratorDecision.profileHidden:
      return l10n.myReportsOutcomeProfileHidden;
    case ModeratorDecision.noAction:
      return l10n.myReportsOutcomeNoAction;
    case null:
      return switch (status) {
        ReportStatus.newReport => l10n.myReportsOutcomeReceived,
        ReportStatus.inReview ||
        ReportStatus.actioned => l10n.myReportsOutcomeInReview,
        ReportStatus.closed => l10n.myReportsOutcomeClosed,
      };
  }
}
