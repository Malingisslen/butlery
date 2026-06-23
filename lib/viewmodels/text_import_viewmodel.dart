/// Text import ViewModel for converting text-based recipe content to structured Recipe objects.
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
/// // Recipe editing during import
/// textImportViewModel.updateRecipeTitle('Fluffiga Pannkakor');
/// textImportViewModel.updateRecipeMealType('Frukost');
/// textImportViewModel.updateRecipePortions(4);
/// textImportViewModel.addIngredientToRecipe('1 msk socker');
/// textImportViewModel.addInstructionToRecipe('3. Servera med sylt och grädde');
/// // Complete import workflow
/// final importSuccess = await textImportViewModel.importAndSave();
/// if (importSuccess) {
///   // Recipe successfully imported and saved
/// } else {
///   // Handle error: textImportViewModel.error
/// }
/// // Text analysis and suggestions
/// final suggestions = textImportViewModel.getInputSuggestions();
/// for (final suggestion in suggestions) {
///   // Display parsing suggestions to user
/// }
/// // Text and source management
/// textImportViewModel.updateTextAndSource(
///   'Recipe content from social media...',
///   sourceUrl: 'https://instagram.com/recipe-post',
/// );
/// // Input validation and quality assessment
/// if (textImportViewModel.hasValidInput) {
///   // Text is ready for parsing
/// } else {
///   // Show input requirements
/// }
/// ```

// lib/viewmodels/text_import_viewmodel.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive text import ViewModel providing advanced text-to-recipe conversion through ImportManager coordination.
/// Specializes in text-based recipe importing from various sources including social media, OCR, manual input, and copied content.
/// Extends ImportBaseViewModel with TextImportMixin to provide complete text import functionality with recipe editing,
/// validation, and parsing workflow management while maintaining clean MVVM architecture separation.
/// **Core Responsibilities:**
/// - Advanced text-to-recipe parsing with validation and error handling
/// - Complete recipe editing functionality during import process
/// - Text input validation ensuring parsing viability and content quality
/// - Import workflow management from text input to saved recipe
/// - Swedish localized error messages and user feedback coordination
class TextImportViewModel extends ImportBaseViewModel with TextImportMixin {
  /// Initializes text import ViewModel with comprehensive ImportManager integration and text import preparation.
  /// [importManager] ImportManager instance for text import strategy coordination and recipe parsing
  /// Establishes text import infrastructure with ImportManager integration, enabling comprehensive
  /// text-to-recipe functionality with unified state management, validation, and error handling.
  /// **Initialization Process:**
  /// - ImportManager integration for text import strategy execution
  /// - TextImportMixin setup for specialized text import functionality
  /// - Base state preparation for text import workflow management
  /// - Text validation system preparation with Swedish localization
  TextImportViewModel({required super.importManager});

  /// BUT-1040: recipes parsed from the current input. A single-recipe paste
  /// holds exactly one entry (and `parsedRecipe` mirrors it, so every existing
  /// single-recipe getter/consumer is unchanged); a cookbook-style paste with
  /// explicit separators holds N. The view checks `hasMultipleParsedRecipes`
  /// to decide between the single-recipe editor and the multi-recipe picker.
  final List<Recipe> _parsedRecipes = [];

  /// Read-only view of the recipes parsed from the last [parseText] call.
  List<Recipe> get parsedRecipes => List.unmodifiable(_parsedRecipes);

  /// True when the last parse produced more than one recipe — the signal the
  /// view uses to route into the shared multi-recipe picker.
  bool get hasMultipleParsedRecipes => _parsedRecipes.length > 1;

  /// Parses current input text into recipe with comprehensive validation and error handling.
  /// Returns true if parsing succeeds and recipe is generated, false if parsing fails.
  /// Performs text-to-recipe parsing through ImportManager strategy with comprehensive
  /// validation, error handling, and Swedish localized error messages for user feedback.
  /// **Parsing Process:**
  /// - Input text validation ensuring content viability
  /// - ImportManager text parsing strategy execution
  /// - Recipe object generation with comprehensive validation
  /// - Error handling with Swedish localized user feedback
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
      setError(AppLocale.current.errorPleaseEnterText);
      return false;
    }

    _parsedRecipes.clear();

    // BUT-960 + BUT-1040: drive isLoading/isParsing manually for the whole
    // Cloud Function round-trip — the social-media view binds its spinner and
    // its double-tap guard to `isParsing` (== isLoading), so the parse MUST
    // flip it true the way the old parseTextToRecipe/executeAsync path did.
    // A bare executeAsyncVoid would also work for the loading state, but it
    // collapses every thrown message to a generic error, losing the distinct
    // 60s-timeout copy this finding requires — so we manage state by hand and
    // map errors precisely.
    clearError();
    setLoading(true);
    try {
      // BUT-1040: route through autoParseMulti so a cookbook-style paste with
      // explicit recipe separators yields N recipes (surfaced via the shared
      // multi-recipe picker). MultiRecipeSplitter collapses a single-recipe
      // paste to one block, so the single-recipe path is behaviourally
      // unchanged — parsedRecipe still drives every existing consumer.
      //
      // BUT-960: parse is a Cloud Function round-trip; a 60s client timeout
      // ensures a server-side hang surfaces errorImportTimeout instead of an
      // endless spinner (mirrors parseTextToRecipe).
      final result = await importManager
          .autoParseMulti(inputText.trim())
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () =>
                throw Exception(AppLocale.current.errorImportTimeout),
          );
      final parsed = result.successfulRecipes;

      if (parsed.isEmpty) {
        setError(AppLocale.current.errorImportFailed);
        return false;
      }

      // Preserve the prior source-URL attribution: the old single-recipe path
      // applied `sourceUrl` to the parsed recipe, so carry it across every
      // recipe in the batch here too.
      final url = sourceUrl;
      final recipes = url == null
          ? parsed
          : parsed.map((r) => r.copyWith(sourceUrl: url)).toList();

      _parsedRecipes.addAll(recipes);

      // Single recipe → preserve the exact prior behaviour: setParsedRecipe
      // drives the single-recipe editor handoff and allergen banner unchanged.
      // Multiple → still seed parsedRecipe with the first so single-recipe
      // getters/consumers stay non-null, but the view routes to the picker.
      setParsedRecipe(recipes.first);
      return true;
    } catch (e) {
      // The timeout throws its own localized copy; everything else collapses to
      // the standard import-failed banner.
      final message = e.toString();
      setError(
        message.contains(AppLocale.current.errorImportTimeout)
            ? AppLocale.current.errorImportTimeout
            : AppLocale.current.errorImportFailed,
      );
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Completes comprehensive import workflow with text parsing, validation, and recipe saving.
  /// Returns true if complete import process succeeds, false if any step fails.
  /// Performs complete text import workflow including text validation, parsing,
  /// recipe validation, and saving with comprehensive error handling and state management.
  /// **Complete Import Process:**
  /// 1. Text input validation and parsing viability checks
  /// 2. Text-to-recipe parsing through ImportManager
  /// 3. Recipe data validation ensuring completeness
  /// 4. Recipe saving to collection with error handling
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

  /// BUT-1040: save the recipes the user ticked in the multi-recipe picker.
  /// Mirrors PhotoImportViewModel.saveSelectedRecipes — one import-layer save
  /// per recipe, surfacing the first failure as an error.
  Future<bool> saveSelectedRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) {
      setError(AppLocale.current.errorNoRecipeToSave);
      return false;
    }
    return executeAsyncVoid(() async {
      for (final recipe in recipes) {
        final result = await importManager.saveImportedRecipe(recipe);
        if (!result.isSuccess) {
          throw Exception(result.errorMessage ?? 'Failed to save recipe');
        }
      }
    });
  }

  /// Updates both input text and source URL with comprehensive state coordination and UI notification.
  /// [text] Text content for recipe parsing and import operations
  /// [sourceUrl] Optional source URL for recipe attribution and reference tracking
  /// Performs combined text and source URL update with immediate state coordination
  /// and UI notification for responsive text import functionality and source attribution.
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

  /// Updates recipe title with immediate state coordination and UI notification.
  /// [title] New recipe title for metadata update
  /// Performs recipe title update with immediate state coordination enabling
  /// real-time recipe editing during import process.
  void updateRecipeTitle(String title) {
    updateParsedRecipe(title: title);
  }

  /// Updates recipe description with comprehensive content management and state coordination.
  /// [description] New recipe description for enhanced recipe information
  /// Performs recipe description update with immediate state coordination enabling
  /// comprehensive recipe editing during import process.
  void updateRecipeDescription(String description) {
    updateParsedRecipe(description: description);
  }

  /// Updates recipe meal type with category management and state coordination.
  /// [mealType] New meal type for recipe categorization (Frukost, Lunch, Middag, etc.)
  /// Performs recipe meal type update with immediate state coordination enabling
  /// proper recipe categorization during import process.
  void updateRecipeMealType(String mealType) {
    updateParsedRecipe(mealType: mealType);
  }

  /// Updates recipe portion count with serving size management and validation.
  /// [portions] New portion count for serving size management
  /// Performs recipe portion update with immediate state coordination enabling
  /// proper serving size management during import process.
  void updateRecipePortions(int? portions) {
    updateParsedRecipe(portions: portions);
  }

  /// Updates recipe cooking time with time management and state coordination.
  /// [timeMinutes] New cooking time in minutes for time management
  /// Performs recipe time update with immediate state coordination enabling
  /// comprehensive time management during import process.
  void updateRecipeTime(int? timeMinutes) {
    updateParsedRecipe(timeMinutes: timeMinutes);
  }

  /// Adds ingredient to parsed recipe with comprehensive validation and list management.
  /// [ingredient] Ingredient text to add to recipe ingredients list
  /// Performs ingredient addition with validation checks, list management,
  /// and immediate state coordination for real-time recipe editing functionality.
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
  /// [index] Index of ingredient to remove from ingredients list
  /// Performs ingredient removal with bounds validation, list management,
  /// and immediate state coordination for safe recipe editing functionality.
  void removeIngredientFromRecipe(int index) {
    if (parsedRecipe == null ||
        index < 0 ||
        index >= parsedRecipe!.ingredients.length) {
      return;
    }

    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients.removeAt(index);
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Updates specific ingredient in parsed recipe with comprehensive validation and list management.
  /// [index] Index of ingredient to update in ingredients list
  /// [ingredient] New ingredient text for replacement
  /// Performs ingredient update with bounds validation, content trimming,
  /// and immediate state coordination for precise recipe editing functionality.
  void updateIngredientInRecipe(int index, String ingredient) {
    if (parsedRecipe == null ||
        index < 0 ||
        index >= parsedRecipe!.ingredients.length) {
      return;
    }

    final currentIngredients = List<String>.from(parsedRecipe!.ingredients);
    currentIngredients[index] = ingredient.trim();
    updateParsedRecipe(ingredients: currentIngredients);
  }

  /// Adds cooking instruction to parsed recipe with comprehensive validation and sequential management.
  /// [instruction] Instruction text to add to recipe cooking instructions
  /// Performs instruction addition with validation checks, sequential ordering,
  /// and immediate state coordination for comprehensive cooking instruction management.
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
  /// [index] Index of instruction to remove from cooking instructions list
  /// Performs instruction removal with bounds validation, sequential ordering,
  /// and immediate state coordination for safe cooking instruction management.
  void removeInstructionFromRecipe(int index) {
    if (parsedRecipe == null ||
        index < 0 ||
        index >= parsedRecipe!.instructions.length) {
      return;
    }

    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions.removeAt(index);
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Updates specific cooking instruction in parsed recipe with comprehensive validation and sequential management.
  /// [index] Index of instruction to update in cooking instructions list
  /// [instruction] New instruction text for replacement
  /// Performs instruction update with bounds validation, content trimming,
  /// and immediate state coordination for precise cooking instruction management.
  void updateInstructionInRecipe(int index, String instruction) {
    if (parsedRecipe == null ||
        index < 0 ||
        index >= parsedRecipe!.instructions.length) {
      return;
    }

    final currentInstructions = List<String>.from(parsedRecipe!.instructions);
    currentInstructions[index] = instruction.trim();
    updateParsedRecipe(instructions: currentInstructions);
  }

  /// Adds tag to parsed recipe with comprehensive duplication prevention and tag management.
  /// [tag] Tag text to add to recipe tags for categorization and discovery
  /// Performs tag addition with validation checks, duplication prevention,
  /// and immediate state coordination for comprehensive recipe tagging functionality.
  /// **Usage Example:**
  /// ```dart
  /// textImportViewModel.addTagToRecipe('vegetarisk');
  /// textImportViewModel.addTagToRecipe('snabbt');
  /// ```
  void addTagToRecipe(String tag) {
    if (parsedRecipe == null || tag.trim().isEmpty) return;

    final currentTags = List<String>.from(parsedRecipe!.personalTagIds ?? []);
    if (!currentTags.contains(tag.trim())) {
      currentTags.add(tag.trim());
      updateParsedRecipe(tags: currentTags);
    }
  }

  /// Removes tag from parsed recipe with comprehensive tag management and state coordination.
  /// [tag] Tag text to remove from recipe tags
  /// Performs tag removal with validation checks, list management,
  /// and immediate state coordination for flexible recipe tagging functionality.
  void removeTagFromRecipe(String tag) {
    if (parsedRecipe == null) return;

    final currentTags = List<String>.from(parsedRecipe!.personalTagIds ?? []);
    currentTags.remove(tag);
    updateParsedRecipe(tags: currentTags);
  }

  /// Validates current input text with comprehensive content assessment and Swedish error messaging.
  /// Returns true if text is valid for recipe parsing, false if validation fails.
  /// Performs comprehensive text validation including content length, parsing viability,
  /// and recipe content assessment with Swedish localized error messages for user feedback.
  /// **Validation Criteria:**
  /// - Text content presence and availability
  /// - Minimum text length for recipe content viability
  /// - Content quality assessment for parsing success
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
      setError(AppLocale.current.errorPleaseEnterTextToImport);
      return false;
    }

    if (inputText.trim().length < 10) {
      setError(AppLocale.current.errorTextTooShort);
      return false;
    }

    clearError();
    return true;
  }

  /// Generates intelligent parsing suggestions with comprehensive text analysis and Swedish localization.
  /// Returns list of suggestions for improving text parsing success and recipe completeness.
  /// Performs comprehensive text analysis including content assessment, structure evaluation,
  /// and parsing optimization suggestions with Swedish localized recommendations.
  /// **Text Analysis Features:**
  /// - Content structure assessment for parsing optimization
  /// - Missing content identification with specific recommendations
  /// - Parsing success prediction with improvement suggestions
  /// - Swedish localized suggestions for optimal user experience
  /// **Usage Example:**
  /// ```dart
  /// final suggestions = textImportViewModel.getInputSuggestions();
  /// for (final suggestion in suggestions) {
  ///   // Display suggestion to user for parsing optimization
  /// }
  /// ```
  List<String> getInputSuggestions() {
    if (!hasValidInput) {
      return [AppLocale.current.hintPasteOrTypeRecipe];
    }

    final text = inputText.toLowerCase();
    final suggestions = <String>[];

    if (!text.contains('ingrediens') && !text.contains('ingredient')) {
      suggestions.add(AppLocale.current.textImportSuggestionIngredients);
    }

    if (!text.contains('instruktion') &&
        !text.contains('steg') &&
        !text.contains('gör så här')) {
      suggestions.add(AppLocale.current.textImportSuggestionInstructions);
    }

    if (!text.contains('minut') &&
        !text.contains('timme') &&
        !text.contains('tid')) {
      suggestions.add(AppLocale.current.textImportSuggestionTime);
    }

    if (!text.contains('portion') && !text.contains('servering')) {
      suggestions.add(AppLocale.current.textImportSuggestionPortions);
    }

    if (suggestions.isEmpty) {
      suggestions.add(AppLocale.current.textImportSuggestionLooksGood);
    }

    return suggestions;
  }

  /// Provides comprehensive debugging state information for development and troubleshooting.
  /// Returns map containing debug information including text import state, parsing suggestions,
  /// input validation status, and inherited debug state from ImportBaseViewModel for comprehensive
  /// development support and troubleshooting capabilities.
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
