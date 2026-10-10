import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';

/// Shows the Art. 12(4) retention notice on the signed-out screen.
///
/// The notice is owed the moment an account deletion lawfully keeps moderation
/// evidence, and there is no email channel (BUT-417). A notice written in this
/// process belongs to the person who just deleted their account here and opens
/// expanded; one left by an earlier run opens collapsed.
///
/// It wraps the signed-out branch rather than living inside [AuthView], which
/// sits at exactly its allowlisted size in `ACCEPTED_LARGE_FILES.md`.
///
/// Modelled on `_OnboardingResumeGate` in `auth_wrapper.dart`: the service is
/// resolved in [initState], never in `build`, and the dialog goes up on a
/// post-frame callback.
class PendingNoticeGate extends StatefulWidget {
  const PendingNoticeGate({super.key, required this.child});

  final Widget child;

  /// The re-entrancy guard is process-wide, so a test process that leaves one
  /// notice open would otherwise silence the gate for every case after it.
  @visibleForTesting
  static void resetForTesting() => _PendingNoticeGateState._showing = false;

  @override
  State<PendingNoticeGate> createState() => _PendingNoticeGateState();
}

class _PendingNoticeGateState extends State<PendingNoticeGate> {
  late final PendingRetentionNoticeStore _store;

  /// Guards against two instances of this gate racing each other. Set BEFORE
  /// the first await, because a check-then-await-then-set lets both pass.
  static bool _showing = false;

  /// A write arrived while an attempt was in flight; look again afterwards.
  bool _recheck = false;

  @override
  void initState() {
    super.initState();
    _store = ServiceLocator.get<PendingRetentionNoticeStore>();
    _store.writes.addListener(_showIfPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfPending());
  }

  @override
  void dispose() {
    _store.writes.removeListener(_showIfPending);
    super.dispose();
  }

  Future<void> _showIfPending() async {
    if (_showing) {
      _recheck = true;
      return;
    }
    _showing = true;

    try {
      final notice = await _store.read();
      if (notice == null || !mounted) return;
      final live = _store.writtenInThisProcess;

      // `recovered` counts the notices that reached their person only at a
      // later launch.
      unawaited(
        ServiceLocator.get<AnalyticsService>().logEvent(
          name: live
              ? AnalyticsEvents.retentionNoticeShown
              : AnalyticsEvents.retentionNoticeRecovered,
        ),
      );
      // Collapsed for a record from an earlier run: the person in front of
      // this screen may not be the person the notice is about. Malin's call,
      // 2026-09-12 (option b).
      await ProfileDialogs.showRetentionNoticeDialog(
        context,
        holdUntil: notice.holdUntil,
        provisional: notice.provisional,
        reviewKept: notice.reviewKept,
        ownReportKept: notice.ownReportKept,
        startCollapsed: !live,
      );
      unawaited(
        ServiceLocator.get<AnalyticsService>().logEvent(
          name: AnalyticsEvents.retentionNoticeClosed,
        ),
      );
      // Cleared only after it has actually been closed: a notice torn down
      // unread must come back.
      await _store.clear();
    } finally {
      _showing = false;
      if (_recheck && mounted) {
        _recheck = false;
        unawaited(_showIfPending());
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
