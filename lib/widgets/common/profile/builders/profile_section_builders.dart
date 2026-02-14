// lib/widgets/common/profile/builders/profile_section_builders.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/profile/builders/menu_item_builders.dart';
import 'package:butlery/widgets/common/profile/handlers/backup_restore_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/auth_action_handler.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
            context.l10n.profileDataBackup,
            style: AppTextStyles.headlineSmall.copyWith(
              fontSize: AppTextStyles.displaySmall.fontSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.download,
            title: context.l10n.profileDownloadBackup,
            subtitle: context.l10n.profileDownloadBackupSubtitle,
            onTap: () =>
                BackupRestoreHandler.handleBackup(rootContext ?? context),
            color: AppColors.forestGreen,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.upload,
            title: context.l10n.profileRestoreFromBackup,
            subtitle: context.l10n.profileRestoreFromBackupSubtitle,
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
                backgroundColor: AppColors.error
                    .withValues(alpha: AppDimensions.opacityVeryLight),
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
              label: Text(context.l10n.profileLogout,
                  style: AppTextStyles.labelLarge),
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
            context.l10n.profileAccountManagement,
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
            title: context.l10n.profilePrivacyPolicy,
            subtitle: context.l10n.profilePrivacyPolicySubtitle,
            onTap: () => GdprConsentHandler.handlePrivacyPolicy(context),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 7 - Consent Management
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.privacy_tip_rounded,
            title: context.l10n.profileManageConsent,
            subtitle: context.l10n.profileManageConsentSubtitle,
            onTap: () => GdprConsentHandler.handleManageConsent(context),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 20 - Right to Data Portability
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.download_rounded,
            title: context.l10n.profileExportData,
            subtitle: context.l10n.profileExportDataSubtitle,
            onTap: () => GdprConsentHandler.handleExportData(context),
            color: AppColors.info,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          // GDPR Article 17 - Right to Erasure
          MenuItemBuilders.buildDataButton(
            context: context,
            icon: Icons.delete_forever,
            title: context.l10n.profileDeleteAccount,
            subtitle: context.l10n.profileDeleteAccountSubtitle,
            onTap: () => AuthActionHandler.handleDeleteAccount(context),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}
