// lib/services/unified/modules/personal_recipe_module.dart

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/permission_helper.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/core/rate_limiting/rate_limiter.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// HIGH-10: Recipe sync status for tracking background Firebase sync state.
enum RecipeSyncStatus {
  /// Recipe saved locally, background sync pending.
  pending,

  /// Recipe successfully synced to Firebase.
  synced,

  /// Sync failed after max retries - recipe is local only.
  failed,

  /// Recipe is being actively synced.
  syncing,
}

/// Personal recipe CRUD operations module handling recipe creation, updates, import/export, and local storage.
class PersonalRecipeModule {
  final RecipeRepository _recipeRepository;
  final UserRepository _userRepository;
  final JsonCacheHelper Function() _getCacheHelper;
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final void Function(String) _setError;
  final void Function() _notifyListeners;
  final RecipeServiceAdapter Function() _getServiceAdapter;
  final TaggingService? _taggingService;
  final PersonalTagService? _personalTagService;
  final RateLimiter _rateLimiter = RateLimiter();

  /// CRIT-7: Callback for notifying UI when tagging fails.
  /// Passes the recipe title so the UI can display a user-friendly message.
  final void Function(String recipeTitle)? _onTaggingFailed;

  /// HIGH-10: Tracks sync status for each recipe by ID.
  final Map<String, RecipeSyncStatus> _syncStatus = {};

  /// HIGH-11: Tracks when each recipe was last successfully synced to Firebase.
  /// Used to verify cache and Firebase are in sync.
  final Map<String, DateTime> _lastSyncedAt = {};

  /// BUG-003: Stores the last created recipe for direct retrieval.
  /// On web, cache is stubbed so we need direct access to the created recipe.
  Recipe? _lastCreatedRecipe;

  JsonCacheHelper get _cacheHelper => _getCacheHelper();

  /// BUG-003: Gets and clears the last created recipe.
  /// Used by PersonalRecipeCrud to add the recipe to the local list on web
  /// where cache is stubbed and cannot be used.
  Recipe? popLastCreatedRecipe() {
    final recipe = _lastCreatedRecipe;
    _lastCreatedRecipe = null;
    return recipe;
  }

  /// HIGH-10: Gets the current sync status for a recipe.
  /// Returns [RecipeSyncStatus.synced] if no status is tracked (assumed synced from Firebase).
  RecipeSyncStatus getSyncStatus(String recipeId) =>
      _syncStatus[recipeId] ?? RecipeSyncStatus.synced;

  /// HIGH-11: Gets the timestamp of the last successful sync for a recipe.
  /// Returns null if the recipe has never been synced in this session.
  DateTime? getLastSyncedAt(String recipeId) => _lastSyncedAt[recipeId];

  /// HIGH-11: Checks if a recipe's sync is considered fresh (within threshold).
  /// Useful for detecting stale cache vs Firebase discrepancies.
  bool isSyncFresh(String recipeId,
      {Duration threshold = const Duration(minutes: 5)}) {
    final lastSync = _lastSyncedAt[recipeId];
    if (lastSync == null) return false;
    return DateTime.now().difference(lastSync) <= threshold;
  }

  PersonalRecipeModule({
    required RecipeRepository recipeRepository,
    required UserRepository userRepository,
    required JsonCacheHelper Function() getCacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required RecipeServiceAdapter Function() getServiceAdapter,
    TaggingService? taggingService,
    PersonalTagService? personalTagService,
    void Function(String recipeTitle)? onTaggingFailed,
  })  : _recipeRepository = recipeRepository,
        _userRepository = userRepository,
        _getCacheHelper = getCacheHelper,
        _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _setError = setError,
        _notifyListeners = notifyListeners,
        _getServiceAdapter = getServiceAdapter,
        _taggingService = taggingService,
        _personalTagService = personalTagService,
        _onTaggingFailed = onTaggingFailed;

  Future<String?> createPersonalRecipe({
    required String title,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Create personal recipe',
    );
    if (currentUserId == null) return null;

    if (ValidationUtils.isNullOrWhitespace(title)) {
      _setError('Receptnamn kan inte vara tomt');
      return null;
    }

    try {
      // Rate limit check for recipe creation (DoS prevention)
      return await _rateLimiter.executeWithLimit(
        RateLimitOperation.createRecipe,
        () async {
          var newRecipe = Recipe.personal(
            title: title.trim(),
            description: description,
            ingredients: ingredients,
            instructions: instructions,
            mealType: mealType,
            createdBy: currentUserId,
            portions: portions,
            timeMinutes: timeMinutes,
            rating: rating,
            personalTagIds: personalTagIds,
            sourceUrl: sourceUrl,
            imageUrls: imageUrls,
          );

          // Generate tags if tagging service is available
          newRecipe = await _applyTagging(newRecipe);

          // Apply personal tag rules (auto-apply based on user-defined rules)
          newRecipe = await _applyPersonalTagRules(newRecipe);

          // ULTRATHINK FIX: Optimistic update - save to cache immediately and return success
          await _saveToCache(newRecipe);

          // Increment user's public recipe count
          try {
            await _userRepository.incrementPublicRecipeCount(currentUserId);
            AppLogger.debug(
                '✅ Incremented public recipe count for user $currentUserId');
          } catch (e) {
            AppLogger.warning('⚠️ Failed to increment recipe count: $e');
            // Continue anyway - don't fail recipe creation for counter issues
          }

          // BUG-003 FIX: On web, cache is a no-op (Drift stubbed), so we MUST
          // await Firebase sync to ensure recipes persist.
          if (kIsWeb) {
            final syncSuccess =
                await _syncRecipeToFirebaseAwaited(newRecipe, 'create');
            if (!syncSuccess) {
              _setError(
                  'Kunde inte spara receptet. Kontrollera din internetanslutning.');
              return null;
            }
            AppLogger.success('✅ Personal recipe "$title" created and synced');
          } else {
            // On mobile, use background sync (cache is real, UX is faster)
            _startBackgroundRecipeSync(newRecipe, 'create');
            AppLogger.success(
                '✅ Personal recipe "$title" created (syncing in background)');
          }
          // BUG-003: Store the created recipe for direct retrieval on web
          _lastCreatedRecipe = newRecipe;
          return newRecipe.id;
        },
      );
    } on RateLimitException catch (e) {
      AppLogger.warning('⚠️ Rate limit exceeded for recipe creation: $e');
      _setError(
          'För många receptskapanden. Försök igen om ${e.retryAfter?.inSeconds ?? 60} sekunder.');
      return null;
    } catch (e) {
      AppLogger.error('❌ Could not create personal recipe: $e');
      _setError('Kunde inte skapa recept: $e');
      return null;
    }
  }

  Future<bool> updatePersonalRecipe(Recipe updatedRecipe) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Update personal recipe',
    );
    if (currentUserId == null) return false;

    if (!updatedRecipe.isPersonal) {
      _setError('Kan bara uppdatera personliga recept');
      return false;
    }

    try {
      // Rate limit check for recipe updates (DoS prevention)
      return await _rateLimiter.executeWithLimit(
        RateLimitOperation.updateRecipe,
        () async {
          var editedRecipe = updatedRecipe.copyWith(
            lastEditedByUserId: currentUserId,
            lastEditedByDisplayName: _getCurrentUserDisplayName(),
          );

          // Regenerate tags if ingredients changed
          editedRecipe = await _applyTagging(editedRecipe);

          // Apply personal tag rules (auto-apply based on user-defined rules)
          editedRecipe = await _applyPersonalTagRules(editedRecipe);

          // ULTRATHINK FIX: Optimistic update - save to cache immediately and return success
          await _saveToCache(editedRecipe);

          // BUG-003 FIX: On web, await Firebase sync directly
          if (kIsWeb) {
            final syncSuccess =
                await _syncRecipeToFirebaseAwaited(editedRecipe, 'update');
            if (!syncSuccess) {
              _setError(
                  'Kunde inte uppdatera receptet. Kontrollera din internetanslutning.');
              return false;
            }
            AppLogger.success(
                '✅ Personal recipe "${editedRecipe.title}" updated and synced');
          } else {
            // On mobile, use background sync (cache is real, UX is faster)
            _startBackgroundRecipeSync(editedRecipe, 'update');
            AppLogger.success(
                '✅ Personal recipe "${editedRecipe.title}" updated (syncing in background)');
          }
          return true;
        },
      );
    } on RateLimitException catch (e) {
      AppLogger.warning('⚠️ Rate limit exceeded for recipe update: $e');
      _setError(
          'För många uppdateringar. Försök igen om ${e.retryAfter?.inSeconds ?? 60} sekunder.');
      return false;
    } catch (e) {
      AppLogger.error('❌ Could not update personal recipe: $e');
      _setError('Kunde inte uppdatera recept: $e');
      return false;
    }
  }

  Future<bool> deletePersonalRecipe(String recipeId) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Delete personal recipe',
    );
    if (currentUserId == null) return false;

    try {
      // Rate limit check for recipe deletion (DoS prevention)
      return await _rateLimiter.executeWithLimit(
        RateLimitOperation.deleteRecipe,
        () async {
          // Remove from cache
          await _removeFromCache(recipeId);

          // Delete from Firebase using repository pattern
          final deleteSuccess =
              await _getServiceAdapter().deleteRecipe(recipeId);
          if (deleteSuccess) {
            // Decrement user's public recipe count
            try {
              await _userRepository.decrementPublicRecipeCount(currentUserId);
              AppLogger.debug(
                  '✅ Decremented public recipe count for user $currentUserId');
            } catch (e) {
              AppLogger.warning('⚠️ Failed to decrement recipe count: $e');
              // Continue anyway - don't fail recipe deletion for counter issues
            }

            AppLogger.success('✅ Personal recipe deleted');
          } else {
            _setError('Kunde inte ta bort recept från servern');
            return false;
          }
          return true;
        },
      );
    } on RateLimitException catch (e) {
      AppLogger.warning('⚠️ Rate limit exceeded for recipe deletion: $e');
      _setError(
          'För många borttagningar. Försök igen om ${e.retryAfter?.inSeconds ?? 60} sekunder.');
      return false;
    } catch (e) {
      AppLogger.error('❌ Could not delete personal recipe: $e');
      _setError('Kunde inte ta bort recept: $e');
      return false;
    }
  }

  Future<bool> markRecipeAsCooked(String recipeId) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Mark recipe as cooked',
    );
    if (currentUserId == null) return false;

    try {
      // This would need to be implemented with recipe loading first
      // For now, we'll create a basic implementation
      AppLogger.info('Recipe marked as cooked: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not mark recipe as cooked: $e');
      _setError('Kunde inte markera recept som tillagat: $e');
      return false;
    }
  }

  Future<bool> addIngredient(String recipeId, String ingredient) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Add ingredient',
    );
    if (currentUserId == null) return false;

    try {
      // This would need recipe loading implementation
      AppLogger.info('Ingredient added to recipe $recipeId: $ingredient');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not add ingredient: $e');
      _setError('Kunde inte lägga till ingrediens: $e');
      return false;
    }
  }

  Future<bool> updateIngredient(
      String recipeId, int index, String newIngredient) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Update ingredient',
    );
    if (currentUserId == null) return false;

    try {
      // This would need recipe loading implementation
      AppLogger.info(
          'Ingredient updated in recipe $recipeId at index $index: $newIngredient');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not update ingredient: $e');
      _setError('Kunde inte uppdatera ingrediens: $e');
      return false;
    }
  }

  Future<bool> removeIngredient(String recipeId, int index) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Remove ingredient',
    );
    if (currentUserId == null) return false;

    try {
      // This would need recipe loading implementation
      AppLogger.info(
          'Ingredient removed from recipe $recipeId at index $index');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not remove ingredient: $e');
      _setError('Kunde inte ta bort ingrediens: $e');
      return false;
    }
  }

  Future<bool> addInstruction(String recipeId, String instruction) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Add instruction',
    );
    if (currentUserId == null) return false;

    try {
      // This would need recipe loading implementation
      AppLogger.info('Instruction added to recipe $recipeId: $instruction');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not add instruction: $e');
      _setError('Kunde inte lägga till instruktion: $e');
      return false;
    }
  }

  Future<bool> updateInstruction(
      String recipeId, int index, String newInstruction) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Update instruction',
    );
    if (currentUserId == null) return false;

    try {
      // This would need recipe loading implementation
      AppLogger.info(
          'Instruction updated in recipe $recipeId at index $index: $newInstruction');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not update instruction: $e');
      _setError('Kunde inte uppdatera instruktion: $e');
      return false;
    }
  }

  Future<bool> removeInstruction(String recipeId, int index) async {
    final currentUserId = PermissionHelper.requireAuthWithError(
      getCurrentUserId: _getCurrentUserId,
      setError: _setError,
      operationName: 'Remove instruction',
    );
    if (currentUserId == null) return false;

    try {
      // This would need recipe loading implementation
      AppLogger.info(
          'Instruction removed from recipe $recipeId at index $index');
      return true;
    } catch (e) {
      AppLogger.error('❌ Could not remove instruction: $e');
      _setError('Kunde inte ta bort instruktion: $e');
      return false;
    }
  }

  bool validateRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    if (ValidationUtils.isNullOrWhitespace(title)) {
      _setError('Receptnamn kan inte vara tomt');
      return false;
    }

    if (ingredients.isEmpty) {
      _setError('Recept måste ha minst en ingrediens');
      return false;
    }

    if (instructions.isEmpty) {
      _setError('Recept måste ha minst en instruktion');
      return false;
    }

    return true;
  }

  bool isOwnRecipe(Recipe recipe) {
    final currentUserId = _getCurrentUserId();
    return currentUserId != null && recipe.core.createdBy == currentUserId;
  }

  Future<void> _saveToCache(Recipe recipe) async {
    try {
      final recipeData = recipe.toJson();
      await _cacheHelper.saveJson(recipe.id, recipeData);
      AppLogger.debug('Recipe cached: ${recipe.title}');
    } catch (e) {
      AppLogger.error('Cache save error: $e');
    }
  }

  Future<void> _removeFromCache(String recipeId) async {
    try {
      await _cacheHelper.delete(recipeId);
      AppLogger.debug('Recipe removed from cache: $recipeId');
    } catch (e) {
      AppLogger.error('Cache removal error: $e');
    }
  }

  Future<List<Recipe>> loadCachedPersonalRecipes() async {
    try {
      final cachedRecipeIds = await _cacheHelper.getAllKeys();
      final recipes = <Recipe>[];

      for (final recipeId in cachedRecipeIds) {
        final recipeData = await _cacheHelper.loadJson(recipeId);
        if (recipeData != null) {
          try {
            final recipe = Recipe.fromJson(recipeData);
            if (recipe.isPersonal && isOwnRecipe(recipe)) {
              recipes.add(recipe);
            }
          } catch (e) {
            AppLogger.error('Error parsing cached recipe $recipeId: $e');
            await _cacheHelper.delete(recipeId);
          }
        }
      }

      AppLogger.debug('✅ ${recipes.length} cached personal recipes loaded');
      return recipes;
    } catch (e) {
      AppLogger.error('Error loading cached recipes: $e');
      return [];
    }
  }

  Stream<List<Recipe>>? getPersonalRecipesStream() {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return null;

    return _recipeRepository.watchRecipes(currentUserId);
  }

  Future<List<Recipe>?> getPersonalRecipesList() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) return null;

    try {
      return await _recipeRepository.fetchUserRecipes(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to fetch personal recipes: $e');
      return null;
    }
  }

  Future<List<String>> importRecipesFromData(
      List<Map<String, dynamic>> recipesData) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      _setError('Du måste vara inloggad för att importera recept');
      return [];
    }

    final importedIds = <String>[];

    try {
      for (final recipeData in recipesData) {
        try {
          final recipe = Recipe.fromJson(recipeData);

          // Convert to personal recipe
          var personalRecipe = recipe.copyWith(
            createdBy: currentUserId,
            lastEditedByUserId: currentUserId,
            lastEditedByDisplayName: _getCurrentUserDisplayName(),
          );

          // Apply tagging to imported recipes
          personalRecipe =
              await _applyTagging(personalRecipe, source: 'import');

          await _saveToCache(personalRecipe);
          await _getServiceAdapter().createRecipe(personalRecipe);

          importedIds.add(personalRecipe.id);
          AppLogger.info('Imported recipe: ${personalRecipe.title}');
        } catch (e) {
          AppLogger.error('Error importing individual recipe: $e');
        }
      }

      if (importedIds.isNotEmpty) {
        _notifyListeners();
        AppLogger.success(
            '✅ ${importedIds.length} recipes imported successfully');
      }

      return importedIds;
    } catch (e) {
      AppLogger.error('❌ Import error: $e');
      _setError('Kunde inte importera recept: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> exportPersonalRecipes() async {
    try {
      final cachedRecipes = await loadCachedPersonalRecipes();
      final exportData =
          cachedRecipes.map((recipe) => recipe.toJson()).toList();

      AppLogger.success('✅ ${exportData.length} recipes exported');
      return exportData;
    } catch (e) {
      AppLogger.error('❌ Export error: $e');
      _setError('Kunde inte exportera recept: $e');
      return [];
    }
  }

  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(message);
  }

  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }

  void clearError() {
    // This would be handled by the parent service
  }

  /// Max retry attempts for background sync to prevent infinite loops.
  static const _maxBackgroundRetries = 5;

  /// CRIT-4: Timeout for individual Firebase sync operations.
  /// Prevents indefinite hangs on slow/unavailable Firebase.
  static const _syncTimeout = Duration(seconds: 30);

  /// Tracks retry attempts per recipe to enforce limits.
  final Map<String, int> _backgroundRetryCount = {};

  /// BUG-003 FIX: Synchronous Firebase sync for web platform.
  /// On web, the local cache (Drift) is stubbed, so we MUST await Firebase
  /// to ensure recipes actually persist. Returns true if sync succeeded.
  Future<bool> _syncRecipeToFirebaseAwaited(
      Recipe recipe, String operation) async {
    try {
      AppLogger.info(
          '🔄 [Web] Awaiting $operation for recipe: ${recipe.title}');
      _syncStatus[recipe.id] = RecipeSyncStatus.syncing;

      bool success = false;
      if (operation == 'create') {
        final createdId = await _getServiceAdapter()
            .createRecipe(recipe)
            .timeout(_syncTimeout, onTimeout: () {
          AppLogger.warning(
              '⚠️ CRIT-4: Sync timeout for create: ${recipe.title}');
          return null;
        });
        success = createdId != null;
      } else if (operation == 'update') {
        success = await _getServiceAdapter()
            .updateRecipe(recipe)
            .timeout(_syncTimeout, onTimeout: () {
          AppLogger.warning(
              '⚠️ CRIT-4: Sync timeout for update: ${recipe.title}');
          return false;
        });
      }

      if (success) {
        AppLogger.success('✅ [Web] $operation completed for: ${recipe.title}');
        _syncStatus[recipe.id] = RecipeSyncStatus.synced;
        // HIGH-11: Record sync timestamp for verification
        _lastSyncedAt[recipe.id] = DateTime.now();
        return true;
      } else {
        AppLogger.error('❌ [Web] $operation failed for: ${recipe.title}');
        _syncStatus[recipe.id] = RecipeSyncStatus.failed;
        return false;
      }
    } catch (e) {
      AppLogger.error('❌ [Web] $operation error for ${recipe.title}: $e');
      _syncStatus[recipe.id] = RecipeSyncStatus.failed;
      return false;
    }
  }

  void _startBackgroundRecipeSync(Recipe recipe, String operation,
      {int retryAttempt = 0}) {
    // HIGH-10: Mark as syncing when starting
    _syncStatus[recipe.id] = RecipeSyncStatus.syncing;

    // Use Future.microtask to ensure this runs asynchronously without blocking
    Future.microtask(() async {
      try {
        AppLogger.info(
            '🔄 Starting background $operation for recipe: ${recipe.title}');

        bool success = false;
        // CRIT-4: Add timeout to prevent indefinite hangs
        if (operation == 'create') {
          final createdId = await _getServiceAdapter()
              .createRecipe(recipe)
              .timeout(_syncTimeout, onTimeout: () {
            AppLogger.warning(
                '⚠️ CRIT-4: Sync timeout for create: ${recipe.title}');
            return null;
          });
          success = createdId != null;
        } else if (operation == 'update') {
          success = await _getServiceAdapter()
              .updateRecipe(recipe)
              .timeout(_syncTimeout, onTimeout: () {
            AppLogger.warning(
                '⚠️ CRIT-4: Sync timeout for update: ${recipe.title}');
            return false;
          });
        }

        if (success) {
          AppLogger.success(
              '✅ Background $operation completed for: ${recipe.title}');
          // HIGH-10: Mark as synced and clear retry counter on success
          _syncStatus[recipe.id] = RecipeSyncStatus.synced;
          // HIGH-11: Record sync timestamp for verification
          _lastSyncedAt[recipe.id] = DateTime.now();
          _backgroundRetryCount.remove(recipe.id);
        } else {
          AppLogger.error(
              '❌ Background $operation failed for: ${recipe.title}');
          // HIGH-10: Mark as pending for retry
          _syncStatus[recipe.id] = RecipeSyncStatus.pending;
          // Recipe is still in cache for retry later
          _scheduleRetrySync(recipe, operation, retryAttempt);
        }
      } catch (e) {
        AppLogger.error(
            '❌ Background $operation error for ${recipe.title}: $e');
        // HIGH-10: Mark as pending for retry
        _syncStatus[recipe.id] = RecipeSyncStatus.pending;
        _scheduleRetrySync(recipe, operation, retryAttempt);
      }
    });
  }

  void _scheduleRetrySync(Recipe recipe, String operation, int currentAttempt) {
    final nextAttempt = currentAttempt + 1;

    // Enforce maximum retry limit
    if (nextAttempt > _maxBackgroundRetries) {
      AppLogger.error(
        '❌ Max retry attempts ($_maxBackgroundRetries) reached for '
        '$operation: ${recipe.title}. Recipe remains in cache for manual sync.',
      );
      // HIGH-10: Mark as failed when max retries exceeded
      _syncStatus[recipe.id] = RecipeSyncStatus.failed;
      return;
    }

    // Exponential backoff: 5s, 10s, 20s, 40s, 80s
    final delaySeconds = 5 * (1 << currentAttempt);
    final delay = Duration(seconds: delaySeconds.clamp(5, 120));

    AppLogger.info(
      '🔄 Scheduling retry $nextAttempt/$_maxBackgroundRetries '
      'for $operation: ${recipe.title} in ${delay.inSeconds}s',
    );

    Future.delayed(delay, () {
      _startBackgroundRecipeSync(recipe, operation, retryAttempt: nextAttempt);
    });
  }

  /// Applies automatic tagging to a recipe if tagging service is available.
  ///
  /// Returns the recipe with tagResult populated. If tagging fails, returns
  /// the recipe with a "failed" tagResult (coverage: 0, version: 'failed')
  /// to indicate retagging is needed.
  ///
  /// GDPR Article 30: Logs tag modifications for allergen/dietary audit trail.
  Future<Recipe> _applyTagging(Recipe recipe,
      {String source = 'auto_tagging'}) async {
    if (_taggingService == null) {
      return recipe;
    }

    final previousTagResult = recipe.core.tagResult;

    try {
      final tagResult = await _taggingService.generateTags(recipe);

      if (tagResult != null) {
        AppLogger.debug(
          '🏷️ Generated ${tagResult.tags.length} tags for "${recipe.title}" '
          '(coverage: ${(tagResult.coverage * 100).toStringAsFixed(0)}%)',
        );

        // GDPR Article 30: Audit trail for allergen/dietary changes
        await _logTagModification(
          recipe: recipe,
          previousTags: previousTagResult,
          newTags: tagResult,
          source: source,
        );

        return Recipe(
          core: recipe.core.copyWith(tagResult: tagResult),
          type: recipe.type,
          socialData: recipe.socialData,
          realtimeData: recipe.realtimeData,
          offlineData: recipe.offlineData,
        );
      }

      // Tagging returned null - log warning and notify UI
      AppLogger.warning(
          '⚠️ Tagging returned null for "${recipe.title}" - marking as needs retagging');
      // CRIT-7: Notify UI that tagging failed
      _onTaggingFailed?.call(recipe.title);
    } catch (e) {
      AppLogger.warning('⚠️ Tagging failed for "${recipe.title}": $e');
      // CRIT-7: Notify UI that tagging failed
      _onTaggingFailed?.call(recipe.title);
    }

    // Return recipe with explicit "needs retagging" marker
    return Recipe(
      core: recipe.core.copyWith(
        tagResult: TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.0, // Explicit 0 = needs retagging
          unknownIngredients: [],
          generatedAt: DateTime.now(),
          generatorVersion: 'failed',
        ),
      ),
      type: recipe.type,
      socialData: recipe.socialData,
      realtimeData: recipe.realtimeData,
      offlineData: recipe.offlineData,
    );
  }

  /// Logs tag modification for GDPR Article 30 compliance.
  /// Fire-and-forget - audit logging failures don't affect tagging operations.
  Future<void> _logTagModification({
    required Recipe recipe,
    required TagResult? previousTags,
    required TagResult newTags,
    required String source,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    try {
      final auditRepository = ServiceLocator.get<FirebaseAuditRepository>();
      await auditRepository.logTagModification(
        userId: userId,
        recipeId: recipe.id,
        previousTags: previousTags?.toFirestore(),
        newTags: newTags.toFirestore(),
        source: source,
      );
    } catch (e) {
      // Audit logging is non-blocking - don't fail the tagging operation
      AppLogger.debug('Audit logging skipped (non-blocking): $e');
    }
  }

  /// Applies personal tag automation rules to a recipe.
  ///
  /// Evaluates user-defined rules against the recipe and adds matching
  /// tag IDs to the recipe's personalTagIds list.
  /// Non-blocking: failures return the original recipe unchanged.
  Future<Recipe> _applyPersonalTagRules(Recipe recipe) async {
    if (_personalTagService == null) return recipe;

    try {
      // Evaluate all enabled rules against this recipe
      final matchingTagIds =
          await _personalTagService.evaluateRulesForRecipe(recipe);

      if (matchingTagIds.isEmpty) return recipe;

      // Get the actual tag objects to get their names
      final allTags = await _personalTagService.getAllTags();
      final ruleTagNames = allTags
          .where((t) => matchingTagIds.contains(t.id))
          .map((t) => t.name)
          .toSet();

      if (ruleTagNames.isEmpty) return recipe;

      // Merge with existing personalTagIds (preserving user-entered tags)
      final existingTags = recipe.personalTagIds?.toSet() ?? <String>{};
      final mergedTags = existingTags.union(ruleTagNames).toList();

      AppLogger.info(
        '🏷️ Personal tag rules: added ${ruleTagNames.length} tags to "${recipe.title}"',
      );

      return recipe.copyWith(personalTagIds: mergedTags);
    } catch (e, stackTrace) {
      // HIGH-8: Log as error and notify UI about personal tag failure
      AppLogger.error(
        '❌ Personal tag rule evaluation failed for "${recipe.title}": $e',
        e,
        'PersonalRecipeModule',
        stackTrace,
      );

      // HIGH-8: Notify UI via the same stream used for tagging failures
      // This allows users to know their personal tags may be incomplete
      _onTaggingFailed?.call(recipe.title);

      return recipe; // Return unchanged on error but user is notified
    }
  }
}
