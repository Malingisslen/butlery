// lib/widgets/common/profile/builders/profile_section_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/profile/builders/menu_item_builders.dart';
import 'package:butlery/widgets/common/profile/handlers/backup_restore_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';

/// Builders for profile section widgets.
class ProfileSectionBuilders {
  /// Build data backup section.
  static Widget buildDataBackupSection(BuildContext context,
      {BuildContext? rootContext}) {
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
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.download,
            title: 'Ladda ner backup',
            subtitle: 'Spara alla recept som JSON',
            onTap: () =>
                BackupRestoreHandler.handleBackup(rootContext ?? context),
            color: AppColors.forestGreen,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.upload,
            title: 'Återställ från backup',
            subtitle: 'Importera recept från JSON',
            onTap: () =>
                BackupRestoreHandler.handleRestore(rootContext ?? context),
            color: AppColors.forestGreen,
          ),
        ],
      ),
    );
  }

  /// Build logout section.
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
              onPressed: () => AuthActionHandler.handleLogout(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
                foregroundColor: AppColors.error,
                minimumSize:
                    const Size(double.infinity, AppDimensions.buttonHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingXl,
                  vertical: AppDimensions.paddingM,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusL),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: Text('Logga ut', style: AppTextStyles.labelLarge),
            ),
          ),
        ],
      ),
    );
  }

  /// Build account management section (GDPR compliance).
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
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.policy_rounded,
            title: 'Integritetspolicy',
            subtitle: 'Läs om hur vi hanterar dina personuppgifter (GDPR)',
            onTap: () => GdprConsentHandler.handlePrivacyPolicy(context),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 7 - Consent Management
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.privacy_tip_rounded,
            title: 'Hantera samtycken',
            subtitle: 'Välj hur vi får behandla dina personuppgifter (GDPR)',
            onTap: () => GdprConsentHandler.handleManageConsent(context),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 20 - Right to Data Portability
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.download_rounded,
            title: 'Exportera mina data',
            subtitle: 'Ladda ner all din data i JSON-format (GDPR)',
            onTap: () => GdprConsentHandler.handleExportData(context),
            color: AppColors.info,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 17 - Right to Erasure
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.delete_forever,
            title: 'Radera konto',
            subtitle: 'Ta bort ditt konto och all data permanent',
            onTap: () => AuthActionHandler.handleDeleteAccount(context),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}
