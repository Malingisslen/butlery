// lib/viewmodels/recipe_form/recipe_persistence_manager.dart

import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';
import 'package:butlery/services/parsing/feedback/recipe_diff_calculator.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';

/// Manages recipe persistence with atomic save, fork, and delete operations.
class RecipePersistenceManager with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  final RecipeFormState _state;
  final RecipeImageManager _imageManager;
  final RecipeCollaborativeManager _collaborativeManager;
  final RecipePermissionManager _permissionManager;
  final _uuid = const Uuid();

  bool _isSaveInProgress = false;
  String? _currentSaveOperationId;
  Recipe? _lastSaveResult;
  final Map<String, Completer<Recipe?>> _pendingSaveOperations = {};

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

  /// Saves recipe with atomic coordination, preventing concurrent saves and ensuring image upload completion.
  Future<Recipe?> saveRecipe({
    required bool isCollaborative,
    required void Function() onNotify,
  }) async {
    if (_disposed) {
      AppLogger.warning('⚠️ Save operation prevented - Manager disposed');
      return null;
    }

    if (_isSaveInProgress) {
      AppLogger.warning('⚠️ Save operation already in progress - queuing request');
      final operationId = _uuid.v4();
      final completer = Completer<Recipe?>();
      _pendingSaveOperations[operationId] = completer;

      try {
        await Future.doWhile(() async {
          if (_disposed) return false;
          if (!_isSaveInProgress) return false;
          await Future.delayed(const Duration(milliseconds: 100));
          return true;
        });

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

    _isSaveInProgress = true;
    _currentSaveOperationId = _uuid.v4();
    AppLogger.info('🔒 Starting atomic save operation: $_currentSaveOperationId');

    _state.setSaving(true);
    _state.clearError();

    try {
      final result = await safeExecute<Recipe>(
        () async {
          if (_disposed) {
            throw Exception('Save operation cancelled - Manager disposed');
          }

          final recipeId = _state.isEditing ? _state.originalRecipe!.id : _uuid.v4();
          _imageManager.setActualRecipeId(recipeId);

          AppLogger.info('🚀 Starting atomic recipe save process for: $recipeId');

          if (_imageManager.pendingImages.isNotEmpty) {
            AppLogger.info('📤 Waiting for ${_imageManager.pendingImages.length} images to upload before save...');

            try {
              await _imageManager.uploadPendingImagesInBackground(
                recipeId,
                onProgress: (completed, total) {
                  AppLogger.info('📈 Upload progress: $completed/$total');
                  if (!_disposed) onNotify();
                },
              );

              if (_imageManager.pendingImages.isNotEmpty) {
                throw Exception('Image upload incomplete - cannot save recipe');
              }

              AppLogger.info('✅ All images uploaded successfully, proceeding with recipe save');
            } catch (e) {
              AppLogger.error('❌ Image upload failed during recipe save: $e');
              throw Exception('Failed to upload images: $e');
            }
          }

          if (_disposed) {
            throw Exception('Save operation cancelled - Manager disposed during image upload');
          }

          final validImageUrls = _imageManager.validImageUrls;
          AppLogger.info('📝 Creating recipe with ${validImageUrls.length} validated image URLs');

          final recipe = _state.createRecipe(
            recipeId: recipeId,
            imageUrls: validImageUrls,
          );

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

          if (_disposed) {
            AppLogger.warning('⚠️ Save completed but Manager disposed - skipping state updates');
            return savedRecipe;
          }

          AppLogger.info('✅ Recipe saved atomically with ${savedRecipe.imageUrls.length} images: ${savedRecipe.id}');

          if (isCollaborative && !_disposed) {
            try {
              await _collaborativeManager.updateRecipeInFirebase(savedRecipe);
              AppLogger.info('🔄 Collaborative state updated for recipe: ${savedRecipe.id}');
            } catch (e) {
              AppLogger.error('❌ Failed to update collaborative state: $e');
            }
          }

          return savedRecipe;
        },
        operationName: 'Save Recipe',
        customErrorMessage: null,
      );

      _lastSaveResult = result;

      if (result == null) {
        if (!_disposed) {
          _state.setError('Kunde inte spara recept');
        }
      } else {
        if (!_disposed) {
          _state.clearCurrentDraft();
          AppLogger.info('✅ Save operation completed successfully: ${result.id}');
          _trackParsingCorrectionsInBackground(result);
        }
      }

      _completePendingSaveOperations(result);

      return result;
    } catch (e) {
      AppLogger.error('❌ Atomic save operation failed: $e');

      if (!_disposed) {
        _state.setError('Kunde inte spara recept: $e');
      }

      _completePendingSaveOperations(null);

      return null;
    } finally {
      _isSaveInProgress = false;
      _currentSaveOperationId = null;

      if (!_disposed) {
        _state.setSaving(false);
      }

      AppLogger.info('🔓 Atomic save operation completed and lock released');
    }
  }

  /// Forks recipe creating an independent copy.
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
          final newRecipe = _state.createRecipe(recipeId: _uuid.v4());

          final saveResult = await _recipeService.personal.addUnifiedRecipe(newRecipe);
          if (!saveResult.isSuccess) {
            throw Exception(saveResult.message ?? 'Failed to fork recipe');
          }
          final savedRecipe = newRecipe;
          AppLogger.info('Recept forkat: ${savedRecipe.id}');

          return savedRecipe;
        },
        operationName: 'Fork Recipe',
        customErrorMessage: null,
      );

      if (result == null) {
        _state.setError('Kunde inte forka recept');
      } else {
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

  /// Deletes recipe with collaborative cleanup and permission validation.
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

        if (isCollaborative) {
          await _collaborativeManager.leaveCollaborativeMode();
        }

        await _imageManager.clearAllImages();
        AppLogger.info('Recept borttaget: ${_state.originalRecipe!.id}');

        return true;
      },
      operationName: 'Delete Recipe',
      customErrorMessage: null,
    );

    if (result == null) {
      _state.setError('Kunde inte ta bort recept');
      return false;
    }

    return result;
  }

  void _completePendingSaveOperations(Recipe? result) {
    for (final completer in _pendingSaveOperations.values) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }
    _pendingSaveOperations.clear();
  }

  /// Track parsing corrections for imported recipes (fire-and-forget).
  void _trackParsingCorrectionsInBackground(Recipe savedRecipe) {
    if (savedRecipe.sourceUrl == null || savedRecipe.sourceUrl!.isEmpty) {
      return;
    }

    final originalParsed = _state.originalParsedRecipe;
    if (originalParsed == null) {
      return;
    }

    Future(() async {
      try {
        final diffCalculator = ServiceLocator.tryGet<RecipeDiffCalculator>();
        final correctionRepo = ServiceLocator.tryGet<ParsingCorrectionRepository>();

        if (diffCalculator == null || correctionRepo == null) {
          AppLogger.debug('📊 Parsing correction tracking not available (services not registered)');
          return;
        }

        final userId = _recipeService.currentUserId;
        if (userId == null) {
          return;
        }

        final correction = diffCalculator.calculateDiff(
          original: originalParsed,
          corrected: savedRecipe,
          userId: userId,
        );

        if (correction != null) {
          await correctionRepo.save(correction);
          AppLogger.info(
            '📊 Tracked ${correction.totalCorrections} parsing corrections '
            'for ${correction.domain ?? correction.source.name}',
          );
        } else {
          AppLogger.debug('📊 No parsing corrections detected');
        }
      } catch (e) {
        AppLogger.warning('Failed to track parsing corrections: $e');
      }
    });

    _state.setOriginalParsedRecipe(null);
  }

  void dispose() {
    _disposed = true;
    _pendingSaveOperations.clear();
  }
}
