// lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_persistence_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_coordinator.dart';

/// Mixin providing backward compatibility methods for RecipeFormViewModel.
///
/// **Purpose:**
/// Maintains existing API surface for views that haven't been migrated to new architecture.
/// All methods delegate to appropriate managers while preserving legacy behavior.
///
/// **Categories:**
/// - Legacy save/fork operations
/// - Image picker convenience methods
/// - Controller getters for form fields
/// - List manipulation methods (ingredients, instructions, tags)
/// - Permission getters
/// - Function getters for callbacks
///
/// **Dependencies (required by classes using this mixin):**
/// - RecipeFormState state
/// - RecipeImageManager imageManager
/// - RecipePermissionManager permissionManager
/// - RecipePersistenceManager persistenceManager
/// - RecipeFormCoordinator coordinator
mixin RecipeBackwardCompatibilityMixin on ChangeNotifier {
  // These must be implemented by the class using this mixin
  RecipeFormState get state;
  RecipeImageManager get imageManager;
  RecipePermissionManager get permissionManager;
  RecipePersistenceManager get persistenceManager;
  RecipeFormCoordinator get coordinator;
  bool get isCollaborative;

  // ===== LEGACY SAVE/FORK OPERATIONS =====

  /// Save fork - creates a copy of the current recipe
  /// @deprecated Use forkRecipe() instead
  Future<Recipe?> saveFork() async {
    return await persistenceManager.forkRecipe();
  }

  // ===== IMAGE PICKER CONVENIENCE METHODS =====

  /// Pick and upload single image
  /// @deprecated Use showImagePickerDialog() instead
  Future<void> pickAndUploadImage(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickAndUploadImage called');
    await showImagePickerDialog(context);
  }

  /// Pick single image from camera (direct, no dialog)
  Future<void> pickImageFromCamera(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickImageFromCamera called');
    final recipeId = state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await imageManager.pickImageFromCamera(context, recipeId: recipeId);
    coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Pick single image from gallery (direct, no dialog)
  Future<void> pickImageFromGallery(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickImageFromGallery called');
    final recipeId = state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await imageManager.pickImageFromGallery(context, recipeId: recipeId);
    coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Pick multiple images from gallery (direct, no dialog)
  Future<void> pickMultipleImagesFromGallery(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickMultipleImagesFromGallery called');
    final recipeId = state.originalRecipe?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await imageManager.pickMultipleImagesFromGallery(context, recipeId: recipeId);
    coordinator.syncImageUrls(isCollaborative: isCollaborative);
  }

  /// Legacy method - Pick multiple images (shows dialog)
  /// @deprecated Use showImagePickerDialog() instead
  Future<void> pickMultipleImages(BuildContext context) async {
    AppLogger.info('🎯 VIEWMODEL: pickMultipleImages called');
    await showImagePickerDialog(context);
  }

  /// Add image URL directly
  /// @deprecated Use addImageFromUrl() instead
  Future<void> addImageUrl(String imageUrl) async {
    await addImageFromUrl(imageUrl);
  }

  /// Remove image at specific index
  Future<void> removeImageAt(int index) async {
    if (index >= 0 && index < imageManager.imageUrls.length) {
      final imageUrl = imageManager.imageUrls[index];
      await removeImageAndCleanup(imageUrl);
    }
  }

  /// Set primary image (move to first position)
  void setPrimaryImage(String imageUrl) {
    moveImageToFirst(imageUrl);
  }

  // ===== CONTROLLER GETTERS (for backward compatibility) =====

  /// Get ingredient controllers (for backward compatibility)
  List<TextEditingController> get ingredientControllers {
    debugPrint('🎯 VIEWMODEL_DEBUG: ingredientControllers called');
    final controllers = state.ingredientsManager.controllers;
    debugPrint('🎯 VIEWMODEL_DEBUG: ingredientControllers returning ${controllers.length} controllers');
    return controllers;
  }

  /// Get instruction controllers (for backward compatibility)
  List<TextEditingController> get instructionControllers {
    debugPrint('🎯 VIEWMODEL_DEBUG: instructionControllers called');
    final controllers = state.instructionsManager.controllers;
    debugPrint('🎯 VIEWMODEL_DEBUG: instructionControllers returning ${controllers.length} controllers');
    return controllers;
  }

  /// Get tag controllers (for backward compatibility)
  List<TextEditingController> get tagControllers {
    debugPrint('🎯 VIEWMODEL_DEBUG: tagControllers called');
    final controllers = state.tagsManager.controllers;
    debugPrint('🎯 VIEWMODEL_DEBUG: tagControllers returning ${controllers.length} controllers');
    return controllers;
  }

  // ===== INGREDIENT MANAGEMENT =====

  /// Update ingredient at index
  void updateIngredient(int index, String value) {
    state.ingredientsManager.updateAt(index, value);
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Add new ingredient
  void addIngredient() {
    state.ingredientsManager.add('');
    notifyListeners();
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Remove ingredient at index
  void removeIngredient(int index) {
    state.ingredientsManager.removeAt(index);
    notifyListeners();
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  // ===== INSTRUCTION MANAGEMENT =====

  /// Update instruction at index
  void updateInstruction(int index, String value) {
    state.instructionsManager.updateAt(index, value);
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Add new instruction
  void addInstruction() {
    state.instructionsManager.add('');
    notifyListeners();
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Remove instruction at index
  void removeInstruction(int index) {
    state.instructionsManager.removeAt(index);
    notifyListeners();
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  // ===== TAG MANAGEMENT =====

  /// Update tag at index
  void updateTag(int index, String value) {
    state.tagsManager.updateAt(index, value);
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Add new tag
  void addTag() {
    state.tagsManager.add('');
    notifyListeners();
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  /// Remove tag at index
  void removeTag(int index) {
    state.tagsManager.removeAt(index);
    notifyListeners();
    coordinator.syncToCollaborative(isCollaborative: isCollaborative);
  }

  // ===== PERMISSION GETTERS =====

  /// Get edit mode (for backward compatibility)
  String? get editMode {
    return permissionManager.editMode;
  }

  /// Get edit mode as enum
  EditMode? get editModeEnum {
    return permissionManager.editModeEnum;
  }

  /// Check if in edit mode
  bool get isEditMode => permissionManager.canEdit;

  // ===== FUNCTION GETTERS (for backward compatibility) =====

  /// Function getter for adding image URL
  Function(String) get addImageUrlFunc => addImageFromUrl;

  /// Function getter for removing image at index
  Function(int) get removeImageAtFunc => (int index) => removeImageAt(index);

  /// Function getter for setting primary image
  Function(String) get setPrimaryImageFunc => (String url) => setPrimaryImage(url);

  /// Function getter for updating ingredient
  Function(int, String) get updateIngredientFunc => (int index, String value) => updateIngredient(index, value);

  /// Function getter for adding ingredient
  Function() get addIngredientFunc => () => addIngredient();

  /// Function getter for removing ingredient
  Function(int) get removeIngredientFunc => (int index) => removeIngredient(index);

  /// Function getter for updating instruction
  Function(int, String) get updateInstructionFunc => (int index, String value) => updateInstruction(index, value);

  /// Function getter for adding instruction
  Function() get addInstructionFunc => () => addInstruction();

  /// Function getter for removing instruction
  Function(int) get removeInstructionFunc => (int index) => removeInstruction(index);

  /// Function getter for updating tag
  Function(int, String) get updateTagFunc => (int index, String value) => updateTag(index, value);

  /// Function getter for adding tag
  Function() get addTagFunc => () => addTag();

  /// Function getter for removing tag
  Function(int) get removeTagFunc => (int index) => removeTag(index);

  // ===== REQUIRED METHODS (must be implemented by class using mixin) =====

  /// Show image picker dialog - must be implemented by class
  Future<void> showImagePickerDialog(BuildContext context);

  /// Add image from URL - must be implemented by class
  Future<void> addImageFromUrl(String imageUrl);

  /// Remove image and cleanup - must be implemented by class
  Future<void> removeImageAndCleanup(String imageUrl);

  /// Move image to first position - must be implemented by class
  void moveImageToFirst(String imageUrl);
}
