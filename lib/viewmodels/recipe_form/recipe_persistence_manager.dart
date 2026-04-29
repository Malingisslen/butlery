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
import 'package:butlery/services/parsing/feedback/parse_correction_uploader.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/first_recipe_source_milestone.dart';
import 'package:butlery/services/analytics/post_import_edit_decider.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/utils/recipe_diff.dart';

/// BUT-569: window after import during which a `recipe_edited` event also
/// fires the dedicated `post_import_edit` event. Tunable knob — long enough
/// to capture genuine post-import cleanup, short enough that ordinary
/// long-term edits don't pollute parse-quality metrics.
const int kPostImportEditWindowDays = 30;

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
              _logRecipeEdited(recipeId, savedRecipe);
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
      // BUT-618: stamp `first_recipe_source` user property exactly once per
      // user. Dedupe via SharedPreferences flag so reload/re-import can't
      // overwrite the original source attribution.
      FirstRecipeSourceMilestone.setIfFirstRecipe(
        analytics: _analyticsService,
        userId: _recipeService.currentUserId,
        source: source,
      );
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
        name: AnalyticsEvents.timeToFirstRecipe,
        parameters: {'minutes_since_signup': minutesSinceSignup},
      );

      // P8-10: Activation metric (recipe within 7 days of signup)
      if (now.difference(joinedAt).inDays <= 7) {
        _analyticsService?.logEvent(name: AnalyticsEvents.userActivated);
      }
    } catch (e) {
      AppLogger.warning('Failed to track first recipe metrics: $e');
    }
  }

  void _logRecipeEdited(String recipeId, Recipe savedRecipe) {
    final original = _state.originalRecipe;
    if (original == null) return;

    final changed = diffRecipeFields(original, savedRecipe);

    _analyticsService?.recipe.logRecipeEdited(
      recipeId: recipeId,
      fieldsChanged: changed.isEmpty ? null : changed,
    );

    // BUT-569: emit `post_import_edit` for imported recipes still inside the
    // post-import window. Runs alongside (not in place of) `recipe_edited`
    // because the two events feed different funnels.
    _logPostImportEditIfApplicable(
      recipeId: recipeId,
      original: original,
      changed: changed,
    );
  }

  /// BUT-569: emit `post_import_edit` when the edited recipe was imported
  /// (has a non-empty sourceUrl) and was created within the configured
  /// window. Decision logic lives in [PostImportEditDecider] so it can be
  /// unit-tested independently of the form-viewmodel stack.
  void _logPostImportEditIfApplicable({
    required String recipeId,
    required Recipe original,
    required List<String> changed,
  }) {
    // BUT-552: tier_used lives on the parsed-recipe metadata captured at
    // import time. Available only on the first edit after import (the
    // `originalParsedRecipe` is cleared post-save). Omit when unknown
    // rather than guessing.
    final tierUsed = _state.originalParsedRecipe?.metadata.successfulTier;

    final params = PostImportEditDecider.build(
      recipeId: recipeId,
      fieldsChanged: changed,
      sourceUrl: original.sourceUrl,
      importedAt: original.createdAt,
      now: DateTime.now(),
      tierUsed: tierUsed,
      windowDays: kPostImportEditWindowDays,
    );
    if (params == null) return;

    _analyticsService?.logEvent(
      name: AnalyticsEvents.postImportEdit,
      parameters: params,
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
  /// Aggregate doc → `parsing_corrections` (alias learning); per-field docs →
  /// `parse_corrections_v2` via logParseCorrection callable (BUT-595).
  void _trackParsingCorrectionsInBackground(Recipe savedRecipe) {
    if (savedRecipe.sourceUrl == null || savedRecipe.sourceUrl!.isEmpty) return;
    final originalParsed = _state.originalParsedRecipe;
    if (originalParsed == null) return;

    Future(() async {
      try {
        final diffCalculator = ServiceLocator.tryGet<RecipeDiffCalculator>();
        final correctionRepo =
            ServiceLocator.tryGet<ParsingCorrectionRepository>();
        final userId = _recipeService.currentUserId;
        if (diffCalculator == null ||
            correctionRepo == null ||
            userId == null) {
          return;
        }

        final correction = diffCalculator.calculateDiff(
          original: originalParsed,
          corrected: savedRecipe,
          userId: userId,
        );
        if (correction == null) return;

        await correctionRepo.save(correction);
        AppLogger.info(
          '📊 Tracked ${correction.totalCorrections} parsing corrections '
          'for ${correction.domain ?? correction.source.name}',
        );
        // BUT-595: per-field fan-out via logParseCorrection callable.
        await ServiceLocator.tryGet<ParseCorrectionUploader>()
            ?.uploadWithSharedSalt(correction: correction);
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
