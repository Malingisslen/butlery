// lib/services/offline/offline_legacy_storage.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';

/// Handles legacy storage operations for backward compatibility
class OfflineLegacyStorage {
  
  final Box<Recipe> _recipeBox;
  final Box<String> _syncQueueBox;
  final OfflineUserStorage _userStorage;
  
  String? _currentUserId;
  
  OfflineLegacyStorage({
    required Box<Recipe> recipeBox,
    required Box<String> syncQueueBox,
    required OfflineUserStorage userStorage,
  }) : _recipeBox = recipeBox,
       _syncQueueBox = syncQueueBox,
       _userStorage = userStorage;

  /// Set current user for storage delegation
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  /// Save recipe offline - with user support fallback
  Future<void> saveRecipe(Recipe recipe, {required bool isOnline}) async {
    if (_currentUserId != null) {
      // Use user-specific storage if user is set
      await _userStorage.saveRecipeForUser(recipe, _currentUserId!, isOnline: isOnline);
    } else {
      // Fallback to old behavior for backward compatibility
      try {
        // Save in Hive FIRST (so object is in a box)
        await _recipeBox.put(recipe.id, recipe);

        // Now we can safely mark as modified
        if (isOnline && _recipeBox.containsKey(recipe.id)) {
          // Note: unified Recipe doesn't have isModifiedOffline field
          // This functionality would need to be implemented differently
          await _recipeBox.put(recipe.id, recipe);
        }

        // Add to sync queue if offline
        if (!isOnline) {
          await _syncQueueBox.put(recipe.id, recipe.id);
        }

        AppLogger.info('💾 Recept sparat offline (legacy): ${recipe.title}');
      } catch (e) {
        AppLogger.error('❌ Fel vid offline-sparning: $e');
        rethrow;
      }
    }
  }

  /// Get all offline recipes - with user support
  List<Recipe> getAllRecipes() {
    if (_currentUserId != null) {
      // Return user-specific recipes if user is set
      return _userStorage.getRecipesForUser(_currentUserId!);
    } else {
      // Fallback to all recipes for backward compatibility
      return _recipeBox.values.toList();
    }
  }

  /// Get specific offline recipe - with user support
  Recipe? getRecipe(String id) {
    if (_currentUserId != null) {
      // Use user-specific lookup if user is set
      return _userStorage.getRecipeForUser(id, _currentUserId!);
    } else {
      // Fallback to old behavior
      return _recipeBox.get(id);
    }
  }

  /// Delete recipe offline - with user support
  Future<void> deleteRecipe(String id) async {
    if (_currentUserId != null) {
      // Use user-specific deletion if user is set
      await _userStorage.deleteRecipeForUser(id, _currentUserId!);
    } else {
      // Fallback to old behavior
      await _recipeBox.delete(id);
      await _syncQueueBox.delete(id);
      AppLogger.info('🗑️ Recept borttaget offline (legacy): $id');
    }
  }

  /// Clear all offline data - with user support
  Future<void> clearAllData() async {
    if (_currentUserId != null) {
      // Clear only current user's data if user is set
      await _userStorage.clearUserData(_currentUserId!);
    } else {
      // Clear all data (old behavior)
      await _recipeBox.clear();
      await _syncQueueBox.clear();
      AppLogger.info('🧹 All offline data rensad');
    }
  }
}