import 'package:clock/clock.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/closed_report.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// What came of a reopen. [blocked] carries the server's reason and leaves
/// the row in the list (or takes it out when the report is no longer closed).
sealed class ReopenResult {
  const ReopenResult();
}

class ReopenSucceeded extends ReopenResult {
  const ReopenSucceeded();
}

class ReopenBlocked extends ReopenResult {
  const ReopenBlocked(this.block);
  final ReopenBlock block;
}

class ReopenFailed extends ReopenResult {
  const ReopenFailed();
}

/// The "Stängda" tab: decided reports, paged (`listClosedReports`).
class ModeratorClosedViewModel extends BaseViewModel {
  ModeratorClosedViewModel({required ModerationAppealsService service})
    : _service = service;

  final ModerationAppealsService _service;

  /// The window for "Den här veckan".
  static const Duration recentWindow = Duration(days: 7);

  List<ClosedReport> _reports = const [];
  String? _nextCursor;
  bool _requested = false;
  bool _loaded = false;
  bool _isLoadingMore = false;

  List<ClosedReport> get reports => _reports;

  /// False until the first page has arrived.
  bool get hasLoaded => _loaded;
  bool get hasMore => _nextCursor != null;
  bool get isLoadingMore => _isLoadingMore;

  List<ClosedReport> get thisWeek {
    final since = clock.now().subtract(recentWindow);
    return [
      for (final r in _reports)
        if (r.decidedAt != null && r.decidedAt!.isAfter(since)) r,
    ];
  }

  List<ClosedReport> get earlier {
    final recent = thisWeek.toSet();
    return [
      for (final r in _reports)
        if (!recent.contains(r)) r,
    ];
  }

  /// Loads the first page the first time the tab is shown.
  Future<void> ensureLoaded() async {
    if (_requested) return;
    await load();
  }

  Future<bool> load() {
    _requested = true;
    return executeAsyncVoid(() async {
      final page = await _service.listClosedReports();
      _reports = page.reports;
      _nextCursor = page.nextCursor;
      _loaded = true;
    }, errorPrefix: AppLocale.current.moderatorClosedLoadFailed);
  }

  /// Appends the next page. False when it failed; the list is left as it was.
  Future<bool> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingMore || isDisposed) return true;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _service.listClosedReports(cursor: cursor);
      if (isDisposed) return true;
      final known = {for (final r in _reports) r.reportId};
      _reports = [
        ..._reports,
        for (final r in page.reports)
          if (!known.contains(r.reportId)) r,
      ];
      _nextCursor = page.nextCursor;
      return true;
    } catch (e) {
      AppLogger.error('[ModeratorClosedViewModel] loadMore failed', e);
      return false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<ReopenResult> reopen(ClosedReport report) async {
    if (isDisposed) return const ReopenFailed();
    try {
      await _service.reopenReport(report.reportId);
    } on ReopenReportException catch (e) {
      final block = e.block;
      if (block == null) {
        AppLogger.error('[ModeratorClosedViewModel] reopen failed', e);
        return const ReopenFailed();
      }
      _applyBlock(report, block);
      return ReopenBlocked(block);
    } catch (e) {
      AppLogger.error('[ModeratorClosedViewModel] reopen failed', e);
      return const ReopenFailed();
    }
    _remove(report);
    return const ReopenSucceeded();
  }

  // A report that is no longer closed or no longer there has left this list
  // for good; any other refusal keeps the row and disables its button.
  void _applyBlock(ClosedReport report, ReopenBlock block) {
    if (isDisposed) return;
    if (block == ReopenBlock.notClosed || block == ReopenBlock.reportGone) {
      _remove(report);
      return;
    }
    _reports = [
      for (final r in _reports)
        if (r.reportId == report.reportId) r.withReopenBlock(block) else r,
    ];
    notifyListeners();
  }

  void _remove(ClosedReport report) {
    if (isDisposed) return;
    _reports = [
      for (final r in _reports)
        if (r.reportId != report.reportId) r,
    ];
    notifyListeners();
  }
}
