import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.dataExportTitle),
          centerTitle: true,
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
              child: Consumer<DataExportViewModel>(
                builder: (context, viewModel, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimensions.paddingXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderSection(context),
                        const SizedBox(height: AppDimensions.spacingXl),
                        _buildExportButton(context, viewModel),
                        const SizedBox(height: AppDimensions.spacingLg),
                        if (viewModel.isExporting) _buildLoadingState(context),
                        if (viewModel.hasError)
                          _buildErrorState(context, viewModel),
                        if (viewModel.hasExportedData)
                          _buildSuccessState(context, viewModel),
                        const SizedBox(height: AppDimensions.spacingXl),
                        _buildInfoSection(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 32,
                  color: cs.primary,
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: Text(
                    context.l10n.dataExportDownloadTitle,
                    style: AppTextStyles.titleBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              context.l10n.dataExportGdprDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(
      BuildContext context, DataExportViewModel viewModel) {
    if (viewModel.hasExportedData) {
      return const SizedBox.shrink(); // Hide button when data is exported
    }

    return ElevatedButton.icon(
      onPressed: viewModel.isExporting
          ? null
          : () => _handleExport(context, viewModel),
      icon: const Icon(Icons.cloud_download_rounded),
      label: Text(context.l10n.dataExportTitle),
      style: ElevatedButton.styleFrom(
        padding: AppDimensions.paddingVertical16,
        textStyle: AppTextStyles.titleMedium,
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              context.l10n.dataExportExporting,
              style: AppTextStyles.contentTitle,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              context.l10n.dataExportMayTakeSeconds,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DataExportViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: cs.error.withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: cs.error,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              context.l10n.dataExportFailed,
              style: AppTextStyles.titleBold,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              viewModel.errorMessage ?? context.l10n.errorUnexpected,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton.icon(
              onPressed: () => viewModel.retryExport(),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(
      BuildContext context, DataExportViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: context.butleryColors.success
          .withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: context.butleryColors.success,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              context.l10n.dataExportSuccess,
              style: AppTextStyles.titleBold,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              '${context.l10n.dataExportExportedAt} ${viewModel.exportTimestampText}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              '${context.l10n.dataExportFileSize}: ${viewModel.exportSizeText}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingXl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleDownload(context, viewModel),
                    icon: const Icon(Icons.save_alt),
                    label: Text(context.l10n.dataExportSaveFile),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleShare(context, viewModel),
                    icon: const Icon(Icons.share),
                    label: Text(context.l10n.commonShare),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            TextButton.icon(
              onPressed: () => _handleClear(context, viewModel),
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.dataExportClear),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      color: context.butleryColors.info
          .withValues(alpha: AppDimensions.opacityVeryLight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: context.butleryColors.info,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  context.l10n.dataExportWhatsIncluded,
                  style: AppTextStyles.titleBold,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            _buildInfoItem(context, context.l10n.dataExportIncludesProfile),
            _buildInfoItem(context, context.l10n.dataExportIncludesRecipes),
            _buildInfoItem(context, context.l10n.dataExportIncludesFriends),
            _buildInfoItem(context, context.l10n.dataExportIncludesMessages),
            _buildInfoItem(context, context.l10n.dataExportIncludesLists),
            _buildInfoItem(context, context.l10n.dataExportIncludesComments),
            _buildInfoItem(context, context.l10n.dataExportIncludesActivity),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              context.l10n.dataExportOnlyYourData,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, String text) {
    return Padding(
      padding: AppDimensions.paddingVertical4,
      child: Row(
        children: [
          Icon(
            Icons.check,
            size: AppDimensions.iconSizeS,
            color: context.butleryColors.success,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  // Action handlers

  Future<void> _handleExport(
      BuildContext context, DataExportViewModel viewModel) async {
    final success = await viewModel.exportData();

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dataExportExportedSuccessfully),
          backgroundColor: context.butleryColors.success,
        ),
      );
    }
  }

  Future<void> _handleDownload(
      BuildContext context, DataExportViewModel viewModel) async {
    if (viewModel.exportedData == null) return;

    try {
      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'butlery_data_export_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write file
      final file = File(filePath);
      await file.writeAsString(viewModel.exportedData!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataExportFileSaved(fileName)),
            backgroundColor: context.butleryColors.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(context.l10n.dataExportCouldNotSaveFile(e.toString())),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(
      BuildContext context, DataExportViewModel viewModel) async {
    if (viewModel.exportedData == null) return;

    try {
      // Create temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'butlery_data_export_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(viewModel.exportedData!);

      // Share file
      await SharePlus.instance.share(ShareParams(
        files: [XFile(filePath)],
        subject: context.l10n.dataExportShareSubject,
        text: context.l10n.dataExportShareText,
      ));
    } catch (e) {
      if (context.mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataExportCouldNotShare(e.toString())),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  Future<void> _handleClear(
      BuildContext context, DataExportViewModel viewModel) async {
    final cs = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.dataExportClearConfirmTitle),
        content: Text(context.l10n.dataExportClearConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: cs.error,
            ),
            child: Text(context.l10n.commonClear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      viewModel.clearExportedData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataExportCleared),
          ),
        );
      }
    }
  }
}
