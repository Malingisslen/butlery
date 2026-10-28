import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/views/account/data_export_helpers/download_stub.dart'
    if (dart.library.io) 'package:butlery/views/account/data_export_helpers/download_native.dart'
    if (dart.library.js_interop) 'package:butlery/views/account/data_export_helpers/download_web.dart'
    as export_helper;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// GDPR Article 20 - Right to Data Portability UI
/// User interface for exporting personal data in compliance with GDPR.
/// Allows users to download all their data in JSON format.
/// **Features:**
/// - One-click data export
/// - Progress indication during export
/// - Download exported JSON file
/// - Share exported data
/// - Clear data after download
class DataExportView extends StatelessWidget {
  const DataExportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => context.read<DataExportViewModel>(),
      child: ButleryPage.undersida(
        title: context.l10n.dataExportPageTitle,
        body: Consumer<DataExportViewModel>(
          builder: (context, viewModel, _) {
            return ListView(
              padding: ButleryPageBody.margin(
                context,
                top: AppDimensions.space16,
                bottom: AppDimensions.space24,
              ),
              children: [
                _buildHeaderSection(context),
                _buildInfoSection(context),
                const SizedBox(height: AppDimensions.space24),
                _buildExportButton(context, viewModel),
                if (viewModel.isExporting) _buildLoadingState(context),
                if (viewModel.hasError) _buildErrorState(context, viewModel),
                if (viewModel.hasExportedData)
                  _buildSuccessState(context, viewModel),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.dataExportHeadline,
            style: AppTextStyles.headlineMedium.copyWith(color: cs.onSurface),
          ),
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          context.l10n.dataExportGdprDescription,
          style: AppTextStyles.bodyLarge.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildExportButton(
    BuildContext context,
    DataExportViewModel viewModel,
  ) {
    if (viewModel.hasExportedData) {
      return const SizedBox.shrink(); // Hide button when data is exported
    }

    // While exporting the button keeps its
    // shape and says what it does, with the plate line.
    return FormButton(
      key: const ValueKey('dataExport.export'),
      label: context.l10n.dataExportTitle,
      icon: ButleryIcons.export,
      onPressed: () => _handleExport(context, viewModel),
      busy: viewModel.isExporting,
      busyLabel: context.l10n.dataExportExporting,
      expand: true,
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StyledCard(
      padding: const EdgeInsets.all(AppDimensions.space24),
      // The export button above carries the plate line and the busy
      // label; this card only says how long it may take.
      child: Column(
        children: [
          Text(
            context.l10n.dataExportMayTakeSeconds,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Three causes, three messages
  /// : an expired sign-in leads to signing in, a
  /// refusal is our fault and asks for no retry, a dropped connection gets
  /// "Inte nu" and "Försök igen". Only the general case asks for a retry
  /// without saying why. No partial file is ever offered.
  Widget _buildErrorState(BuildContext context, DataExportViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final failure = viewModel.failure ?? ExportFailure.other;

    final String title;
    final String body;
    switch (failure) {
      case ExportFailure.network:
        title = l10n.dataExportNetworkTitle;
        body = l10n.dataExportNetworkBody;
      case ExportFailure.signedOut:
        title = l10n.dataExportSignedOutTitle;
        body = l10n.dataExportSignedOutBody;
      case ExportFailure.permissionDenied:
        title = l10n.dataExportDeniedTitle;
        body = l10n.dataExportDeniedBody;
      case ExportFailure.other:
        title = l10n.dataExportFailed;
        body = viewModel.errorMessage ?? l10n.errorExportFailed;
    }

    final List<Widget> actions = switch (failure) {
      ExportFailure.network => [
        ButleryTextButton(
          key: const ValueKey('dataExport.notNow'),
          label: l10n.dataExportNotNow,
          onPressed: viewModel.reset,
        ),
        ActionButtons.primaryButton(
          context,
          key: const ValueKey('dataExport.retry'),
          label: l10n.commonRetry,
          onPressed: () => viewModel.retryExport(),
        ),
      ],
      ExportFailure.signedOut => [
        ActionButtons.primaryButton(
          context,
          key: const ValueKey('dataExport.signIn'),
          label: l10n.dataExportSignIn,
          onPressed: () => _handleSignInAgain(context),
        ),
      ],
      ExportFailure.permissionDenied => const <Widget>[],
      ExportFailure.other => [
        ActionButtons.primaryButton(
          context,
          key: const ValueKey('dataExport.retry'),
          label: l10n.commonRetry,
          onPressed: () => viewModel.retryExport(),
        ),
      ],
    };

    return StyledCard(
      key: ValueKey('dataExport.error.${failure.name}'),
      padding: const EdgeInsets.all(AppDimensions.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleBold),
          const SizedBox(height: AppDimensions.space8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (failure == ExportFailure.network) ...[
            const SizedBox(height: AppDimensions.space8),
            Text(
              l10n.dataExportNoPartialFile,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppDimensions.space8,
              runSpacing: AppDimensions.space8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  /// "Utgången inloggning leder till inloggningen".
  /// The session is no longer usable, so it is ended and the sign-in screen
  /// shown. It is not the user's own sign-out: nothing in the queue is
  /// touched.
  Future<void> _handleSignInAgain(BuildContext context) async {
    await ServiceLocator.get<AuthService>().forceSignOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.auth,
        (_) => false,
      );
    }
  }

  Widget _buildSuccessState(
    BuildContext context,
    DataExportViewModel viewModel,
  ) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final warning = AppModeColors.textWarning(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space16),
      child: StyledCard(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: ButleryIcon(ButleryIcons.file, color: cs.onSurface),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dataExportFileTitle,
                        style: AppTextStyles.titleBold,
                      ),
                      Text(
                        '${viewModel.exportSizeText} · '
                        '${viewModel.exportTimestampText}',
                        style: AppTextStyles.captionBase.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space12),
            Row(
              children: [
                Expanded(
                  child: FormButton(
                    key: const ValueKey('dataExport.saveFile'),
                    label: l10n.dataExportSaveFile,
                    icon: ButleryIcons.download,
                    onPressed: () => _handleDownload(context, viewModel),
                    expand: true,
                  ),
                ),
                if (export_helper.canShareFiles) ...[
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: ActionButtons.outlinedButton(
                      context,
                      label: l10n.commonShare,
                      icon: ButleryIcons.externalLink,
                      onPressed: () => _handleShare(context, viewModel),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppDimensions.space12),
            // The file lives only in memory and is cleared when the view is
            // left, and the view says so
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.space4),
                  child: ExcludeSemantics(
                    child: ButleryIcon(
                      ButleryIcons.info,
                      size: AppDimensions.iconSizeS,
                      color: warning,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: Text(
                    l10n.dataExportMemoryNotice,
                    key: const ValueKey('dataExport.memoryNotice'),
                    style: AppTextStyles.bodySmall.copyWith(color: warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.space8),
            ButleryTextButton(
              label: l10n.dataExportClear,
              icon: ButleryIcons.trash2,
              onPressed: () => _handleClear(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final l10n = context.l10n;
    return ButleryListSection(
      title: l10n.dataExportWhatsIncluded,
      rows: [
        for (final line in [
          l10n.dataExportIncludesProfile,
          l10n.dataExportIncludesRecipesComments,
          l10n.dataExportIncludesLists,
          l10n.dataExportIncludesSocial,
          l10n.dataExportIncludesAuditLogs,
        ])
          ButleryListRow.note(
            label: line,
            leading: ButleryIcons.check,
            emphasis: true,
          ),
        ButleryListRow.note(
          label: l10n.dataExportSharedDataNote,
          leading: ButleryIcons.info,
          muted: true,
        ),
      ],
    );
  }

  // Action handlers

  Future<void> _handleExport(
    BuildContext context,
    DataExportViewModel viewModel,
  ) async {
    final success = await viewModel.exportData();

    if (success && context.mounted) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.dataExportExportedSuccessfully,
      );
    }
  }

  Future<void> _handleDownload(
    BuildContext context,
    DataExportViewModel viewModel,
  ) async {
    if (viewModel.exportedData == null) return;

    try {
      final timestamp = clock
          .now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'butlery_data_export_$timestamp.json';

      await export_helper.downloadJsonFile(viewModel.exportedData!, fileName);

      if (context.mounted) {
        // No "OK" action: a snackbar action is never OK
        // and this one did nothing.
        SnackBarUtils.showSuccess(
          context,
          context.l10n.dataExportFileSaved(fileName),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.dataExportCouldNotSaveFile(
            SnackBarUtils.userFriendlyMessage(context, e),
          ),
        );
      }
    }
  }

  Future<void> _handleShare(
    BuildContext context,
    DataExportViewModel viewModel,
  ) async {
    if (viewModel.exportedData == null) return;

    final shareSubject = context.l10n.dataExportShareSubject;
    final shareText = context.l10n.dataExportShareText;

    try {
      final timestamp = clock
          .now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'butlery_data_export_$timestamp.json';

      await export_helper.shareJsonFile(
        viewModel.exportedData!,
        fileName,
        subject: shareSubject,
        text: shareText,
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.dataExportCouldNotShare(
            SnackBarUtils.userFriendlyMessage(context, e),
          ),
        );
      }
    }
  }

  Future<void> _handleClear(
    BuildContext context,
    DataExportViewModel viewModel,
  ) async {
    final confirmed = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.dataExportClearConfirmTitle,
      message: context.l10n.dataExportClearConfirmMessage,
      primaryActionText: context.l10n.dataExportClearAction,
    );

    if (confirmed == true) {
      viewModel.clearExportedData();
      if (context.mounted) {
        SnackBarUtils.showInfo(context, context.l10n.dataExportCleared);
      }
    }
  }
}
