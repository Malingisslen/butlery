/// ViewModel for user-assisted recipe import.
///
/// Manages state for the 3-step wizard:
/// 1. Select ingredient lines
/// 2. Select instruction lines
/// 3. Review and edit recipe details
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
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

  /// The origin strategy that fed this assisted-import wizard (URL, text paste,
  /// voice dictation, photo/OCR …). Drives the correction-snapshot source tag
  /// in [buildRecipe]. Defaults to [ImportSource.url] because the smart-import
  /// URL pipeline is the historical Tier-7 fallback into this wizard.
  final ImportSource source;

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

  /// The selection sets the current editable lists were last built from.
  /// Null until the first build. Used to skip a rebuild (which would discard
  /// the user's review-step edits) when they step Back to a selection screen
  /// and Forward again without actually changing what lines are selected.
  Set<int>? _builtFromIngredientIndices;
  Set<int>? _builtFromInstructionIndices;

  // Loading and error states reserved for future async operations

  AssistedImportViewModel({
    required this.extractedText,
    this.suggestedTitle,
    this.thumbnailUrl,
    this.sourceUrl,
    this.source = ImportSource.url,
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
        // Only (re)derive the editable lists from the raw selected lines when
        // the selection actually changed since the last build. Rebuilding
        // unconditionally would silently revert every correction the user made
        // on the review step after stepping Back and Forward again — the exact
        // manual fixes this wizard exists to capture.
        if (_selectionChangedSinceLastBuild()) {
          _buildEditableLists();
        }
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

  /// True when either selection set differs from the one the current editable
  /// lists were built from (or nothing has been built yet).
  bool _selectionChangedSinceLastBuild() {
    return !_setEquals(
          _builtFromIngredientIndices,
          _selectedIngredientIndices,
        ) ||
        !_setEquals(
          _builtFromInstructionIndices,
          _selectedInstructionIndices,
        );
  }

  bool _setEquals(Set<int>? a, Set<int> b) {
    if (a == null) return false;
    return a.length == b.length && a.containsAll(b);
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

    // Snapshot the selections these lists were derived from, so a Back→Forward
    // round-trip with unchanged selections skips the rebuild (preserving edits).
    _builtFromIngredientIndices = Set<int>.from(_selectedIngredientIndices);
    _builtFromInstructionIndices = Set<int>.from(_selectedInstructionIndices);
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

    final recipe = Recipe.personal(
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

    // BUT-1501: feed the wizard's manual selections into the same parser
    // correction loop every other import path uses (BUT-1469). Which lines the
    // user hand-picked as the recipe is a strong correction signal; capturing a
    // snapshot here anchors the later edit diff so it becomes training data.
    // PII-SCRUBBED by construction: the snapshot is built only from the recipe
    // the user assembled (title + chosen ingredient/instruction lines), never
    // from the raw extracted page text, which can carry unrelated PII.
    // BUT-1656: tag the snapshot with the true origin strategy ([source]) rather
    // than a hardcoded url, so voice/text/photo-origin corrections aren't
    // mislabelled as URL imports in the feedback analytics. Domain attribution
    // only applies when a source URL exists (null for voice/text/photo).
    ImportCorrectionSnapshot.capture(
      recipe,
      source: source,
      domain: _domainOf(sourceUrl),
    );

    return recipe;
  }

  /// Bare registrable domain of [url] for correction attribution, or null.
  String? _domainOf(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final host = Uri.parse(url.trim()).host;
      if (host.isEmpty) return null;
      return host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
    } catch (_) {
      return null;
    }
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
