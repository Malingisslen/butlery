// lib/widgets/common/profile/handlers/auth_action_handler.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/support_mail.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/auth/sign_out_guard.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/widgets/common/profile/dialogs/deletion_schedule_dialogs.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/widgets/guest/guest_erasure.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handler for authentication-related actions (logout, delete account).
class AuthActionHandler {
  /// The one re-authentication entry point (BUT-916 C7). AuthService decides
  /// password or provider; this only renders the password dialog or lets the
  /// provider's sheet open, then the second factor if the account has one.
  /// Returns true on success; on failure [onError] gets the message. Leaving
  /// a dialog or sheet returns false without a message.
  static Future<bool> reauthenticate(
    BuildContext context, {
    void Function(String error)? onError,
    bool forDeletion = false,
    SignInProvider? through,
  }) async {
    final authService = ServiceLocator.get<AuthService>();
    // A challenge left from an earlier attempt must not be taken for this
    // one's.
    authService.clearPendingMfa();
    final provider =
        through ??
        authService.reauthenticationProvider(forDeletion: forDeletion);
    var success = false;
    if (provider == null) {
      final password = await ProfileDialogs.showPasswordDialog(context);
      if (password == null || !context.mounted) return false;
      success = await authService.reauthenticateWithPassword(password);
    } else {
      final outcome = await authService.reauthenticateWithProvider(provider);
      if (outcome == ProviderSignInOutcome.cancelled) return false;
      success = outcome == ProviderSignInOutcome.signedIn;
    }
    final challenge = authService.pendingMfaChallenge;
    if (!success && challenge != null && context.mounted) {
      final result = await Navigator.of(context).push<MfaChallengeResult>(
        MaterialPageRoute(
          builder: (_) => MfaChallengeView(
            challenge: challenge,
            provider: provider,
            forReauthentication: true,
          ),
        ),
      );
      return result != null;
    }
    if (!success && context.mounted) {
      final msg = authService.errorMessage ?? context.l10n.errorSessionExpired;
      onError?.call(msg);
    }
    return success;
  }

  /// Builds the sign-out guard. Replaced in tests.
  @visibleForTesting
  static SignOutGuard Function() guardFactory = () => SignOutGuard(
    authService: ServiceLocator.get<AuthService>(),
    source: const OfflinePendingChangesSource(
      offlineService: ServiceLocator.tryGet<OfflineService>,
    ),
  );

  /// Handle logout flow.
  ///
  /// With changes still in the queue, the sign-out is blocked with an
  /// explanation instead of the plain question: "N ändringar har inte
  /// sparats", Vänta på synk · Logga ut och släng
  /// The queue is only emptied when the
  /// user picks the destructive choice; an ordinary sign-out leaves it on the
  /// device, where it syncs at this account's next sign-in.
  static Future<void> handleLogout(BuildContext context) async {
    // A guest cannot sign back in, so signing out erases the guest at once
    // (BUT-920). Only for an anonymous user; nobody else takes this path.
    if (ServiceLocator.tryGet<AuthService>()?.currentUser?.isAnonymous ??
        false) {
      await _handleGuestLogout(context);
      return;
    }

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

  /// Nothing the guest saved can be reached after this, so the queue guard
  /// does not apply: the queue goes with the account.
  static Future<void> _handleGuestLogout(BuildContext context) {
    final l10n = context.l10n;
    return _eraseGuest(
      context,
      title: l10n.guestLogoutTitle,
      confirmLabel: l10n.guestLogoutConfirm,
      reason: 'guest_sign_out',
    );
  }

  static Future<void> _eraseGuest(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String reason,
  }) async {
    final confirmed = await GuestErasure.confirm(
      context,
      title: title,
      body: context.l10n.guestLogoutBody,
      confirmLabel: confirmLabel,
    );
    if (!confirmed || !context.mounted) return;
    final erased = await GuestErasure.eraseAndSignOut(context, reason: reason);
    if (erased && context.mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/auth', (route) => false);
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
    // A guest has no password to confirm with, so the account is erased at
    // once, as signing out as a guest does (BUT-920).
    if (ServiceLocator.tryGet<AuthService>()?.currentUser?.isAnonymous ??
        false) {
      final l10n = context.l10n;
      await _eraseGuest(
        context,
        title: l10n.guestDeleteTitle,
        confirmLabel: l10n.guestDeleteConfirm,
        reason: 'guest_account_delete',
      );
      return;
    }

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
    // fråga".
    final reason = await ProfileDialogs.showDeleteAccountDialog(
      context,
      mayHaveOpenReview: reportStatus == OwnReportStatus.reported,
    );
    if (reason == null || !context.mounted) return;

    String? reauthError;
    final reauthSuccess = await reauthenticate(
      context,
      onError: (msg) => reauthError = msg,
      forDeletion: true,
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
      // Nothing was scheduled yet.
      if (result.status == DeletionScheduleStatus.requiresReauth &&
          context.mounted) {
        Navigator.pop(context); // Close the waiting state
        final again = await ProfileDialogs.showDeletionReauthStep(context);
        if (!again || !context.mounted) return;
        final reauthed = await reauthenticate(
          context,
          onError: (msg) => reauthError = msg,
          forDeletion: true,
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
  /// The same address the legal views use (support_mail.dart).
  static Future<void> contactSupportAboutDeletion(
    BuildContext context,
    String? auditLogId,
  ) async {
    final subject = Uri.encodeComponent(
      context.l10n.accountDeletionPartialEmailSubject(auditLogId.orEmpty()),
    );
    final uri = Uri.parse('mailto:$privacyMailAddress?subject=$subject');
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
