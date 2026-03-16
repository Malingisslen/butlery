import 'package:flutter/material.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Consolidated state class for FileImportView to reduce setState calls
class FileImportState {
  final bool isLoading;
  final String? statusMessage;
  final int importedCount;
  final int failedCount;

  const FileImportState({
    this.isLoading = false,
    this.statusMessage,
    this.importedCount = 0,
    this.failedCount = 0,
  });

  FileImportState copyWith({
    bool? isLoading,
    String? statusMessage,
    int? importedCount,
    int? failedCount,
  }) {
    return FileImportState(
      isLoading: isLoading ?? this.isLoading,
      statusMessage: statusMessage ?? this.statusMessage,
      importedCount: importedCount ?? this.importedCount,
      failedCount: failedCount ?? this.failedCount,
    );
  }
}

/// File import view for CSV and Excel recipe imports
class FileImportView extends StatefulWidget {
  const FileImportView({super.key});

  @override
  State<FileImportView> createState() => _FileImportViewState();
}

class _FileImportViewState extends State<FileImportView> {
  final FileImportStrategy _fileImportStrategy = FileImportStrategy();
  FileImportState _state = const FileImportState();

  Future<void> _importFile() async {
    setState(() {
      _state = _state.copyWith(
        isLoading: true,
        statusMessage: context.l10n.importSelectingFile,
        importedCount: 0,
        failedCount: 0,
      );
    });

    try {
      // Import multiple recipes from file
      final recipes = await _fileImportStrategy.importMultiple();

      if (recipes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _state = _state.copyWith(
            statusMessage: context.l10n.importNoFileOrNoRecipes,
            isLoading: false,
          );
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          statusMessage: context.l10n.importImportingRecipes(recipes.length),
        );
      });

      // Get recipe service
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();

      // Import each recipe
      for (final recipe in recipes) {
        try {
          await recipeService.createPersonalRecipe(
            title: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            instructions: recipe.instructions,
            mealType: recipe.mealType,
            portions: recipe.portions,
            timeMinutes: recipe.timeMinutes,
            personalTagIds: recipe.personalTagIds,
            rating: recipe.rating,
            sourceUrl: recipe.sourceUrl,
            imageUrls: recipe.imageUrls,
          );
          if (!mounted) return;
          setState(() {
            _state = _state.copyWith(importedCount: _state.importedCount + 1);
          });
        } catch (e) {
          AppLogger.error('Failed to import recipe: ${recipe.title}', e);
          if (!mounted) return;
          setState(() {
            _state = _state.copyWith(failedCount: _state.failedCount + 1);
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          statusMessage: context.l10n
              .importComplete(_state.importedCount, _state.failedCount),
        );
      });

      // Navigate back if all successful
      if (_state.failedCount == 0 && mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      AppLogger.error('File import failed', e);
      if (!mounted) return;
      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          statusMessage: context.l10n.importFailed(
            SnackBarUtils.userFriendlyMessage(context, e),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  if (!_state.isLoading)
                    UtilityComponents.primaryButton(
                      context,
                      label: context.l10n.importSelectFileAndImport,
                      icon: Icons.file_upload,
                      onPressed: _importFile,
                    ),

                  // Loading indicator
                  if (_state.isLoading)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppDimensions.spacingL),
                        if (_state.statusMessage != null)
                          Text(
                            _state.statusMessage!,
                            style: AppTextStyles.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        if (_state.importedCount > 0 || _state.failedCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: AppDimensions.spacingM),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_state.importedCount > 0) ...[
                                  Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingS),
                                  Text(context.l10n.importSucceededCount(
                                      _state.importedCount)),
                                ],
                                if (_state.importedCount > 0 &&
                                    _state.failedCount > 0)
                                  const SizedBox(width: AppDimensions.spacingL),
                                if (_state.failedCount > 0) ...[
                                  Icon(
                                    Icons.error,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: AppDimensions.spacingS),
                                  Text(context.l10n
                                      .importFailedCount(_state.failedCount)),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),

                  // Status message
                  if (!_state.isLoading && _state.statusMessage != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: AppDimensions.spacingL),
                      child: Card(
                        color: _state.failedCount > 0
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.spacingM),
                          child: Text(
                            _state.statusMessage!,
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
      padding: const EdgeInsets.only(
          left: AppDimensions.spacingM, bottom: AppDimensions.spacingXs),
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
      padding: const EdgeInsets.only(
          left: AppDimensions.spacingM, bottom: AppDimensions.spacingXs),
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
