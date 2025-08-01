// lib/viewmodels/recipe_form/recipe_form_state.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/form/form_fields_manager.dart';

/// Core state management for recipe form
class RecipeFormState extends ChangeNotifier {
  // FormFieldsManagers för dynamiska fält
  late final FormFieldsManager _ingredientsManager;
  late final FormFieldsManager _instructionsManager;
  late final FormFieldsManager _tagsManager;

  // Core state
  Recipe? _originalRecipe;
  bool _isSaving = false;
  bool _isForking = false;
  String? _error;

  // Form data
  String _title = '';
  String _description = '';
  String _mealType = 'Middag';
  int? _portions;
  int? _timeMinutes;
  double? _rating;
  List<String> _imageUrls = [];
  String? _sourceUrl;
  List<String> _ingredients = [''];
  List<String> _instructions = [''];
  List<String> _tags = [''];

  // Constants
  static const List<String> mealTypes = [
    'Frukost',
    'Lunch',
    'Middag',
    'Dessert',
    'Mellanmål',
    'Fika',
  ];
  static const int maxImages = 5;

  RecipeFormState({Recipe? initialRecipe, bool isTemplate = false}) {
    _initializeFormFields();
    if (initialRecipe != null) {
      _loadRecipeData(initialRecipe, isTemplate);
    }
  }

  void _initializeFormFields() {
    _ingredientsManager = FormFieldsManager(
      initialItems: _ingredients,
      validator: (ingredient) => ingredient?.trim().isNotEmpty == true ? null : 'Empty ingredient',
      onValueChanged: (index, value) {
        if (index < _ingredients.length) {
          _ingredients[index] = value;
          notifyListeners();
        }
      },
    );

    _instructionsManager = FormFieldsManager(
      initialItems: _instructions,
      validator: (instruction) => instruction?.trim().isNotEmpty == true ? null : 'Empty instruction',
      onValueChanged: (index, value) {
        if (index < _instructions.length) {
          _instructions[index] = value;
          notifyListeners();
        }
      },
    );

    _tagsManager = FormFieldsManager(
      initialItems: _tags,
      validator: (tag) => tag?.trim().isNotEmpty == true ? null : 'Empty tag',
      onValueChanged: (index, value) {
        if (index < _tags.length) {
          _tags[index] = value;
          notifyListeners();
        }
      },
    );
  }

  void _loadRecipeData(Recipe recipe, bool isTemplate) {
    _originalRecipe = isTemplate ? null : recipe;
    
    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrls = List<String>.from(recipe.imageUrls);
    _sourceUrl = recipe.sourceUrl;
    _ingredients = recipe.ingredients.isNotEmpty ? List<String>.from(recipe.ingredients) : [''];
    _instructions = recipe.instructions.isNotEmpty ? List<String>.from(recipe.instructions) : [''];
    _tags = recipe.tags?.isNotEmpty == true ? List<String>.from(recipe.tags!) : [''];

    // Uppdatera FormFieldsManagers
    _ingredientsManager.updateItems(_ingredients);
    _instructionsManager.updateItems(_instructions);
    _tagsManager.updateItems(_tags);
  }

  // ===== GETTERS =====

  // Core getters
  Recipe? get originalRecipe => _originalRecipe;
  bool get isSaving => _isSaving;
  bool get isForking => _isForking;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEditing => _originalRecipe != null;

  // Form data getters
  String get title => _title;
  String get description => _description;
  String get mealType => _mealType;
  int? get portions => _portions;
  int? get timeMinutes => _timeMinutes;
  double? get rating => _rating;
  List<String> get imageUrls => List<String>.from(_imageUrls);
  String? get sourceUrl => _sourceUrl;
  List<String> get ingredients => List<String>.from(_ingredients);
  List<String> get instructions => List<String>.from(_instructions);
  List<String> get tags => List<String>.from(_tags);

  // Controller getters
  FormFieldsManager get ingredientsManager => _ingredientsManager;
  FormFieldsManager get instructionsManager => _instructionsManager;
  FormFieldsManager get tagsManager => _tagsManager;

  // Validation
  bool get isValid => _title.trim().isNotEmpty && 
                     _ingredients.any((ingredient) => ingredient.trim().isNotEmpty) &&
                     _instructions.any((instruction) => instruction.trim().isNotEmpty);

  // ===== SETTERS =====

  void setTitle(String title) {
    _title = title;
    notifyListeners();
  }

  void setDescription(String description) {
    _description = description;
    notifyListeners();
  }

  void setMealType(String mealType) {
    _mealType = mealType;
    notifyListeners();
  }

  void setPortions(int? portions) {
    _portions = portions;
    notifyListeners();
  }

  void setTimeMinutes(int? timeMinutes) {
    _timeMinutes = timeMinutes;
    notifyListeners();
  }

  void setRating(double? rating) {
    _rating = rating;
    notifyListeners();
  }

  void setSourceUrl(String? sourceUrl) {
    _sourceUrl = sourceUrl;
    notifyListeners();
  }

  void setImageUrls(List<String> imageUrls) {
    _imageUrls = List<String>.from(imageUrls);
    notifyListeners();
  }

  void addImageUrl(String imageUrl) {
    if (_imageUrls.length < maxImages) {
      _imageUrls.add(imageUrl);
      notifyListeners();
    }
  }

  void removeImageUrl(String imageUrl) {
    _imageUrls.remove(imageUrl);
    notifyListeners();
  }

  void moveImageToFirst(String imageUrl) {
    _imageUrls.remove(imageUrl);
    _imageUrls.insert(0, imageUrl);
    notifyListeners();
  }

  // ===== STATE MANAGEMENT =====

  void setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  void setForking(bool forking) {
    _isForking = forking;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ===== RECIPE CREATION =====

  /// Skapa Recipe från nuvarande form state
  Recipe createRecipe({String? recipeId}) {
    final cleanIngredients = _ingredients.where((ingredient) => ingredient.trim().isNotEmpty).toList();
    final cleanInstructions = _instructions.where((instruction) => instruction.trim().isNotEmpty).toList();
    final cleanTags = _tags.where((tag) => tag.trim().isNotEmpty).toList();

    return Recipe(
      core: RecipeCore(
        id: recipeId ?? _originalRecipe?.id ?? '',
        title: _title.trim(),
        description: _description.trim(),
        mealType: _mealType,
        portions: _portions,
        timeMinutes: _timeMinutes,
        rating: _rating,
        ingredients: cleanIngredients,
        instructions: cleanInstructions,
        tags: cleanTags,
        imageUrls: _imageUrls,
        sourceUrl: _sourceUrl?.trim(),
        createdAt: _originalRecipe?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      type: RecipeType.personal,
    );
  }

  // ===== RESET =====

  void resetForm() {
    _originalRecipe = null;
    _isSaving = false;
    _isForking = false;
    _error = null;
    
    _title = '';
    _description = '';
    _mealType = 'Middag';
    _portions = null;
    _timeMinutes = null;
    _rating = null;
    _imageUrls = [];
    _sourceUrl = null;
    _ingredients = [''];
    _instructions = [''];
    _tags = [''];

    _ingredientsManager.updateItems(_ingredients);
    _instructionsManager.updateItems(_instructions);
    _tagsManager.updateItems(_tags);

    notifyListeners();
  }
}