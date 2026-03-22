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
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Manages recipe persistence with atomic save, fork, and delete operations.
class RecipePersistenceManager with ErrorHandlingMixin {
  final UnifiedRecipeService _recipeService;
  final RecipeFormState _state;
  final RecipeImageManager _imageManager;
  final RecipeCollaborativeManager _collaborativeManager;
  final RecipePermissionManager _permissionManager;
  final AnalyticsService? _analyticsService;
  final _uuid = const Uuid();

  bool _isSaveInProgress = false;
  String? _currentSaveOperationId;
  Recipe? _lastSaveResult;
  final Map<String, Completer<Recipe?>> _pendingSaveOperations = {};

  bool _isFirstRecipe = false;
  bool get isFirstRecipe => _isFirstRecipe;

  bool _disposed = false;
  bool get disposed => _disposed;

  RecipePersistenceManager({
    required UnifiedRecipeService recipeService,
    required RecipeFormState state,
    required RecipeImageManager imageManager,
    required RecipeCollaborativeManager collaborativeManager,
    required RecipePermissionManager permissionManager,
    AnalyticsService? analyticsService,
  })  : _recipeService = recipeService,
        _state = state,
        _imageManager = imageManager,
        _collaborativeManager = collaborativeManager,
        _permissionManager = permissionManager,
        _analyticsService =
            analyticsService ?? ServiceLocator.tryGet<AnalyticsService>();

  /// Saves recipe with atomic coordination, preventing concurrent saves and ensuring image upload completion.
  Future<Recipe?> saveRecipe({
    required bool isCollaborative,
    required void Function() onNotify,
  }) async {
    _isFirstRecipe = false;

    if (_disposed) {
      AppLogger.warning('⚠️ Save operation prevented - Manager disposed');
      return null;
    }

    if (_isSaveInProgress) {
      AppLogger.warning(
          '⚠️ Save operation already in progress - queuing request');
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
      AppLogger.info(
          '⏳ Waiting for auto-save to complete before manual save...');
      await Future.doWhile(() async {
        if (_disposed) return false;
        if (!_state.isAutoSaving) return false;
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      });
    }

    if (!_state.isValid) {
      _state.setError(AppLocale.current.errorFillRequiredFields);
      return null;
    }

    if (!_permissionManager.canEdit) {
      _state.setError(AppLocale.current.errorNoPermissionToSave);
      return null;
    }

    _isSaveInProgress = true;
    _currentSaveOperationId = _uuid.v4();
    AppLogger.info(
        '🔒 Starting atomic save operation: $_currentSaveOperationId');

    _state.setSaving(true);
    _state.clearError();

    try {
      final result = await safeExecute<Recipe>(
        () async {
          if (_disposed) {
            throw Exception('Save operation cancelled - Manager disposed');
          }

          final recipeId =
              _state.isEditing ? _state.originalRecipe!.id : _uuid.v4();
          _imageManager.setActualRecipeId(recipeId);

          AppLogger.info(
              '🚀 Starting atomic recipe save process for: $recipeId');

          if (_imageManager.pendingImages.isNotEmpty) {
            AppLogger.info(
                '📤 Waiting for ${_imageManager.pendingImages.length} images to upload before save...');

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

              AppLogger.info(
                  '✅ All images uploaded successfully, proceeding with recipe save');
            } catch (e) {
              AppLogger.error('❌ Image upload failed during recipe save: $e');
              throw Exception('Failed to upload images: $e');
            }
          }

          if (_disposed) {
            throw Exception(
                'Save operation cancelled - Manager disposed during image upload');
          }

          final validImageUrls = _imageManager.validImageUrls;
          AppLogger.info(
              '📝 Creating recipe with ${validImageUrls.length} validated image URLs');

          final recipe = _state.createRecipe(
            recipeId: recipeId,
            imageUrls: validImageUrls,
            thumbnailUrl: _imageManager.firstThumbnailUrl,
          );

          Recipe savedRecipe;
          if (_state.isEditing) {
            AppLogger.info('📝 Updating existing recipe: $recipeId');
            final result =
                await _recipeService.personal.updateUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
              _logRecipeEdited(recipeId);
            } else {
              throw Exception(result.message ?? 'Failed to update recipe');
            }
          } else {
            AppLogger.info('📝 Creating new recipe: $recipeId');
            final result =
                await _recipeService.personal.addUnifiedRecipe(recipe);
            if (result.isSuccess) {
              savedRecipe = recipe;
              _logRecipeCreated(validImageUrls);
            } else {
              throw Exception(result.message ?? 'Failed to create recipe');
            }
          }

          if (validImageUrls.isNotEmpty) {
            _analyticsService?.recipe.logRecipeImageUploaded(
              recipeId: recipeId,
              imageCount: validImageUrls.length,
              uploadSource: 'form',
            );
          }

          if (_disposed) {
            AppLogger.warning(
                '⚠️ Save completed but Manager disposed - skipping state updates');
            return savedRecipe;
          }

          AppLogger.info(
              '✅ Recipe saved atomically with ${savedRecipe.imageUrls.length} images: ${savedRecipe.id}');

          if (isCollaborative && !_disposed) {
            try {
              await _collaborativeManager.updateRecipeInFirebase(savedRecipe);
              AppLogger.info(
                  '🔄 Collaborative state updated for recipe: ${savedRecipe.id}');
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
          _state.setError(AppLocale.current.errorCouldNotSaveRecipe);
        }
      } else {
        if (!_disposed) {
          _state.clearCurrentDraft();
          AppLogger.info(
              '✅ Save operation completed successfully: ${result.id}');
          _trackParsingCorrectionsInBackground(result);
        }
      }

      _completePendingSaveOperations(result);

      return result;
    } catch (e) {
      AppLogger.error('❌ Atomic save operation failed: $e');

      if (!_disposed) {
        _state.setError(AppLocale.current.errorCouldNotSaveRecipe);
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
      _state.setError(AppLocale.current.errorNoRecipeToFork);
      return null;
    }

    _state.setForking(true);
    _state.clearError();

    try {
      final result = await safeExecute<Recipe>(
        () async {
          final newRecipe = _state.createRecipe(recipeId: _uuid.v4());

          final saveResult =
              await _recipeService.personal.addUnifiedRecipe(newRecipe);
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
        _state.setError(AppLocale.current.errorCouldNotForkRecipe);
      } else {
        if (!_disposed) {
          _state.clearCurrentDraft();
        }
      }

      return result;
    } catch (e) {
      AppLogger.error('Fel vid forkning av recept: $e');
      _state.setError(AppLocale.current.errorCouldNotForkRecipe);
      return null;
    } finally {
      _state.setForking(false);
    }
  }

  /// Deletes recipe with collaborative cleanup and permission validation.
  Future<bool> deleteRecipe({required bool isCollaborative}) async {
    if (_state.originalRecipe == null) {
      _state.setError(AppLocale.current.errorNoRecipeToDelete);
      return false;
    }

    if (!_permissionManager.canDelete) {
      _state.setError(AppLocale.current.errorNoPermissionToDelete);
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
      _state.setError(AppLocale.current.errorCouldNotDeleteRecipe);
      return false;
    }

    return result;
  }

  void _logRecipeCreated(List<String> imageUrls) {
    final source = _state.originalParsedRecipe != null ? 'import' : 'manual';
    _analyticsService?.recipe.logRecipeCreated(
      source: source,
      hasImage: imageUrls.isNotEmpty,
    );

    // P8-15: Keep user properties in sync after recipe creation
    final recipeCount = _recipeService.recipes.length;
    _analyticsService?.setUserProperties(recipeCount: recipeCount);

    if (source == 'import') {
      _analyticsService?.setUserProperties(hasUsedImport: true);
    }

    // P8-10 + P8-20: Activation metric & time-to-first-value (first recipe only)
    if (recipeCount == 1) {
      _isFirstRecipe = true;
      _trackFirstRecipeMetrics();
    }
  }

  void _trackFirstRecipeMetrics() {
    try {
      final userService = ServiceLocator.tryGet<UserService>();
      final joinedAt = userService?.currentUserProfile?.joinedAt;
      if (joinedAt == null) return;

      final now = DateTime.now();
      final minutesSinceSignup = now.difference(joinedAt).inMinutes;

      // P8-20: Time-to-first-value
      _analyticsService?.logEvent(
        name: 'time_to_first_recipe',
        parameters: {'minutes_since_signup': minutesSinceSignup},
      );

      // P8-10: Activation metric (recipe within 7 days of signup)
      if (now.difference(joinedAt).inDays <= 7) {
        _analyticsService?.logEvent(name: 'user_activated');
      }
    } catch (e) {
      AppLogger.warning('Failed to track first recipe metrics: $e');
    }
  }

  void _logRecipeEdited(String recipeId) {
    final original = _state.originalRecipe;
    if (original == null) return;

    final changed = <String>[];
    final current = _state;
    if (current.title != original.title) changed.add('title');
    if (current.description != original.description) {
      changed.add('description');
    }
    if (current.mealType != original.mealType) changed.add('mealType');
    if (current.portions != original.portions) changed.add('portions');
    if (current.timeMinutes != original.timeMinutes) changed.add('timeMinutes');

    _analyticsService?.recipe.logRecipeEdited(
      recipeId: recipeId,
      fieldsChanged: changed.isEmpty ? null : changed,
    );
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
        final correctionRepo =
            ServiceLocator.tryGet<ParsingCorrectionRepository>();

        if (diffCalculator == null || correctionRepo == null) {
          AppLogger.debug(
              '📊 Parsing correction tracking not available (services not registered)');
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
