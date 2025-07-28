// lib/services/offline/offline_user_storage.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles user-specific storage operations for offline service
class OfflineUserStorage {
  
  final Box<Recipe> _recipeBox;
  final Box<String> _syncQueueBox;
  
  OfflineUserStorage({
    required Box<Recipe> recipeBox,
    required Box<String> syncQueueBox,
  }) : _recipeBox = recipeBox,
       _syncQueueBox = syncQueueBox;

  /// Get recipes for specific user
  List<Recipe> getRecipesForUser(String userId) {
    try {
      final userPrefix = '${userId}_';
      final userRecipes = <Recipe>[];

      // Find all recipes that belong to this user
      for (final key in _recipeBox.keys) {
        if (key.toString().startsWith(userPrefix)) {
          final recipe = _recipeBox.get(key);
          if (recipe != null) {
            userRecipes.add(recipe);
          }
        }
      }

      AppLogger.info(
          '📦 Hittade ${userRecipes.length} offline recept för användare: $userId');
      return userRecipes;
    } catch (e) {
      AppLogger.error('❌ Error getting user recipes: $e');
      return [];
    }
  }

  /// Save recipe with user-specific key
  Future<void> saveRecipeForUser(Recipe recipe, String userId, {required bool isOnline}) async {
    try {
      // Create user-specific key: "userId_recipeId"
      final userSpecificKey = '${userId}_${recipe.id}';

      // Save with user-specific key
      await _recipeBox.put(userSpecificKey, recipe);

      // Handle sync queue with user-specific key
      if (!isOnline) {
        await _syncQueueBox.put(userSpecificKey, userSpecificKey);
      }

      AppLogger.info(
          '💾 Recept sparat offline för användare $userId: ${recipe.title}');
    } catch (e) {
      AppLogger.error('❌ Fel vid user-specific offline-sparning: $e');
      rethrow;
    }
  }

  /// Get specific offline recipe for user
  Recipe? getRecipeForUser(String recipeId, String userId) {
    final userSpecificKey = '${userId}_$recipeId';
    return _recipeBox.get(userSpecificKey);
  }

  /// Delete recipe for specific user
  Future<void> deleteRecipeForUser(String recipeId, String userId) async {
    final userSpecificKey = '${userId}_$recipeId';
    await _recipeBox.delete(userSpecificKey);
    await _syncQueueBox.delete(userSpecificKey);
    AppLogger.info(
        '🗑️ Recept borttaget offline för användare $userId: $recipeId');
  }

  /// Clear data for specific user
  Future<void> clearUserData(String userId) async {
    try {
      final userPrefix = '${userId}_';
      final keysToDelete = <dynamic>[];

      // Find all keys that belong to this user
      for (final key in _recipeBox.keys) {
        if (key.toString().startsWith(userPrefix)) {
          keysToDelete.add(key);
        }
      }

      // Delete user-specific recipes
      for (final key in keysToDelete) {
        await _recipeBox.delete(key);
      }

      // Clear sync queue for this user
      final syncKeysToDelete = <dynamic>[];
      for (final key in _syncQueueBox.keys) {
        if (key.toString().startsWith(userPrefix)) {
          syncKeysToDelete.add(key);
        }
      }

      for (final key in syncKeysToDelete) {
        await _syncQueueBox.delete(key);
      }

      AppLogger.success(
          '✅ Rensade offline data för användare: $userId (${keysToDelete.length} recept)');
    } catch (e) {
      AppLogger.error('❌ Fel vid rensning av user data: $e');
    }
  }

  /// Get all users who have offline data
  List<String> getUsersWithOfflineData() {
    final users = <String>{};

    for (final key in _recipeBox.keys) {
      final keyStr = key.toString();
      if (keyStr.contains('_')) {
        final userId = keyStr.split('_').first;
        users.add(userId);
      }
    }

    return users.toList();
  }
}