import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// One decision as its two parties see it. [role] is the caller's side: the
/// reporter reads it from their own report, the owner from
/// `getMyContentDecisions`, which carries the content type and reason itself.
class DecisionDetailViewModel extends BaseViewModel {
  DecisionDetailViewModel({
    required this.role,
    required this.reportId,
    required ReportService reportService,
    required ReportOutcomesService outcomesService,
    ModerationOutcome? outcome,
    ContentReport? report,
  }) : _reportService = reportService,
       _outcomesService = outcomesService,
       _outcome = outcome,
       _report = report;

  final AppealRole role;
  final String reportId;
  final ReportService _reportService;
  final ReportOutcomesService _outcomesService;

  ModerationOutcome? _outcome;
  ContentReport? _report;
  bool _loaded = false;

  ModerationOutcome? get outcome => _outcome;
  ContentReport? get report => _report;

  /// Loaded fine, but the caller has no decision or report with this id.
  bool get notFound =>
      _loaded &&
      !hasError &&
      _outcome == null &&
      (role == AppealRole.owner || _report == null);

  bool get isReady =>
      _outcome != null || (role == AppealRole.reporter && _report != null);

  ContentType? get contentType => _report?.contentType ?? _outcome?.contentType;
  String? get reason => _report?.reason ?? _outcome?.reason;
  DateTime? get reportedAt => _report?.createdAt;

  /// Fetches what the screen does not already hold.
  Future<bool> load({bool force = false}) {
    if (!force && isReady && (role == AppealRole.owner || _report != null)) {
      _loaded = true;
      return Future.value(true);
    }
    return executeAsyncVoid(() async {
      if (role == AppealRole.owner) {
        final all = await _outcomesService.getMyContentDecisions();
        _outcome = _firstWhereId(all);
      } else {
        final reports = await _reportService.getMyReports();
        for (final r in reports) {
          if (r.id == reportId) _report = r;
        }
        if (_report != null && _report!.status == ReportStatus.closed) {
          final details = await _outcomesService.getMyReportOutcomeDetails();
          _outcome = details[reportId];
        }
      }
      _loaded = true;
    }, errorPrefix: AppLocale.current.decisionDetailLoadFailed);
  }

  ModerationOutcome? _firstWhereId(List<ModerationOutcome> all) {
    for (final o in all) {
      if (o.reportId == reportId) return o;
    }
    return null;
  }

  Future<bool> reload() => load(force: true);
}
