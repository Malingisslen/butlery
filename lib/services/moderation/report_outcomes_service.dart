import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/models/social/content_report.dart';

/// What was decided on the caller's closed reports, read through the
/// `getMyReportOutcomes` callable.
class ReportOutcomesService extends BaseService {
  ReportOutcomesService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  String get serviceName => 'ReportOutcomesService';

  /// Report id to decision. No uid is sent: the callable takes the caller from
  /// `request.auth`. Throws on failure so the caller decides how to degrade.
  Future<Map<String, ModeratorDecision>> getMyReportOutcomes() async {
    final result = await _functions
        .httpsCallable(
          'getMyReportOutcomes',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Map<dynamic, dynamic>>();
    final rows = result.data['outcomes'];
    final outcomes = <String, ModeratorDecision>{};
    if (rows is! List) return outcomes;
    for (final row in rows.whereType<Map<dynamic, dynamic>>()) {
      final id = row['reportId'];
      final wire = row['decision'];
      final decision = ModeratorDecision.fromWire(wire is String ? wire : null);
      if (id is String && id.isNotEmpty && decision != null) {
        outcomes[id] = decision;
      }
    }
    return outcomes;
  }
}
