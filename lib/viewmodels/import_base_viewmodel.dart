// lib/viewmodels/import_base_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe_unified.dart';
import '../services/import/import_manager.dart';
import 'base_viewmodel.dart';

/// Base class for all import ViewModels that provides common import functionality
/// Eliminates duplication across PhotoImportViewModel, TextImportViewModel, etc.
abstract class ImportBaseViewModel extends BaseViewModel with AsyncOperationMixin {
  final ImportManager _importManager;

  // ===== COMMON IMPORT STATE =====
  
  Recipe? _parsedRecipe;
  String? _sourceUrl;

  ImportBaseViewModel({required ImportManager importManager})
      : _importManager = importManager;

  // ===== COMMON GETTERS =====

  /// The parsed recipe from import
  Recipe? get parsedRecipe => _parsedRecipe;

  /// Whether a recipe has been successfully parsed
  bool get hasParsedRecipe => _parsedRecipe != null;

  /// Source URL for the imported recipe (if applicable)
  String? get sourceUrl => _sourceUrl;

  /// Whether the import can proceed (subclasses should override)
  bool get canImport => true;

  /// Whether currently parsing/importing (common across import types)
  bool get isParsing => isLoading;

  /// Whether the input can be parsed (subclasses should override with specific logic)
  bool get canParse => true;

  /// Import manager for strategy-based importing
  @protected
  ImportManager get importManager => _importManager;

  // ===== COMMON STATE MANAGEMENT =====

  /// Set the parsed recipe and notify listeners
  @protected
  void setParsedRecipe(Recipe? recipe) {
    if (isDisposed) return;
    
    _parsedRecipe = recipe;
    notifyListeners();
  }

  /// Set the source URL and notify listeners
  void setSourceUrl(String? url) {
    if (isDisposed) return;
    
    _sourceUrl = url;
    notifyListeners();
  }

  /// Clear all import data
  @protected
  void clearImportData() {
    if (isDisposed) return;
    
    _parsedRecipe = null;
    _sourceUrl = null;
    clearState();
  }

  // ===== ABSTRACT METHODS =====

  /// Import method that subclasses must implement
  Future<void> performImport();

  /// Get the import type for analytics/logging
  String get importType;

  // ===== COMMON OPERATIONS =====

  /// Parse text into a recipe using ImportManager
  @protected
  Future<Recipe?> parseTextToRecipe(String text, {String? url}) async {
    return await executeAsync<Recipe?>(
      () async {
        final strategy = importManager.getTextImportStrategy();
        final result = await strategy.import(text);
        
        if (result.isSuccess && result.recipe != null) {
          // Set source URL if provided
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

  /// Save the parsed recipe using ImportManager
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

  /// Validate import data before saving
  @protected
  bool validateImportData() {
    if (_parsedRecipe == null) {
      setError('No recipe to validate');
      return false;
    }

    if (_parsedRecipe!.title.trim().isEmpty) {
      setError('Recipe title is required');
      return false;
    }

    if (_parsedRecipe!.ingredients.isEmpty) {
      setError('Recipe must have at least one ingredient');
      return false;
    }

    if (_parsedRecipe!.instructions.isEmpty) {
      setError('Recipe must have at least one instruction');
      return false;
    }

    return true;
  }

  /// Complete import process: parse and save
  Future<bool> completeImport() async {
    if (!canImport) {
      setError('Import conditions not met');
      return false;
    }

    // Perform the import (subclass-specific logic)
    await performImport();

    if (hasError || _parsedRecipe == null) {
      return false;
    }

    // Validate the imported data
    if (!validateImportData()) {
      return false;
    }

    // Save the recipe
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