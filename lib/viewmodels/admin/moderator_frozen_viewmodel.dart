import 'dart:async';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/admin/freeze_result.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// The "Sparade" tab: copies a moderator keeps past their case, streamed so
/// an extension or release shows up without a reload.
class ModeratorFrozenViewModel extends BaseViewModel {
  ModeratorFrozenViewModel({
    required ReportService reportService,
    required ModerationAppealsService appealsService,
  }) : _reportService = reportService,
       _appealsService = appealsService;

  final ReportService _reportService;
  final ModerationAppealsService _appealsService;

  StreamSubscription<List<ReportEvidence>>? _sub;
  List<ReportEvidence> _items = const [];
  bool _hasStarted = false;
  bool _hasLoaded = false;

  List<ReportEvidence> get items => _items;
  bool get hasLoaded => _hasLoaded;

  void startListening() {
    if (_hasStarted) return;
    _hasStarted = true;
    _sub = _reportService.watchFrozenEvidence().listen(
      (list) {
        if (isDisposed) return;
        _items = list;
        _hasLoaded = true;
        clearError();
        notifyListeners();
      },
      onError: (Object err) {
        if (isDisposed) return;
        AppLogger.error('Frozen evidence stream failed', err);
        _sub?.cancel();
        _sub = null;
        setError(AppLocale.current.moderatorFrozenLoadFailed);
      },
    );
  }

  /// The error state's Försök igen.
  void retry() {
    _sub?.cancel();
    _sub = null;
    _hasStarted = false;
    clearError();
    startListening();
  }

  Future<FreezeResult> extend(ReportEvidence evidence, FreezeReason reason) =>
      _run(evidence, FreezeAction.extend, reason);

  Future<FreezeResult> release(ReportEvidence evidence) =>
      _run(evidence, FreezeAction.release, null);

  Future<FreezeResult> _run(
    ReportEvidence evidence,
    FreezeAction action,
    FreezeReason? reason,
  ) async {
    if (isDisposed) return const FreezeFailed();
    final result = await runFreeze(
      _appealsService,
      evidence.reportId,
      action: action,
      reason: reason,
    );
    if (result is! FreezeFailed) {
      _reportService.forgetReportEvidence(evidence.reportId);
    }
    return result;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}
