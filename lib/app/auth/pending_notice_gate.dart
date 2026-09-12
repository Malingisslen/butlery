import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';

/// Shows an Art. 12(4) retention notice that was never read.
///
/// The notice is owed the moment an account deletion lawfully keeps moderation
/// evidence, and it has one moment to be shown: after the account is gone and
/// before the sign-out navigation. If the app was killed, backgrounded or the
/// route was torn down in that second, nothing else would ever deliver it —
/// there is no email channel (BUT-417). This gate is the second attempt, on the
/// signed-out screen where such a person lands.
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
  ///
  /// It does NOT arbitrate against the live dialog — `deliveredLiveInThisProcess`
  /// does that, and it has to, because this flag is false at the moment the
  /// deletion's own sign-out rebuilds this branch.
  static bool _showing = false;

  @override
  void initState() {
    super.initState();
    _store = ServiceLocator.get<PendingRetentionNoticeStore>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfPending());
  }

  Future<void> _showIfPending() async {
    // The live dialog has this run. A record is still on disk while that dialog
    // is up — it is cleared only once the person closes it.
    //
    // This gate makes ONE attempt per mount and never retries, so any
    // interleaving it loses defers delivery to the next launch rather than
    // costing it.
    if (_showing || _store.deliveredLiveInThisProcess) return;
    _showing = true;

    try {
      final notice = await _store.read();
      if (notice == null || !mounted) return;
      // Re-checked AFTER the read: the handler may have claimed the run while
      // this await was in flight, and drawing then would put a second notice
      // on a working one and log a recovery for a delivery that happened.
      if (_store.deliveredLiveInThisProcess) return;

      // The one number that says whether this mechanism earns its keep: a
      // record still here means the live dialog never delivered.
      unawaited(
        ServiceLocator.get<AnalyticsService>().logEvent(
          name: AnalyticsEvents.retentionNoticeRecovered,
        ),
      );
      // Collapsed: the person in front of this screen may not be the person the
      // notice is about. Malin's call, 2026-09-12 (option b).
      await ProfileDialogs.showRetentionNoticeDialog(
        context,
        holdUntil: notice.holdUntil,
        provisional: notice.provisional,
        startCollapsed: true,
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
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
