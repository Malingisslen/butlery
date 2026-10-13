import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
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
        builder: (_) => BatchImportPreview(
          recipes: parsed,
          backTo: context.l10n.importFromFile,
        ),
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
    return ButleryPage.undersida(
      title: context.l10n.importFromFile,
      body: Padding(
        padding: AppDimensions.responsiveContentPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            TintedNote(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.importFromFileTitle,
                    style: AppTextStyles.headlineSmall,
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    context.l10n.importFileColumnsRequired,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  _buildRequirement(context.l10n.importColumnTitle),
                  _buildRequirement(
                    context.l10n.importColumnIngredients,
                  ),
                  _buildRequirement(
                    context.l10n.importColumnInstructions,
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(
                    context.l10n.importFileColumnsOptional,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  _buildOptional(context.l10n.importColumnCookingTime),
                  _buildOptional(context.l10n.importColumnServings),
                  _buildOptional(context.l10n.importColumnCategory),
                  _buildOptional(context.l10n.importColumnTags),
                ],
              ),
            ),

            const SizedBox(height: AppDimensions.space32),

            // Import button
            if (!_vm.isLoading)
              UtilityComponents.primaryButton(
                context,
                label: context.l10n.importSelectFileAndImport,
                icon: ButleryIcons.download,
                onPressed: _handleImport,
              ),

            // Loading indicator
            if (_vm.isLoading)
              Column(
                children: [
                  // The plate line with its text (B-18): the status says
                  // what is being read.
                  PlateLineMessage(
                    message:
                        _vm.statusMessage ?? context.l10n.importReadingFile,
                  ),
                  if (_vm.importedCount > 0 || _vm.failedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppDimensions.space8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_vm.importedCount > 0) ...[
                            ButleryIcon(
                              ButleryIcons.circleCheck,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                            ),
                            const SizedBox(width: AppDimensions.space4),
                            Text(
                              context.l10n.importSucceededCount(
                                _vm.importedCount,
                              ),
                            ),
                          ],
                          if (_vm.importedCount > 0 && _vm.failedCount > 0)
                            const SizedBox(width: AppDimensions.space12),
                          if (_vm.failedCount > 0) ...[
                            ButleryIcon(
                              ButleryIcons.triangleAlert,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: AppDimensions.space4),
                            Text(
                              context.l10n.importFailedCount(
                                _vm.failedCount,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),

            // Status message
            if (!_vm.isLoading && _vm.statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppDimensions.space12,
                ),
                child: TintedNote(
                  child: Text(
                    _vm.statusMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _vm.failedCount > 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.space8,
        bottom: AppDimensions.space4,
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.check,
            size: AppDimensions.iconSizeS,
            color: context.modeColors.success,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }

  Widget _buildOptional(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.space8,
        bottom: AppDimensions.space4,
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.plus,
            size: AppDimensions.iconSizeS,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
