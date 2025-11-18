import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/theme/app_colors.dart';
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
                    _buildHeaderSection(),
                    const SizedBox(height: 32),
                    _buildExportButton(context, viewModel),
                    const SizedBox(height: 24),
                    if (viewModel.isExporting) _buildLoadingState(),
                    if (viewModel.hasError) _buildErrorState(context, viewModel),
                    if (viewModel.hasExportedData) _buildSuccessState(context, viewModel),
                    const SizedBox(height: 32),
                    _buildInfoSection(),
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

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 32,
                  color: AppColors.primary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ladda ner dina data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Enligt GDPR Artikel 20 har du rätt att få en kopia av all din personliga data som lagras i Butlery. Data exporteras i JSON-format som du kan spara eller överföra till en annan tjänst.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, DataExportViewModel viewModel) {
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
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Exporterar dina data...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Detta kan ta några sekunder',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
            const SizedBox(height: 16),
            const Text(
              'Export misslyckades',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? 'Ett okänt fel uppstod',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
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

  Widget _buildSuccessState(BuildContext context, DataExportViewModel viewModel) {
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
            const SizedBox(height: 16),
            const Text(
              'Data exporterad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Exporterad ${viewModel.exportTimestampText}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Filstorlek: ${viewModel.exportSizeText}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
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
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleShare(context, viewModel),
                    icon: const Icon(Icons.share),
                    label: const Text('Dela'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _handleClear(context, viewModel),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Rensa export'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: AppColors.info.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Vad ingår i exporten?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('Profil och inställningar'),
            _buildInfoItem('Alla dina recept'),
            _buildInfoItem('Vänner och sociala kontakter'),
            _buildInfoItem('Meddelanden och konversationer'),
            _buildInfoItem('Inköpslistor och menyer'),
            _buildInfoItem('Kommentarer och betyg'),
            _buildInfoItem('Aktivitetshistorik'),
            const SizedBox(height: 12),
            Text(
              'OBS: Exporten innehåller endast din egen data. Ingen data från andra användare inkluderas.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // Action handlers

  Future<void> _handleExport(BuildContext context, DataExportViewModel viewModel) async {
    final success = await viewModel.exportData();

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Data exporterad framgångsrikt'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleDownload(BuildContext context, DataExportViewModel viewModel) async {
    if (viewModel.exportedData == null) return;

    try {
      // Get downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'butlery_data_export_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      // Write file
      final file = File(filePath);
      await file.writeAsString(viewModel.exportedData!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Fil sparad: $fileName'),
            backgroundColor: Colors.green,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Kunde inte spara fil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(BuildContext context, DataExportViewModel viewModel) async {
    if (viewModel.exportedData == null) return;

    try {
      // Create temporary file
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'butlery_data_export_$timestamp.json';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsString(viewModel.exportedData!);

      // Share file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Butlery Data Export',
        text: 'Min exporterade data från Butlery app',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Kunde inte dela: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleClear(BuildContext context, DataExportViewModel viewModel) async {
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
