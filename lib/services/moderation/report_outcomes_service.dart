import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/moderation_outcome.dart';

/// What was decided on the caller's closed reports (`getMyReportOutcomes`)
/// and on reports about the caller's own content (`getMyContentDecisions`).
class ReportOutcomesService extends BaseService {
  ReportOutcomesService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  String get serviceName => 'ReportOutcomesService';

  /// Report id to decision. No uid is sent: the callable takes the caller from
  /// `request.auth`. Throws on failure so the caller decides how to degrade.
  Future<Map<String, ModeratorDecision>> getMyReportOutcomes() async {
    final details = await getMyReportOutcomeDetails();
    return {for (final o in details.values) o.reportId: o.decision};
  }

  /// Report id to the full outcome (motivation, dates, appeal).
  Future<Map<String, ModerationOutcome>> getMyReportOutcomeDetails() async {
    final rows = await _rows('getMyReportOutcomes', 'outcomes');
    return {for (final o in rows) o.reportId: o};
  }

  /// Decisions about the caller's own content, newest first as the server
  /// sends them. Never names the reporter.
  Future<List<ModerationOutcome>> getMyContentDecisions() =>
      _rows('getMyContentDecisions', 'decisions');

  Future<List<ModerationOutcome>> _rows(String callable, String key) async {
    final result = await _functions
        .httpsCallable(
          callable,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Map<dynamic, dynamic>>();
    final rows = result.data[key];
    if (rows is! List) return const [];
    return [
      for (final row in rows) ?ModerationOutcome.fromMap(row),
    ];
  }
}
