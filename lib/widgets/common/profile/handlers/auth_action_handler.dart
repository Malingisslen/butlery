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
      final success = await profileViewModel.deleteAccount(
        reason: 'User requested account deletion',
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator

        if (success) {
          // Account deleted successfully
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.profileAccountDeletedPermanently),
              backgroundColor: context.butleryColors.success,
            ),
          );
        } else {
          // Deletion failed
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
