/// User-assisted import dialog for manual recipe extraction.
///
/// A 3-step wizard that guides users through:
/// 1. Selecting ingredient lines from extracted text
/// 2. Selecting instruction lines from remaining text
/// 3. Reviewing and editing the final recipe
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/widgets/import/text_line_selector.dart';

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
    final theme = Theme.of(context);
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
            // Header
            _buildHeader(context, viewModel, theme),

            // Progress indicator
            _buildProgressIndicator(viewModel, theme),

            // Content area
            Expanded(
              child: _buildContent(context, viewModel),
            ),

            // Footer with navigation buttons
            _buildFooter(context, viewModel, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AssistedImportViewModel viewModel,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manuell import',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  _getStepDescription(viewModel.currentStep),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showCancelConfirmation(context),
            tooltip: 'Avbryt',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
    AssistedImportViewModel viewModel,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          for (int i = 1; i <= viewModel.totalSteps; i++) ...[
            if (i > 1)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= viewModel.stepNumber
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            _buildStepIndicator(
              stepNumber: i,
              isActive: i == viewModel.stepNumber,
              isCompleted: i < viewModel.stepNumber,
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepIndicator({
    required int stepNumber,
    required bool isActive,
    required bool isCompleted,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color textColor;

    if (isCompleted) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isActive) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest;
      textColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, size: 16, color: textColor)
            : Text(
                '$stepNumber',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
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

  Widget _buildFooter(
    BuildContext context,
    AssistedImportViewModel viewModel,
    ThemeData theme,
  ) {
    final validationError = viewModel.validateCurrentStep();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Validation error
          if (validationError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validationError,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Buttons
          Row(
            children: [
              // Back button
              if (viewModel.canGoBack)
                TextButton.icon(
                  onPressed: viewModel.previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Tillbaka'),
                )
              else
                TextButton(
                  onPressed: () => _showCancelConfirmation(context),
                  child: const Text('Avbryt'),
                ),
              const Spacer(),
              // Next/Save button
              if (viewModel.currentStep == AssistedImportStep.reviewEdit)
                FilledButton.icon(
                  onPressed: viewModel.canProceed
                      ? () => _saveRecipe(context, viewModel)
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Spara recept'),
                )
              else
                FilledButton.icon(
                  onPressed: viewModel.canProceed
                      ? viewModel.nextStep
                      : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Nästa'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStepDescription(AssistedImportStep step) {
    switch (step) {
      case AssistedImportStep.selectIngredients:
        return 'Steg 1: Välj ingredienser';
      case AssistedImportStep.selectInstructions:
        return 'Steg 2: Välj instruktioner';
      case AssistedImportStep.reviewEdit:
        return 'Steg 3: Granska och redigera';
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

// =============================================================================
// Step 1: Ingredient Selection
// =============================================================================

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

// =============================================================================
// Step 2: Instruction Selection
// =============================================================================

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

// =============================================================================
// Step 3: Review and Edit
// =============================================================================

class _ReviewEditStep extends StatelessWidget {
  final AssistedImportViewModel viewModel;

  const _ReviewEditStep({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          _buildSectionHeader(
            theme,
            'Ingredienser',
            Icons.restaurant,
            viewModel.editedIngredients.length,
          ),
          const SizedBox(height: 8),
          _buildEditableList(
            context,
            items: viewModel.editedIngredients,
            onUpdate: viewModel.updateIngredient,
            onRemove: viewModel.removeIngredient,
            onAdd: viewModel.addIngredient,
            hintText: 'Lägg till ingrediens',
          ),
          const SizedBox(height: 24),

          // Instructions section
          _buildSectionHeader(
            theme,
            'Instruktioner',
            Icons.format_list_numbered,
            viewModel.editedInstructions.length,
          ),
          const SizedBox(height: 8),
          _buildEditableList(
            context,
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

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    IconData icon,
    int count,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableList(
    BuildContext context, {
    required List<String> items,
    required void Function(int, String) onUpdate,
    required void Function(int) onRemove,
    required void Function(String) onAdd,
    required String hintText,
    bool showNumbers = false,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Existing items
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showNumbers) ...[
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: TextFormField(
                    initialValue: item,
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => onRemove(index),
                        tooltip: 'Ta bort',
                      ),
                    ),
                    onChanged: (value) => onUpdate(index, value),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
          );
        }),

        // Add new item
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (showNumbers) const SizedBox(width: 28),
              Expanded(
                child: _AddItemField(
                  hintText: hintText,
                  onAdd: onAdd,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Text field for adding new items.
class _AddItemField extends StatefulWidget {
  final String hintText;
  final void Function(String) onAdd;

  const _AddItemField({
    required this.hintText,
    required this.onAdd,
  });

  @override
  State<_AddItemField> createState() => _AddItemFieldState();
}

class _AddItemFieldState extends State<_AddItemField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      widget.onAdd(value);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.hintText,
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            Icons.add_circle,
            color: theme.colorScheme.primary,
          ),
          onPressed: _add,
          tooltip: 'Lägg till',
        ),
      ),
      textCapitalization: TextCapitalization.sentences,
      onFieldSubmitted: (_) => _add(),
    );
  }
}
