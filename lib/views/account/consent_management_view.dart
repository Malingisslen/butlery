import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/views/account/consent_management/consent_history_sheet.dart';
import 'package:butlery/views/account/consent_management/consent_what_we_log_sheet.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// GDPR Article 7 - Consent Management View for user consent preferences.
/// The switches change the view model's draft; "Spara mina val" writes one
/// consent record through [ConsentViewModel.saveConsent].
class ConsentManagementView extends StatefulWidget {
  const ConsentManagementView({this.backTo, super.key});

  /// Where Back leads, given only by Integritet & data; the consent renewal
  /// dialog that also opens this page leaves it null.
  final String? backTo;

  @override
  State<ConsentManagementView> createState() => _ConsentManagementViewState();
}

class _ConsentManagementViewState extends State<ConsentManagementView> {
  // Saving flips the model's loading flag too, so the page is replaced by
  // the spinner only until the first load has finished.
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsentViewModel>().loadConsent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ButleryPage.undersida(
      title: l10n.settingsConsents,
      backTo: widget.backTo,
      body: Consumer<ConsentViewModel>(
        builder: (context, viewModel, _) {
          if (!viewModel.isLoading) _loadedOnce = true;
          if (viewModel.isLoading && !_loadedOnce) {
            return StateWidget.loading(message: l10n.loadingConsents);
          }
          return ListView(
            padding: ButleryPageBody.margin(
              context,
              bottom: AppDimensions.space24,
            ),
            children: _sections(context, viewModel),
          );
        },
      ),
    );
  }

  List<Widget> _sections(BuildContext context, ConsentViewModel viewModel) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return [
      if (viewModel.hasError)
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space16),
          child: Text(
            viewModel.errorMessage!,
            style: AppTextStyles.bodyMedium.copyWith(color: cs.error),
          ),
        ),
      const SizedBox(height: AppDimensions.space16),
      SectionHeading(l10n.consentTermsHeading),
      const SizedBox(height: AppDimensions.space8),
      TintedNote(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TintedNoteEntry(
              title: l10n.consentEssentialTitle,
              body: l10n.consentEssentialBody,
              icon: ButleryIcons.shield,
            ),
            const SizedBox(height: AppDimensions.space12),
            TintedNoteEntry(
              title: l10n.consentDataProcessing,
              body: l10n.consentDataProcessingBody,
              icon: ButleryIcons.server,
            ),
            const SizedBox(height: AppDimensions.space12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l10n.consentRequiredNoteBefore),
                  TextSpan(
                    text: l10n.consentRequiredNoteBold,
                    style: AppTextStyles.bodySmallBold,
                  ),
                  TextSpan(text: l10n.consentRequiredNoteAfter),
                ],
              ),
              style: TintedNote.textStyle(context),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppDimensions.space16),
      ButleryListSection(
        title: l10n.consentYourChoices,
        rows: [
          ButleryListRow.toggle(
            label: l10n.consentAnalytics,
            subtitle: l10n.consentAnalyticsDescription,
            checked: viewModel.analytics,
            onChanged: viewModel.setAnalytics,
          ),
          ButleryListRow.toggle(
            label: l10n.consentMarketing,
            subtitle: l10n.consentMarketingDescription,
            checked: viewModel.marketing,
            onChanged: viewModel.setMarketing,
          ),
          ButleryListRow.toggle(
            label: l10n.consentSocial,
            subtitle: l10n.consentSocialDescription,
            checked: viewModel.socialFeatures,
            onChanged: viewModel.setSocialFeatures,
          ),
          ButleryListRow.toggle(
            label: l10n.consentPushNotifications,
            subtitle: l10n.consentPushNotificationsDescription,
            checked: viewModel.pushNotifications,
            onChanged: viewModel.setPushNotifications,
          ),
          // The model has carried this purpose since consent version 1.1.0
          // and the import checks it; without a switch it could only be lost.
          ButleryListRow.toggle(
            label: l10n.consentAiProcessing,
            subtitle: l10n.consentAiProcessingDescription,
            checked: viewModel.aiProcessing,
            onChanged: viewModel.setAiProcessing,
          ),
        ],
      ),
      if (viewModel.currentConsent != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
          child: Text(
            _savedLine(context, viewModel.currentConsent!),
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ButleryListSection(
        rows: [
          ButleryListRow(
            label: l10n.consentHistory,
            subtitle: l10n.consentHistorySubtitle,
            leading: ButleryIcons.history,
            onTap: () => showConsentHistorySheet(context, viewModel),
          ),
          ButleryListRow(
            label: l10n.consentWhatWeLog,
            leading: ButleryIcons.list,
            onTap: () => showConsentWhatWeLogSheet(context),
          ),
        ],
      ),
      const SizedBox(height: AppDimensions.space16),
      HeroButton(
        label: l10n.consentSaveMyChoices,
        expand: true,
        busy: viewModel.isSaving,
        onPressed: viewModel.isSaving ? null : () => _save(viewModel),
      ),
      Center(
        child: TextButton(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          onPressed: viewModel.isSaving ? null : () => _revokeAll(viewModel),
          child: Text(l10n.consentRevokeAllOptional),
        ),
      ),
    ];
  }

  String _savedLine(BuildContext context, UserConsent consent) {
    final l10n = context.l10n;
    final when = consent.updatedAt ?? consent.grantedAt;
    final device = consent.deviceInfo.trim();
    return l10n.consentSavedVersion(
      consent.consentVersion,
      DateFormat.MMMMd(l10n.localeName).format(when.toLocal()),
      device.isEmpty ? '' : ' · $device',
    );
  }

  Future<void> _save(ConsentViewModel viewModel) async {
    if (viewModel.isSaving) return;
    final success = await viewModel.saveConsent();
    if (!mounted) return;
    if (success) {
      SnackBarUtils.showSuccess(context, context.l10n.consentSaved);
      return;
    }
    SnackBarUtils.showFailure(
      context,
      what: viewModel.errorMessage ?? context.l10n.errorGeneric,
    );
    // The switches show what is stored, not what was asked for.
    await viewModel.loadConsent();
  }

  Future<void> _revokeAll(ConsentViewModel viewModel) async {
    if (viewModel.isSaving) return;
    final l10n = context.l10n;
    final confirmed =
        await ConfirmationDialogs.showDestructiveConfirmationDialog(
          context,
          title: l10n.consentRevokeAllTitle,
          message: l10n.consentRevokeAllMessage,
          confirmText: l10n.consentRevokeAll,
          cancelText: l10n.commonCancel,
        );
    if (!confirmed || !mounted) return;
    final success = await viewModel.revokeAllOptional();
    if (!mounted) return;
    if (success) {
      SnackBarUtils.showSuccess(context, context.l10n.consentAllRevoked);
      return;
    }
    SnackBarUtils.showFailure(
      context,
      what: viewModel.errorMessage ?? context.l10n.errorGeneric,
    );
  }
}
