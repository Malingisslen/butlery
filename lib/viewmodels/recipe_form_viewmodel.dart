// lib/viewmodels/recipe_form_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../core/injection.dart';

/// ViewModel för recept-formulär (skapa/redigera)
/// Hanterar all formulärlogik och validering
class RecipeFormViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final _uuid = const Uuid();

  // State
  Recipe? _originalRecipe;
  bool _isSaving = false;
  String? _error;

  // Form data
  String _title = '';
  String _description = '';
  String _mealType = 'Middag';
  int? _portions;
  int? _timeMinutes;
  double? _rating;
  String? _imageUrl;
  List<String> _ingredients = [''];
  List<String> _instructions = [''];
  List<String> _tags = [''];

  // Tillgängliga måltidstyper
  static const List<String> mealTypes = [
    'Frukost',
    'Lunch',
    'Middag',
    'Dessert',
    'Mellanmål',
    'Fika',
  ];

  RecipeFormViewModel({RecipeService? recipeService, Recipe? initialRecipe})
    : _recipeService = recipeService ?? sl<RecipeService>() {
    if (initialRecipe != null) {
      loadRecipe(initialRecipe);
    }
  }

  // ===== GETTERS =====

  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEditMode => _originalRecipe != null;

  String get title => _title;
  String get description => _description;
  String get mealType => _mealType;
  int? get portions => _portions;
  int? get timeMinutes => _timeMinutes;
  double? get rating => _rating;
  String? get imageUrl => _imageUrl;
  List<String> get ingredients => _ingredients;
  List<String> get instructions => _instructions;
  List<String> get tags => _tags;

  // Validation
  bool get isValid =>
      _title.trim().isNotEmpty &&
      _ingredients.any((i) => i.trim().isNotEmpty) &&
      _instructions.any((i) => i.trim().isNotEmpty);

  // ===== SETTERS =====

  void setTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setMealType(String value) {
    if (mealTypes.contains(value)) {
      _mealType = value;
      notifyListeners();
    }
  }

  void setPortions(String value) {
    _portions = int.tryParse(value);
    notifyListeners();
  }

  void setTimeMinutes(String value) {
    _timeMinutes = int.tryParse(value);
    notifyListeners();
  }

  void setRating(String value) {
    _rating = double.tryParse(value.replaceAll(',', '.'));
    notifyListeners();
  }

  void setImageUrl(String value) {
    _imageUrl = value.trim().isEmpty ? null : value.trim();
    notifyListeners();
  }

  // ===== LIST OPERATIONS =====

  void updateIngredient(int index, String value) {
    if (index >= 0 && index < _ingredients.length) {
      _ingredients[index] = value;

      // Auto-add ny rad om sista fältet fylls i
      if (index == _ingredients.length - 1 && value.trim().isNotEmpty) {
        _ingredients.add('');
      }
      // Ta bort tomma rader (utom sista)
      else if (value.trim().isEmpty && index < _ingredients.length - 1) {
        _ingredients.removeAt(index);
      }

      notifyListeners();
    }
  }

  void addIngredient() {
    _ingredients.add('');
    notifyListeners();
  }

  void removeIngredient(int index) {
    if (_ingredients.length > 1 && index >= 0 && index < _ingredients.length) {
      _ingredients.removeAt(index);
      notifyListeners();
    }
  }

  void updateInstruction(int index, String value) {
    if (index >= 0 && index < _instructions.length) {
      _instructions[index] = value;

      // Auto-add ny rad om sista fältet fylls i
      if (index == _instructions.length - 1 && value.trim().isNotEmpty) {
        _instructions.add('');
      }
      // Ta bort tomma rader (utom sista)
      else if (value.trim().isEmpty && index < _instructions.length - 1) {
        _instructions.removeAt(index);
      }

      notifyListeners();
    }
  }

  void addInstruction() {
    _instructions.add('');
    notifyListeners();
  }

  void removeInstruction(int index) {
    if (_instructions.length > 1 &&
        index >= 0 &&
        index < _instructions.length) {
      _instructions.removeAt(index);
      notifyListeners();
    }
  }

  void updateTag(int index, String value) {
    if (index >= 0 && index < _tags.length) {
      _tags[index] = value;

      // Auto-add ny rad om sista fältet fylls i
      if (index == _tags.length - 1 && value.trim().isNotEmpty) {
        _tags.add('');
      }
      // Ta bort tomma rader (utom sista)
      else if (value.trim().isEmpty && index < _tags.length - 1) {
        _tags.removeAt(index);
      }

      notifyListeners();
    }
  }

  void addTag() {
    _tags.add('');
    notifyListeners();
  }

  void removeTag(int index) {
    if (_tags.length > 1 && index >= 0 && index < _tags.length) {
      _tags.removeAt(index);
      notifyListeners();
    }
  }

  // ===== ACTIONS =====

  /// Ladda recept för redigering
  void loadRecipe(Recipe recipe) {
    _originalRecipe = recipe;
    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrl = recipe.imageUrl;
    _ingredients = [...recipe.ingredients, ''];
    _instructions = [...recipe.instructions, ''];
    _tags = [...(recipe.tags ?? []), ''];
    notifyListeners();
  }

  /// Spara recept
  Future<bool> saveRecipe() async {
    if (!isValid) {
      _setError('Fyll i alla obligatoriska fält');
      return false;
    }

    _setSaving(true);

    try {
      final recipe = Recipe(
        id: _originalRecipe?.id ?? _uuid.v4(),
        title: _title.trim(),
        description: _description.trim(),
        mealType: _mealType,
        portions: _portions,
        timeMinutes: _timeMinutes,
        ingredients:
            _ingredients
                .map((i) => i.trim())
                .where((i) => i.isNotEmpty)
                .toList(),
        instructions:
            _instructions
                .map((i) => i.trim())
                .where((i) => i.isNotEmpty)
                .toList(),
        tags: _tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        rating: _rating,
        imageUrl: _imageUrl,
      );

      RecipeOperationResult result;

      if (isEditMode) {
        result = await _recipeService.updateRecipe(recipe);
      } else {
        result = await _recipeService.addRecipe(recipe);
      }

      if (result.isSuccess) {
        _error = null;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('Kunde inte spara recept: ${e.toString()}');
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Återställ formulär
  void reset() {
    _originalRecipe = null;
    _title = '';
    _description = '';
    _mealType = 'Middag';
    _portions = null;
    _timeMinutes = null;
    _rating = null;
    _imageUrl = null;
    _ingredients = [''];
    _instructions = [''];
    _tags = [''];
    _error = null;
    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
