// lib/viewmodels/recipe_form_viewmodel.dart
// REFACTORED: Split into focused managers for better maintainability

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

// Import focused managers
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';

/// Main coordinator for recipe form operations
/// Delegates to focused managers for specific responsibilities
class RecipeFormViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  // final AnalyticsService _analyticsService; // Currently unused
  final _uuid = const Uuid();

  // Focused managers
  late final RecipeFormState _state;
  late final RecipeCollaborativeManager _collaborativeManager;
  late final RecipeImageManager _imageManager;
  late final RecipePermissionManager _permissionManager;

  RecipeFormViewModel({
    UnifiedRecipeService? recipeService,
    AnalyticsService? analyticsService,
    Recipe? initialRecipe,
    bool isTemplate = false,
  }) : _recipeService = recipeService ?? sl<UnifiedRecipeService>() {
       // _analyticsService = analyticsService ?? sl<AnalyticsService>();
    
    // Initialize focused managers
    _state = RecipeFormState(initialRecipe: initialRecipe, isTemplate: isTemplate);
    _collaborativeManager = RecipeCollaborativeManager();
    _imageManager = RecipeImageManager();
    _permissionManager = RecipePermissionManager();

    // Set up listeners
    _setupManagerListeners();

    // Load permissions if editing existing recipe
    if (initialRecipe != null && !isTemplate) {
      _loadInitialPermissions(initialRecipe);
    }
  }

  // ===== GETTERS (Delegate to managers) =====

  // State getters
  Recipe? get originalRecipe => _state.originalRecipe;
  bool get isSaving => _state.isSaving;
  bool get isForking => _state.isForking;
  String? get error => _state.error;
  bool get hasError => _state.hasError;
  bool get isEditing => _state.isEditing;
  bool get isValid => _state.isValid;
  
  // Check if form has unsaved changes
  bool get hasUnsavedChanges {
    if (!isEditing || originalRecipe == null) return false;
    // Simple check - if any basic field has changed
    return title != (originalRecipe?.core.title ?? '') ||
           description != (originalRecipe?.core.description ?? '') ||
           mealType != (originalRecipe?.core.mealType ?? 'Middag');
  }

  // Form data getters
  String get title => _state.title;
  String get description => _state.description;
  String get mealType => _state.mealType;
  int? get portions => _state.portions;
  int? get timeMinutes => _state.timeMinutes;
  double? get rating => _state.rating;
  List<String> get imageUrls => _state.imageUrls;
  String? get sourceUrl => _state.sourceUrl;
  List<String> get ingredients => _state.ingredients;
  List<String> get instructions => _state.instructions;
  List<String> get tags => _state.tags;

  // Manager getters
  get ingredientsManager => _state.ingredientsManager;
  get instructionsManager => _state.instructionsManager;
  get tagsManager => _state.tagsManager;

  // Collaborative getters
  bool get isCollaborative => _collaborativeManager.isCollaborative;
  bool get isConnectedToFirebase => _collaborativeManager.isConnectedToFirebase;
  String get connectionStatusText => _collaborativeManager.connectionStatusText;
  List<UserProfile> get collaborativeParticipants => _collaborativeManager.collaborativeParticipants;
  get liveEditors => _collaborativeManager.liveEditors;

  // Image getters
  bool get isUploadingImage => _imageManager.isUploadingImage;
  String? get imageUploadError => _imageManager.imageUploadError;
  bool get hasImageUploadError => _imageManager.hasImageUploadError;
  bool get canAddMoreImages => _imageManager.canAddMoreImages;

  // Permission getters
  bool get canEdit => _permissionManager.canEdit;
  bool get canView => _permissionManager.canView;
  bool get canShare => _permissionManager.canShare;
  bool get canInvite => _permissionManager.canInvite;
  bool get canDelete => _permissionManager.canDelete;
  bool get isOwner => _permissionManager.isOwner;
  bool get hasPermissions => _permissionManager.hasPermissions;

  // Constants
  static const List<String> mealTypes = RecipeFormState.mealTypes;
  static const int maxImages = RecipeFormState.maxImages;

  // ===== ACTIONS =====

  /// Spara recept
  Future<Recipe?> saveRecipe() async {
    if (!_state.isValid) {
      _state.setError('Fyll i alla obligatoriska fält');
      return null;
    }

    if (!canEdit) {
      _state.setError('Du har inte behörighet att spara detta recept');
      return null;
    }

    _state.setSaving(true);
    _state.clearError();

    try {
      return await safeExecute<Recipe>(
        () async {
          // Skapa recept från state
          final recipe = _state.createRecipe(
            recipeId: _state.isEditing ? _state.originalRecipe!.id : _uuid.v4(),
          );

          // Spara via service
          Recipe savedRecipe;
          if (_state.isEditing) {
            final result = await _recipeService.personal.updateUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to update recipe');
            }
          } else {
            final result = await _recipeService.personal.addUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to create recipe');
            }
          }

          // Uppdatera collaborative state om aktivt
          if (isCollaborative) {
            await _collaborativeManager.updateRecipeInFirebase(savedRecipe);
          }

          AppLogger.info('Recept sparat: ${savedRecipe.id}');
          return savedRecipe;
        },
        operationName: 'Save Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );
    } catch (e) {
      AppLogger.error('Fel vid sparande av recept: $e');
      _state.setError('Kunde inte spara recept: $e');
      return null;
    } finally {
      _state.setSaving(false);
    }
  }

  /// Forka recept (skapa kopia)
  Future<Recipe?> forkRecipe() async {
    if (_state.originalRecipe == null) {
      _state.setError('Inget recept att forka');
      return null;
    }

    _state.setForking(true);
    _state.clearError();

    try {
      return await safeExecute<Recipe>(
        () async {
          // Skapa nytt recept från state
          final newRecipe = _state.createRecipe(recipeId: _uuid.v4());
          
          // Spara som nytt recipe
          final result = await _recipeService.personal.addUnifiedRecipe(newRecipe);
          if (!result.isSuccess) {
            throw Exception(result.message ?? 'Failed to fork recipe');
          }
          final savedRecipe = newRecipe;
          
          // _analyticsService.trackRecipeForked(_state.originalRecipe!.id, savedRecipe.id);
          AppLogger.info('Recept forkat: ${savedRecipe.id}');
          
          return savedRecipe;
        },
        operationName: 'Fork Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );
    } catch (e) {
      AppLogger.error('Fel vid forkning av recept: $e');
      _state.setError('Kunde inte forka recept: $e');
      return null;
    } finally {
      _state.setForking(false);
    }
  }

  /// Ta bort recept
  Future<bool> deleteRecipe() async {
    if (_state.originalRecipe == null) {
      _state.setError('Inget recept att ta bort');
      return false;
    }

    if (!canDelete) {
      _state.setError('Du har inte behörighet att ta bort detta recept');
      return false;
    }

    _state.clearError();

    final result = await safeExecute<bool>(
      () async {
        await _recipeService.deleteRecipe(_state.originalRecipe!.id);
        
        // Cleanup collaborative state
        if (isCollaborative) {
          await _collaborativeManager.leaveCollaborativeMode();
        }
        
        // Cleanup images
        await _imageManager.clearAllImages();
        
        // _analyticsService.trackRecipeDeleted(_state.originalRecipe!.id);
        AppLogger.info('Recept borttaget: ${_state.originalRecipe!.id}');
        
        return true;
      },
      operationName: 'Delete Recipe',
      customErrorMessage: null, // Handle error with custom logic below
    );

    if (result == null) {
      _state.setError('Kunde inte ta bort recept');
      return false;
    }

    return result;
  }

  // ===== FORM SETTERS (Delegate to state) =====

  void setTitle(String title) {
    _state.setTitle(title);
    _syncToCollaborative();
  }

  void setDescription(String description) {
    _state.setDescription(description);
    _syncToCollaborative();
  }

  void setMealType(String mealType) {
    _state.setMealType(mealType);
    _syncToCollaborative();
  }

  void setPortions(int? portions) {
    _state.setPortions(portions);
    _syncToCollaborative();
  }

  void setTimeMinutes(int? timeMinutes) {
    _state.setTimeMinutes(timeMinutes);
    _syncToCollaborative();
  }

  void setRating(double? rating) {
    _state.setRating(rating);
    _syncToCollaborative();
  }

  void setSourceUrl(String? sourceUrl) {
    _state.setSourceUrl(sourceUrl);
    _syncToCollaborative();
  }

  // ===== BACKWARD COMPATIBILITY SETTERS =====

  /// Set portions from double (for backward compatibility)
  void setPortionsFromDouble(double? portions) {
    setPortions(portions?.toInt());
  }

  /// Set time minutes from double (for backward compatibility)
  void setTimeMinutesFromDouble(double? timeMinutes) {
    setTimeMinutes(timeMinutes?.toInt());
  }

  // ===== IMAGE OPERATIONS (Delegate to image manager) =====

  Future<void> showImagePickerDialog(BuildContext context) async {
    await _imageManager.showImagePickerDialog(context);
    _syncImageUrls();
  }

  Future<void> addImageFromUrl(String imageUrl) async {
    await _imageManager.addImageFromUrl(imageUrl);
    _syncImageUrls();
  }

  Future<void> uploadImageFromFile(XFile imageFile) async {
    final recipeId = _state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _imageManager.uploadImageFromFile(imageFile, recipeId);
    _syncImageUrls();
  }

  Future<void> removeImageAndCleanup(String imageUrl) async {
    await _imageManager.removeImageAndCleanup(imageUrl);
    _syncImageUrls();
  }

  void moveImageToFirst(String imageUrl) {
    _imageManager.moveImageToFirst(imageUrl);
    _syncImageUrls();
  }

  void reorderImages(int oldIndex, int newIndex) {
    _imageManager.reorderImages(oldIndex, newIndex);
    _syncImageUrls();
  }

  // ===== MISSING API METHODS (for backward compatibility) =====

  /// Save fork - creates a copy of the current recipe
  Future<Recipe?> saveFork() async {
    return await forkRecipe();
  }

  /// Pick and upload single image
  Future<void> pickAndUploadImage(BuildContext context) async {
    await showImagePickerDialog(context);
  }

  /// Pick multiple images
  Future<void> pickMultipleImages(BuildContext context) async {
    await showImagePickerDialog(context);
  }

  /// Add image URL directly
  Future<void> addImageUrl(String imageUrl) async {
    await addImageFromUrl(imageUrl);
  }

  /// Remove image at specific index
  Future<void> removeImageAt(int index) async {
    if (index >= 0 && index < _imageManager.imageUrls.length) {
      final imageUrl = _imageManager.imageUrls[index];
      await removeImageAndCleanup(imageUrl);
    }
  }

  /// Set primary image (move to first position)
  void setPrimaryImage(String imageUrl) {
    moveImageToFirst(imageUrl);
  }

  /// Get ingredient controllers (for backward compatibility)
  List<TextEditingController> get ingredientControllers {
    return _state.ingredientsManager.controllers;
  }

  /// Get instruction controllers (for backward compatibility)
  List<TextEditingController> get instructionControllers {
    return _state.instructionsManager.controllers;
  }

  /// Get tag controllers (for backward compatibility)
  List<TextEditingController> get tagControllers {
    return _state.tagsManager.controllers;
  }

  /// Update ingredient at index
  void updateIngredient(int index, String value) {
    _state.ingredientsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new ingredient
  void addIngredient() {
    _state.ingredientsManager.add('');
    _syncToCollaborative();
  }

  /// Remove ingredient at index
  void removeIngredient(int index) {
    _state.ingredientsManager.removeAt(index);
    _syncToCollaborative();
  }

  /// Update instruction at index
  void updateInstruction(int index, String value) {
    _state.instructionsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new instruction
  void addInstruction() {
    _state.instructionsManager.add('');
    _syncToCollaborative();
  }

  /// Remove instruction at index
  void removeInstruction(int index) {
    _state.instructionsManager.removeAt(index);
    _syncToCollaborative();
  }

  /// Update tag at index
  void updateTag(int index, String value) {
    _state.tagsManager.updateAt(index, value);
    _syncToCollaborative();
  }

  /// Add new tag
  void addTag() {
    _state.tagsManager.add('');
    _syncToCollaborative();
  }

  /// Remove tag at index
  void removeTag(int index) {
    _state.tagsManager.removeAt(index);
    _syncToCollaborative();
  }

  /// Get edit mode (for backward compatibility)
  String? get editMode {
    return _permissionManager.editMode?.name;
  }

  /// Get edit mode as enum
  EditMode? get editModeEnum {
    return _permissionManager.editMode;
  }

  /// Check if in edit mode
  bool get isEditMode => canEdit;

  /// Get function getters (for backward compatibility)
  Function(String) get addImageUrlFunc => addImageFromUrl;
  Function(int) get removeImageAtFunc => (int index) => removeImageAt(index);
  Function(String) get setPrimaryImageFunc => (String url) => setPrimaryImage(url);
  Function(int, String) get updateIngredientFunc => (int index, String value) => updateIngredient(index, value);
  Function() get addIngredientFunc => () => addIngredient();
  Function(int) get removeIngredientFunc => (int index) => removeIngredient(index);
  Function(int, String) get updateInstructionFunc => (int index, String value) => updateInstruction(index, value);
  Function() get addInstructionFunc => () => addInstruction();
  Function(int) get removeInstructionFunc => (int index) => removeInstruction(index);
  Function(int, String) get updateTagFunc => (int index, String value) => updateTag(index, value);
  Function() get addTagFunc => () => addTag();
  Function(int) get removeTagFunc => (int index) => removeTag(index);

  // ===== COLLABORATIVE OPERATIONS (Delegate to collaborative manager) =====

  Future<void> enableCollaborativeMode() async {
    if (_state.originalRecipe == null) return;
    
    await _collaborativeManager.enableCollaborativeMode(_state.originalRecipe!);
  }

  Future<void> inviteUserToCollaboration(String userId, String userDisplayName, ResourcePermission permission) async {
    await _collaborativeManager.inviteUserToCollaboration(userId, userDisplayName, permission);
  }

  Future<void> removeUserFromCollaboration(String userId) async {
    await _collaborativeManager.removeUserFromCollaboration(userId);
  }

  Future<void> leaveCollaborativeMode() async {
    await _collaborativeManager.leaveCollaborativeMode();
  }

  // ===== PERMISSION OPERATIONS (Delegate to permission manager) =====

  Future<void> updateUserPermission(String userId, ResourcePermission permission) async {
    if (_state.originalRecipe == null) return;
    
    await _permissionManager.updateUserPermission(_state.originalRecipe!.id, userId, permission);
  }

  Future<void> shareRecipeWithUser(String userId, ResourcePermission permission) async {
    if (_state.originalRecipe == null) return;
    
    await _permissionManager.shareRecipeWithUser(_state.originalRecipe!.id, userId, permission);
  }

  bool canPerformAction(String action) {
    return _permissionManager.canPerformAction(action);
  }

  bool canEditField(String fieldName) {
    return _permissionManager.canEditField(fieldName);
  }

  // ===== PRIVATE METHODS =====

  void _setupManagerListeners() {
    _state.addListener(_onStateChanged);
    _collaborativeManager.addListener(_onCollaborativeChanged);
    _imageManager.addListener(_onImageChanged);
    _permissionManager.addListener(_onPermissionChanged);
  }

  void _onStateChanged() {
    notifyListeners();
  }

  void _onCollaborativeChanged() {
    notifyListeners();
  }

  void _onImageChanged() {
    notifyListeners();
  }

  void _onPermissionChanged() {
    notifyListeners();
  }

  Future<void> _loadInitialPermissions(Recipe recipe) async {
    await safeExecute(
      () async {
        await _permissionManager.loadPermissions(recipe);
      },
      operationName: 'Load Initial Permissions',
      customErrorMessage: 'Fel vid laddning av permissions',
    );
  }

  void _syncToCollaborative() {
    if (isCollaborative && _state.originalRecipe != null) {
      final recipe = _state.createRecipe(recipeId: _state.originalRecipe!.id);
      _collaborativeManager.updateRecipeInFirebase(recipe);
    }
  }

  void _syncImageUrls() {
    _state.setImageUrls(_imageManager.imageUrls);
    _syncToCollaborative();
  }

  @override
  void dispose() {
    _state.dispose();
    _collaborativeManager.dispose();
    _imageManager.dispose();
    _permissionManager.dispose();
    super.dispose();
  }
}