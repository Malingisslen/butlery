// lib/widgets/common/profile/handlers/auth_action_handler.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/auth_service.dart';
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
    // Show initial confirmation dialog
    final shouldDelete = await ProfileDialogs.showDeleteAccountDialog(context);
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
          await ProfileDialogs.showRetentionNoticeDialog(
            context,
            holdUntil: outcome.retained.first.holdUntil,
            provisional: outcome.retained.first.provisional,
          );
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
