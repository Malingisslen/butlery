// lib/viewmodels/recipe_form/recipe_persistence_manager.dart

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';

/// Manages recipe persistence operations (save, fork, delete) with atomic coordination.
/// **Responsibilities:**
/// - Atomic save operations with race condition protection
/// - Recipe forking with data duplication
/// - Recipe deletion with cleanup coordination
/// - Pending operation management
/// - Image upload coordination during save
/// - Collaborative state synchronization
/// **Dependencies:**
/// - RecipeFormState: Form data and validation
/// - UnifiedRecipeService: Recipe persistence
/// - RecipeImageManager: Image upload coordination
/// - RecipeCollaborativeManager: Collaborative sync
/// - RecipePermissionManager: Permission validation
class RecipePersistenceManager with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  final RecipeFormState _state;
  final RecipeImageManager _imageManager;
  final RecipeCollaborativeManager _collaborativeManager;
  final RecipePermissionManager _permissionManager;
  final _uuid = const Uuid();

  // Atomic save coordination
  bool _isSaveInProgress = false;
  String? _currentSaveOperationId;
  Recipe? _lastSaveResult;
  final Map<String, Completer<Recipe?>> _pendingSaveOperations = {};

  // Disposal tracking
  bool _disposed = false;
  bool get disposed => _disposed;

  RecipePersistenceManager({
    required UnifiedRecipeService recipeService,
    required RecipeFormState state,
    required RecipeImageManager imageManager,
    required RecipeCollaborativeManager collaborativeManager,
    required RecipePermissionManager permissionManager,
  })  : _recipeService = recipeService,
        _state = state,
        _imageManager = imageManager,
        _collaborativeManager = collaborativeManager,
        _permissionManager = permissionManager;

  // ===== PUBLIC API =====

  /// CRITICAL FIX: Atomic save operation with comprehensive race condition protection and image consistency.
  /// Returns saved Recipe instance if successful, null if validation fails or save errors occur.
  /// Implements atomic save coordination ensuring:
  /// - Single concurrent save operation per recipe
  /// - Image upload completion before final recipe persistence
  /// - Auto-save conflict prevention and coordination
  /// - State consistency throughout save operation
  /// - Comprehensive disposal protection
  /// **Atomic Save Process:**
  /// - Save operation locking to prevent concurrent saves
  /// - Image upload completion coordination for consistency
  /// - Form validation with comprehensive field checking
  /// - Permission validation for save operation authorization
  /// - Service-coordinated recipe persistence with atomic state management
  /// - Collaborative state synchronization for real-time updates
  Future<Recipe?> saveRecipe({
    required bool isCollaborative,
    required void Function() onNotify,
  }) async {
    // CRITICAL FIX: Prevent disposal-related race conditions
    if (_disposed) {
      AppLogger.warning('⚠️ Save operation prevented - Manager disposed');
      return null;
    }

    // CRITICAL FIX: Prevent concurrent save operations
    if (_isSaveInProgress) {
      AppLogger.warning('⚠️ Save operation already in progress - queuing request');
      final operationId = _uuid.v4();
      final completer = Completer<Recipe?>();
      _pendingSaveOperations[operationId] = completer;

      // Wait for current save to complete, then return same result
      try {
        await Future.doWhile(() async {
          if (_disposed) return false;
          if (!_isSaveInProgress) return false;
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        });

        // Return the result of the completed save operation
        final result = _lastSaveResult;
        _pendingSaveOperations.remove(operationId);
        completer.complete(result);
        return result;
      } catch (e) {
        _pendingSaveOperations.remove(operationId);
        completer.completeError(e);
        rethrow;
      }
    }

    // CRITICAL FIX: Check if auto-save is in progress and wait for it
    if (_state.isAutoSaving) {
      AppLogger.info('⏳ Waiting for auto-save to complete before manual save...');
      await Future.doWhile(() async {
        if (_disposed) return false;
        if (!_state.isAutoSaving) return false;
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      });
    }

    if (!_state.isValid) {
      _state.setError('Fyll i alla obligatoriska fält');
      return null;
    }

    if (!_permissionManager.canEdit) {
      _state.setError('Du har inte behörighet att spara detta recept');
      return null;
    }

    // CRITICAL FIX: Set atomic save lock
    _isSaveInProgress = true;
    _currentSaveOperationId = _uuid.v4();
    AppLogger.info('🔒 Starting atomic save operation: $_currentSaveOperationId');

    _state.setSaving(true);
    _state.clearError();

    try {
      final result = await safeExecute<Recipe>(
        () async {
          // CRITICAL FIX: Prevent disposal during save operation
          if (_disposed) {
            throw Exception('Save operation cancelled - Manager disposed');
          }

          // Create recipe ID for both metadata and image uploads
          final recipeId = _state.isEditing ? _state.originalRecipe!.id : _uuid.v4();

          // Update image manager with actual recipe ID
          _imageManager.setActualRecipeId(recipeId);

          AppLogger.info('🚀 Starting atomic recipe save process for: $recipeId');

          // CRITICAL FIX: Atomic image upload coordination for consistency
          if (_imageManager.pendingImages.isNotEmpty) {
            AppLogger.info('📤 Waiting for ${_imageManager.pendingImages.length} images to upload before save...');

            try {
              // CRITICAL FIX: Wait for all images to upload before saving recipe
              await _imageManager.uploadPendingImagesInBackground(
                recipeId,
                onProgress: (completed, total) {
                  AppLogger.info('📈 Upload progress: $completed/$total');
                  // CRITICAL FIX: Disposal-safe progress updates
                  if (!_disposed) onNotify();
                },
              );

              // CRITICAL FIX: Verify upload completion before proceeding
              if (_imageManager.pendingImages.isNotEmpty) {
                throw Exception('Image upload incomplete - cannot save recipe');
              }

              AppLogger.info('✅ All images uploaded successfully, proceeding with recipe save');
            } catch (e) {
              AppLogger.error('❌ Image upload failed during recipe save: $e');
              throw Exception('Failed to upload images: $e');
            }
          }

          // CRITICAL FIX: Final disposal check before recipe persistence
          if (_disposed) {
            throw Exception('Save operation cancelled - Manager disposed during image upload');
          }

          // CRITICAL FIX: Create recipe with atomic image URL consistency
          // Use only uploaded Firebase URLs to ensure image consistency
          final validImageUrls = _imageManager.validImageUrls;
          AppLogger.info('📝 Creating recipe with ${validImageUrls.length} validated image URLs');

          final recipe = _state.createRecipe(
            recipeId: recipeId,
            imageUrls: validImageUrls, // Only use validated Firebase URLs
          );

          // CRITICAL FIX: Atomic recipe persistence with state consistency
          Recipe savedRecipe;
          if (_state.isEditing) {
            AppLogger.info('📝 Updating existing recipe: $recipeId');
            final result = await _recipeService.personal.updateUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to update recipe');
            }
          } else {
            AppLogger.info('📝 Creating new recipe: $recipeId');
            final result = await _recipeService.personal.addUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
            } else {
              throw Exception(result.message ?? 'Failed to create recipe');
            }
          }

          // CRITICAL FIX: Final disposal check after persistence
          if (_disposed) {
            AppLogger.warning('⚠️ Save completed but Manager disposed - skipping state updates');
            return savedRecipe; // Return saved recipe even if state updates are skipped
          }

          AppLogger.info('✅ Recipe saved atomically with ${savedRecipe.imageUrls.length} images: ${savedRecipe.id}');

          // CRITICAL FIX: Atomic collaborative state update
          if (isCollaborative && !_disposed) {
            try {
              await _collaborativeManager.updateRecipeInFirebase(savedRecipe);
              AppLogger.info('🔄 Collaborative state updated for recipe: ${savedRecipe.id}');
            } catch (e) {
              AppLogger.error('❌ Failed to update collaborative state: $e');
              // Don't fail the entire save operation for collaborative update issues
            }
          }

          return savedRecipe;
        },
        operationName: 'Save Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );

      // CRITICAL FIX: Store result for pending operations
      _lastSaveResult = result;

      // Check if safeExecute returned null (indicating an error)
      if (result == null) {
        if (!_disposed) {
          _state.setError('Kunde inte spara recept');
        }
      } else {
        // CRITICAL FIX: Safe state updates after successful save
        if (!_disposed) {
          // Clear auto-save draft after successful save
          _state.clearCurrentDraft();
          AppLogger.info('✅ Save operation completed successfully: ${result.id}');
        }
      }

      // CRITICAL FIX: Complete any pending save operations
      _completePendingSaveOperations(result);

      return result;
    } catch (e) {
      AppLogger.error('❌ Atomic save operation failed: $e');

      // CRITICAL FIX: Safe error handling with disposal protection
      if (!_disposed) {
        _state.setError('Kunde inte spara recept: $e');
      }

      // CRITICAL FIX: Complete pending operations with error
      _completePendingSaveOperations(null);

      return null;
    } finally {
      // CRITICAL FIX: Always release atomic save lock
      _isSaveInProgress = false;
      _currentSaveOperationId = null;

      // CRITICAL FIX: Safe state cleanup
      if (!_disposed) {
        _state.setSaving(false);
      }

      AppLogger.info('🔓 Atomic save operation completed and lock released');
    }
  }

  /// Forks recipe creating independent copy with comprehensive duplication and state management.
  /// Returns forked Recipe instance if successful, null if operation fails.
  /// Performs complete recipe forking flow including data duplication, service coordination,
  /// and analytics tracking for comprehensive recipe copy functionality and user workflow support.
  /// **Fork Process:**
  /// - Recipe data duplication with new unique identifier
  /// - Service-coordinated recipe creation with error handling
  /// - Analytics tracking for fork operation monitoring
  /// - State management with progress indication
  Future<Recipe?> forkRecipe() async {
    if (_state.originalRecipe == null) {
      _state.setError('Inget recept att forka');
      return null;
    }

    _state.setForking(true);
    _state.clearError();

    try {
      final result = await safeExecute<Recipe>(
        () async {
          // Skapa nytt recept från state
          final newRecipe = _state.createRecipe(recipeId: _uuid.v4());

          // Spara som nytt recipe
          final saveResult = await _recipeService.personal.addUnifiedRecipe(newRecipe);
          if (!saveResult.isSuccess) {
            throw Exception(saveResult.message ?? 'Failed to fork recipe');
          }
          final savedRecipe = newRecipe;
          AppLogger.info('Recept forkat: ${savedRecipe.id}');

          return savedRecipe;
        },
        operationName: 'Fork Recipe',
        customErrorMessage: null, // Handle error with custom logic below
      );

      // Check if safeExecute returned null (indicating an error)
      if (result == null) {
        _state.setError('Kunde inte forka recept');
      } else {
        // CRITICAL: Clear auto-save draft after successful fork operation
        // This ensures consistency with saveRecipe() behavior and prevents
        // orphaned drafts from confusing users with recovery prompts
        if (!_disposed) {
          _state.clearCurrentDraft();
        }
      }

      return result;
    } catch (e) {
      AppLogger.error('Fel vid forkning av recept: $e');
      _state.setError('Kunde inte forka recept: $e');
      return null;
    } finally {
      _state.setForking(false);
    }
  }

  /// Deletes recipe with comprehensive cleanup, permission validation, and collaborative coordination.
  /// Returns true if deletion succeeds, false if operation fails or permission denied.
  /// Performs complete recipe deletion flow including permission validation, service coordination,
  /// collaborative cleanup, and resource management for comprehensive recipe removal and cleanup.
  /// **Deletion Process:**
  /// - Permission validation for delete operation authorization
  /// - Service-coordinated recipe deletion with error handling
  /// - Collaborative state cleanup and participant notification
  /// - Image and resource cleanup for complete removal
  Future<bool> deleteRecipe({required bool isCollaborative}) async {
    if (_state.originalRecipe == null) {
      _state.setError('Inget recept att ta bort');
      return false;
    }

    if (!_permissionManager.canDelete) {
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

        await _imageManager.clearAllImages();
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

  // ===== PRIVATE HELPERS =====

  /// Complete all pending save operations with the given result
  void _completePendingSaveOperations(Recipe? result) {
    for (final completer in _pendingSaveOperations.values) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
    _pendingSaveOperations.clear();
  }

  // ===== DISPOSAL =====

  void dispose() {
    _disposed = true;
    _pendingSaveOperations.clear();
  }
}
