import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/views/account/consent_management/consent_what_we_log_sheet.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// GDPR Article 7 - Consent Management View for user consent preferences.
/// Every switch saves at once through [ConsentViewModel.saveConsent], which
/// writes one consent record per change.
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
    final margin = ButleryTopBar.sideMargin(context);
    return Scaffold(
      appBar: ButleryTopBar.undersida(
        title: l10n.settingsConsents,
        backTo: widget.backTo,
      ),
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Consumer<ConsentViewModel>(
              builder: (context, viewModel, _) {
                if (!viewModel.isLoading) _loadedOnce = true;
                if (viewModel.isLoading && !_loadedOnce) {
                  return StateWidget.loading(message: l10n.loadingConsents);
                }
                return ListView(
                  padding: EdgeInsetsDirectional.only(
                    start: margin,
                    end: margin,
                    bottom: AppDimensions.spacingLg,
                  ),
                  children: _sections(context, viewModel),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, ConsentViewModel viewModel) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return [
      Padding(
        padding: const EdgeInsets.only(top: AppDimensions.spacingMd),
        child: Text(
          l10n.consentGdprDescription,
          style: AppTextStyles.bodyMedium.copyWith(color: muted),
        ),
      ),
      if (viewModel.hasConsent)
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
          child: Text(
            '${l10n.consentLastUpdated}: ${viewModel.getConsentTimestampText()}',
            style: AppTextStyles.infoText.copyWith(color: muted),
          ),
        ),
      if (viewModel.hasError)
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
          child: Text(
            viewModel.errorMessage!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ButleryListSection(
        title: l10n.consentRequiredTitle,
        rows: [
          ButleryListRow.info(
            label: l10n.consentBasicServices,
            value: l10n.consentRequiredValue,
          ),
          ButleryListRow.info(
            label: l10n.consentDataProcessing,
            value: l10n.consentRequiredValue,
          ),
        ],
      ),
      _note(context, l10n.consentRequiredDescription),
      // Marketing and social-features have no switch: no marketing system
      // exists, and social features run on the contract basis, not consent
      // (BUT-1395). Both fields stay in the model for Firestore back-compat.
      ButleryListSection(
        title: l10n.consentOptionalTitle,
        rows: [
          ButleryListRow.toggle(
            label: l10n.consentAnalytics,
            subtitle: l10n.consentAnalyticsDescription,
            checked: viewModel.analytics,
            onChanged: (v) => _change(viewModel, viewModel.setAnalytics, v),
          ),
          ButleryListRow.toggle(
            label: l10n.consentPushNotifications,
            subtitle: l10n.consentPushNotificationsDescription,
            checked: viewModel.pushNotifications,
            onChanged: (v) =>
                _change(viewModel, viewModel.setPushNotifications, v),
          ),
          // The model has carried this purpose since consent version 1.1.0
          // and the import checks it; without a switch it could only be lost.
          ButleryListRow.toggle(
            label: l10n.consentAiProcessing,
            subtitle: l10n.consentAiProcessingDescription,
            checked: viewModel.aiProcessing,
            onChanged: (v) => _change(viewModel, viewModel.setAiProcessing, v),
          ),
        ],
      ),
      _note(context, l10n.consentOptionalDescription),
      ButleryListSection(
        rows: [
          ButleryListRow(
            label: l10n.consentWhatWeLog,
            leading: ButleryIcons.history,
            onTap: () => showConsentWhatWeLogSheet(context),
          ),
          ButleryListRow.danger(
            label: l10n.consentTurnOffAllOptional,
            onTap: () => _revokeAll(viewModel),
          ),
        ],
      ),
      ButleryListSection(
        title: l10n.consentGoodToKnow,
        rows: [
          for (final line in [
            l10n.consentInfoImmediate,
            l10n.consentInfoChangeAnytime,
            l10n.consentInfoHistory,
            l10n.consentInfoRevoke,
          ])
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingSm,
              ),
              child: Text(
                line,
                style: AppTextStyles.bodySmall.copyWith(color: muted),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
    child: Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Future<void> _change(
    ConsentViewModel viewModel,
    void Function(bool) setter,
    bool value,
  ) async {
    if (viewModel.isSaving) return;
    setter(value);
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
    // The switch shows what is stored, not what was asked for.
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
