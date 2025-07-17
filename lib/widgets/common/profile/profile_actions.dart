// lib/widgets/common/profile/profile_actions.dart

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../core/injection.dart';
import '../../../core/utils/logger.dart';
import '../../../services/backup_service.dart';
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
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingSm),
        margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppTheme.iconSizeAction,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.cardTitleStyle,
                  ),
                  AppTheme.tinyGap,
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppTheme.iconSizeInfo,
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
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingSm),
        margin: EdgeInsets.only(bottom: AppTheme.spacingXs),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: AppTheme.iconSizeAction,
                  color: Theme.of(context).colorScheme.primary,
                ),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(AppTheme.spacingXs),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: AppTheme.microText.copyWith(
                          color: AppTheme.neutralLight,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.cardTitleStyle,
                  ),
                  AppTheme.tinyGap,
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: AppTheme.iconSizeInfo,
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
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: AppTheme.dividerColor,
            height: AppTheme.dividerHeight,
          ),
          AppTheme.mediumGap,
          Text(
            'Data & Backup',
            style: AppTheme.sectionTitleStyle.copyWith(
              fontSize: AppTheme.displaySmall.fontSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          AppTheme.smallGap,
          _buildDataButton(
            context: context,
            icon: Icons.download,
            title: 'Ladda ner backup',
            subtitle: 'Spara alla recept som JSON',
            onTap: () => _handleBackup(context),
            color: AppTheme.primaryColor,
          ),
          AppTheme.smallGap,
          _buildDataButton(
            context: context,
            icon: Icons.upload,
            title: 'Återställ från backup',
            subtitle: 'Importera recept från JSON',
            onTap: () => _handleRestore(context),
            color: AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  /// Build logout section
  static Widget buildLogoutSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Column(
        children: [
          Divider(
            color: AppTheme.dividerColor,
            height: AppTheme.dividerHeight,
          ),
          AppTheme.mediumGap,
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => _handleLogout(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.errorColor,
                minimumSize: Size(double.infinity, AppTheme.buttonHeight),
                padding: AppTheme.buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.largeRadius,
                ),
              ),
              icon: const Icon(Icons.logout),
              label: Text('Logga ut', style: AppTheme.buttonTextStyle),
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
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppTheme.iconSizeAction,
              color: color,
            ),
            SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.cardTitleStyle.copyWith(
                      color: color,
                    ),
                  ),
                  AppTheme.tinyGap,
                  Text(
                    subtitle,
                    style: AppTheme.captionStyle.copyWith(
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
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  /// Show restore result
  static void _showRestoreResult(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
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
              backgroundColor: AppTheme.errorColor,
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
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}