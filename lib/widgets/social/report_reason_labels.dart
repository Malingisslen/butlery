import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/report_reason.dart';

extension ReportReasonLabel on ReportReason {
  /// Null for the ids the dialog never offers; nothing in the app writes them.
  String? label(AppLocalizations l10n) => switch (this) {
    ReportReason.abuse => l10n.reportReasonInappropriate,
    ReportReason.spam => l10n.reportReasonSpam,
    ReportReason.harassment => l10n.reportReasonHarassment,
    ReportReason.copyright => l10n.reportReasonCopyright,
    ReportReason.other => l10n.reportReasonOther,
    ReportReason.csam || ReportReason.misinformation => null,
  };
}

/// The label for a stored `reports/*.reason`. A report saved before reasons
/// had ids holds its label as text, which is shown as it was saved.
String reportReasonDisplay(AppLocalizations l10n, String storedReason) =>
    ReportReason.fromWire(storedReason)?.label(l10n) ?? storedReason;
