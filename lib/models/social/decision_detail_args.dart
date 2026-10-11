import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_outcome.dart';

/// Route arguments for the decision detail. A list passes what it already
/// holds; a push tap passes only the [reportId] and the view fetches the rest.
class DecisionDetailArgs {
  const DecisionDetailArgs({
    required this.role,
    required this.reportId,
    this.outcome,
    this.report,
  });

  final AppealRole role;
  final String reportId;
  final ModerationOutcome? outcome;
  final ContentReport? report;
}

/// Route arguments for the appeal form.
class AppealFormArgs {
  const AppealFormArgs({required this.role, required this.outcome});

  final AppealRole role;
  final ModerationOutcome outcome;
}
