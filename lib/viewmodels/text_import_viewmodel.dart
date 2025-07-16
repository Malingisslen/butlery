// lib/viewmodels/text_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../services/import/import_manager.dart';

/// ViewModel för text-baserad receptimport (sociala medier, OCR, etc)
/// Now using ImportManager with strategy pattern
class TextImportViewModel extends ChangeNotifier {
  final ImportManager _importManager;

  // State
  String _inputText = '';
  bool _isParsing = false;
  String? _error;
  Recipe? _parsedRecipe;
  String? _sourceUrl; // URL från import

  TextImportViewModel({required ImportManager importManager})
      : _importManager = importManager;

  // Getters
  String get inputText => _inputText;
  bool get isParsing => _isParsing;
  String? get error => _error;
  bool get hasError => _error != null;
  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;
  bool get canParse => _inputText.trim().isNotEmpty;
  String? get sourceUrl => _sourceUrl;

  /// Sätt sourceUrl (används när recept importeras från URL)
  void setSourceUrl(String url) {
    _sourceUrl = url;
    notifyListeners();
  }

  /// Uppdatera input-text
  void updateInputText(String text) {
    _inputText = text;
    _error = null;
    notifyListeners();
  }

  /// Rensa all input
  void clearInput() {
    _inputText = '';
    _error = null;
    _parsedRecipe = null;
    _sourceUrl = null;
    notifyListeners();
  }

  /// Parsa text till recept using ImportManager strategy pattern
  Future<bool> parseText() async {
    final input = _inputText.trim();
    if (input.isEmpty) {
      _setError('Ange text att tolka');
      return false;
    }

    _setParsing(true);
    _error = null;

    try {
      final result = await _importManager.autoImport(input);

      if (result.isSuccess && result.importedRecipes.isNotEmpty) {
        _parsedRecipe = result.importedRecipes.first;
        if (_sourceUrl != null) {
          _parsedRecipe = _parsedRecipe!.copyWith(sourceUrl: _sourceUrl);
        }
        return true;
      } else {
        throw Exception(result.error ?? 'Kunde inte tolka receptet från texten');
      }
    } catch (e) {
      _setError('Kunde inte tolka text: ${e.toString()}');
      return false;
    } finally {
      _setParsing(false);
    }
  }


  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Private methods
  void _setParsing(bool value) {
    _isParsing = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
