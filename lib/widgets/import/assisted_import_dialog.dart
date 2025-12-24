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
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/widgets/import/text_line_selector.dart';
import 'package:butlery/widgets/import/components/import_dialog_header.dart';
import 'package:butlery/widgets/import/components/step_progress_indicator.dart';
import 'package:butlery/widgets/import/components/import_dialog_footer.dart';
import 'package:butlery/widgets/import/components/editable_list_builder.dart';

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
    barrierDismissible: false,
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

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth.clamp(300, 700),
          maxHeight: dialogHeight.clamp(400, 800),
        ),
        child: Column(
          children: [
            ImportDialogHeader(
              currentStep: viewModel.currentStep,
              onClose: () => _showCancelConfirmation(context),
            ),
            StepProgressIndicator(
              currentStep: viewModel.stepNumber,
              totalSteps: viewModel.totalSteps,
            ),
            Expanded(
              child: _buildContent(context, viewModel),
            ),
            ImportDialogFooter(
              validationError: viewModel.validateCurrentStep(),
              canGoBack: viewModel.canGoBack,
              canProceed: viewModel.canProceed,
              currentStep: viewModel.currentStep,
              onBack: viewModel.previousStep,
              onCancel: () => _showCancelConfirmation(context),
              onNext: viewModel.nextStep,
              onSave: () => _saveRecipe(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AssistedImportViewModel viewModel) {
    switch (viewModel.currentStep) {
      case AssistedImportStep.selectIngredients:
        return _IngredientSelectionStep(viewModel: viewModel);
      case AssistedImportStep.selectInstructions:
        return _InstructionSelectionStep(viewModel: viewModel);
      case AssistedImportStep.reviewEdit:
        return _ReviewEditStep(viewModel: viewModel);
    }
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avbryt import?'),
        content: const Text(
          'Är du säker på att du vill avbryta? Alla val kommer att förloras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fortsätt'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close confirmation
              Navigator.of(context).pop(); // Close dialog
            },
            child: const Text('Avbryt import'),
          ),
        ],
      ),
    );
  }

  void _saveRecipe(BuildContext context, AssistedImportViewModel viewModel) {
    final recipe = viewModel.buildRecipe();
    Navigator.of(context).pop(recipe);
  }
}

// ===== STEP WIDGETS =====

class _IngredientSelectionStep extends StatelessWidget {
  final AssistedImportViewModel viewModel;

  const _IngredientSelectionStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return TextLineSelector(
      lines: viewModel.lines,
      selectedIndices: viewModel.selectedIngredientIndices,
      highlightedIndices: viewModel.likelyIngredientIndices,
      excludedIndices: const {},
      mode: SelectionMode.ingredients,
      headerText: 'Välj ingredienser',
      onSelectionChanged: viewModel.setIngredientSelection,
    );
  }
}

class _InstructionSelectionStep extends StatelessWidget {
  final AssistedImportViewModel viewModel;

  const _InstructionSelectionStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    // Detect likely instruction lines (excluding already selected ingredients)
    final likelyInstructions = viewModel.lines
        .asMap()
        .entries
        .where((e) =>
            !viewModel.selectedIngredientIndices.contains(e.key) &&
            e.value.trim().length > 20)
        .map((e) => e.key)
        .toSet();

    return TextLineSelector(
      lines: viewModel.lines,
      selectedIndices: viewModel.selectedInstructionIndices,
      highlightedIndices: likelyInstructions,
      excludedIndices: viewModel.selectedIngredientIndices,
      mode: SelectionMode.instructions,
      headerText: 'Välj instruktioner',
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          TextFormField(
            initialValue: viewModel.title,
            decoration: const InputDecoration(
              labelText: 'Receptnamn *',
              hintText: 'Ange receptets namn',
              border: OutlineInputBorder(),
            ),
            onChanged: viewModel.setTitle,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            initialValue: viewModel.description,
            decoration: const InputDecoration(
              labelText: 'Beskrivning',
              hintText: 'Kort beskrivning (valfritt)',
              border: OutlineInputBorder(),
            ),
            onChanged: viewModel.setDescription,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),

          // Portions and Time row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: viewModel.portions.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Portioner',
                    border: OutlineInputBorder(),
                    suffixText: 'st',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null) viewModel.setPortions(parsed);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  initialValue: viewModel.timeMinutes.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Tid',
                    border: OutlineInputBorder(),
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
          const SizedBox(height: 16),

          // Meal type dropdown
          DropdownButtonFormField<String>(
            initialValue: viewModel.mealType,
            decoration: const InputDecoration(
              labelText: 'Måltid',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'breakfast', child: Text('Frukost')),
              DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
              DropdownMenuItem(value: 'dinner', child: Text('Middag')),
              DropdownMenuItem(value: 'snack', child: Text('Mellanmål')),
              DropdownMenuItem(value: 'dessert', child: Text('Dessert')),
            ],
            onChanged: (value) {
              if (value != null) viewModel.setMealType(value);
            },
          ),
          const SizedBox(height: 24),

          // Ingredients section
          EditableListHeader(
            title: 'Ingredienser',
            icon: Icons.restaurant,
            count: viewModel.editedIngredients.length,
          ),
          const SizedBox(height: 8),
          EditableListBuilder(
            items: viewModel.editedIngredients,
            onUpdate: viewModel.updateIngredient,
            onRemove: viewModel.removeIngredient,
            onAdd: viewModel.addIngredient,
            hintText: 'Lägg till ingrediens',
          ),
          const SizedBox(height: 24),

          // Instructions section
          EditableListHeader(
            title: 'Instruktioner',
            icon: Icons.format_list_numbered,
            count: viewModel.editedInstructions.length,
          ),
          const SizedBox(height: 8),
          EditableListBuilder(
            items: viewModel.editedInstructions,
            onUpdate: viewModel.updateInstruction,
            onRemove: viewModel.removeInstruction,
            onAdd: viewModel.addInstruction,
            hintText: 'Lägg till steg',
            showNumbers: true,
          ),
        ],
      ),
    );
  }
}
