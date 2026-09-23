import 'dart:async';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
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

  /// Resolved minor-status per content-owner uid (BUT-1609). Populated
  /// lazily as reports stream in; missing entries render as non-minor
  /// until the lookup completes (fail-closed, no flicker to "minor").
  final Map<String, bool> _minorOwners = {};
  final Set<String> _minorLookupsInFlight = {};

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
        _resolveMinorOwners(list);
      },
      onError: (Object err) {
        if (isDisposed) return;
        // The error state names what failed; the raw exception belongs to
        // the log (content-style-guide.md:89-94, P5-U01). Release the
        // subscription; [_hasStarted] stays set so a rebuild of the view
        // (which calls [startListening]) does not re-subscribe behind the
        // error. Only [retry] opens a fresh one.
        AppLogger.error('Moderator review stream failed', err);
        _reportsSub?.cancel();
        _reportsSub = null;
        setError(AppLocale.current.moderatorReportsLoadFailed);
      },
    );
  }

  /// The error state's Försök igen: drop any open subscription and listen
  /// again from scratch.
  void retry() {
    _reportsSub?.cancel();
    _reportsSub = null;
    _hasStarted = false;
    clearError();
    startListening();
  }

  /// Whether the reported content's owner account belongs to a minor.
  /// `false` while the lookup is pending or when the report has no owner.
  bool isMinorOwner(ContentReport report) =>
      _minorOwners[report.contentOwnerId] ?? false;

  Future<void> _resolveMinorOwners(List<ContentReport> reports) async {
    final pending = reports
        .map((r) => r.contentOwnerId)
        .whereType<String>()
        .where(
          (id) =>
              id.isNotEmpty &&
              !_minorOwners.containsKey(id) &&
              !_minorLookupsInFlight.contains(id),
        )
        .toSet();
    if (pending.isEmpty) return;
    _minorLookupsInFlight.addAll(pending);

    // Resolve the owners CONCURRENTLY (the in-flight set is already populated,
    // so this is safe) — a busy queue's badges shouldn't wait on a sum of
    // sequential Firestore round-trips, just the slowest one.
    final resolved = await Future.wait(
      pending.map((id) async => (id, await _reportService.isMinorAccount(id))),
    );
    if (isDisposed) return;

    var anyMinor = false;
    for (final (id, isMinor) in resolved) {
      _minorLookupsInFlight.remove(id);
      // A failed lookup (null) is left UNRESOLVED — not memoized as false — so
      // a later report emission retries it. Locking in a fail-closed false on a
      // transient blip would hide a real minor for the rest of the session.
      if (isMinor == null) continue;
      _minorOwners[id] = isMinor;
      anyMinor = anyMinor || isMinor;
    }
    // Only a `true` resolution changes what the cards render: (a) the list
    // emission already notified with the fail-closed default, so a false
    // changes nothing rendered, and (b) minority is immutable per owner
    // (server-set once at signup), so a value never flips true→false — no
    // rebuild is ever missed.
    if (anyMinor) notifyListeners();
  }

  /// Moves [report] one step on. Returns false when the write was refused;
  /// the view then shows the failure as a snackbar (content-style-guide.md
  /// :87-97), and the list and its load-error state are left alone, so a
  /// refused action never replaces the queue.
  Future<bool> advance(ContentReport report) => _act(
    'Moderator advance failed',
    () => _reportService.advanceReportStatus(report),
  );

  Future<bool> close(ContentReport report) => _act(
    'Moderator close failed',
    () => _reportService.closeReport(report),
  );

  /// Dispatches the moderator's takedown action for [report]:
  /// - profile → suspend (hide flag, reversible)
  /// - everything else → hard delete
  ///
  /// The dashboard binds a single button to this method; the verb in the
  /// confirmation dialog should reflect [isReversibleAction].
  Future<bool> takeDown(ContentReport report) => _act(
    'Moderator takedown failed',
    () => report.contentType == ContentType.profile
        ? _reportService.suspendReportedProfile(report)
        : _reportService.deleteReportedContent(report),
  );

  /// Runs one moderator action. The service reports a refusal as `false`
  /// (its safeExecute swallows the exception), so that result is the
  /// failure; a thrown error counts too. The exception goes to the log only;
  /// what the user reads is the view's failure snackbar.
  Future<bool> _act(String logLabel, Future<bool> Function() action) async {
    if (isDisposed) return false;
    try {
      final ok = await action();
      if (!ok) AppLogger.error(logLabel, 'refused');
      return ok;
    } catch (e) {
      AppLogger.error(logLabel, e);
      return false;
    }
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
