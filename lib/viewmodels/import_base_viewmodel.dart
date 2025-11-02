/// Base ViewModel for all import operations (text, URL, photo, archive) with unified workflow and validation.

// lib/viewmodels/import_base_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

abstract class ImportBaseViewModel extends BaseViewModel with AsyncOperationMixin {
  final ImportManager _importManager;

  Recipe? _parsedRecipe;
  String? _sourceUrl;

  ImportBaseViewModel({required ImportManager importManager})
      : _importManager = importManager;

  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;
  String? get sourceUrl => _sourceUrl;
  bool get canImport => true;
  bool get isParsing => isLoading;
  bool get canParse => true;

  @protected
  ImportManager get importManager => _importManager;

  @protected
  void setParsedRecipe(Recipe? recipe) {
    if (isDisposed) return;
    _parsedRecipe = recipe;
    notifyListeners();
  }

  void setSourceUrl(String? url) {
    if (isDisposed) return;
    _sourceUrl = url;
    notifyListeners();
  }

  @protected
  void clearImportData() {
    if (isDisposed) return;
    _parsedRecipe = null;
    _sourceUrl = null;
    clearState();
  }

  Future<void> performImport();
  String get importType;

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

  void clearAll() {
    if (isDisposed) return;
    
    _parsedRecipe = null;
    _sourceUrl = null;
    clearError();
    notifyListeners();
  }

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

mixin TextImportMixin on ImportBaseViewModel {
  String _inputText = '';

  String get inputText => _inputText;
  bool get hasValidInput => _inputText.trim().isNotEmpty;

  @override
  bool get canImport => hasValidInput;

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

mixin UrlImportMixin on ImportBaseViewModel {
  String _url = '';
  String _extractedText = '';

  String get url => _url;
  String get extractedText => _extractedText;
  bool get hasExtractedText => _extractedText.isNotEmpty;
  bool get canFetch => _url.trim().isNotEmpty && _isValidUrl(_url);

  @override
  bool get canImport => hasExtractedText;

  void updateUrl(String url) {
    if (isDisposed) return;
    
    _url = url;
    clearError();
    
    // Clear previous results if URL changed
    _extractedText = '';
    clearImportData();
    
    notifyListeners();
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @protected
  Future<String> fetchContentFromUrl(String url);

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

    _extractedText = extractedText;
    notifyListeners();
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