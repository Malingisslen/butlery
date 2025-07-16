// lib/viewmodels/url_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/recipe_scraper.dart';
import '../models/recipe.dart';
import '../services/import/import_manager.dart';

/// ViewModel för URL-baserad receptimport
/// Now using ImportManager for text processing
class UrlImportViewModel extends ChangeNotifier {
  final ImportManager _importManager;

  // State
  String _url = '';
  String _extractedText = '';
  bool _isLoading = false;
  String? _error;
  Recipe? _parsedRecipe;

  UrlImportViewModel({required ImportManager importManager})
      : _importManager = importManager;

  // Getters
  String get url => _url;
  String get extractedText => _extractedText;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasExtractedText => _extractedText.isNotEmpty;
  bool get canFetch => _url.trim().isNotEmpty && _isValidUrl(_url);
  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;

  // Getter för att få den rensade URL:en som sourceUrl
  String? get sourceUrl => _url.trim().isNotEmpty ? _url.trim() : null;

  /// Uppdatera URL
  void updateUrl(String url) {
    _url = url;
    _error = null;
    notifyListeners();
  }

  /// Hämta och extrahera recept från URL
  Future<void> fetchFromUrl() async {
    final trimmedUrl = _url.trim();

    if (trimmedUrl.isEmpty) {
      _setError('Ange en URL');
      return;
    }

    if (!_isValidUrl(trimmedUrl)) {
      _setError('Ogiltig URL');
      return;
    }

    _setLoading(true);
    _error = null;
    _extractedText = '';

    try {
      // Använd proxy för att undvika CORS
      final encodedUrl = Uri.encodeComponent(trimmedUrl);
      final proxyUrl = 'https://api.allorigins.win/raw?url=$encodedUrl';

      final response = await http.get(Uri.parse(proxyUrl));

      if (response.statusCode != 200) {
        throw Exception('Hämtning misslyckades (kod ${response.statusCode})');
      }

      final html = response.body;
      final recipeJson = extractRecipeFromHtml(html);

      if (recipeJson == null) {
        throw Exception('Kunde inte hitta receptdata på sidan.');
      }

      // Bygg text från JSON-LD data
      _extractedText = _buildTextFromRecipeJson(recipeJson);

      if (_extractedText.isEmpty) {
        throw Exception('Ingen receptdata kunde extraheras från sidan.');
      }

      // Process extracted text through ImportManager
      final importResult = await _importManager.autoImport(_extractedText);
      if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
        _parsedRecipe = importResult.importedRecipes.first.copyWith(
          sourceUrl: trimmedUrl,
        );
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Bygg text från recipe JSON-LD
  String _buildTextFromRecipeJson(Map<String, dynamic> recipeJson) {
    final buffer = StringBuffer();

    // Titel
    if (recipeJson['name'] != null) {
      buffer.writeln(recipeJson['name']);
      buffer.writeln();
    }

    // Ingredienser
    final ingredients = <String>[];
    if (recipeJson['recipeIngredient'] is List) {
      ingredients.addAll(
        (recipeJson['recipeIngredient'] as List).cast<String>(),
      );
    }

    if (ingredients.isNotEmpty) {
      buffer.writeln('Ingredienser:');
      for (var ingredient in ingredients) {
        buffer.writeln('- $ingredient');
      }
      buffer.writeln();
    }

    // Instruktioner
    final instructions = <String>[];
    if (recipeJson['recipeInstructions'] is List) {
      for (final step in recipeJson['recipeInstructions'] as List) {
        if (step is Map<String, dynamic>) {
          // Hantera HowToSection → itemListElement
          if (step.containsKey('itemListElement') &&
              step['itemListElement'] is List) {
            for (final subStep in step['itemListElement'] as List) {
              if (subStep is Map<String, dynamic> && subStep['text'] != null) {
                instructions.add(subStep['text'].toString());
              }
            }
          }
          // Hantera vanligt "text"-fält
          else if (step['text'] != null) {
            instructions.add(step['text'].toString());
          }
        } else if (step is String) {
          instructions.add(step);
        }
      }
    }

    if (instructions.isNotEmpty) {
      buffer.writeln('Instruktioner:');
      for (var i = 0; i < instructions.length; i++) {
        buffer.writeln('${i + 1}. ${instructions[i]}');
      }
    }

    return buffer.toString();
  }

  /// Validera URL
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Parse current extracted text to recipe
  Future<bool> parseExtractedText() async {
    if (_extractedText.isEmpty) return false;

    try {
      _setLoading(true);
      final result = await _importManager.autoImport(_extractedText);
      
      if (result.isSuccess && result.importedRecipes.isNotEmpty) {
        _parsedRecipe = result.importedRecipes.first.copyWith(
          sourceUrl: sourceUrl,
        );
        return true;
      } else {
        _setError(result.error ?? 'Could not parse recipe from extracted text');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Rensa all state
  void clearAll() {
    _url = '';
    _extractedText = '';
    _error = null;
    _parsedRecipe = null;
    notifyListeners();
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
