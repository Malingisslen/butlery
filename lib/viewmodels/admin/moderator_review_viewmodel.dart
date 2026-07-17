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
        setError(err.toString());
      },
    );
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
