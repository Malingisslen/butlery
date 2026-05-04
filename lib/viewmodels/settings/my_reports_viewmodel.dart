import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Surfaces the current user's submitted moderation reports so they can see
/// which content they reported and the moderation status of each. Required
/// by Google Play's UGC appeal-process policy.
class MyReportsViewModel extends BaseViewModel {
  MyReportsViewModel({required ReportService reportService})
      : _reportService = reportService;

  final ReportService _reportService;

  List<ContentReport> _reports = const [];
  List<ContentReport> get reports => _reports;

  bool get hasReports => _reports.isNotEmpty;

  Future<bool> load() {
    return executeAsyncVoid(() async {
      _reports = await _reportService.getMyReports();
    }, errorPrefix: 'my_reports_load');
  }

  Future<bool> refresh() => load();
}
