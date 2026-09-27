// lib/widgets/common/profile/handlers/auth_action_handler.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/account/retained_record.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Builds the sign-out guard. Replaced in tests.
  @visibleForTesting
  static SignOutGuard Function() guardFactory = () =>
      SignOutGuard(authService: ServiceLocator.get<AuthService>());

  /// Handle logout flow.
  ///
  /// With changes still in the queue, the sign-out is blocked with an
  /// explanation instead of the plain question: "N ändringar har inte
  /// sparats", Vänta på synk · Logga ut och släng (produktregler.md:193,
  /// Skarmar v12 del 4 #utloggningko). The queue is only emptied when the
  /// user picks the destructive choice; an ordinary sign-out leaves it on the
  /// device, where it syncs at this account's next sign-in.
  static Future<void> handleLogout(BuildContext context) async {
    final guard = guardFactory();
    final pending = await guard.pendingForCurrentUser();
    if (!context.mounted) return;

    if (!pending.isEmpty) {
      final choice = await ProfileDialogs.showPendingChangesDialog(
        context,
        pending,
      );
      if (choice != PendingChangesChoice.discardAndSignOut ||
          !context.mounted) {
        return;
      }
      try {
        await guard.discardForCurrentUser();
      } catch (e) {
        AppLogger.error('Discarding queued changes failed', e);
        if (context.mounted) {
          SnackBarUtils.showFailure(
            context,
            what: context.l10n.signOutDiscardFailed,
          );
        }
        return;
      }
      if (context.mounted) await _performLogout(context);
      return;
    }

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
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.errorCouldNotLogOut,
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

    // Show initial confirmation dialog. It asks for the reason before
    // anything else: "Ett skäl skickas med och hamnar i revisionsraden. Det
    // frågas före, för efteråt finns ingen kvar att fråga"
    // (produktregler.md:614; Skarmar v12 etapp 5-7 #kontoradera).
    final reason = await ProfileDialogs.showDeleteAccountDialog(
      context,
      mayHaveOpenReview: reportStatus == OwnReportStatus.reported,
    );
    if (reason == null || !context.mounted) return;

    // Re-authenticate before proceeding
    String? reauthError;
    final reauthSuccess = await reauthenticate(
      context,
      onError: (msg) => reauthError = msg,
    );
    if (!reauthSuccess) {
      if (reauthError != null && context.mounted) {
        _showDeletionFailed(context, cause: reauthError);
      }
      return;
    }
    if (!context.mounted) return;

    // The deletion runs as a waiting STATE that cannot be cancelled once it
    // has started (produktregler.md:611; #kontovantan): the plate line with
    // what is happening, never a spinner (produktregler.md:163, B-18).
    ProfileDialogs.showDeletionWaitingDialog(context);

    try {
      // Perform deletion using ProfileViewModel
      final profileViewModel = ServiceLocator.get<ProfileViewModel>();
      var outcome = await profileViewModel.deleteAccount(reason: reason);

      // The server wants a sign-in at most five minutes old. That is a step,
      // not an error: sign in again and the same request is made again
      // (produktregler.md:612; #kontoreauth). Nothing was deleted yet.
      if (outcome.requiresReauth && context.mounted) {
        Navigator.pop(context); // Close the waiting state
        final again = await ProfileDialogs.showDeletionReauthStep(context);
        if (!again || !context.mounted) return;
        final reauthed = await reauthenticate(
          context,
          onError: (msg) => reauthError = msg,
        );
        if (!reauthed || !context.mounted) {
          if (reauthError != null && context.mounted) {
            _showDeletionFailed(context, cause: reauthError);
          }
          return;
        }
        ProfileDialogs.showDeletionWaitingDialog(context);
        outcome = await profileViewModel.deleteAccount(reason: reason);
      }
      final success = outcome.success || outcome.isComplete;

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
        final facts = RetentionNoticeFacts.from(outcome.retained);
        await store.write(
          holdUntil: facts.holdUntil,
          provisional: facts.provisional,
          reviewKept: facts.reviewKept,
          ownReportKept: facts.ownReportKept,
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
          final facts = RetentionNoticeFacts.from(outcome.retained);
          await ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: facts.holdUntil,
            provisional: facts.provisional,
            reviewKept: facts.reviewKept,
            ownReportKept: facts.ownReportKept,
          );
          unawaited(
            analytics.logEvent(name: AnalyticsEvents.retentionNoticeClosed),
          );
          // Shown and read here, so the device copy has done its job and the
          // sign-in screen must not repeat it.
          await ServiceLocator.get<PendingRetentionNoticeStore>().clear();
          if (!context.mounted) return;
        }

        if (outcome.isPartial) {
          // The account is gone and something remained. Its own words, the
          // audit id, and support as the way on — never "Försök igen"
          // (produktregler.md:613; #kontodelvis).
          await ProfileDialogs.showPartialDeletionDialog(
            context,
            failedCount: outcome.genuinelyFailed.length,
            auditLogId: outcome.auditLogId,
            onContactSupport: (id) => _contactSupport(context, id),
          );
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
        } else if (success) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
          // The ordinary deletion keeps the snackbar it always had; a deletion
          // that kept something has just said more than a snackbar could.
          if (!outcome.hasRetainedRecords) {
            SnackBarUtils.showSuccess(
              context,
              context.l10n.profileAccountDeletedPermanently,
            );
          }
        } else {
          // Deletion failed. Shown AFTER the retention notice when both apply:
          // the person is owed both facts, and the one they cannot get later is
          // what was kept.
          ProfileDialogs.showErrorDialog(
            context,
            message: context.l10n.profileAccountCouldNotBeFullyDeleted,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Account deletion failed', e);
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        ProfileDialogs.showErrorDialog(context);
      }
    }
  }

  /// The account was not deleted because of a known [cause] (a failed
  /// sign-in): what did not happen, then why (content-style-guide.md:90).
  static void _showDeletionFailed(BuildContext context, {String? cause}) {
    ProfileDialogs.showErrorDialog(
      context,
      message: SnackBarUtils.failureMessage(
        context.l10n.profileAccountDeleteFailed,
        cause,
      ),
    );
  }

  /// Opens a mail to the privacy address with the audit id in the subject.
  /// The same address the legal views use (legal_contact_footer.dart).
  static Future<void> _contactSupport(
    BuildContext context,
    String? auditLogId,
  ) async {
    final subject = Uri.encodeComponent(
      context.l10n.accountDeletionPartialEmailSubject(auditLogId.orEmpty()),
    );
    final uri = Uri.parse('mailto:integritet@butlery.se?subject=$subject');
    final fallback = context.l10n.accountDeletionPartialNoEmail;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } on Exception catch (e) {
      AppLogger.error('Could not open the mail app', e);
    }
    if (context.mounted) SnackBarUtils.showFailure(context, what: fallback);
  }
}
