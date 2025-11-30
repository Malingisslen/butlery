// lib/services/unified/helpers/recipe_auth_state_handler.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/modules/recipe_cache_module.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';

/// Helper class for handling auth state changes in recipe service.
/// Manages recipe reloading and cache clearing when users log in/out.
class RecipeAuthStateHandler {
  final RecipeCacheModule cacheModule;
  final FirebaseAuthRepository authRepository;
  final List<Recipe> recipes;
  final void Function(String) setError;
  final void Function(bool) setLoading;
  final void Function() notifyListeners;

  RecipeAuthStateHandler({
    required this.cacheModule,
    required this.authRepository,
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
        '🔍 [UnifiedRecipeService] ✅ Triggering recipe reload for user: $userId',
      );
      reloadUserRecipes(userId);
    }
  }

  /// Reload user-specific recipes when user logs in.
  Future<void> reloadUserRecipes(String userId) async {
    try {
      AppLogger.info(
        '🔍 [UnifiedRecipeService] Starting user recipe reload for: $userId',
      );

      setLoading(true);
      setError(''); // Clear error
      notifyListeners();

      // Clear existing recipes to prevent showing wrong user's data
      recipes.clear();

      // Reload from cache (contains user-specific data)
      AppLogger.info('🔍 [UnifiedRecipeService] Reloading from cache...');
      final cachedRecipes = await cacheModule.initializeCache();
      recipes.addAll(cachedRecipes);

      AppLogger.info(
        '🔍 [UnifiedRecipeService] ✅ Loaded ${cachedRecipes.length} recipes from cache',
      );

      // Ensure Firebase sync is active
      if (authRepository.currentUser != null) {
        AppLogger.info(
          '🔍 [UnifiedRecipeService] Starting Firebase sync for authenticated user',
        );
        await cacheModule.startFirebaseSync();

        // Additional safety delay to ensure all async cache writes complete
        // startFirebaseSync already waits 300ms, but we add extra buffer for large datasets
        await Future.delayed(const Duration(milliseconds: 300));

        // Reload from cache after initial fetch has populated it
        recipes.clear();
        final fetchedRecipes = await cacheModule.initializeCache();
        recipes.addAll(fetchedRecipes);
        AppLogger.info(
          '🔍 [UnifiedRecipeService] 📦 Reloaded ${fetchedRecipes.length} recipes from cache after sync',
        );
      }

      setLoading(false);
      AppLogger.success(
        '🔍 [UnifiedRecipeService] ✅ User recipe reload complete - ${recipes.length} recipes loaded',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('🔍 [UnifiedRecipeService] ❌ Recipe reload failed: $e');
      setError('Kunde inte ladda recept: $e');
      setLoading(false);
      notifyListeners();
    }
  }

  /// Clear all recipe data.
  void _clearAll() {
    recipes.clear();
    setLoading(false);
    setError(''); // Clear error
    notifyListeners();
  }
}
