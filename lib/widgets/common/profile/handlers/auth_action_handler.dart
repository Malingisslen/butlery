// lib/widgets/common/profile/handlers/auth_action_handler.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/dialogs/deletion_schedule_dialogs.dart';
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
  ///
  /// The confirmation schedules the deletion (BUT-950); the account is erased
  /// by the server when the grace period ends, and signing in before then
  /// offers an undo.
  static Future<void> handleDeleteAccount(BuildContext context) async {
    // The Art. 12(4) notice can no longer be shown after the erasure, because
    // the server runs it days later with nobody signed in. `unknown` is
    // silent, because a failed read must not surface
    // moderation-adjacent text (ADR-0019), and the timeout inside
    // `ownReportStatus` keeps this from stalling the dialog offline.
    final reportStatus = await ServiceLocator.get<ReportService>()
        .ownReportStatus();
    if (!context.mounted) return;

    // The reason is asked first: "Ett skäl skickas med och hamnar i
    // revisionsraden. Det frågas före, för efteråt finns ingen kvar att
    // fråga" (Skarmar v12 etapp 5-7 #kontoradera).
    final reason = await ProfileDialogs.showDeleteAccountDialog(
      context,
      mayHaveOpenReview: reportStatus == OwnReportStatus.reported,
    );
    if (reason == null || !context.mounted) return;

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

    DeletionScheduleDialogs.showSchedulingDialog(context);

    try {
      final profileViewModel = ServiceLocator.get<ProfileViewModel>();
      var result = await profileViewModel.scheduleDeletion(reason: reason);

      // The server wants a sign-in at most five minutes old. That is a step,
      // not an error: sign in again and the same request is made again
      // (#kontoreauth). Nothing was scheduled yet.
      if (result.status == DeletionScheduleStatus.requiresReauth &&
          context.mounted) {
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
        DeletionScheduleDialogs.showSchedulingDialog(context);
        result = await profileViewModel.scheduleDeletion(reason: reason);
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close the waiting state

      if (!result.isOk) {
        _showDeletionFailed(
          context,
          cause: result.status == DeletionScheduleStatus.network
              ? context.l10n.errorNetwork
              : null,
        );
        return;
      }

      // Shown while still signed in, then signed out: signing out replaces
      // this screen, so a dialog shown after it would never appear.
      try {
        await DeletionScheduleDialogs.showScheduledDialog(
          context,
          scheduledFor: result.scheduledFor,
        );
      } finally {
        await profileViewModel.signOutAfterScheduling();
      }
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } catch (e) {
      AppLogger.error('Scheduling account deletion failed', e);
      if (context.mounted) {
        Navigator.pop(context); // Close the waiting state
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
  static Future<void> contactSupportAboutDeletion(
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
