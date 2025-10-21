// lib/widgets/common/profile/profile_actions.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/backup_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/views/account/data_export_view.dart';
import 'package:butlery/views/account/consent_management_view.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:provider/provider.dart';

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
  static Widget buildDataBackupSection(BuildContext context, {BuildContext? rootContext}) {
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
            onTap: () => _handleBackup(rootContext ?? context),
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          _buildDataButton(
            context: context,
            icon: Icons.upload,
            title: 'Återställ från backup',
            subtitle: 'Importera recept från JSON',
            onTap: () => _handleRestore(rootContext ?? context),
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

  /// Build account management section (GDPR compliance)
  static Widget buildAccountManagementSection(BuildContext context) {
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
            'Kontohantering',
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: AppTextStyles.displaySmall.fontSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 13/14 - Privacy Policy & Transparency
          _buildDataButton(
            context: context,
            icon: Icons.policy_rounded,
            title: 'Integritetspolicy',
            subtitle: 'Läs om hur vi hanterar dina personuppgifter (GDPR)',
            onTap: () => _handlePrivacyPolicy(context),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 7 - Consent Management
          _buildDataButton(
            context: context,
            icon: Icons.privacy_tip_rounded,
            title: 'Hantera samtycken',
            subtitle: 'Välj hur vi får behandla dina personuppgifter (GDPR)',
            onTap: () => _handleManageConsent(context),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 20 - Right to Data Portability
          _buildDataButton(
            context: context,
            icon: Icons.download_rounded,
            title: 'Exportera mina data',
            subtitle: 'Ladda ner all din data i JSON-format (GDPR)',
            onTap: () => _handleExportData(context),
            color: AppColors.info,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 17 - Right to Erasure
          _buildDataButton(
            context: context,
            icon: Icons.delete_forever,
            title: 'Radera konto',
            subtitle: 'Ta bort ditt konto och all data permanent',
            onTap: () => _handleDeleteAccount(context),
            color: AppColors.error,
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
      final backupService = ServiceLocator.get<BackupService>();
      final result = await backupService.exportToFile();
      
      if (context.mounted) {
        if (result.success) {
          _showBackupResult(context, true, result.message);
        } else {
          _showBackupResult(context, false, 'Backup misslyckades: ${result.message}');
        }
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
      final backupService = ServiceLocator.get<BackupService>();
      final result = await backupService.importFromFile();
      
      if (context.mounted) {
        if (result.success) {
          _showRestoreResult(context, true, 'Återställning genomförd!');
        } else if (result.cancelled) {
          // User cancelled - no message needed
          return;
        } else {
          _showRestoreResult(context, false, 'Återställning misslyckades: ${result.errorMessage ?? 'Okänt fel'}');
        }
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
    // Close the modal first
    Navigator.of(context).pop();
    
    // Use a delay to show the snackbar after the modal closes
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        if (!context.mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        AppLogger.error('Failed to show backup result', e);
      }
    });
  }

  /// Show restore result
  static void _showRestoreResult(BuildContext context, bool success, String message) {
    // Close the modal first
    Navigator.of(context).pop();
    
    // Use a delay to show the snackbar after the modal closes
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        if (!context.mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? AppColors.success : AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        AppLogger.error('Failed to show restore result', e);
      }
    });
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
      await ServiceLocator.get<AuthRepository>().signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/auth',  // Fixed: Use correct auth route
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

  /// Handle delete account
  /// Handle privacy policy - GDPR Article 13/14
  static Future<void> _handlePrivacyPolicy(BuildContext context) async {
    try {
      // Close the profile menu modal first
      Navigator.pop(context);

      // Navigate to privacy policy view
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PrivacyPolicyView(),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open privacy policy', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna integritetspolicy: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle consent management - GDPR Article 7
  static Future<void> _handleManageConsent(BuildContext context) async {
    try {
      // Close the profile menu modal first
      Navigator.pop(context);

      // Get consent service
      final consentService = ServiceLocator.get<ConsentService>();

      // Create view model with the service
      final viewModel = ConsentViewModel(consentService: consentService);

      // Navigate to consent management view
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: viewModel,
            child: const ConsentManagementView(),
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open consent management', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna samtyckeshantering: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle data export - GDPR Article 20
  static Future<void> _handleExportData(BuildContext context) async {
    try {
      // Close the profile menu modal first
      Navigator.pop(context);

      // Get data export service
      final exportService = ServiceLocator.get<DataExportService>();

      // Create view model with the service
      final viewModel = DataExportViewModel(exportService: exportService);

      // Navigate to data export view
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider.value(
            value: viewModel,
            child: const DataExportView(),
          ),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open data export', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte öppna dataexport: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle account deletion - GDPR Article 17
  static Future<void> _handleDeleteAccount(BuildContext context) async {
    // Show initial confirmation dialog
    final shouldDelete = await _showDeleteAccountDialog(context);
    if (shouldDelete != true || !context.mounted) return;

    // Show password re-authentication dialog
    final password = await _showPasswordDialog(context);
    if (password == null || !context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Re-authenticate user
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) throw Exception('Ingen inloggad användare');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Create deletion service
      final deletionService = AccountDeletionService(
        auth: auth,
        firestore: FirebaseFirestore.instance,
        authService: ServiceLocator.get<AuthService>(),
        userService: ServiceLocator.get<UserService>(),
        recipeService: ServiceLocator.get<UnifiedRecipeService>(),
        offlineService: ServiceLocator.get<OfflineService>(),
        analyticsService: ServiceLocator.get<AnalyticsService>(),
      );

      // Perform deletion
      final result = await deletionService.deleteUserAccount(
        reason: 'User requested account deletion',
        createAuditLog: true,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator

        if (result['success'] == true) {
          // Account deleted successfully
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/auth',
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ditt konto har raderats permanent'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          // Deletion failed
          _showDeletionErrorDialog(context, result);
        }
      }
    } catch (e) {
      AppLogger.error('Account deletion failed', e);
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        _showErrorDialog(context, e.toString());
      }
    }
  }

  /// Show delete account confirmation dialog
  static Future<bool?> _showDeleteAccountDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radera konto permanent'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VARNING: Detta kommer att:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Ta bort alla dina recept'),
            Text('• Ta bort alla dina menyer'),
            Text('• Ta bort alla dina shoppinglistor'),
            Text('• Ta bort alla vänner och meddelanden'),
            Text('• Ta bort all delad innehåll'),
            SizedBox(height: 16),
            Text(
              'Denna åtgärd kan INTE ångras!',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
            child: const Text('Jag förstår, radera mitt konto'),
          ),
        ],
      ),
    );
  }

  /// Show password re-authentication dialog
  static Future<String?> _showPasswordDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bekräfta med lösenord'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ange ditt lösenord för att bekräfta raderingen:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Lösenord',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Bekräfta'),
          ),
        ],
      ),
    );
  }

  /// Show deletion error dialog
  static void _showDeletionErrorDialog(
    BuildContext context,
    Map<String, dynamic> result,
  ) {
    final failedCollections = result['failedCollections'] as List<dynamic>?;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radering misslyckades delvis'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Följande data kunde inte raderas:'),
            const SizedBox(height: 8),
            if (failedCollections != null)
              ...failedCollections.map((collection) => Text('• $collection')),
            const SizedBox(height: 16),
            const Text(
              'Kontakta support för hjälp.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fel'),
        content: Text('Kunde inte radera konto: $error'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}