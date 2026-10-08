import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/settings/blocked_users_section.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

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
      appBar: ButleryTopBar.undersida(
        title: context.l10n.consentManageTitle,
      ),
      body: SafeArea(
        // RESPONSIVE: Center and constrain content on large screens
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
                  padding: EdgeInsets.all(
                    AppDimensions.layoutMarginOf(context),
                  ),
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
    return StateWidget.loading(message: context.l10n.loadingConsents);
  }

  Widget _buildHeaderSection(ConsentViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ButleryIcon(
                  ButleryIcons.shield,
                  size: 32,
                  color: cs.onSurface,
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: Text(
                    context.l10n.consentYourConsents,
                    style: AppTextStyles.titleBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              context.l10n.consentGdprDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (viewModel.hasConsent) ...[
              const SizedBox(height: AppDimensions.spacingL),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
                  ),
                ),
                child: Row(
                  children: [
                    ButleryIcon(
                      ButleryIcons.info,
                      color: context.modeColors.info,
                      size: AppDimensions.iconSizeM,
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        '${context.l10n.consentLastUpdated}: ${viewModel.getConsentTimestampText()}',
                        style: AppTextStyles.infoText.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
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
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ButleryIcon(
                  ButleryIcons.lock,
                  color: cs.onSurfaceVariant,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.consentRequiredTitle,
                  style: AppTextStyles.titleBold,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              context.l10n.consentRequiredDescription,
              style: AppTextStyles.metadataEmphasized,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            _buildRequiredConsentItem(
              context.l10n.consentBasicServices,
              context.l10n.consentBasicServicesDescription,
              ButleryIcons.shield,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            _buildRequiredConsentItem(
              context.l10n.consentDataProcessing,
              context.l10n.consentDataProcessingDescription,
              ButleryIcons.server,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequiredConsentItem(
    String title,
    String description,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ButleryIcon(
          icon,
          size: AppDimensions.iconSizeM,
          color: context.modeColors.success,
        ),
        const SizedBox(width: AppDimensions.spacingL),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyBold),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        ButleryIcon(
          ButleryIcons.circleCheck,
          color: context.modeColors.success,
          size: AppDimensions.iconSizeM,
        ),
      ],
    );
  }

  Widget _buildOptionalConsentsSection(ConsentViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.consentOptionalTitle,
              style: AppTextStyles.titleBold,
            ),
            TextButton.icon(
              onPressed: viewModel.isSaving
                  ? null
                  : () => _handleRevokeAll(viewModel),
              icon: const ButleryIcon(
                ButleryIcons.block,
                size: AppDimensions.iconSizeS,
              ),
              label: Text(context.l10n.consentRejectAll),
              style: TextButton.styleFrom(
                foregroundColor: cs.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          context.l10n.consentOptionalDescription,
          style: AppTextStyles.metadataEmphasized,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentAnalytics,
          context.l10n.consentAnalyticsDescription,
          ButleryIcons.barChart,
          viewModel.analytics,
          viewModel.setAnalytics,
        ),
        // BUT-918: GDPR transparency — let users see exactly what telemetry the
        // analytics consent covers, pulled from the AnalyticsEvents constants.
        _buildAnalyticsTransparency(),
        // Marketing toggle hidden — no marketing system implemented yet.
        // Social-features toggle removed (BUT-1395): it was an unenforced
        // "consent" gate, but social features run on the GDPR *contract* basis
        // (they are part of the service you sign up for), not consent. A toggle
        // that did nothing is the misleading-consent pattern IMY has fined for.
        // Both fields stay in the model for Firestore back-compat.
        const SizedBox(height: AppDimensions.spacingL),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentPushNotifications,
          context.l10n.consentPushNotificationsDescription,
          ButleryIcons.bell,
          viewModel.pushNotifications,
          viewModel.setPushNotifications,
        ),
        // AI-tolkning, drawn among "Dina val" (Skarmar v12 etapp 6
        // #kontosamtycke). The model has carried the purpose since consent
        // version 1.1.0 and the import checks it (llm_service.dart), but no
        // switch set it, so it could only ever be lost (produktregler.md:728).
        const SizedBox(height: AppDimensions.spacingL),
        _buildConsentToggle(
          viewModel,
          context.l10n.consentAiProcessing,
          context.l10n.consentAiProcessingDescription,
          ButleryIcons.sparkles,
          viewModel.aiProcessing,
          viewModel.setAiProcessing,
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
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: value ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        side: BorderSide(
          color: value ? cs.onSurface : cs.outlineVariant,
          width: value ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Row(
          children: [
            Container(
              padding: AppDimensions.paddingAll8,
              decoration: BoxDecoration(
                color: value ? cs.surface : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusControl,
                ),
              ),
              child: ButleryIcon(
                icon,
                size: AppDimensions.iconSizeL,
                color: value ? cs.onSurface : cs.onSurfaceVariant,
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
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
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
              activeTrackColor: cs.primary,
            ),
          ],
        ),
      ),
    );
  }

  /// BUT-918: collapsible "What we log" disclosure under the analytics toggle.
  /// Categories carry representative [AnalyticsEvents] constants directly, so a
  /// renamed event breaks compilation here rather than drifting out of sync.
  Widget _buildAnalyticsTransparency() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final categories = <(String, List<String>)>[
      (
        l10n.consentLogCategoryUsage,
        [
          AnalyticsEvents.appOpened,
          AnalyticsEvents.appBackgrounded,
          AnalyticsEvents.logout,
        ],
      ),
      (
        l10n.consentLogCategoryRecipes,
        [
          AnalyticsEvents.recipeCreated,
          AnalyticsEvents.recipeCooked,
          AnalyticsEvents.recipeViewed,
          AnalyticsEvents.recipeSearchPerformed,
        ],
      ),
      (
        l10n.consentLogCategoryMenuShopping,
        [
          AnalyticsEvents.menuGenerated,
          AnalyticsEvents.shoppingListItemChecked,
        ],
      ),
      (
        l10n.consentLogCategoryImport,
        [
          AnalyticsEvents.importStarted,
          AnalyticsEvents.importSuccess,
        ],
      ),
      (
        l10n.consentLogCategorySocial,
        [
          AnalyticsEvents.friendRequestSent,
          AnalyticsEvents.recipeShared,
        ],
      ),
      (
        l10n.consentLogCategoryOnboarding,
        [
          AnalyticsEvents.onboardingCompleted,
          AnalyticsEvents.timeToFirstRecipe,
        ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space4),
      // Strip the default ExpansionTile dividers so it sits flush under the card.
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingMd,
            0,
            AppDimensions.spacingMd,
            AppDimensions.spacingMd,
          ),
          leading: ButleryIcon(
            ButleryIcons.history,
            size: AppDimensions.iconSizeM,
            color: cs.onSurfaceVariant,
          ),
          title: Text(l10n.consentWhatWeLog, style: AppTextStyles.titleSmall),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.consentWhatWeLogIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space4),
            ...categories.map((c) => _buildLoggedCategoryRow(c.$1, c.$2)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedCategoryRow(String label, List<String> eventNames) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: AppDimensions.paddingOnlyBottom8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodyBold),
          const SizedBox(height: AppDimensions.space4),
          Text(
            eventNames.join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ConsentViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: context.modeColors.surfaceTintDanger,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            color: cs.onErrorContainer,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              viewModel.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ConsentViewModel viewModel) {
    // The view's one saffron action, "Spara mina val" (Skarmar v12 etapp 6
    // 'Samtycke — sju ändamål'; Grafisk manual v6:219). While saving it keeps
    // its name and gets the plate line (Komponentark v1:372).
    return HeroButton(
      key: const ValueKey('consent.save'),
      label: context.l10n.consentSaveMyChoices,
      onPressed: () => _handleSaveConsent(viewModel),
      busy: viewModel.isSaving,
      busyLabel: context.l10n.statusSaving,
      expand: true,
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ButleryIcon(
                  ButleryIcons.info,
                  color: context.modeColors.info,
                  size: AppDimensions.iconSizeM,
                ),
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
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: AppDimensions.paddingOnlyBottom8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
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
      SnackBarUtils.showSuccess(context, context.l10n.consentSaved);
    }
  }

  Future<void> _handleRevokeAll(ConsentViewModel viewModel) async {
    final cs = Theme.of(context).colorScheme;

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
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(context.l10n.consentRevokeAll),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await viewModel.revokeAllOptional();

      if (success && mounted) {
        SnackBarUtils.showSuccess(context, context.l10n.consentAllRevoked);
      }
    }
  }
}
