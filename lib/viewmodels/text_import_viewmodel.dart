// lib/viewmodels/text_import_viewmodel.dart

import 'import_base_viewmodel.dart';

/// ViewModel för text-baserad receptimport (sociala medier, OCR, etc)
/// Refactored to use ImportBaseViewModel with TextImportMixin for consistency
class TextImportViewModel extends ImportBaseViewModel with TextImportMixin {

  TextImportViewModel({required super.importManager});

  // ===== TEXT-SPECIFIC METHODS =====

  /// Parse the current input text into a recipe
  Future<bool> parseText() async {
    if (!hasValidInput) {
      setError('Please provide text to parse');
      return false;
    }

    try {
      await performImport();
      return hasParsedRecipe && !hasError;
    } catch (e) {
      setError('Failed to parse text: $e');
      return false;
    }
  }

  /// Complete the import process: parse text and save recipe
  Future<bool> importAndSave() async {
    return await completeImport();
  }

  /// Update both input text and source URL
  void updateTextAndSource(String text, {String? sourceUrl}) {
    updateInputText(text);
    if (sourceUrl != null) {
      setSourceUrl(sourceUrl);
    }
  }

  // ===== RECIPE EDITING =====

  /// Update title of parsed recipe
  void updateRecipeTitle(String title) {
    updateParsedRecipe(title: title);
  }

  /// Update description of parsed recipe
  void updateRecipeDescription(String description) {
    updateParsedRecipe(description: description);
  }

  /// Update meal type of parsed recipe
  void updateRecipeMealType(String mealType) {
    updateParsedRecipe(mealType: mealType);
  }

  /// Update portions of parsed recipe
  void updateRecipePortions(int? portions) {
    updateParsedRecipe(portions: portions);
  }

  /// Update cooking time of parsed recipe
  void updateRecipeTime(int? timeMinutes) {
    updateParsedRecipe(timeMinutes: timeMinutes);
  }

  /// Add ingredient to parsed recipe
  void addIngredientToRecipe(String ingredient) {
    if (parsedRecipe == null || ingredient.trim().isEmpty) return;
    
    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients.add(ingredient.trim());
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Remove ingredient from parsed recipe
  void removeIngredientFromRecipe(int index) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.ingredients.length) return;
    
    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients.removeAt(index);
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Update ingredient in parsed recipe
  void updateIngredientInRecipe(int index, String ingredient) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.ingredients.length) return;
    
    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients[index] = ingredient.trim();
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Add instruction to parsed recipe
  void addInstructionToRecipe(String instruction) {
    if (parsedRecipe == null || instruction.trim().isEmpty) return;
    
    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions.add(instruction.trim());
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Remove instruction from parsed recipe
  void removeInstructionFromRecipe(int index) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.instructions.length) return;
    
    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions.removeAt(index);
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Update instruction in parsed recipe
  void updateInstructionInRecipe(int index, String instruction) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.instructions.length) return;
    
    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions[index] = instruction.trim();
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Add tag to parsed recipe
  void addTagToRecipe(String tag) {
    if (parsedRecipe == null || tag.trim().isEmpty) return;
    
    final currentTags = List<String>.from(parsedRecipe!.tags ?? []);
    if (!currentTags.contains(tag.trim())) {
      currentTags.add(tag.trim());
      updateParsedRecipe(tags: currentTags);
    }
  }

  /// Remove tag from parsed recipe
  void removeTagFromRecipe(String tag) {
    if (parsedRecipe == null) return;
    
    final currentTags = List<String>.from(parsedRecipe!.tags ?? []);
    currentTags.remove(tag);
    updateParsedRecipe(tags: currentTags);
  }

  // ===== VALIDATION =====

  /// Validate current input text
  bool validateInput() {
    if (!hasValidInput) {
      setError('Please provide text to import');
      return false;
    }

    if (inputText.trim().length < 10) {
      setError('Text is too short to contain a recipe');
      return false;
    }

    clearError();
    return true;
  }

  /// Get suggestions for improving text parsing
  List<String> getInputSuggestions() {
    if (!hasValidInput) {
      return ['Paste or type recipe text to get started'];
    }

    final text = inputText.toLowerCase();
    final suggestions = <String>[];

    if (!text.contains('ingredient')) {
      suggestions.add('Include ingredients list for better parsing');
    }

    if (!text.contains('instruction') && !text.contains('step')) {
      suggestions.add('Include cooking instructions or steps');
    }

    if (!text.contains('minute') && !text.contains('hour') && !text.contains('time')) {
      suggestions.add('Include cooking time if available');
    }

    if (!text.contains('serve') && !text.contains('portion')) {
      suggestions.add('Include serving size if known');
    }

    if (suggestions.isEmpty) {
      suggestions.add('Text looks good for recipe parsing');
    }

    return suggestions;
  }

  // ===== DEBUGGING SUPPORT =====

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'inputSuggestions': getInputSuggestions(),
    'validInput': validateInput(),
  };
}