// lib/viewmodels/recipe_form/recipe_form_state.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/core/form/form_fields_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/viewmodels/recipe_form/contextual_error_handler.dart';
import 'package:butlery/core/errors/contextual_error_engine.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Core state management for recipe form with intelligent auto-save
class RecipeFormState extends ChangeNotifier {
  // FormFieldsManagers for dynamic fields
  late final FormFieldsManager _ingredientsManager;
  late final FormFieldsManager _instructionsManager;
  late final FormFieldsManager _tagsManager;

  // Auto-save manager for draft persistence
  late final RecipeFormAutoSaveManager _autoSaveManager;

  // Core state
  Recipe? _originalRecipe;
  ParsedRecipe? _originalParsedRecipe;
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
  TagOverrides? _tagOverrides;

  // CRITICAL FIX: Remove internal arrays to eliminate dual state inconsistency
  // Single source of truth is now FormFieldsManager values only

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
  static const int maxIngredients = 100;
  static const int maxInstructions = 50;

  RecipeFormState({Recipe? initialRecipe, bool isTemplate = false}) {
    _initializeFormFields();
    _autoSaveManager = RecipeFormAutoSaveManager();
    _autoSaveManager.initialize(isTemplate: isTemplate);
    if (initialRecipe != null) {
      _loadRecipeData(initialRecipe, isTemplate);
    }
  }

  void _initializeFormFields() {
    // CRITICAL FIX: Initialize managers with enhanced validation consistency
    _ingredientsManager = FormFieldsManager(
      initialItems: [''], // Start with one empty field
      validator: (ingredient) {
        // CRITICAL FIX: Enhanced validator with consistent validation rules
        if (ingredient == null || ingredient.trim().isEmpty) {
          return AppLocale.current.formValidationIngredientRequired;
        }
        if (ingredient.length > 200) {
          return AppLocale.current.formValidationIngredientTooLong;
        }
        return null; // Valid
      },
      onValueChanged: (index, value) {
        // CRITICAL FIX: Validation-aware change handling
        notifyListeners();
        // Trigger auto-save for ingredient changes
        _scheduleAutoSave(
            isQuickSave: true); // Ingredients are important - quick save
      },
    );

    _instructionsManager = FormFieldsManager(
      initialItems: [''], // Start with one empty field
      validator: (instruction) {
        // CRITICAL FIX: Enhanced validator with consistent validation rules
        if (instruction == null || instruction.trim().isEmpty) {
          return AppLocale.current.formValidationInstructionRequired;
        }
        if (instruction.length > 500) {
          return AppLocale.current.formValidationInstructionTooLong;
        }
        return null; // Valid
      },
      onValueChanged: (index, value) {
        // CRITICAL FIX: Validation-aware change handling
        notifyListeners();
        // Trigger auto-save for instruction changes
        _scheduleAutoSave(
            isQuickSave: true); // Instructions are important - quick save
      },
    );

    _tagsManager = FormFieldsManager(
      initialItems: [''], // Start with one empty field
      validator: (tag) {
        // CRITICAL FIX: Enhanced validator with consistent validation rules
        if (tag == null || tag.trim().isEmpty) {
          return null; // Tags are optional, empty is OK
        }
        if (tag.length > 50) {
          return AppLocale.current.formValidationTagTooLong;
        }
        if (tag.contains(',')) {
          return AppLocale.current.formValidationTagNoCommas;
        }
        return null; // Valid
      },
      onValueChanged: (index, value) {
        // CRITICAL FIX: Validation-aware change handling
        notifyListeners();
        // Trigger auto-save for tag changes
        _scheduleAutoSave();
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
    _tagOverrides = recipe.tagOverrides;

    // CRITICAL FIX: Update FormFieldsManagers directly as single source of truth
    // CRITICAL FIX: Always add an empty field at the end for auto-add behavior when editing
    final ingredients =
        recipe.ingredients.isNotEmpty ? [...recipe.ingredients, ''] : [''];
    final instructions =
        recipe.instructions.isNotEmpty ? [...recipe.instructions, ''] : [''];
    final tags = recipe.personalTagIds?.isNotEmpty == true
        ? [...recipe.personalTagIds!, '']
        : [''];

    _ingredientsManager.updateItems(ingredients);
    _instructionsManager.updateItems(instructions);
    _tagsManager.updateItems(tags);
  }

  // Core getters
  Recipe? get originalRecipe => _originalRecipe;

  /// Original parsed recipe for correction tracking (set during import)
  ParsedRecipe? get originalParsedRecipe => _originalParsedRecipe;

  /// Set original parsed recipe for correction tracking
  /// Called when importing a recipe to enable diff calculation on save
  void setOriginalParsedRecipe(ParsedRecipe? parsed) {
    _originalParsedRecipe = parsed;
  }

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
  List<String> get ingredients => List<String>.from(_ingredientsManager.values);
  List<String> get instructions =>
      List<String>.from(_instructionsManager.values);
  List<String> get tags => List<String>.from(_tagsManager.values);
  TagOverrides? get tagOverrides => _tagOverrides;

  // Controller getters
  FormFieldsManager get ingredientsManager => _ingredientsManager;
  FormFieldsManager get instructionsManager => _instructionsManager;
  FormFieldsManager get tagsManager => _tagsManager;

  /// Check if more ingredients can be added (respects max limit)
  bool get canAddIngredient =>
      _ingredientsManager.values.length < maxIngredients;

  /// Check if more instructions can be added (respects max limit)
  bool get canAddInstruction =>
      _instructionsManager.values.length < maxInstructions;

  /// Get remaining ingredient slots
  int get remainingIngredientSlots =>
      maxIngredients - _ingredientsManager.values.length;

  /// Get remaining instruction slots
  int get remainingInstructionSlots =>
      maxInstructions - _instructionsManager.values.length;

  // CRITICAL FIX: Enhanced validation with consistent state sources and manager validation integration
  bool get isValid => _isFormValidWithConsistentSources();

  /// Comprehensive validation using consistent state sources and manager validators
  bool _isFormValidWithConsistentSources() {
    // Basic field validation using same sources as serialization
    if (_title.trim().isEmpty) {
      return false;
    }

    // CRITICAL FIX: Use FormFieldsManager validation consistently
    // Check ingredients using manager validator and values (same as serialization)
    final ingredientValues = _ingredientsManager.values;
    if (!ingredientValues.any((ingredient) => ingredient.trim().isNotEmpty)) {
      return false;
    }

    // Validate ingredients using FormFieldsManager validator if available
    if (_ingredientsManager.validator != null) {
      for (int i = 0; i < ingredientValues.length; i++) {
        final ingredient = ingredientValues[i];
        if (ingredient.trim().isNotEmpty) {
          // Only validate non-empty ingredients
          final validationError = _ingredientsManager.validator!(ingredient);
          if (validationError != null) {
            return false; // Validation failed
          }
        }
      }
    }

    // Check instructions using manager validator and values (same as serialization)
    final instructionValues = _instructionsManager.values;
    if (!instructionValues
        .any((instruction) => instruction.trim().isNotEmpty)) {
      return false;
    }

    // Validate instructions using FormFieldsManager validator if available
    if (_instructionsManager.validator != null) {
      for (int i = 0; i < instructionValues.length; i++) {
        final instruction = instructionValues[i];
        if (instruction.trim().isNotEmpty) {
          // Only validate non-empty instructions
          final validationError = _instructionsManager.validator!(instruction);
          if (validationError != null) {
            return false; // Validation failed
          }
        }
      }
    }

    // CRITICAL FIX: Validate FormFieldsManager synchronization consistency
    // Ensure managers are not in an updating state that could affect validation
    try {
      // Access manager state to ensure it's synchronized
      // If managers are updating, validation state may be inconsistent
      final ingredientsLength = _ingredientsManager.length;
      final instructionsLength = _instructionsManager.length;
      final tagsLength = _tagsManager.length;

      // Basic sanity check - lengths should match values
      if (ingredientsLength != ingredientValues.length ||
          instructionsLength != instructionValues.length ||
          tagsLength != _tagsManager.values.length) {
        // State inconsistency detected - managers not synchronized
        return false;
      }
    } catch (e) {
      // Manager access failed - state may be inconsistent
      return false;
    }

    // CRITICAL FIX: Validate that all required fields use consistent data sources
    // Ensure validation uses same data that would be serialized
    final serializedData = _serializeFormData();

    // Cross-validate that our validation sources match serialization sources
    final serializedIngredients =
        List<String>.from((serializedData['ingredients'] as List?).orEmpty());
    final serializedInstructions =
        List<String>.from((serializedData['instructions'] as List?).orEmpty());

    if (!_listEquals(ingredientValues, serializedIngredients) ||
        !_listEquals(instructionValues, serializedInstructions)) {
      // Data source inconsistency - validation and serialization using different data
      return false;
    }

    return true;
  }

  /// Helper method for safe list comparison to prevent null pointer crashes
  bool _listEquals(List<String>? list1, List<String>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  // Auto-save getters
  bool get isAutoSaving => _autoSaveManager.isAutoSaving;
  bool get hasRecentAutoSave => _autoSaveManager.hasRecentAutoSave;
  String? get currentDraftId => _autoSaveManager.currentDraftId;
  RecipeFormAutoSaveManager get autoSaveManager => _autoSaveManager;

  // CRITICAL FIX: Enhanced validation getters with detailed validation state
  /// Get detailed validation status for each form section
  Map<String, bool> get validationStatus => {
        'title': _title.trim().isNotEmpty,
        'ingredients': _ingredientsManager.values
            .any((ingredient) => ingredient.trim().isNotEmpty),
        'instructions': _instructionsManager.values
            .any((instruction) => instruction.trim().isNotEmpty),
        'managersSync': _areManagersSynchronized(),
        'dataConsistency': _isDataConsistent(),
      };

  /// Check if all FormFieldsManagers are in synchronized state
  bool _areManagersSynchronized() {
    try {
      // Verify managers are accessible and consistent
      final ingredientsOk =
          _ingredientsManager.length == _ingredientsManager.values.length;
      final instructionsOk =
          _instructionsManager.length == _instructionsManager.values.length;
      final tagsOk = _tagsManager.length == _tagsManager.values.length;
      return ingredientsOk && instructionsOk && tagsOk;
    } catch (e) {
      return false;
    }
  }

  /// Check if validation data sources match serialization data sources
  bool _isDataConsistent() {
    try {
      final serializedData = _serializeFormData();
      final serializedIngredients =
          List<String>.from((serializedData['ingredients'] as List?).orEmpty());
      final serializedInstructions = List<String>.from(
          (serializedData['instructions'] as List?).orEmpty());
      final serializedTags =
          List<String>.from((serializedData['tags'] as List?).orEmpty());

      return _listEquals(_ingredientsManager.values, serializedIngredients) &&
          _listEquals(_instructionsManager.values, serializedInstructions) &&
          _listEquals(_tagsManager.values, serializedTags);
    } catch (e) {
      return false;
    }
  }

  void setTitle(String title) {
    // CRITICAL FIX: Enhanced title validation with consistency checks
    final trimmedTitle = title.trim();

    // Validate title length and content
    if (trimmedTitle.length > 100) {
      // Don't allow titles that are too long - truncate to prevent validation issues
      _title = trimmedTitle.substring(0, 100);
    } else {
      _title = trimmedTitle;
    }

    notifyListeners();
    _scheduleAutoSave(isQuickSave: true); // Critical field - quick save
  }

  void setDescription(String description) {
    _description = description;
    notifyListeners();
    _scheduleAutoSave(isQuickSave: true); // Critical field - quick save
  }

  void setMealType(String mealType) {
    _mealType = mealType;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setPortions(int? portions) {
    _portions = portions;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setTimeMinutes(int? timeMinutes) {
    _timeMinutes = timeMinutes;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setRating(double? rating) {
    _rating = rating;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setSourceUrl(String? sourceUrl) {
    _sourceUrl = sourceUrl;
    notifyListeners();
    _scheduleAutoSave();
  }

  void setTagOverrides(TagOverrides? overrides) {
    _tagOverrides = overrides;
    notifyListeners();
    _scheduleAutoSave();
  }

  /// Sets the personal tag names directly (from PersonalTagSelector).
  /// Replaces all current tags with the provided list.
  ///
  /// HIGH-6: Filters empty strings from input before storing.
  void setPersonalTagNames(List<String> tagNames) {
    // HIGH-6: Always filter empty strings before storing
    final cleanedTags = tagNames.where((t) => t.trim().isNotEmpty).toList();

    // Add an empty field at the end for the DynamicListBuilder UI
    final tagsWithEmpty =
        cleanedTags.isNotEmpty ? [...cleanedTags, ''] : <String>[''];
    _tagsManager.updateItems(tagsWithEmpty);
    notifyListeners();
    _scheduleAutoSave();
  }

  /// HIGH-6: Returns cleaned tag names for persistence/sync (without empty UI field).
  List<String> get personalTagNamesForSync =>
      _tagsManager.values.where((t) => t.trim().isNotEmpty).toList();

  void setImageUrls(List<String> imageUrls, {bool skipAutoSave = false}) {
    _imageUrls = List<String>.from(imageUrls);
    notifyListeners();

    // RACE CONDITION GUARD: Don't trigger autosave during save operations or when explicitly skipped
    if (!skipAutoSave && !_isSaving && !_isForking) {
      _scheduleAutoSave(
          isQuickSave: true,
          skipIfBusy:
              true); // Images are important - quick save with busy check
    }
  }

  void addImageUrl(String imageUrl) {
    if (_imageUrls.length < maxImages) {
      _imageUrls.add(imageUrl);
      notifyListeners();
      _scheduleAutoSave(
          isQuickSave: true,
          skipIfBusy:
              true); // Images are important - quick save with busy check
    }
  }

  void removeImageUrl(String imageUrl) {
    _imageUrls.remove(imageUrl);
    notifyListeners();
    _scheduleAutoSave();
  }

  void moveImageToFirst(String imageUrl) {
    if (_imageUrls.remove(imageUrl)) {
      _imageUrls.insert(0, imageUrl);
      notifyListeners();
      _scheduleAutoSave();
    }
  }

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

  /// Set contextual error with intelligent message generation
  Future<void> setContextualError({
    required ErrorType errorType,
    required UserActionContext actionContext,
    String? technicalDetails,
    List<String>? recoveryActions,
    ErrorSeverity severity = ErrorSeverity.standard,
    Map<String, dynamic>? additionalData,
  }) async {
    final message = await ContextualErrorHandler.generateContextualError(
      errorType: errorType,
      actionContext: actionContext,
      technicalDetails: technicalDetails,
      recoveryActions: recoveryActions,
      severity: severity,
      additionalData: additionalData,
    );
    setError(message);
  }

  /// Set network-aware error with connectivity context
  Future<void> setNetworkAwareError({
    required String operation,
    String? technicalDetails,
    bool includeRecoveryAction = true,
  }) async {
    final message = await ContextualErrorHandler.generateNetworkAwareError(
      operation: operation,
      technicalDetails: technicalDetails,
      includeRecoveryAction: includeRecoveryAction,
    );
    setError(message);
  }

  /// Set permission-aware error with access context
  void setPermissionError({
    required String resource,
    required String action,
    String? reason,
    String? suggestedAction,
  }) {
    final message = ContextualErrorHandler.generatePermissionError(
      resource: resource,
      action: action,
      reason: reason,
      suggestedAction: suggestedAction,
    );
    setError(message);
  }

  /// Set error with recovery suggestions
  void setErrorWithRecovery({
    required String action,
    required String issue,
    String? recoveryAction,
  }) {
    final message = ContextualErrorHandler.generateErrorWithRecovery(
      action: action,
      issue: issue,
      recoveryAction: recoveryAction,
    );
    setError(message);
  }

  /// Show informational message for offline operations
  void setOfflineInfo(String operation) {
    final message = ContextualErrorHandler.generateOfflineInfo(operation);
    setError(message);
  }

  /// Schedule auto-save with optional quick save for critical fields
  /// [skipIfBusy] - Skip scheduling if autosave is already in progress (prevents race conditions)
  void _scheduleAutoSave({bool isQuickSave = false, bool skipIfBusy = false}) {
    // RACE CONDITION GUARD: Additional check for save operations at the form state level
    if (_isSaving || _isForking) {
      return;
    }

    final formData = _serializeFormData();
    _autoSaveManager.scheduleAutoSave(formData,
        isQuickSave: isQuickSave, skipIfBusy: skipIfBusy);
  }

  /// Serialize current form state for auto-save
  Map<String, dynamic> _serializeFormData() {
    return {
      'title': _title,
      'description': _description,
      'mealType': _mealType,
      'portions': _portions,
      'timeMinutes': _timeMinutes,
      'rating': _rating,
      'sourceUrl': _sourceUrl,
      'imageUrls': _imageUrls,
      'ingredients': _ingredientsManager.values,
      'instructions': _instructionsManager.values,
      'tags': _tagsManager.values,
      'tagOverrides': _tagOverrides?.toJson(),
    };
  }

  /// Load form state from auto-saved draft
  Future<bool> loadFromDraft(String draftId) async {
    final draftData = await _autoSaveManager.loadDraftData(draftId);
    if (draftData == null) return false;

    try {
      _title = (draftData['title'] as String?).orEmpty();
      _description = (draftData['description'] as String?).orEmpty();
      _mealType = draftData['mealType'] ?? 'Middag';
      _portions = draftData['portions'];
      _timeMinutes = draftData['timeMinutes'];
      _rating = draftData['rating'];
      _sourceUrl = draftData['sourceUrl'];
      _imageUrls =
          List<String>.from((draftData['imageUrls'] as List?).orEmpty());
      _tagOverrides = draftData['tagOverrides'] != null
          ? TagOverrides.fromJson(draftData['tagOverrides'])
          : null;

      final ingredients = List<String>.from(draftData['ingredients'] ?? ['']);
      final instructions = List<String>.from(draftData['instructions'] ?? ['']);
      final tags = List<String>.from(draftData['tags'] ?? ['']);

      _ingredientsManager.updateItems(ingredients);
      _instructionsManager.updateItems(instructions);
      _tagsManager.updateItems(tags);

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear current draft after successful save
  void clearCurrentDraft() {
    _autoSaveManager.clearCurrentDraft();
  }

  /// Get available drafts for recovery
  Future<List<DraftMetadata>> getAvailableDrafts() async {
    return _autoSaveManager.getAvailableDrafts();
  }

  /// Get current form data for external analysis
  Map<String, dynamic> serializeFormData() {
    return _serializeFormData();
  }

  /// Create Recipe from current form state
  Recipe createRecipe(
      {String? recipeId, List<String>? imageUrls, String? thumbnailUrl}) {
    final cleanIngredients = _ingredientsManager.values
        .where((ingredient) => ingredient.trim().isNotEmpty)
        .toList();
    final cleanInstructions = _instructionsManager.values
        .where((instruction) => instruction.trim().isNotEmpty)
        .toList();
    final cleanTagIds =
        _tagsManager.values.where((tag) => tag.trim().isNotEmpty).toList();

    // Build rich personalTags from IDs for dual-write
    List<RecipePersonalTag>? personalTags;
    if (cleanTagIds.isNotEmpty) {
      try {
        final tagVm = ServiceLocator.get<PersonalTagViewModel>();
        personalTags = cleanTagIds.map((id) {
          final tag = tagVm.getTagById(id);
          return RecipePersonalTag.manual(
            tagId: id,
            name: tag?.name ?? id,
          );
        }).toList();
      } catch (_) {
        // Fallback: create with ID as name if VM unavailable
        personalTags = cleanTagIds
            .map((id) => RecipePersonalTag.manual(tagId: id, name: id))
            .toList();
      }
    }

    return Recipe(
      core: RecipeCore(
        id: (recipeId ?? _originalRecipe?.id).orEmpty(),
        title: _title.trim(),
        description: _description.trim(),
        mealType: _mealType,
        portions: _portions,
        timeMinutes: _timeMinutes,
        rating: _rating,
        ingredients: cleanIngredients,
        instructions: cleanInstructions,
        personalTagIds: cleanTagIds,
        personalTags: personalTags,
        imageUrls: imageUrls ?? _imageUrls,
        thumbnailUrl: thumbnailUrl ?? _originalRecipe?.core.thumbnailUrl,
        sourceUrl: _sourceUrl?.trim(),
        createdAt: (_originalRecipe?.createdAt).orNow(),
        updatedAt: DateTime.now(),
        tagResult: _originalRecipe?.tagResult,
        tagOverrides: _tagOverrides,
      ),
      type: RecipeType.personal,
    );
  }

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
    _tagOverrides = null;

    _ingredientsManager.updateItems(['']);
    _instructionsManager.updateItems(['']);
    _tagsManager.updateItems(['']);

    notifyListeners();
  }

  @override
  void dispose() {
    _autoSaveManager.dispose();
    super.dispose();
  }
}
