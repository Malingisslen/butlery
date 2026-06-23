/// Web stub for OfflineUserStorage - no-op implementation for web platform
library;

import 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Stub implementation of OfflineUserStorage for web platform.
class OfflineUserStorage {
  OfflineUserStorage({required AppDatabase database});

  Future<List<Recipe>> getRecipesForUser(String userId) async => [];

  Future<Recipe?> getRecipeForUser(String recipeId, String userId) async =>
      null;

  Future<int> getRecipeCountForUser(String userId) async => 0;

  Future<void> saveRecipeForUser(
    Recipe recipe,
    String userId, {
    bool isOnline = true,
  }) async {}

  Future<void> deleteRecipeForUser(String recipeId, String userId) async {}

  Future<void> clearUserData(String userId) async {}

  Stream<List<Recipe>> watchRecipesForUser(String userId) => Stream.value([]);
}
