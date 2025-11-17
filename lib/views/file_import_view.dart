import 'package:flutter/material.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/layout_components.dart';

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
        statusMessage: 'Väljer fil...',
        importedCount: 0,
        failedCount: 0,
      );
    });

    try {
      // Import multiple recipes from file
      final recipes = await _fileImportStrategy.importMultiple();

      if (recipes.isEmpty) {
        setState(() {
          _state = _state.copyWith(
            statusMessage: 'Ingen fil vald eller filen innehåller inga recept',
            isLoading: false,
          );
        });
        return;
      }

      setState(() {
        _state = _state.copyWith(
          statusMessage: 'Importerar ${recipes.length} recept...',
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
            tags: recipe.tags,
            rating: recipe.rating,
            sourceUrl: recipe.sourceUrl,
            imageUrls: recipe.imageUrls,
          );
          setState(() {
            _state = _state.copyWith(importedCount: _state.importedCount + 1);
          });
        } catch (e) {
          AppLogger.error('Failed to import recipe: ${recipe.title}', e);
          setState(() {
            _state = _state.copyWith(failedCount: _state.failedCount + 1);
          });
        }
      }

      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          statusMessage: 'Import klar: ${_state.importedCount} lyckades, ${_state.failedCount} misslyckades',
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
      setState(() {
        _state = _state.copyWith(
          isLoading: false,
          statusMessage: 'Import misslyckades: ${e.toString()}',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importera från fil'),
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
                      const Text(
                        'Importera recept från CSV eller Excel',
                        style: AppTextStyles.headlineSmall,
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      const Text(
                        'Din fil bör innehålla kolumner för:',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      _buildRequirement('Titel (title/namn)'),
                      _buildRequirement('Ingredienser (ingredients/ingredienser)'),
                      _buildRequirement('Instruktioner (instructions/instruktioner)'),
                      const SizedBox(height: AppDimensions.spacingS),
                      const Text(
                        'Valfria kolumner:',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      _buildOptional('Tillagningstid (cookingtime/tid)'),
                      _buildOptional('Portioner (servings/portioner)'),
                      _buildOptional('Kategori (category/kategori)'),
                      _buildOptional('Taggar (tags/taggar)'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: AppDimensions.spacingXl),

              // Import button
              if (!_state.isLoading)
                UtilityComponents.primaryButton(
                  context,
                  label: 'Välj fil och importera',
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
                        padding: const EdgeInsets.only(top: AppDimensions.spacingM),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_state.importedCount > 0) ...[
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Text('${_state.importedCount} lyckades'),
                            ],
                            if (_state.importedCount > 0 && _state.failedCount > 0)
                              const SizedBox(width: AppDimensions.spacingL),
                            if (_state.failedCount > 0) ...[
                              Icon(
                                Icons.error,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Text('${_state.failedCount} misslyckades'),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),

              // Status message
              if (!_state.isLoading && _state.statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.spacingL),
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
      padding: const EdgeInsets.only(left: AppDimensions.spacingM, bottom: AppDimensions.spacingXs),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Colors.green),
          const SizedBox(width: AppDimensions.spacingS),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOptional(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.spacingM, bottom: AppDimensions.spacingXs),
      child: Row(
        children: [
          Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppDimensions.spacingS),
          Text(text, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}