/// Web stub for AppDatabase - provides no-op implementation for web platform
/// since drift with native SQLite is not supported on web.
library;

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/cache/cache_dao_stub.dart';

/// Stub implementation of AppDatabase for web platform.
/// All operations are no-ops since SQLite is not available on web.
class AppDatabase {
  AppDatabase();
  AppDatabase.forTesting(dynamic e);

  int get schemaVersion => 2;

  Future<void> clearAllData() async {}
  Future<void> clearUserData(String userId) async {}

  Future<Map<String, int>> getStats() async {
    return {
      'offlineRecipes': 0,
      'syncQueue': 0,
      'jsonCache': 0,
      'parseCache': 0,
      'uploadQueue': 0,
    };
  }

  Future<void> close() async {}

  // Stub DAOs - cacheDao uses shared CacheDao from cache_dao_stub.dart
  RecipeDaoStub get recipeDao => RecipeDaoStub();
  SyncQueueDaoStub get syncQueueDao => SyncQueueDaoStub();
  CacheDao get cacheDao => CacheDao();
  UploadQueueDaoStub get uploadQueueDao => UploadQueueDaoStub();
}

/// Stub RecipeDao for web
class RecipeDaoStub {
  Future<List<OfflineRecipeEntry>> getAllRecipesForUser(String userId) async =>
      [];
  Future<OfflineRecipeEntry?> getRecipeForUser(
    String recipeId,
    String userId,
  ) async => null;
  Future<int> getRecipeCountForUser(String userId) async => 0;
  Future<void> upsertRecipe(OfflineRecipeEntry entry) async {}
  Future<void> deleteRecipe(String recipeId, String userId) async {}
  Future<void> deleteAllRecipesForUser(String userId) async {}
  Stream<List<OfflineRecipeEntry>> watchRecipesForUser(String userId) =>
      Stream.value([]);
}

/// Stub SyncQueueDao for web
class SyncQueueDaoStub {
  Future<List<SyncQueueEntryData>> getPendingEntries(String userId) async => [];
  Future<int> getPendingCount(String userId) async => 0;
  Future<void> addEntry(SyncQueueEntryData entry) async {}
  Future<void> deleteEntry(String id) async {}
  Future<void> deleteAllForUser(String userId) async {}
  Future<bool> hasPendingEntries(String userId) async => false;
}

// CacheDao is imported from cache_dao_stub.dart

/// Stub UploadQueueDao for web
class UploadQueueDaoStub {
  Future<List<UploadQueueEntryData>> getPendingUploads(String userId) async =>
      [];
  Future<void> addUpload(UploadQueueEntryData entry) async {}
  Future<void> updateUploadStatus(String id, String status) async {}
  Future<void> deleteUpload(String id) async {}
  Future<void> deleteAllForUser(String userId) async {}
}

/// Stub data classes for web compatibility
class OfflineRecipeEntry {
  final String recipeId;
  final String userId;
  final String jsonData;
  final DateTime lastModified;
  final bool needsSync;

  OfflineRecipeEntry({
    required this.recipeId,
    required this.userId,
    required this.jsonData,
    required this.lastModified,
    required this.needsSync,
  });

  Recipe toRecipe() => throw UnimplementedError('Not supported on web');
}

class SyncQueueEntryData {
  final String id;
  final String userId;
  final String operationType;
  final String entityType;
  final String entityId;
  final String? jsonData;
  final DateTime createdAt;
  final int retryCount;

  SyncQueueEntryData({
    required this.id,
    required this.userId,
    required this.operationType,
    required this.entityType,
    required this.entityId,
    this.jsonData,
    required this.createdAt,
    this.retryCount = 0,
  });
}

class UploadQueueEntryData {
  final String id;
  final String userId;
  final String localPath;
  final String targetPath;
  final String status;
  final DateTime createdAt;

  UploadQueueEntryData({
    required this.id,
    required this.userId,
    required this.localPath,
    required this.targetPath,
    required this.status,
    required this.createdAt,
  });
}

/// Stub database connection for testing
dynamic createInMemoryDatabase() {
  throw UnimplementedError('Not supported on web');
}
