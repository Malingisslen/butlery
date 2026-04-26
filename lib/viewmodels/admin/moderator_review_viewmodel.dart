import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel powering the admin-only moderator review screen.
///
/// Keeps the Firestore listener lifecycle tied to view lifetime: subscribes
/// in [startListening] and cancels in [dispose]. The underlying stream is
/// filtered to open reports (status != 'closed').
class ModeratorReviewViewModel extends BaseViewModel {
  final ReportService _reportService;

  StreamSubscription<List<ContentReport>>? _reportsSub;
  List<ContentReport> _reports = const [];
  bool _hasStarted = false;

  ModeratorReviewViewModel({ReportService? reportService})
      : _reportService = reportService ?? ServiceLocator.get<ReportService>();

  List<ContentReport> get reports => _reports;

  void startListening() {
    if (_hasStarted) return;
    _hasStarted = true;
    setLoading(true);
    _reportsSub = _reportService.watchOpenReports().listen(
      (list) {
        if (isDisposed) return;
        _reports = list;
        setLoading(false);
        notifyListeners();
      },
      onError: (Object err) {
        if (isDisposed) return;
        setError(err.toString());
      },
    );
  }

  Future<void> advance(ContentReport report) async {
    await executeAsyncVoid(
      () async {
        await _reportService.advanceReportStatus(report);
      },
      errorPrefix: 'advanceReportStatus',
    );
  }

  Future<void> close(ContentReport report) async {
    await executeAsyncVoid(
      () async {
        await _reportService.closeReport(report);
      },
      errorPrefix: 'closeReport',
    );
  }

  /// Dispatches the moderator's takedown action for [report]:
  /// - profile → suspend (hide flag, reversible)
  /// - everything else → hard delete
  ///
  /// The dashboard binds a single button to this method; the verb in the
  /// confirmation dialog should reflect [isReversibleAction].
  Future<void> takeDown(ContentReport report) async {
    await executeAsyncVoid(
      () async {
        if (report.contentType == ContentType.profile) {
          await _reportService.suspendReportedProfile(report);
        } else {
          await _reportService.deleteReportedContent(report);
        }
      },
      errorPrefix: 'takeDown',
    );
  }

  /// Whether the takedown action for [report] is reversible (true for
  /// profile suspend; false for hard-delete content types).
  bool isReversibleAction(ContentReport report) =>
      report.contentType == ContentType.profile;

  @override
  void dispose() {
    _reportsSub?.cancel();
    _reportsSub = null;
    super.dispose();
  }
}
