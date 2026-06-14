/// User-assisted import dialog for manual recipe extraction.
///
/// A 3-step wizard that guides users through:
/// 1. Selecting ingredient lines from extracted text
/// 2. Selecting instruction lines from remaining text
/// 3. Reviewing and editing the final recipe
///
/// Uses extracted components for reusability:
/// - [ImportDialogHeader] - Header with title and close button
/// - [StepProgressIndicator] - Progress dots
/// - [ImportDialogFooter] - Validation and navigation buttons
/// - [EditableListBuilder] - Editable list component
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/widgets/import/text_line_selector.dart';
import 'package:butlery/widgets/import/components/import_dialog_header.dart';
import 'package:butlery/widgets/import/components/step_progress_indicator.dart';
import 'package:butlery/widgets/import/components/import_dialog_footer.dart';
import 'package:butlery/widgets/import/components/editable_list_builder.dart';
import 'package:butlery/core/dialogs/dialog_factory.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';

/// Show the assisted import dialog.
///
/// Returns the created [Recipe] or null if cancelled.
Future<Recipe?> showAssistedImportDialog({
  required BuildContext context,
  required String extractedText,
  String? suggestedTitle,
  String? thumbnailUrl,
  String? sourceUrl,
  List<int>? preDetectedIngredientLines,
}) {
  return showDialog<Recipe>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AssistedImportDialog(
      extractedText: extractedText,
      suggestedTitle: suggestedTitle,
      thumbnailUrl: thumbnailUrl,
      sourceUrl: sourceUrl,
      preDetectedIngredientLines: preDetectedIngredientLines,
    ),
  );
}

/// Main dialog widget for user-assisted import.
class AssistedImportDialog extends StatelessWidget {
  final String extractedText;
  final String? suggestedTitle;
  final String? thumbnailUrl;
  final String? sourceUrl;
  final List<int>? preDetectedIngredientLines;

  const AssistedImportDialog({
    super.key,
    required this.extractedText,
    this.suggestedTitle,
    this.thumbnailUrl,
    this.sourceUrl,
    this.preDetectedIngredientLines,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AssistedImportViewModel(
        extractedText: extractedText,
        suggestedTitle: suggestedTitle,
        thumbnailUrl: thumbnailUrl,
        sourceUrl: sourceUrl,
        preDetectedIngredientLines: preDetectedIngredientLines,
      ),
      child: const _AssistedImportDialogContent(),
    );
  }
}

class _AssistedImportDialogContent extends StatelessWidget {
  const _AssistedImportDialogContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AssistedImportViewModel>();
    final mediaQuery = MediaQuery.of(context);

    // Responsive sizing
    final isSmallScreen = mediaQuery.size.width < 600;
    final dialogWidth = isSmallScreen
        ? mediaQuery.size.width * 0.95
        : mediaQuery.size.width * 0.8;
    final dialogHeight = isSmallScreen
        ? mediaQuery.size.height * 0.9
        : mediaQuery.size.height * 0.85;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleCancel(context, viewModel);
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth.clamp(300, 700),
            maxHeight: dialogHeight.clamp(400, 800),
          ),
          child: Column(
            children: [
              ImportDialogHeader(
                currentStep: viewModel.currentStep,
                onClose: () => _handleCancel(context, viewModel),
              ),
              StepProgressIndicator(
                currentStep: viewModel.stepNumber,
                totalSteps: viewModel.totalSteps,
              ),
              if (viewModel.thumbnailUrl != null)
                _ThumbnailBanner(url: viewModel.thumbnailUrl!),
              Expanded(
                child: _buildContent(context, viewModel),
              ),
              ImportDialogFooter(
                validationError: viewModel.validateCurrentStep(),
                canGoBack: viewModel.canGoBack,
                canProceed: viewModel.canProceed,
                currentStep: viewModel.currentStep,
                onBack: viewModel.previousStep,
                onCancel: () => _handleCancel(context, viewModel),
                onNext: viewModel.nextStep,
                onSave: () => _saveRecipe(context, viewModel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, AssistedImportViewModel viewModel) {
    switch (viewModel.currentStep) {
      case AssistedImportStep.selectIngredients:
        return _IngredientSelectionStep(viewModel: viewModel);
      case AssistedImportStep.selectInstructions:
        return _InstructionSelectionStep(viewModel: viewModel);
      case AssistedImportStep.reviewEdit:
        return _ReviewEditStep(viewModel: viewModel);
    }
  }

  void _handleCancel(BuildContext context, AssistedImportViewModel viewModel) {
    if (viewModel.hasSelections) {
      _showCancelConfirmation(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showCancelConfirmation(BuildContext context) async {
    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: context.l10n.importCancelTitle,
      message: context.l10n.importCancelMessage,
      confirmText: context.l10n.importCancelConfirm,
      cancelText: context.l10n.commonContinue,
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  void _saveRecipe(BuildContext context, AssistedImportViewModel viewModel) {
    final recipe = viewModel.buildRecipe();
    Navigator.of(context).pop(recipe);
  }
}

class _IngredientSelectionStep extends StatelessWidget {
  final AssistedImportViewModel viewModel;

  const _IngredientSelectionStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return TextLineSelector(
      lines: viewModel.lines,
      selectedIndices: viewModel.selectedIngredientIndices,
      highlightedIndices: viewModel.likelyIngredientIndices,
      aiSuggestedIndices: viewModel.likelyIngredientIndices,
      excludedIndices: const {},
      mode: SelectionMode.ingredients,
      headerText: context.l10n.importSelectIngredients,
      onSelectionChanged: viewModel.setIngredientSelection,
    );
  }
}

class _InstructionSelectionStep extends StatelessWidget {
  final AssistedImportViewModel viewModel;

  const _InstructionSelectionStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final likelyInstructions = viewModel.likelyInstructionIndices
        .difference(viewModel.selectedIngredientIndices);

    return TextLineSelector(
      lines: viewModel.lines,
      selectedIndices: viewModel.selectedInstructionIndices,
      highlightedIndices: likelyInstructions,
      aiSuggestedIndices: likelyInstructions,
      excludedIndices: viewModel.selectedIngredientIndices,
      mode: SelectionMode.instructions,
      headerText: context.l10n.importSelectInstructions,
      onSelectionChanged: viewModel.setInstructionSelection,
    );
  }
}

class _ReviewEditStep extends StatelessWidget {
  final AssistedImportViewModel viewModel;

  const _ReviewEditStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          TextFormField(
            initialValue: viewModel.title,
            decoration: InputDecoration(
              labelText: context.l10n.importRecipeNameRequired,
              hintText: context.l10n.importRecipeNameHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: viewModel.setTitle,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Description
          TextFormField(
            initialValue: viewModel.description,
            decoration: InputDecoration(
              labelText: context.l10n.recipeDescription,
              hintText: context.l10n.importDescriptionHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: viewModel.setDescription,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Portions and Time row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: viewModel.portions.toString(),
                  decoration: InputDecoration(
                    labelText: context.l10n.recipePortions,
                    border: const OutlineInputBorder(),
                    suffixText: 'st',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) viewModel.setPortions(parsed);
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: TextFormField(
                  initialValue: viewModel.timeMinutes.toString(),
                  decoration: InputDecoration(
                    labelText: context.l10n.recipeCookingTime,
                    border: const OutlineInputBorder(),
                    suffixText: 'min',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) viewModel.setTimeMinutes(parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Meal type dropdown
          DropdownButtonFormField<String>(
            initialValue: viewModel.mealType,
            decoration: InputDecoration(
              labelText: context.l10n.importMealType,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                  value: 'breakfast',
                  child: Text(context.l10n.importMealBreakfast)),
              DropdownMenuItem(
                  value: 'lunch', child: Text(context.l10n.importMealLunch)),
              DropdownMenuItem(
                  value: 'dinner', child: Text(context.l10n.importMealDinner)),
              DropdownMenuItem(
                  value: 'snack', child: Text(context.l10n.importMealSnack)),
              DropdownMenuItem(
                  value: 'dessert',
                  child: Text(context.l10n.importMealDessert)),
            ],
            onChanged: (value) {
              if (value != null) viewModel.setMealType(value);
            },
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          // Ingredients section
          EditableListHeader(
            title: context.l10n.recipeIngredients,
            icon: Icons.restaurant,
            count: viewModel.editedIngredients.length,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          EditableListBuilder(
            items: viewModel.editedIngredients,
            onUpdate: viewModel.updateIngredient,
            onRemove: viewModel.removeIngredient,
            onAdd: viewModel.addIngredient,
            hintText: context.l10n.importAddIngredient,
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          // Instructions section
          EditableListHeader(
            title: context.l10n.recipeInstructions,
            icon: Icons.format_list_numbered,
            count: viewModel.editedInstructions.length,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          EditableListBuilder(
            items: viewModel.editedInstructions,
            onUpdate: viewModel.updateInstruction,
            onRemove: viewModel.removeInstruction,
            onAdd: viewModel.addInstruction,
            hintText: context.l10n.importAddStep,
            showNumbers: true,
          ),
        ],
      ),
    );
  }
}

class _ThumbnailBanner extends StatelessWidget {
  final String url;
  const _ThumbnailBanner({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: SizedBox(
        height: AppDimensions.imageHeightMedium,
        width: double.infinity,
        child: SimpleImageWidget(
          imageUrl: url,
          fit: BoxFit.cover,
          config: ImageConfig.thumbnail(),
        ),
      ),
    );
  }
}
