import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Surfaces the current user's submitted moderation reports so they can see
/// which content they reported and the moderation status of each. Required
/// by Google Play's UGC appeal-process policy.
class MyReportsViewModel extends BaseViewModel {
  MyReportsViewModel({
    required ReportService reportService,
    required ReportOutcomesService reportOutcomesService,
  }) : _reportService = reportService,
       _outcomesService = reportOutcomesService;

  final ReportService _reportService;
  final ReportOutcomesService _outcomesService;

  List<ContentReport> _reports = const [];
  List<ContentReport> get reports => _reports;

  bool get hasReports => _reports.isNotEmpty;

  // Memory only: the outcome of a closed case is not stored on the device.
  Map<String, ModeratorDecision> _outcomes = const {};

  ModeratorDecision? decisionFor(ContentReport report) =>
      report.moderatorAction ?? _outcomes[report.id];

  Future<bool> load() {
    return executeAsyncVoid(() async {
      _reports = await _reportService.getMyReports();
      _outcomes = await _loadOutcomes(_reports);
    }, errorPrefix: AppLocale.current.myReportsLoadFailed);
  }

  // The reports still show without an outcome, so a failure here is not an
  // error screen.
  Future<Map<String, ModeratorDecision>> _loadOutcomes(
    List<ContentReport> reports,
  ) async {
    if (!reports.any((r) => r.status == ReportStatus.closed)) return const {};
    try {
      return await _outcomesService.getMyReportOutcomes();
    } catch (e) {
      AppLogger.warning('[MyReportsViewModel] Could not load outcomes: $e');
      return const {};
    }
  }

  Future<bool> refresh() => load();
}
