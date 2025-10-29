/// Text import ViewModel for converting text-based recipe content to structured Recipe objects.
///
/// **Features:** Text parsing, recipe editing, validation, Swedish localization. Delegates to ImportManager.
/// ```dart
/// final vm = TextImportViewModel(importManager: ServiceLocator.get<ImportManager>());
/// vm.updateInputText('Pannkakor\nIngredienser:\n- 2 ägg...');
/// if (vm.canParse) await vm.parseText();
/// if (textImportViewModel.validateInput()) {
///   final parseSuccess = await textImportViewModel.parseText();
///   if (parseSuccess && textImportViewModel.hasParsedRecipe) {
///     final recipe = textImportViewModel.parsedRecipe;
///   }
/// }
/// 
/// // Recipe editing during import
/// textImportViewModel.updateRecipeTitle('Fluffiga Pannkakor');
/// textImportViewModel.updateRecipeMealType('Frukost');
/// textImportViewModel.updateRecipePortions(4);
/// textImportViewModel.addIngredientToRecipe('1 msk socker');
/// textImportViewModel.addInstructionToRecipe('3. Servera med sylt och grädde');
/// 
/// // Complete import workflow
/// final importSuccess = await textImportViewModel.importAndSave();
/// if (importSuccess) {
///   // Recipe successfully imported and saved
/// } else {
///   // Handle error: textImportViewModel.error
/// }
/// 
/// // Text analysis and suggestions
/// final suggestions = textImportViewModel.getInputSuggestions();
/// for (final suggestion in suggestions) {
///   // Display parsing suggestions to user
/// }
/// 
/// // Text and source management
/// textImportViewModel.updateTextAndSource(
///   'Recipe content from social media...',
///   sourceUrl: 'https://instagram.com/recipe-post',
/// );
/// 
/// // Input validation and quality assessment
/// if (textImportViewModel.hasValidInput) {
///   // Text is ready for parsing
/// } else {
///   // Show input requirements
/// }
/// ```

// lib/viewmodels/text_import_viewmodel.dart

import 'package:butlery/viewmodels/import_base_viewmodel.dart';

/// Comprehensive text import ViewModel providing advanced text-to-recipe conversion through ImportManager coordination.
///
/// Specializes in text-based recipe importing from various sources including social media, OCR, manual input, and copied content.
/// Extends ImportBaseViewModel with TextImportMixin to provide complete text import functionality with recipe editing,
/// validation, and parsing workflow management while maintaining clean MVVM architecture separation.
///
/// **Core Responsibilities:**
/// - Advanced text-to-recipe parsing with validation and error handling
/// - Complete recipe editing functionality during import process
/// - Text input validation ensuring parsing viability and content quality
/// - Import workflow management from text input to saved recipe
/// - Swedish localized error messages and user feedback coordination
class TextImportViewModel extends ImportBaseViewModel with TextImportMixin {

  /// Initializes text import ViewModel with comprehensive ImportManager integration and text import preparation.
  /// 
  /// [importManager] ImportManager instance for text import strategy coordination and recipe parsing
  /// 
  /// Establishes text import infrastructure with ImportManager integration, enabling comprehensive
  /// text-to-recipe functionality with unified state management, validation, and error handling.
  /// 
  /// **Initialization Process:**
  /// - ImportManager integration for text import strategy execution
  /// - TextImportMixin setup for specialized text import functionality
  /// - Base state preparation for text import workflow management
  /// - Text validation system preparation with Swedish localization
  TextImportViewModel({required super.importManager});

  // ===== TEXT PARSING OPERATIONS =====

  /// Parses current input text into recipe with comprehensive validation and error handling.
  /// 
  /// Returns true if parsing succeeds and recipe is generated, false if parsing fails.
  /// Performs text-to-recipe parsing through ImportManager strategy with comprehensive
  /// validation, error handling, and Swedish localized error messages for user feedback.
  /// 
  /// **Parsing Process:**
  /// - Input text validation ensuring content viability
  /// - ImportManager text parsing strategy execution
  /// - Recipe object generation with comprehensive validation
  /// - Error handling with Swedish localized user feedback
  /// 
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.updateInputText('Recipe content...');
  /// final parseSuccess = await textImportViewModel.parseText();
  /// if (parseSuccess) {
  ///   final recipe = textImportViewModel.parsedRecipe;
  /// } else {
  ///   // Handle error: textImportViewModel.error
  /// }
  /// ```
  Future<bool> parseText() async {
    if (!hasValidInput) {
      setError('Vänligen ange text att tolka');
      return false;
    }

    try {
      await performImport();
      return hasParsedRecipe && !hasError;
    } catch (e) {
      setError('Kunde inte tolka text: $e');
      return false;
    }
  }

  /// Completes comprehensive import workflow with text parsing, validation, and recipe saving.
  /// 
  /// Returns true if complete import process succeeds, false if any step fails.
  /// Performs complete text import workflow including text validation, parsing,
  /// recipe validation, and saving with comprehensive error handling and state management.
  /// 
  /// **Complete Import Process:**
  /// 1. Text input validation and parsing viability checks
  /// 2. Text-to-recipe parsing through ImportManager
  /// 3. Recipe data validation ensuring completeness
  /// 4. Recipe saving to collection with error handling
  /// 
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.updateInputText('Recipe content...');
  /// final importSuccess = await textImportViewModel.importAndSave();
  /// if (importSuccess) {
  ///   // Recipe successfully imported and saved
  /// } else {
  ///   // Handle error: textImportViewModel.error
  /// }
  /// ```
  Future<bool> importAndSave() async {
    return await completeImport();
  }

  /// Updates both input text and source URL with comprehensive state coordination and UI notification.
  /// 
  /// [text] Text content for recipe parsing and import operations
  /// [sourceUrl] Optional source URL for recipe attribution and reference tracking
  /// 
  /// Performs combined text and source URL update with immediate state coordination
  /// and UI notification for responsive text import functionality and source attribution.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.updateTextAndSource(
  ///   'Recipe content from social media...',
  ///   sourceUrl: 'https://instagram.com/recipe-post',
  /// );
  /// ```
  void updateTextAndSource(String text, {String? sourceUrl}) {
    updateInputText(text);
    if (sourceUrl != null) {
      setSourceUrl(sourceUrl);
    }
  }

  // ===== RECIPE EDITING OPERATIONS =====

  /// Updates recipe title with immediate state coordination and UI notification.
  /// 
  /// [title] New recipe title for metadata update
  /// 
  /// Performs recipe title update with immediate state coordination enabling
  /// real-time recipe editing during import process.
  void updateRecipeTitle(String title) {
    updateParsedRecipe(title: title);
  }

  /// Updates recipe description with comprehensive content management and state coordination.
  /// 
  /// [description] New recipe description for enhanced recipe information
  /// 
  /// Performs recipe description update with immediate state coordination enabling
  /// comprehensive recipe editing during import process.
  void updateRecipeDescription(String description) {
    updateParsedRecipe(description: description);
  }

  /// Updates recipe meal type with category management and state coordination.
  /// 
  /// [mealType] New meal type for recipe categorization (Frukost, Lunch, Middag, etc.)
  /// 
  /// Performs recipe meal type update with immediate state coordination enabling
  /// proper recipe categorization during import process.
  void updateRecipeMealType(String mealType) {
    updateParsedRecipe(mealType: mealType);
  }

  /// Updates recipe portion count with serving size management and validation.
  /// 
  /// [portions] New portion count for serving size management
  /// 
  /// Performs recipe portion update with immediate state coordination enabling
  /// proper serving size management during import process.
  void updateRecipePortions(int? portions) {
    updateParsedRecipe(portions: portions);
  }

  /// Updates recipe cooking time with time management and state coordination.
  /// 
  /// [timeMinutes] New cooking time in minutes for time management
  /// 
  /// Performs recipe time update with immediate state coordination enabling
  /// comprehensive time management during import process.
  void updateRecipeTime(int? timeMinutes) {
    updateParsedRecipe(timeMinutes: timeMinutes);
  }

  /// Adds ingredient to parsed recipe with comprehensive validation and list management.
  /// 
  /// [ingredient] Ingredient text to add to recipe ingredients list
  /// 
  /// Performs ingredient addition with validation checks, list management,
  /// and immediate state coordination for real-time recipe editing functionality.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.addIngredientToRecipe('1 msk socker');
  /// textImportViewModel.addIngredientToRecipe('2 dl mjölk');
  /// ```
  void addIngredientToRecipe(String ingredient) {
    if (parsedRecipe == null || ingredient.trim().isEmpty) return;
    
    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients.add(ingredient.trim());
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Removes ingredient from parsed recipe with comprehensive bounds checking and list management.
  /// 
  /// [index] Index of ingredient to remove from ingredients list
  /// 
  /// Performs ingredient removal with bounds validation, list management,
  /// and immediate state coordination for safe recipe editing functionality.
  void removeIngredientFromRecipe(int index) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.ingredients.length) return;
    
    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients.removeAt(index);
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Updates specific ingredient in parsed recipe with comprehensive validation and list management.
  /// 
  /// [index] Index of ingredient to update in ingredients list
  /// [ingredient] New ingredient text for replacement
  /// 
  /// Performs ingredient update with bounds validation, content trimming,
  /// and immediate state coordination for precise recipe editing functionality.
  void updateIngredientInRecipe(int index, String ingredient) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.ingredients.length) return;
    
    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients[index] = ingredient.trim();
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Adds cooking instruction to parsed recipe with comprehensive validation and sequential management.
  /// 
  /// [instruction] Instruction text to add to recipe cooking instructions
  /// 
  /// Performs instruction addition with validation checks, sequential ordering,
  /// and immediate state coordination for comprehensive cooking instruction management.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.addInstructionToRecipe('1. Vispa ihop alla ingredienser');
  /// textImportViewModel.addInstructionToRecipe('2. Stek i smör i pannan');
  /// ```
  void addInstructionToRecipe(String instruction) {
    if (parsedRecipe == null || instruction.trim().isEmpty) return;
    
    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions.add(instruction.trim());
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Removes cooking instruction from parsed recipe with comprehensive bounds checking and sequential management.
  /// 
  /// [index] Index of instruction to remove from cooking instructions list
  /// 
  /// Performs instruction removal with bounds validation, sequential ordering,
  /// and immediate state coordination for safe cooking instruction management.
  void removeInstructionFromRecipe(int index) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.instructions.length) return;
    
    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions.removeAt(index);
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Updates specific cooking instruction in parsed recipe with comprehensive validation and sequential management.
  /// 
  /// [index] Index of instruction to update in cooking instructions list
  /// [instruction] New instruction text for replacement
  /// 
  /// Performs instruction update with bounds validation, content trimming,
  /// and immediate state coordination for precise cooking instruction management.
  void updateInstructionInRecipe(int index, String instruction) {
    if (parsedRecipe == null || index < 0 || index >= parsedRecipe!.instructions.length) return;
    
    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions[index] = instruction.trim();
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Adds tag to parsed recipe with comprehensive duplication prevention and tag management.
  /// 
  /// [tag] Tag text to add to recipe tags for categorization and discovery
  /// 
  /// Performs tag addition with validation checks, duplication prevention,
  /// and immediate state coordination for comprehensive recipe tagging functionality.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.addTagToRecipe('vegetarisk');
  /// textImportViewModel.addTagToRecipe('snabbt');
  /// ```
  void addTagToRecipe(String tag) {
    if (parsedRecipe == null || tag.trim().isEmpty) return;
    
    final currentTags = List<String>.from(parsedRecipe!.tags ?? []);
    if (!currentTags.contains(tag.trim())) {
      currentTags.add(tag.trim());
      updateParsedRecipe(tags: currentTags);
    }
  }

  /// Removes tag from parsed recipe with comprehensive tag management and state coordination.
  /// 
  /// [tag] Tag text to remove from recipe tags
  /// 
  /// Performs tag removal with validation checks, list management,
  /// and immediate state coordination for flexible recipe tagging functionality.
  void removeTagFromRecipe(String tag) {
    if (parsedRecipe == null) return;
    
    final currentTags = List<String>.from(parsedRecipe!.tags ?? []);
    currentTags.remove(tag);
    updateParsedRecipe(tags: currentTags);
  }

  // ===== TEXT VALIDATION OPERATIONS =====

  /// Validates current input text with comprehensive content assessment and Swedish error messaging.
  /// 
  /// Returns true if text is valid for recipe parsing, false if validation fails.
  /// Performs comprehensive text validation including content length, parsing viability,
  /// and recipe content assessment with Swedish localized error messages for user feedback.
  /// 
  /// **Validation Criteria:**
  /// - Text content presence and availability
  /// - Minimum text length for recipe content viability
  /// - Content quality assessment for parsing success
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (textImportViewModel.validateInput()) {
  ///   // Text is ready for parsing
  /// } else {
  ///   // Handle validation error: textImportViewModel.error
  /// }
  /// ```
  bool validateInput() {
    if (!hasValidInput) {
      setError('Vänligen ange text att importera');
      return false;
    }

    if (inputText.trim().length < 10) {
      setError('Texten är för kort för att innehålla ett recept');
      return false;
    }

    clearError();
    return true;
  }

  /// Generates intelligent parsing suggestions with comprehensive text analysis and Swedish localization.
  /// 
  /// Returns list of suggestions for improving text parsing success and recipe completeness.
  /// Performs comprehensive text analysis including content assessment, structure evaluation,
  /// and parsing optimization suggestions with Swedish localized recommendations.
  /// 
  /// **Text Analysis Features:**
  /// - Content structure assessment for parsing optimization
  /// - Missing content identification with specific recommendations
  /// - Parsing success prediction with improvement suggestions
  /// - Swedish localized suggestions for optimal user experience
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final suggestions = textImportViewModel.getInputSuggestions();
  /// for (final suggestion in suggestions) {
  ///   // Display suggestion to user for parsing optimization
  /// }
  /// ```
  List<String> getInputSuggestions() {
    if (!hasValidInput) {
      return ['Klistra in eller skriv recepttext för att komma igång'];
    }

    final text = inputText.toLowerCase();
    final suggestions = <String>[];

    if (!text.contains('ingrediens') && !text.contains('ingredient')) {
      suggestions.add('Inkludera ingredienslista för bättre tolkning');
    }

    if (!text.contains('instruktion') && !text.contains('steg') && !text.contains('gör så här')) {
      suggestions.add('Inkludera tillagningsinstruktioner eller steg');
    }

    if (!text.contains('minut') && !text.contains('timme') && !text.contains('tid')) {
      suggestions.add('Inkludera tillagningstid om tillgänglig');
    }

    if (!text.contains('portion') && !text.contains('servering')) {
      suggestions.add('Inkludera antal portioner om känt');
    }

    if (suggestions.isEmpty) {
      suggestions.add('Texten ser bra ut för recepttolkning');
    }

    return suggestions;
  }

  // ===== DEBUGGING SUPPORT =====

  /// Provides comprehensive debugging state information for development and troubleshooting.
  /// 
  /// Returns map containing debug information including text import state, parsing suggestions,
  /// input validation status, and inherited debug state from ImportBaseViewModel for comprehensive
  /// development support and troubleshooting capabilities.
  /// 
  /// **Debug Information Includes:**
  /// - Input validation status and parsing suggestions
  /// - Text import specific state and validation results
  /// - Inherited ImportBaseViewModel debug state information
  /// - Text analysis results for parsing optimization
  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'inputSuggestions': getInputSuggestions(),
    'inputValidationResult': hasValidInput,
    'textLength': inputText.length,
    'hasParsingErrors': hasError,
  };
}