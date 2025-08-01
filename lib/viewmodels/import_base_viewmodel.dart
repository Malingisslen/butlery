/// Comprehensive import base ViewModel providing advanced import infrastructure for Flutter applications.
///
/// This module implements sophisticated import functionality following Single Responsibility Principle,
/// serving as the foundational base class for all import ViewModels including text imports, URL imports,
/// photo imports, and archive imports. It provides complete import infrastructure while maintaining clean
/// separation from UI rendering, data persistence, and platform-specific import implementations.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles import presentation layer foundations:
/// - **Import Infrastructure Management**: Comprehensive base functionality for all import operations with unified state management
/// - **Recipe Parsing Coordination**: Advanced recipe parsing through ImportManager with validation and error handling
/// - **Import State Management**: Complete import workflow state including parsing, validation, and saving operations
/// - **Cross-Import Type Support**: Unified interface for text, URL, photo, and archive imports with consistent behavior
/// - **Import Validation Excellence**: Comprehensive validation system ensuring recipe completeness and data integrity
///
/// **What This Module Does NOT Handle:**
/// - Platform-specific import implementations (handled by specialized import ViewModels and import strategies)
/// - UI rendering and widget creation (handled by import views and presentation components)
/// - Direct data persistence (handled by ImportManager and underlying storage services)
/// - Complex business logic implementation (handled by import services and strategy pattern implementations)
///
/// **Import Base ViewModel Features:**
/// - **Unified Import Interface**: Complete base functionality for all import types with consistent state management
/// - **Advanced Recipe Parsing**: Sophisticated text-to-recipe parsing with ImportManager integration and error handling
/// - **Import Validation System**: Comprehensive validation ensuring recipe completeness, data integrity, and user requirements
/// - **State Management Excellence**: Complete import workflow state management with loading, error, and success coordination
/// - **Mixin Architecture Support**: Advanced mixin system for specialized import functionality (text, URL, photo imports)
///
/// **Usage Examples:**
/// ```dart
/// // Create specialized import ViewModel extending ImportBaseViewModel
/// class TextImportViewModel extends ImportBaseViewModel with TextImportMixin {
///   TextImportViewModel() : super(importManager: ServiceLocator.get<ImportManager>());
/// }
/// 
/// // Initialize and use import functionality
/// final textImportViewModel = TextImportViewModel();
/// 
/// // Text import workflow
/// textImportViewModel.updateInputText('Ingredienser: 2 ägg, 200g mjöl...');
/// await textImportViewModel.performImport();
/// 
/// if (textImportViewModel.hasParsedRecipe) {
///   final recipe = textImportViewModel.parsedRecipe;
///   final saved = await textImportViewModel.saveImportedRecipe();
/// }
/// 
/// // URL import with content extraction
/// class UrlImportViewModel extends ImportBaseViewModel with UrlImportMixin {
///   // Implementation for URL content fetching
/// }
/// 
/// // Complete import workflow
/// final success = await importViewModel.completeImport();
/// if (success) {
///   // Recipe successfully imported and saved
/// } else {
///   // Handle error: importViewModel.error
/// }
/// 
/// // Recipe manipulation during import
/// importViewModel.updateParsedRecipe(
///   title: 'Updated Recipe Title',
///   mealType: 'Middag',
///   portions: 4,
/// );
/// 
/// // State monitoring and validation
/// if (importViewModel.canImport && importViewModel.validateImportData()) {
///   // Proceed with import operation
/// }
/// ```

// lib/viewmodels/import_base_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
/// Comprehensive import base ViewModel providing advanced import infrastructure through ImportManager coordination.
///
/// Serves as the foundational base class for all import ViewModels, providing unified API for import operations,
/// recipe parsing, validation, and state management while maintaining clean MVVM architecture separation
/// between import business logic and UI presentation concerns.
///
/// **Core Responsibilities:**
/// - Unified import workflow management with parsing, validation, and saving operations
/// - Advanced recipe parsing through ImportManager with comprehensive error handling
/// - Import state management including loading, error, and success coordination
/// - Recipe manipulation and validation ensuring data completeness and integrity
/// - Cross-import type support through mixin architecture for specialized functionality
abstract class ImportBaseViewModel extends BaseViewModel with AsyncOperationMixin {
  final ImportManager _importManager;

  // ===== IMPORT STATE MANAGEMENT =====
  
  /// Parsed recipe result from import operation for validation and manipulation.
  /// 
  /// Stores successfully parsed recipe data for user review, editing,
  /// and final saving to the recipe collection.
  Recipe? _parsedRecipe;
  
  /// Source URL for imported recipe for attribution and reference tracking.
  /// 
  /// Maintains source attribution for imported recipes enabling proper
  /// credit and reference management throughout the import process.
  String? _sourceUrl;

  /// Initializes import base ViewModel with comprehensive ImportManager integration and state preparation.
  /// 
  /// [importManager] ImportManager instance for import strategy coordination and recipe parsing
  /// 
  /// Establishes import infrastructure with ImportManager integration, enabling comprehensive
  /// import functionality across all import types with unified state management and error handling.
  /// 
  /// **Initialization Process:**
  /// - ImportManager integration for strategy-based importing
  /// - Base state preparation for import workflow management
  /// - Async operation mixin setup for loading and error coordination
  /// - Import validation system preparation
  ImportBaseViewModel({required ImportManager importManager})
      : _importManager = importManager;

  // ===== IMPORT STATE ACCESSORS =====

  /// Parsed recipe result from import operation for validation and display.
  /// 
  /// Provides access to successfully parsed recipe data enabling user review,
  /// editing, and final import confirmation with comprehensive recipe management.
  Recipe? get parsedRecipe => _parsedRecipe;

  /// Recipe parsing success indicator for UI conditional rendering and workflow management.
  /// 
  /// Indicates whether import operation has successfully generated a valid recipe
  /// for UI state management and import workflow progression.
  bool get hasParsedRecipe => _parsedRecipe != null;

  /// Source URL for imported recipe attribution and reference management.
  /// 
  /// Provides source URL for recipe attribution, reference tracking,
  /// and import source management throughout the import process.
  String? get sourceUrl => _sourceUrl;

  /// Import readiness indicator for workflow progression and operation validation.
  /// 
  /// Indicates whether import conditions are met for operation execution.
  /// Subclasses should override with specific import type validation logic.
  bool get canImport => true;

  /// Import operation state for UI progress indication and interaction control.
  /// 
  /// Indicates active import parsing operations for loading indicators
  /// and user interaction management during import processing.
  bool get isParsing => isLoading;

  /// Input parsing capability indicator for validation and UI enabling.
  /// 
  /// Indicates whether current input can be parsed for import operations.
  /// Subclasses should override with import type specific validation logic.
  bool get canParse => true;

  /// ImportManager instance for strategy-based importing and recipe parsing coordination.
  /// 
  /// Provides protected access to ImportManager for subclass import operations
  /// with strategy pattern implementation and comprehensive parsing functionality.
  @protected
  ImportManager get importManager => _importManager;

  // ===== IMPORT STATE MANAGEMENT OPERATIONS =====

  /// Sets parsed recipe with comprehensive state management and UI notification.
  /// 
  /// [recipe] Parsed recipe result for state management and user interaction
  /// 
  /// Updates parsed recipe state with disposal safety checks and immediate UI notification
  /// for responsive import workflow and user feedback coordination.
  /// 
  /// **Protected Method**: For use by subclasses during import operations.
  @protected
  void setParsedRecipe(Recipe? recipe) {
    if (isDisposed) return;
    
    _parsedRecipe = recipe;
    notifyListeners();
  }

  /// Sets source URL with comprehensive attribution management and UI coordination.
  /// 
  /// [url] Source URL for recipe attribution and reference tracking
  /// 
  /// Updates source URL for recipe attribution with disposal safety checks
  /// and immediate UI notification for import source management.
  void setSourceUrl(String? url) {
    if (isDisposed) return;
    
    _sourceUrl = url;
    notifyListeners();
  }

  /// Clears all import data with comprehensive state reset and memory management.
  /// 
  /// Performs complete import state cleanup including parsed recipe, source URL,
  /// and base state reset with disposal safety for proper memory management.
  /// 
  /// **Protected Method**: For use by subclasses during state cleanup operations.
  @protected
  void clearImportData() {
    if (isDisposed) return;
    
    _parsedRecipe = null;
    _sourceUrl = null;
    clearState();
  }

  // ===== ABSTRACT IMPORT INTERFACE =====

  /// Performs import operation with subclass-specific implementation and comprehensive coordination.
  /// 
  /// Abstract method that subclasses must implement for specialized import functionality.
  /// Handles the core import logic specific to each import type (text, URL, photo, archive)
  /// with comprehensive error handling and state management coordination.
  /// 
  /// **Implementation Requirements:**
  /// - Parse input data into Recipe object using appropriate parsing strategy
  /// - Set parsed recipe using setParsedRecipe() method for state management
  /// - Handle import-specific errors with comprehensive error messaging
  /// - Coordinate with ImportManager for strategy-based parsing operations
  Future<void> performImport();

  /// Gets import type identifier for analytics tracking and logging coordination.
  /// 
  /// Abstract getter that subclasses must implement to provide import type classification.
  /// Used for analytics tracking, logging coordination, and import workflow identification
  /// throughout the import process and system monitoring.
  /// 
  /// **Expected Values**: 'text', 'url', 'photo', 'archive', or other import type identifiers
  String get importType;

  // ===== CORE IMPORT OPERATIONS =====

  /// Parses text into recipe using ImportManager with comprehensive error handling and source attribution.
  /// 
  /// [text] Text content for recipe parsing and extraction
  /// [url] Optional source URL for recipe attribution and reference tracking
  /// 
  /// Returns parsed Recipe object if successful, null if parsing fails.
  /// Performs text-to-recipe parsing through ImportManager strategy pattern with comprehensive
  /// error handling, source URL attribution, and async operation coordination.
  /// 
  /// **Parsing Process:**
  /// - Text import strategy retrieval from ImportManager
  /// - Recipe parsing with comprehensive validation and error handling
  /// - Source URL attribution for imported recipes
  /// - Async operation wrapper with loading state and error management
  /// 
  /// **Protected Method**: For use by subclasses during import operations.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final recipe = await parseTextToRecipe(
  ///   'Ingredienser: 2 ägg, 200g mjöl...',
  ///   url: 'https://example.com/recipe',
  /// );
  /// ```
  @protected
  Future<Recipe?> parseTextToRecipe(String text, {String? url}) async {
    return await executeAsync<Recipe?>(
      () async {
        final strategy = importManager.getTextImportStrategy();
        final result = await strategy.import(text);
        
        if (result.isSuccess && result.recipe != null) {
          // Apply source URL attribution if provided
          if (url != null) {
            final recipe = result.recipe!;
            final updatedRecipe = recipe.copyWith(sourceUrl: url);
            return updatedRecipe;
          }
          return result.recipe;
        } else {
          throw Exception(result.errorMessage ?? 'Failed to parse recipe from text');
        }
      },
      errorPrefix: 'Failed to parse recipe',
    );
  }

  /// Saves parsed recipe using ImportManager with comprehensive validation and error handling.
  /// 
  /// Returns true if save operation succeeds, false if validation fails or save errors occur.
  /// Performs imported recipe saving through ImportManager with validation checks,
  /// error handling, and async operation coordination for complete import workflow.
  /// 
  /// **Save Process:**
  /// - Parsed recipe validation ensuring data availability
  /// - ImportManager save operation with comprehensive error handling
  /// - Async operation wrapper with loading state and error management
  /// - Success/failure indication for UI feedback and workflow progression
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (viewModel.hasParsedRecipe) {
  ///   final saved = await viewModel.saveImportedRecipe();
  ///   if (saved) {
  ///     // Recipe successfully saved to collection
  ///   }
  /// }
  /// ```
  Future<bool> saveImportedRecipe() async {
    if (_parsedRecipe == null) {
      setError('No recipe to save');
      return false;
    }

    return await executeAsyncVoid(
      () async {
        final result = await _importManager.saveImportedRecipe(_parsedRecipe!);
        if (!result.isSuccess) {
          throw Exception(result.errorMessage ?? 'Failed to save recipe');
        }
      },
      errorPrefix: 'Failed to save recipe',
    );
  }

  /// Validates import data with comprehensive recipe completeness checking and Swedish error messaging.
  /// 
  /// Returns true if recipe data is valid and complete, false if validation fails.
  /// Performs comprehensive recipe validation ensuring title, ingredients, and instructions
  /// are present and valid with Swedish localized error messages for user feedback.
  /// 
  /// **Validation Requirements:**
  /// - Recipe object must be present and valid
  /// - Recipe title must be non-empty after trimming
  /// - At least one ingredient must be specified
  /// - At least one instruction must be provided
  /// 
  /// **Protected Method**: For use by subclasses during import validation.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (viewModel.validateImportData()) {
  ///   // Proceed with recipe saving
  /// } else {
  ///   // Handle validation error: viewModel.error
  /// }
  /// ```
  @protected
  bool validateImportData() {
    if (_parsedRecipe == null) {
      setError('Inget recept att validera');
      return false;
    }

    if (_parsedRecipe!.title.trim().isEmpty) {
      setError('Recepttitel krävs');
      return false;
    }

    if (_parsedRecipe!.ingredients.isEmpty) {
      setError('Receptet måste ha minst en ingrediens');
      return false;
    }

    if (_parsedRecipe!.instructions.isEmpty) {
      setError('Receptet måste ha minst en instruktion');
      return false;
    }

    return true;
  }

  /// Completes full import workflow with parsing, validation, and saving operations.
  /// 
  /// Returns true if complete import process succeeds, false if any step fails.
  /// Performs comprehensive import workflow including condition validation, parsing,
  /// data validation, and recipe saving with complete error handling and state management.
  /// 
  /// **Complete Import Process:**
  /// 1. Import condition validation (canImport check)
  /// 2. Subclass-specific import operation (performImport)
  /// 3. Import result validation and error checking
  /// 4. Recipe data validation (validateImportData)
  /// 5. Recipe saving operation (saveImportedRecipe)
  /// 
  /// **Usage Example:**
  /// ```dart
  /// // Set up import data (text, URL, etc.)
  /// viewModel.updateInputText('Recipe content...');
  /// 
  /// // Execute complete import workflow
  /// final success = await viewModel.completeImport();
  /// if (success) {
  ///   // Recipe successfully imported and saved
  /// } else {
  ///   // Handle error: viewModel.error
  /// }
  /// ```
  Future<bool> completeImport() async {
    if (!canImport) {
      setError('Importvillkor inte uppfyllda');
      return false;
    }

    // Execute subclass-specific import logic
    await performImport();

    if (hasError || _parsedRecipe == null) {
      return false;
    }

    // Validate imported recipe data
    if (!validateImportData()) {
      return false;
    }

    // Save recipe to collection
    return await saveImportedRecipe();
  }

  // ===== RECIPE MANIPULATION =====

  /// Update the parsed recipe with new data
  @protected
  void updateParsedRecipe({
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    String? mealType,
    int? portions,
    int? timeMinutes,
    List<String>? tags,
    List<String>? imageUrls,
  }) {
    if (_parsedRecipe == null || isDisposed) return;

    final updatedRecipe = _parsedRecipe!.copyWith(
      title: title,
      description: description,
      ingredients: ingredients,
      instructions: instructions,
      mealType: mealType,
      portions: portions,
      timeMinutes: timeMinutes,
      tags: tags,
      imageUrls: imageUrls,
    );

    setParsedRecipe(updatedRecipe);
  }

  /// Clear all import data and reset state
  void clearAll() {
    if (isDisposed) return;
    
    _parsedRecipe = null;
    _sourceUrl = null;
    clearError();
    notifyListeners();
  }

  // ===== DEBUGGING SUPPORT =====

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'hasParsedRecipe': hasParsedRecipe,
    'sourceUrl': _sourceUrl,
    'canImport': canImport,
    'importType': importType,
  };

  @override
  void dispose() {
    clearImportData();
    super.dispose();
  }
}

/// Mixin for ViewModels that handle text-based imports
mixin TextImportMixin on ImportBaseViewModel {
  
  String _inputText = '';

  /// Current input text
  String get inputText => _inputText;

  /// Whether input text is valid for parsing
  bool get hasValidInput => _inputText.trim().isNotEmpty;

  @override
  bool get canImport => hasValidInput;

  /// Update input text and clear previous results
  void updateInputText(String text) {
    if (isDisposed) return;
    
    _inputText = text;
    clearError();
    
    // Clear previous results if text changed significantly
    if (text.trim().isEmpty) {
      clearImportData();
    }
    
    notifyListeners();
  }

  /// Clear input text and all data
  void clearInput() {
    if (isDisposed) return;
    
    _inputText = '';
    clearImportData();
  }

  @override
  Future<void> performImport() async {
    if (!hasValidInput) {
      setError('Please provide text to import');
      return;
    }

    final recipe = await parseTextToRecipe(_inputText.trim(), url: sourceUrl);
    setParsedRecipe(recipe);
  }

  @override
  String get importType => 'text';

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'inputText': _inputText.length > 50 
        ? '${_inputText.substring(0, 50)}...' 
        : _inputText,
    'hasValidInput': hasValidInput,
  };
}

/// Mixin for ViewModels that handle URL-based imports
mixin UrlImportMixin on ImportBaseViewModel {
  
  String _url = '';
  String _extractedText = '';

  /// Current URL
  String get url => _url;

  /// Text extracted from URL
  String get extractedText => _extractedText;

  /// Whether extracted text is available
  bool get hasExtractedText => _extractedText.isNotEmpty;

  /// Whether URL is valid for fetching
  bool get canFetch => _url.trim().isNotEmpty && _isValidUrl(_url);

  @override
  bool get canImport => hasExtractedText;

  /// Update URL and clear previous results
  void updateUrl(String url) {
    if (isDisposed) return;
    
    _url = url;
    clearError();
    
    // Clear previous results if URL changed
    _extractedText = '';
    clearImportData();
    
    notifyListeners();
  }

  /// Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Fetch content from URL (subclasses should implement the actual fetching)
  @protected
  Future<String> fetchContentFromUrl(String url);

  /// Fetch and extract content from URL
  Future<void> fetchFromUrl() async {
    if (!canFetch) {
      setError('Please provide a valid URL');
      return;
    }

    final trimmedUrl = _url.trim();
    setSourceUrl(trimmedUrl);

    final extractedText = await executeAsync<String>(
      () => fetchContentFromUrl(trimmedUrl),
      errorPrefix: 'Failed to fetch content from URL',
    );

    if (extractedText != null) {
      _extractedText = extractedText;
      notifyListeners();
    }
  }

  @override
  Future<void> performImport() async {
    if (!hasExtractedText) {
      setError('No content extracted from URL');
      return;
    }

    final recipe = await parseTextToRecipe(_extractedText, url: sourceUrl);
    setParsedRecipe(recipe);
  }

  @override
  String get importType => 'url';

  /// Clear URL and all data
  void clearUrl() {
    if (isDisposed) return;
    
    _url = '';
    _extractedText = '';
    clearImportData();
  }

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'url': _url,
    'hasExtractedText': hasExtractedText,
    'canFetch': canFetch,
  };
}