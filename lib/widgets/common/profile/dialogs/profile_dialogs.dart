// lib/widgets/common/profile/dialogs/profile_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Dialog builders for profile actions.
/// Provides static methods for showing various confirmation and input dialogs.
class ProfileDialogs {
  /// Show logout confirmation dialog.
  static Future<bool?> showLogoutDialog(BuildContext context) {
    final l10n = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileLogout),
        content: Text(l10n.profileLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(l10n.profileLogout),
          ),
        ],
      ),
    );
  }

  /// Show delete account confirmation dialog.
  static Future<bool?> showDeleteAccountDialog(BuildContext context) {
    final l10n = context.l10n;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileDeleteAccount),
        content: Builder(
          builder: (builderContext) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileDeleteWarningTitle,
                style: Theme.of(builderContext).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text('• ${l10n.profileDeleteWarningRecipes}'),
              Text('• ${l10n.profileDeleteWarningMenus}'),
              Text('• ${l10n.profileDeleteWarningShoppingLists}'),
              Text('• ${l10n.profileDeleteWarningFriends}'),
              Text('• ${l10n.profileDeleteWarningSharedContent}'),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                l10n.profileDeleteIrreversible,
                style: Theme.of(builderContext).textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(l10n.profileDeleteConfirmButton),
          ),
        ],
      ),
    );
  }

  /// Show password re-authentication dialog.
  static Future<String?> showPasswordDialog(BuildContext context) {
    final l10n = context.l10n;
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileConfirmWithPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.profileEnterPasswordToConfirm),
            const SizedBox(height: AppDimensions.spacingMd),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.profilePassword,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(l10n.profileConfirm),
          ),
        ],
      ),
    );
  }

  /// Show error dialog.
  static void showErrorDialog(BuildContext context, String error) {
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileError),
        content: Text(l10n.profileCouldNotDeleteAccount(error)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }
}
