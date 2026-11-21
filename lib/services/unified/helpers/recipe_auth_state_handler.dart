// lib/services/unified/helpers/recipe_auth_state_handler.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Helper class for handling auth state changes in recipe service.
/// Manages recipe reloading and cache clearing when users log in/out.
class RecipeAuthStateHandler {
  final RecipeCacheModule cacheModule;
  final FirebaseAuthRepository authRepository;
  final Future<List<Recipe>> Function(String userId)? fetchRecipesFromFirebase;
  final List<Recipe> recipes;
  final void Function(String) setError;
  final void Function(bool) setLoading;
  final void Function() notifyListeners;

  // Bumped on every auth change and by [cancelInFlight]; a reload started under
  // an older value belongs to an account that has since changed and is dropped.
  int _generation = 0;

  RecipeAuthStateHandler({
    required this.cacheModule,
    required this.authRepository,
    this.fetchRecipesFromFirebase,
    required this.recipes,
    required this.setError,
    required this.setLoading,
    required this.notifyListeners,
  });

  /// Handle auth state change (login/logout).
  void handleAuthStateChange(String? userId) {
    AppLogger.info(
      '🔍 [UnifiedRecipeService] Auth state changed - User ID: ${userId ?? 'NULL'}',
    );

    _generation++;
    cacheModule.onAuthStateChanged(userId);

    if (userId == null) {
      AppLogger.info(
        '🔍 [UnifiedRecipeService] User logged out - clearing all recipe data',
      );
      _clearAll();
    } else {
      AppLogger.info(
        '🔍 [UnifiedRecipeService] 🚨 USER LOGGED IN - RELOADING RECIPES',
      );
      AppLogger.info(
        '🔍 [UnifiedRecipeService] ✅ Triggering recipe reload for user: ${userId.maskedUserId}',
      );
      reloadUserRecipes(userId);
    }
  }

  void cancelInFlight() => _generation++;

  /// Reload user-specific recipes when user logs in.
  Future<void> reloadUserRecipes(String userId) async {
    final generation = _generation;
    try {
      AppLogger.info(
        '🔍 [UnifiedRecipeService] Starting user recipe reload for: ${userId.maskedUserId}',
      );

      setLoading(true);
      setError('');
      notifyListeners();

      // Clear existing recipes to prevent showing wrong user's data
      recipes.clear();

      // Reload from cache (contains user-specific data)
      AppLogger.info('🔍 [UnifiedRecipeService] Reloading from cache...');
      final cachedRecipes = await cacheModule.initializeCache();
      if (generation != _generation) return;
      _takeCached(cachedRecipes);

      AppLogger.info(
        '🔍 [UnifiedRecipeService] ✅ Loaded ${cachedRecipes.length} recipes from cache',
      );

      // Ensure Firebase sync is active
      if (authRepository.currentUser != null) {
        AppLogger.info(
          '🔍 [UnifiedRecipeService] Starting Firebase sync for authenticated user',
        );
        await cacheModule.startFirebaseSync();
        if (generation != _generation) return;

        // BUG-003 FIX: On web, cache is stubbed so we load directly from Firebase
        if (kIsWeb && fetchRecipesFromFirebase != null) {
          final firebaseRecipes = await fetchRecipesFromFirebase!(userId);
          if (generation != _generation) return;
          recipes.clear();
          recipes.addAll(firebaseRecipes);
          AppLogger.info(
            '🔍 [UnifiedRecipeService] 📦 [Web] Loaded ${firebaseRecipes.length} recipes directly from Firebase',
          );
        } else {
          // Additional safety delay to ensure all async cache writes complete
          // startFirebaseSync already waits 300ms, but we add extra buffer for large datasets
          await Future.delayed(const Duration(milliseconds: 300));
          if (generation != _generation) return;

          // Reload from cache after initial fetch has populated it
          final fetchedRecipes = await cacheModule.initializeCache();
          if (generation != _generation) return;
          _takeCached(fetchedRecipes);
          AppLogger.info(
            '🔍 [UnifiedRecipeService] 📦 Reloaded ${fetchedRecipes.length} recipes from cache after sync',
          );
        }
      }

      setLoading(false);
      AppLogger.success(
        '🔍 [UnifiedRecipeService] ✅ User recipe reload complete - ${recipes.length} recipes loaded',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('🔍 [UnifiedRecipeService] ❌ Recipe reload failed: $e');
      if (generation != _generation) return;
      setError(AppLocale.current.errorCouldNotLoadRecipes);
      setLoading(false);
      notifyListeners();
    }
  }

  /// Puts [cached] on screen without losing or doubling a recipe the live
  /// sync handed over while the cache was being read: the synced copy is the
  /// newer one, so it wins.
  void _takeCached(List<Recipe> cached) {
    final byId = {for (final r in cached) r.id: r};
    for (final r in recipes) {
      byId[r.id] = r;
    }
    recipes
      ..clear()
      ..addAll(byId.values);
  }

  /// Clear all recipe data.
  void _clearAll() {
    recipes.clear();
    setLoading(false);
    setError(''); // Clear error
    notifyListeners();
  }
}
