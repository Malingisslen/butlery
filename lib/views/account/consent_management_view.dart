import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/settings/blocked_users_section.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GDPR Article 7 - Consent Management View for user consent preferences
class ConsentManagementView extends StatefulWidget {
  const ConsentManagementView({super.key});

  @override
  State<ConsentManagementView> createState() => _ConsentManagementViewState();
}

class _ConsentManagementViewState extends State<ConsentManagementView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsentViewModel>().loadConsent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.consentManageTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        // ✅ RESPONSIVE: Center and constrain content on large screens
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 600,
                desktop: 700,
              ),
            ),
            child: Consumer<ConsentViewModel>(
              builder: (context, viewModel, _) {
                if (viewModel.isLoading) {
                  return _buildLoadingState();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingXl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSection(viewModel),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _buildRequiredConsentsSection(),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _buildOptionalConsentsSection(viewModel),
                      const SizedBox(height: AppDimensions.spacingLg),
                      const BlockedUsersSection(),
                      const SizedBox(height: AppDimensions.spacingLg),
                      if (viewModel.hasError) _buildErrorMessage(viewModel),
                      if (viewModel.hasError)
                        const SizedBox(height: AppDimensions.spacingMd),
                      _buildActionButtons(viewModel),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _buildInfoSection(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildHeaderSection(ConsentViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.privacy_tip_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: Text(context.l10n.consentYourConsents,
                      style: AppTextStyles.titleBold),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(context.l10n.consentGdprDescription,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMedium, height: 1.5)),
            if (viewModel.hasConsent) ...[
              const SizedBox(height: AppDimensions.spacingL),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.info
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadiusM),
                  border: Border.all(
                      color: AppColors.info
                          .withValues(alpha: AppDimensions.opacityMediumLight)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: AppDimensions.iconSizeM),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                        child: Text(
                            '${context.l10n.consentLastUpdated}: ${viewModel.getConsentTimestampText()}',
                            style: AppTextStyles.infoText)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredConsentsSection() {
    return Card(
      elevation: 0,
      color: AppColors.backgroundTint,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock,
                    color: AppColors.textMedium, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(context.l10n.consentRequiredTitle,
                    style: AppTextStyles.titleBold),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(context.l10n.consentRequiredDescription,
                style: AppTextStyles.metadataEmphasized),
            const SizedBox(height: AppDimensions.spacingMd),
            _buildRequiredConsentItem(
              context.l10n.consentBasicServices,
              context.l10n.consentBasicServicesDescription,
              Icons.security,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            _buildRequiredConsentItem(
              context.l10n.consentDataProcessing,
              context.l10n.consentDataProcessingDescription,
              Icons.storage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredConsentItem(
      String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimensions.iconSizeM, color: AppColors.success),
        const SizedBox(width: AppDimensions.spacingL),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyBold),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMedium, height: 1.4)),
            ],
          ),
        ),
        const Icon(Icons.check_circle,
            color: AppColors.success, size: AppDimensions.iconSizeM),
      ],
    );
  }

  Widget _buildOptionalConsentsSection(ConsentViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.l10n.consentOptionalTitle,
                style: AppTextStyles.titleBold),
            TextButton.icon(
              onPressed:
                  viewModel.isSaving ? null : () => _handleRevokeAll(viewModel),
              icon: const Icon(Icons.block, size: AppDimensions.iconSizeS),
              label: Text(context.l10n.consentRejectAll),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(context.l10n.consentOptionalDescription,
            style: AppTextStyles.metadataEmphasized),
        const SizedBox(height: AppDimensions.spacingMd),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentAnalytics,
          context.l10n.consentAnalyticsDescription,
          Icons.analytics_rounded,
          viewModel.analytics,
          viewModel.setAnalytics,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentMarketing,
          context.l10n.consentMarketingDescription,
          Icons.mail_rounded,
          viewModel.marketing,
          viewModel.setMarketing,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentSocialFeatures,
          context.l10n.consentSocialFeaturesDescription,
          Icons.people_rounded,
          viewModel.socialFeatures,
          viewModel.setSocialFeatures,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentPushNotifications,
          context.l10n.consentPushNotificationsDescription,
          Icons.notifications_rounded,
          viewModel.pushNotifications,
          viewModel.setPushNotifications,
        ),
      ],
    );
  }

  Widget _buildConsentToggle(
    ConsentViewModel viewModel,
    String title,
    String description,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      elevation: value ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        side: BorderSide(
          color: value
              ? AppColors.primary.withValues(alpha: AppDimensions.opacityHalf)
              : AppColors.divider,
          width: value ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          children: [
            Container(
              padding: AppDimensions.paddingAll8,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primary
                        .withValues(alpha: AppDimensions.opacityVeryLight)
                    : AppColors.backgroundTint,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: Icon(
                icon,
                size: AppDimensions.iconSizeL,
                color: value ? AppColors.primary : AppColors.textMedium,
              ),
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
                  const SizedBox(height: AppDimensions.spacingTight),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMedium,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Switch(
              value: value,
              onChanged: viewModel.isSaving ? null : onChanged,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(ConsentViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color:
            AppColors.error.withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
            color: AppColors.error
                .withValues(alpha: AppDimensions.opacityMediumLight)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: AppDimensions.iconSizeM),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              viewModel.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ConsentViewModel viewModel) {
    return ElevatedButton(
      onPressed:
          viewModel.isSaving ? null : () => _handleSaveConsent(viewModel),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.cardWhite,
        padding: AppDimensions.paddingVertical16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      child: viewModel.isSaving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.cardWhite),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.save_rounded, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.commonSaveChanges,
                  style: AppTextStyles.titleBold.copyWith(
                    color: AppColors.cardWhite,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color:
          AppColors.info.withValues(alpha: AppDimensions.opacityExtraVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.info, size: AppDimensions.iconSizeM),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.consentGoodToKnow,
                  style: AppTextStyles.bodyBold,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            _buildInfoItem(context.l10n.consentInfoImmediate),
            _buildInfoItem(context.l10n.consentInfoChangeAnytime),
            _buildInfoItem(context.l10n.consentInfoHistory),
            _buildInfoItem(context.l10n.consentInfoRevoke),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: AppDimensions.paddingOnlyBottom8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMedium,
                ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveConsent(ConsentViewModel viewModel) async {
    final success = await viewModel.saveConsent();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.cardWhite),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(context.l10n.consentSaved),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRevokeAll(ConsentViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.consentRevokeAllTitle),
        content: Text(context.l10n.consentRevokeAllMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(context.l10n.consentRevokeAll),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await viewModel.revokeAllOptional();

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.cardWhite),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(context.l10n.consentAllRevoked),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
