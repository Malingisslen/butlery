/// ViewModel for user-assisted recipe import.
///
/// Manages state for the 3-step wizard:
/// 1. Select ingredient lines
/// 2. Select instruction lines
/// 3. Review and edit recipe details
library;

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/import/ingredient_line_detector.dart';

/// Step in the assisted import wizard.
enum AssistedImportStep {
  /// Step 1: Select ingredient lines
  selectIngredients,

  /// Step 2: Select instruction lines
  selectInstructions,

  /// Step 3: Review and edit
  reviewEdit,
}

/// ViewModel for the assisted import dialog.
class AssistedImportViewModel extends ChangeNotifier {
  /// Current wizard step.
  AssistedImportStep _currentStep = AssistedImportStep.selectIngredients;
  AssistedImportStep get currentStep => _currentStep;

  /// Source data.
  final String extractedText;
  final String? suggestedTitle;
  final String? thumbnailUrl;
  final String? sourceUrl;

  /// Parsed lines from extracted text.
  late final List<String> lines;

  /// Pre-detected ingredient line indices.
  late final Set<int> likelyIngredientIndices;

  /// User selections.
  Set<int> _selectedIngredientIndices = {};
  Set<int> get selectedIngredientIndices => _selectedIngredientIndices;

  Set<int> _selectedInstructionIndices = {};
  Set<int> get selectedInstructionIndices => _selectedInstructionIndices;

  /// Editable recipe fields.
  String _title = '';
  String get title => _title;

  String _description = '';
  String get description => _description;

  int _portions = 4;
  int get portions => _portions;

  int _timeMinutes = 0;
  int get timeMinutes => _timeMinutes;

  String _mealType = 'dinner';
  String get mealType => _mealType;

  /// Editable ingredient list (after selection, can be modified).
  List<String> _editedIngredients = [];
  List<String> get editedIngredients => _editedIngredients;

  /// Editable instruction list (after selection, can be modified).
  List<String> _editedInstructions = [];
  List<String> get editedInstructions => _editedInstructions;

  // Loading and error states reserved for future async operations

  AssistedImportViewModel({
    required this.extractedText,
    this.suggestedTitle,
    this.thumbnailUrl,
    this.sourceUrl,
    List<int>? preDetectedIngredientLines,
  }) {
    // Parse lines
    lines = extractedText
        .split('\n')
        .map((line) => line.trim())
        .toList();

    // Use provided pre-detected lines or detect automatically
    if (preDetectedIngredientLines != null) {
      likelyIngredientIndices = preDetectedIngredientLines.toSet();
    } else {
      likelyIngredientIndices =
          IngredientLineDetector.detectFromLines(lines).toSet();
    }

    // Set initial title
    _title = suggestedTitle ?? '';
  }

  // ===========================================================================
  // Step Navigation
  // ===========================================================================

  /// Check if can proceed to next step.
  bool get canProceed {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        return _selectedIngredientIndices.isNotEmpty;
      case AssistedImportStep.selectInstructions:
        return _selectedInstructionIndices.isNotEmpty;
      case AssistedImportStep.reviewEdit:
        return _title.isNotEmpty &&
            _editedIngredients.isNotEmpty &&
            _editedInstructions.isNotEmpty;
    }
  }

  /// Check if can go back.
  bool get canGoBack => _currentStep != AssistedImportStep.selectIngredients;

  /// Proceed to next step.
  void nextStep() {
    if (!canProceed) return;

    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        _currentStep = AssistedImportStep.selectInstructions;
        break;
      case AssistedImportStep.selectInstructions:
        // Build editable lists from selections
        _buildEditableLists();
        _currentStep = AssistedImportStep.reviewEdit;
        break;
      case AssistedImportStep.reviewEdit:
        // Final step - nothing to do here
        break;
    }
    notifyListeners();
  }

  /// Go back to previous step.
  void previousStep() {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        // Can't go back from first step
        break;
      case AssistedImportStep.selectInstructions:
        _currentStep = AssistedImportStep.selectIngredients;
        break;
      case AssistedImportStep.reviewEdit:
        _currentStep = AssistedImportStep.selectInstructions;
        break;
    }
    notifyListeners();
  }

  /// Get step number (1-based).
  int get stepNumber {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        return 1;
      case AssistedImportStep.selectInstructions:
        return 2;
      case AssistedImportStep.reviewEdit:
        return 3;
    }
  }

  /// Total number of steps.
  int get totalSteps => 3;

  // ===========================================================================
  // Selection Methods
  // ===========================================================================

  /// Update ingredient selection.
  void setIngredientSelection(Set<int> indices) {
    _selectedIngredientIndices = indices;
    notifyListeners();
  }

  /// Update instruction selection.
  void setInstructionSelection(Set<int> indices) {
    _selectedInstructionIndices = indices;
    notifyListeners();
  }

  /// Select all highlighted ingredient lines.
  void selectAllHighlightedIngredients() {
    _selectedIngredientIndices = Set.from(likelyIngredientIndices);
    notifyListeners();
  }

  /// Get lines available for instruction selection (excluding ingredients).
  List<String> get availableInstructionLines {
    return lines
        .asMap()
        .entries
        .where((e) => !_selectedIngredientIndices.contains(e.key))
        .map((e) => e.value)
        .toList();
  }

  // ===========================================================================
  // Field Update Methods
  // ===========================================================================

  void setTitle(String value) {
    _title = value.trim();
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value.trim();
    notifyListeners();
  }

  void setPortions(int value) {
    _portions = value.clamp(1, 100);
    notifyListeners();
  }

  void setTimeMinutes(int value) {
    _timeMinutes = value.clamp(0, 1440); // Max 24 hours
    notifyListeners();
  }

  void setMealType(String value) {
    _mealType = value;
    notifyListeners();
  }

  // ===========================================================================
  // Ingredient/Instruction Editing
  // ===========================================================================

  void updateIngredient(int index, String value) {
    if (index >= 0 && index < _editedIngredients.length) {
      _editedIngredients[index] = value;
      notifyListeners();
    }
  }

  void addIngredient(String value) {
    if (value.trim().isNotEmpty) {
      _editedIngredients.add(value.trim());
      notifyListeners();
    }
  }

  void removeIngredient(int index) {
    if (index >= 0 && index < _editedIngredients.length) {
      _editedIngredients.removeAt(index);
      notifyListeners();
    }
  }

  void updateInstruction(int index, String value) {
    if (index >= 0 && index < _editedInstructions.length) {
      _editedInstructions[index] = value;
      notifyListeners();
    }
  }

  void addInstruction(String value) {
    if (value.trim().isNotEmpty) {
      _editedInstructions.add(value.trim());
      notifyListeners();
    }
  }

  void removeInstruction(int index) {
    if (index >= 0 && index < _editedInstructions.length) {
      _editedInstructions.removeAt(index);
      notifyListeners();
    }
  }

  // ===========================================================================
  // Recipe Building
  // ===========================================================================

  /// Build editable lists from selections.
  void _buildEditableLists() {
    // Extract ingredients from selected lines (sorted by index)
    final sortedIngredientIndices = _selectedIngredientIndices.toList()..sort();
    _editedIngredients = sortedIngredientIndices
        .map((i) => lines[i].trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Extract instructions from selected lines (sorted by index)
    final sortedInstructionIndices = _selectedInstructionIndices.toList()..sort();
    _editedInstructions = sortedInstructionIndices
        .map((i) => lines[i].trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Clean up instructions (remove step numbers if present)
    _editedInstructions = _editedInstructions
        .map(_cleanInstructionLine)
        .toList();
  }

  /// Clean instruction line (remove leading step numbers).
  String _cleanInstructionLine(String line) {
    // Remove patterns like "1. ", "Step 1: ", "Steg 1. "
    return line
        .replaceFirst(RegExp(r'^(steg|step)?\s*\d+[\.\):\s]+', caseSensitive: false), '')
        .trim();
  }

  /// Build final Recipe object.
  Recipe buildRecipe() {
    // Filter out empty items
    final ingredients = _editedIngredients
        .where((i) => i.trim().isNotEmpty)
        .toList();

    final instructions = _editedInstructions
        .where((i) => i.trim().isNotEmpty)
        .toList();

    return Recipe.personal(
      title: _title,
      description: _description,
      mealType: _mealType,
      portions: _portions,
      timeMinutes: _timeMinutes,
      ingredients: ingredients,
      instructions: instructions,
      sourceUrl: sourceUrl,
      imageUrls: thumbnailUrl != null ? [thumbnailUrl!] : null,
    );
  }

  // ===========================================================================
  // Validation
  // ===========================================================================

  /// Validate current step.
  String? validateCurrentStep() {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        if (_selectedIngredientIndices.isEmpty) {
          return 'Välj minst en ingrediens';
        }
        return null;

      case AssistedImportStep.selectInstructions:
        if (_selectedInstructionIndices.isEmpty) {
          return 'Välj minst en instruktion';
        }
        return null;

      case AssistedImportStep.reviewEdit:
        if (_title.isEmpty) {
          return 'Ange ett receptnamn';
        }
        if (_editedIngredients.isEmpty) {
          return 'Lägg till minst en ingrediens';
        }
        if (_editedInstructions.isEmpty) {
          return 'Lägg till minst en instruktion';
        }
        return null;
    }
  }

  /// Check if recipe is valid for saving.
  bool get isValidForSave {
    return _title.isNotEmpty &&
        _editedIngredients.isNotEmpty &&
        _editedInstructions.isNotEmpty;
  }
}
