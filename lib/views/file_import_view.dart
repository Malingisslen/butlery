import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/file_import_viewmodel.dart';
import 'package:butlery/widgets/import/batch_import_preview.dart';

/// File import view for CSV and Excel recipe imports
class FileImportView extends StatefulWidget {
  const FileImportView({super.key});

  @override
  State<FileImportView> createState() => _FileImportViewState();
}

class _FileImportViewState extends State<FileImportView> {
  final FileImportViewModel _vm = FileImportViewModel();

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  /// Orchestrates the flow: the VM parses + imports (business logic + state);
  /// the view owns the navigation (showing the preview, reading the selection,
  /// popping on success).
  Future<void> _handleImport() async {
    final parsed = await _vm.parseFile();
    if (!mounted || parsed.isEmpty) return;

    final selected = await Navigator.push<List<Recipe>>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchImportPreview(recipes: parsed),
      ),
    );
    if (!mounted) return;
    if (selected == null || selected.isEmpty) {
      _vm.reset();
      return;
    }

    await _vm.importSelected(selected);
    if (!mounted) return;

    // Auto-close once everything imported cleanly.
    if (_vm.allSucceeded) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.importFromFile),
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
                tablet: 700,
                desktop: 800,
              ),
            ),
            child: Padding(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacingL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.importFromFileTitle,
                            style: AppTextStyles.headlineSmall,
                          ),
                          const SizedBox(height: AppDimensions.spacingM),
                          Text(
                            context.l10n.importFileColumnsRequired,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppDimensions.spacingS),
                          _buildRequirement(context.l10n.importColumnTitle),
                          _buildRequirement(
                              context.l10n.importColumnIngredients),
                          _buildRequirement(
                              context.l10n.importColumnInstructions),
                          const SizedBox(height: AppDimensions.spacingS),
                          Text(
                            context.l10n.importFileColumnsOptional,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppDimensions.spacingS),
                          _buildOptional(context.l10n.importColumnCookingTime),
                          _buildOptional(context.l10n.importColumnServings),
                          _buildOptional(context.l10n.importColumnCategory),
                          _buildOptional(context.l10n.importColumnTags),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXl),

                  // Import button
                  if (!_vm.isLoading)
                    UtilityComponents.primaryButton(
                      context,
                      label: context.l10n.importSelectFileAndImport,
                      icon: Icons.file_upload,
                      onPressed: _handleImport,
                    ),

                  // Loading indicator
                  if (_vm.isLoading)
                    Column(
                      children: [
                        const LoadingIndicator(),
                        const SizedBox(height: AppDimensions.spacingL),
                        if (_vm.statusMessage != null)
                          Text(
                            _vm.statusMessage!,
                            style: AppTextStyles.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        if (_vm.importedCount > 0 || _vm.failedCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: AppDimensions.spacingM),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_vm.importedCount > 0) ...[
                                  Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingS),
                                  Text(context.l10n
                                      .importSucceededCount(_vm.importedCount)),
                                ],
                                if (_vm.importedCount > 0 &&
                                    _vm.failedCount > 0)
                                  const SizedBox(width: AppDimensions.spacingL),
                                if (_vm.failedCount > 0) ...[
                                  Icon(
                                    Icons.error,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingS),
                                  Text(context.l10n
                                      .importFailedCount(_vm.failedCount)),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),

                  // Status message
                  if (!_vm.isLoading && _vm.statusMessage != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: AppDimensions.spacingL),
                      child: Card(
                        color: _vm.failedCount > 0
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.spacingM),
                          child: Text(
                            _vm.statusMessage!,
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          start: AppDimensions.spacingM, bottom: AppDimensions.spacingXs),
      child: Row(
        children: [
          Icon(Icons.check,
              size: AppDimensions.iconSizeS,
              color: context.butleryColors.success),
          const SizedBox(width: AppDimensions.spacingS),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOptional(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
          start: AppDimensions.spacingM, bottom: AppDimensions.spacingXs),
      child: Row(
        children: [
          Icon(Icons.add,
              size: AppDimensions.iconSizeS,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppDimensions.spacingS),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
