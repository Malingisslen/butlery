// lib/widgets/common/profile/profile_actions.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Profile action handlers and UI components
///
/// This module provides action handlers for profile operations like
/// backup, restore, logout, and their corresponding UI components.
class ProfileActions {
  /// Build menu item for basic navigation
  static Widget buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap != null ? () {
        Navigator.pop(context);
        onTap();
      } : null,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.spacingS),
        margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppDimensions.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Build notification menu item with badge
  static Widget buildNotificationMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    int count = 0,
  }) {
    return InkWell(
      onTap: onTap != null ? () {
        Navigator.pop(context);
        onTap();
      } : null,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.spacingS),
        margin: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: AppDimensions.iconSizeAction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingXs),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.neutralLight,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppDimensions.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Build data backup section
  static Widget buildDataBackupSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(
            color: AppColors.divider,
            height: AppDimensions.dividerHeight,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Data & Backup',
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: AppTextStyles.displaySmall.fontSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _buildDataButton(
            context: context,
            icon: Icons.download,
            title: 'Ladda ner backup',
            subtitle: 'Spara alla recept som JSON',
            onTap: () => _handleBackup(context),
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _buildDataButton(
            context: context,
            icon: Icons.upload,
            title: 'Återställ från backup',
            subtitle: 'Importera recept från JSON',
            onTap: () => _handleRestore(context),
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  /// Build logout section
  static Widget buildLogoutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Column(
        children: [
          const Divider(
            color: AppColors.divider,
            height: AppDimensions.dividerHeight,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _handleLogout(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: 0.1),
                foregroundColor: AppColors.error,
                minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingXl,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Logga ut', style: AppTextStyles.labelLarge),
            ),
          ),
        ],
      ),
    );
  }

  // PRIVATE HELPERS

  /// Build data button
  static Widget _buildDataButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.spacingS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSizeAction,
              color: color,
            ),
            const SizedBox(width: AppDimensions.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: color,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ACTION HANDLERS

  /// Handle backup
  static Future<void> _handleBackup(BuildContext context) async {
    try {
      final backupService = sl<BackupService>();
      await backupService.exportToFile();
      if (context.mounted) {
        _showBackupResult(context, true, 'Backup skapad framgångsrikt!');
      }
    } catch (e) {
      AppLogger.error('Backup failed', e);
      if (context.mounted) {
        _showBackupResult(context, false, 'Backup misslyckades: $e');
      }
    }
  }

  /// Handle restore
  static Future<void> _handleRestore(BuildContext context) async {
    try {
      final backupService = sl<BackupService>();
      await backupService.importFromFile();
      if (context.mounted) {
        _showRestoreResult(context, true, 'Återställning genomförd!');
      }
    } catch (e) {
      AppLogger.error('Restore failed', e);
      if (context.mounted) {
        _showRestoreResult(context, false, 'Återställning misslyckades: $e');
      }
    }
  }

  /// Handle logout
  static Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await _showLogoutDialog(context);
    if (shouldLogout == true && context.mounted) {
      await _performLogout(context);
    }
  }

  /// Show backup result
  static void _showBackupResult(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  /// Show restore result
  static void _showRestoreResult(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  /// Show logout dialog
  static Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logga ut'),
        content: const Text('Är du säker på att du vill logga ut?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logga ut'),
          ),
        ],
      ),
    );
  }

  /// Perform logout
  static Future<void> _performLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      AppLogger.error('Logout failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utloggning misslyckades: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}