/// ViewModel for user-assisted recipe import.
///
/// Manages state for the 3-step wizard:
/// 1. Select ingredient lines
/// 2. Select instruction lines
/// 3. Review and edit recipe details
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
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
class AssistedImportViewModel extends BaseViewModel {
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

  /// Pre-detected instruction line indices (scored, garbage-filtered).
  late final Set<int> likelyInstructionIndices;

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
    lines = extractedText.split('\n').map((line) => line.trim()).toList();

    // Use provided pre-detected lines or detect automatically
    if (preDetectedIngredientLines != null) {
      likelyIngredientIndices = preDetectedIngredientLines.toSet();
    } else {
      likelyIngredientIndices = IngredientLineDetector.detectFromLines(
        lines,
      ).toSet();
    }

    likelyInstructionIndices = _detectLikelyInstructions();

    // Set initial title
    _title = suggestedTitle.orEmpty();
  }

  /// Whether the user has made any selections that would be lost on cancel.
  bool get hasSelections =>
      _selectedIngredientIndices.isNotEmpty ||
      _selectedInstructionIndices.isNotEmpty;

  Set<int> _detectLikelyInstructions() {
    final result = <int>{};
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      if (likelyIngredientIndices.contains(i)) continue;
      if (RecipeSectionDetector.isGarbage(line)) continue;
      if (RecipeSectionDetector.instructionScore(line) >= 2) {
        result.add(i);
      }
    }
    return result;
  }

  bool get canProceed {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        return _selectedIngredientIndices.isNotEmpty;
      case AssistedImportStep.selectInstructions:
        return _selectedInstructionIndices.isNotEmpty;
      case AssistedImportStep.reviewEdit:
        return isValidForSave;
    }
  }

  bool get canGoBack => _currentStep != AssistedImportStep.selectIngredients;

  void nextStep() {
    if (!canProceed) return;

    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        _currentStep = AssistedImportStep.selectInstructions;
        break;
      case AssistedImportStep.selectInstructions:
        _buildEditableLists();
        _currentStep = AssistedImportStep.reviewEdit;
        break;
      case AssistedImportStep.reviewEdit:
        break;
    }
    notifyListeners();
  }

  void previousStep() {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
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

  int get totalSteps => 3;

  void setIngredientSelection(Set<int> indices) {
    _selectedIngredientIndices = indices;
    notifyListeners();
  }

  void setInstructionSelection(Set<int> indices) {
    _selectedInstructionIndices = indices;
    notifyListeners();
  }

  void selectAllHighlightedIngredients() {
    _selectedIngredientIndices = Set.from(likelyIngredientIndices);
    notifyListeners();
  }

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

  void updateIngredient(int index, String value) {
    if (index >= 0 && index < _editedIngredients.length) {
      _editedIngredients[index] = value;
      notifyListeners();
    }
  }

  void addIngredient(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      _editedIngredients.add(trimmed);
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
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      _editedInstructions.add(trimmed);
      notifyListeners();
    }
  }

  void removeInstruction(int index) {
    if (index >= 0 && index < _editedInstructions.length) {
      _editedInstructions.removeAt(index);
      notifyListeners();
    }
  }

  void _buildEditableLists() {
    final sortedIngredientIndices = _selectedIngredientIndices.toList()..sort();
    _editedIngredients = sortedIngredientIndices
        .map((i) => lines[i])
        .where((line) => line.isNotEmpty)
        .toList();

    final sortedInstructionIndices = _selectedInstructionIndices.toList()
      ..sort();
    _editedInstructions = sortedInstructionIndices
        .map((i) => lines[i])
        .where((line) => line.isNotEmpty)
        .map(_cleanInstructionLine)
        .toList();
  }

  String _cleanInstructionLine(String line) {
    return line
        .replaceFirst(
          RegExp(r'^(steg|step)?\s*\d+[\.\):\s]+', caseSensitive: false),
          '',
        )
        .trim();
  }

  Recipe buildRecipe() {
    final ingredients = _editedIngredients
        .map((i) => i.trim())
        .where((i) => i.isNotEmpty)
        .toList();

    final instructions = _editedInstructions
        .map((i) => i.trim())
        .where((i) => i.isNotEmpty)
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

  String? validateCurrentStep() {
    switch (_currentStep) {
      case AssistedImportStep.selectIngredients:
        if (_selectedIngredientIndices.isEmpty) {
          return AppLocale.current.validationSelectIngredient;
        }
        return null;

      case AssistedImportStep.selectInstructions:
        if (_selectedInstructionIndices.isEmpty) {
          return AppLocale.current.assistedImportSelectInstructionsError;
        }
        return null;

      case AssistedImportStep.reviewEdit:
        if (_title.isEmpty) {
          return AppLocale.current.assistedImportEnterRecipeName;
        }
        if (_editedIngredients.isEmpty) {
          return AppLocale.current.assistedImportAddIngredientError;
        }
        if (_editedInstructions.isEmpty) {
          return AppLocale.current.assistedImportAddInstructionError;
        }
        return null;
    }
  }

  bool get isValidForSave {
    return _title.isNotEmpty &&
        _editedIngredients.isNotEmpty &&
        _editedInstructions.isNotEmpty;
  }
}
