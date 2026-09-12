// lib/widgets/common/profile/handlers/auth_action_handler.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';

/// Handler for authentication-related actions (logout, delete account).
class AuthActionHandler {
  /// Shows password dialog and re-authenticates. Returns true on success.
  /// On failure, shows error via [onError] callback and returns false.
  static Future<bool> reauthenticate(
    BuildContext context, {
    void Function(String error)? onError,
  }) async {
    final password = await ProfileDialogs.showPasswordDialog(context);
    if (password == null || !context.mounted) return false;

    final authService = ServiceLocator.get<AuthService>();
    final success = await authService.reauthenticateWithPassword(password);
    if (!success && context.mounted) {
      final msg = authService.errorMessage ?? context.l10n.errorSessionExpired;
      onError?.call(msg);
    }
    return success;
  }

  /// Handle logout flow.
  static Future<void> handleLogout(BuildContext context) async {
    final shouldLogout = await ProfileDialogs.showLogoutDialog(context);
    if (shouldLogout == true && context.mounted) {
      await _performLogout(context);
    }
  }

  /// Perform the actual logout.
  static Future<void> _performLogout(BuildContext context) async {
    try {
      final profileViewModel = ServiceLocator.get<ProfileViewModel>();
      await profileViewModel.logout();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',
          (route) => false,
        );
      }
    } catch (e) {
      AppLogger.error('Logout failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.profileLogoutFailed('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Handle account deletion flow - GDPR Article 17.
  static Future<void> handleDeleteAccount(BuildContext context) async {
    // The cheapest way to make the Art. 12(4) notice unmissable is not to need
    // it: say it here, before anything is deleted. `reported` is the only state
    // that draws the line — `unknown` is silent, because a failed read must not
    // surface moderation-adjacent text (ADR-0019), and the timeout inside
    // `ownReportStatus` is what keeps this from stalling the dialog offline.
    final reportStatus = await ServiceLocator.get<ReportService>()
        .ownReportStatus();
    if (!context.mounted) return;

    // Show initial confirmation dialog
    final shouldDelete = await ProfileDialogs.showDeleteAccountDialog(
      context,
      mayHaveOpenReview: reportStatus == OwnReportStatus.reported,
    );
    if (shouldDelete != true || !context.mounted) return;

    // Re-authenticate before proceeding
    String? reauthError;
    final reauthSuccess = await reauthenticate(
      context,
      onError: (msg) => reauthError = msg,
    );
    if (!reauthSuccess) {
      if (reauthError != null && context.mounted) {
        ProfileDialogs.showErrorDialog(context, reauthError!);
      }
      return;
    }
    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: LoadingIndicator(),
      ),
    );

    try {
      // Perform deletion using ProfileViewModel
      final profileViewModel = ServiceLocator.get<ProfileViewModel>();
      final outcome = await profileViewModel.deleteAccount(
        reason: 'User requested account deletion',
      );
      final success = outcome.success;

      // OUTSIDE the `context.mounted` gate below, and that placement is the
      // whole mechanism. `deleteUserAccount` signs out INSIDE itself before
      // returning — `AuthService.signOut` runs `popUserScope()` and the
      // repository sign-out, both really async — and `AuthWrapper` rebuilds to
      // the signed-out tree on that, which can dispose the context this method
      // holds. That is precisely the run where the live dialog never happens
      // and the persisted notice is the only delivery left; written inside the
      // gate, the same race that loses the dialog would lose the record too,
      // and the feature would be a no-op on exactly the runs it exists for.
      //
      // AWAITED: `SharedPreferences.setString` returns a Future, and a
      // fire-and-forget write leaves the race open while looking closed.
      //
      // Best-effort: the store swallows and logs its own failures. The live
      // dialog below renders from memory and must not depend on this.
      if (outcome.owesRetentionNotice) {
        final store = ServiceLocator.get<PendingRetentionNoticeStore>();

        // Claimed BEFORE the write, not merely before the dialog. The sign-out
        // above has already rebuilt the signed-out tree, so `PendingNoticeGate`
        // may be mounted and about to read this very record — and
        // `shared_preferences` publishes to its in-process cache before
        // `setString`'s future completes, so a claim taken afterwards leaves a
        // window where the record is readable and unclaimed. The gate would
        // then stack a second notice on the live one and log a recovery for a
        // delivery that worked.
        store.markDeliveredLive();
        await store.write(
          holdUntil: outcome.retained.first.holdUntil,
          provisional: outcome.retained.first.provisional,
        );

        // The context died during the write, so no live dialog is coming and
        // the gate is the only delivery left. Claiming early must not cost
        // that — this is the run the whole feature exists for.
        if (!context.mounted) store.releaseLiveClaim();
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator

        // BUT-2046 follow-up: when the erasure lawfully kept moderation
        // evidence, GDPR Art. 12(4) owes this person a notice — and this is
        // the only moment it can be given. The account and the session are
        // both already gone (`deleteUserAccount` signs out before it returns),
        // so there is no signed-in surface afterwards and no second channel:
        // email infra does not exist (BUT-417).
        //
        // OUTSIDE the success branch, and that placement is the decision
        // (Malin, 2026-09-09, BUT-2047). Art. 12(4) is owed because data was
        // KEPT, which does not depend on the rest of the erasure completing.
        // While the notice lived inside `if (success)` it was unreachable on
        // the path that hedges its wording: a provisional hold reports
        // `ok: false`, which lands in `failedCollections` and makes `success`
        // false — so the person was shown "could not be fully deleted" and
        // never told that anything had been kept, or why.
        //
        // AWAITED, and before the navigation: `pushNamedAndRemoveUntil` tears
        // down this route, so a dialog shown after it goes with it.
        //
        // The cap DATE comes from the server rather than the copy — a
        // hardcoded "180 days" is a promise the constant can silently break.
        if (outcome.owesRetentionNotice) {
          // Telemetry lives at the call sites rather than inside the dialog:
          // `ProfileDialogs` is a pure builder with no service dependencies,
          // and reaching into `ServiceLocator` from it would put DI in the
          // widget layer and break every test that renders the notice without
          // a container. Fire-and-forget, never awaited — the notice must not
          // wait on telemetry. `logEvent` is consent-gated inside the service,
          // so it is silently a no-op for anyone who never granted analytics,
          // which is what makes these counters a lower bound and never proof
          // that anybody was told anything.
          final analytics = ServiceLocator.get<AnalyticsService>();
          unawaited(
            analytics.logEvent(name: AnalyticsEvents.retentionNoticeShown),
          );
          await ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: outcome.retained.first.holdUntil,
            provisional: outcome.retained.first.provisional,
          );
          unawaited(
            analytics.logEvent(name: AnalyticsEvents.retentionNoticeClosed),
          );
          // Shown and read here, so the device copy has done its job and the
          // sign-in screen must not repeat it.
          await ServiceLocator.get<PendingRetentionNoticeStore>().clear();
          if (!context.mounted) return;
        }

        if (success) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
          // The ordinary deletion keeps the snackbar it always had; a deletion
          // that kept something has just said more than a snackbar could.
          if (!outcome.hasRetainedRecords) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.profileAccountDeletedPermanently),
                backgroundColor: context.butleryColors.success,
              ),
            );
          }
        } else {
          // Deletion failed. Shown AFTER the retention notice when both apply:
          // the person is owed both facts, and the one they cannot get later is
          // what was kept.
          ProfileDialogs.showErrorDialog(
            context,
            context.l10n.profileAccountCouldNotBeFullyDeleted,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Account deletion failed', e);
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ProfileDialogs.showErrorDialog(context, e.toString());
      }
    }
  }
}
