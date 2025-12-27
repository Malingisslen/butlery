import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout_components.dart';

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
          title: const Text('Exportera mina data'),
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
              child: Consumer<DataExportViewModel>(
                builder: (context, viewModel, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.download_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: Text(
                    'Ladda ner dina data',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Enligt GDPR Artikel 20 har du rätt att få en kopia av all din personliga data som lagras i Butlery. Data exporteras i JSON-format som du kan spara eller överföra till en annan tjänst.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
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
      label: const Text('Exportera mina data'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Exporterar dina data...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Detta kan ta några sekunder',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, DataExportViewModel viewModel) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Export misslyckades',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              viewModel.errorMessage ?? 'Ett okänt fel uppstod',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ElevatedButton.icon(
              onPressed: () => viewModel.retryExport(),
              icon: const Icon(Icons.refresh),
              label: const Text('Försök igen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(
      BuildContext context, DataExportViewModel viewModel) {
    return Card(
      color: AppColors.success.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppColors.success,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Data exporterad',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Exporterad ${viewModel.exportTimestampText}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              'Filstorlek: ${viewModel.exportSizeText}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMedium,
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
                    label: const Text('Spara fil'),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleShare(context, viewModel),
                    icon: const Icon(Icons.share),
                    label: const Text('Dela'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            TextButton.icon(
              onPressed: () => _handleClear(context, viewModel),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Rensa export'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      color: AppColors.info.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  'Vad ingår i exporten?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),
            _buildInfoItem(context, 'Profil och inställningar'),
            _buildInfoItem(context, 'Alla dina recept'),
            _buildInfoItem(context, 'Vänner och sociala kontakter'),
            _buildInfoItem(context, 'Meddelanden och konversationer'),
            _buildInfoItem(context, 'Inköpslistor och menyer'),
            _buildInfoItem(context, 'Kommentarer och betyg'),
            _buildInfoItem(context, 'Aktivitetshistorik'),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'OBS: Exporten innehåller endast din egen data. Ingen data från andra användare inkluderas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMedium,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check,
            size: 16,
            color: AppColors.success,
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
        const SnackBar(
          content: Text('✓ Data exporterad framgångsrikt'),
          backgroundColor: AppColors.success,
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
            content: Text('✓ Fil sparad: $fileName'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: AppColors.cardWhite,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Kunde inte spara fil: $e'),
            backgroundColor: AppColors.error,
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
        subject: 'Butlery Data Export',
        text: 'Min exporterade data från Butlery app',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Kunde inte dela: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleClear(
      BuildContext context, DataExportViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa export?'),
        content: const Text(
          'Är du säker på att du vill rensa den exporterade datan? '
          'Du kan när som helst exportera igen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Rensa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      viewModel.clearExportedData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Export rensad'),
          ),
        );
      }
    }
  }
}
