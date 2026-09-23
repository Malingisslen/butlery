/// Web stub for AppDatabase - provides no-op implementation for web platform
/// since drift with native SQLite is not supported on web.
library;

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/cache/cache_dao_stub.dart';
import 'package:butlery/core/storage/drift/queue_counts.dart';

export 'package:butlery/core/storage/drift/queue_counts.dart';

/// Stub implementation of AppDatabase for web platform.
/// All operations are no-ops since SQLite is not available on web.
class AppDatabase {
  AppDatabase();
  AppDatabase.forTesting(dynamic e);

  /// Mirrors the native schema version (app_database.dart).
  int get schemaVersion => 3;

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

  /// The web has no offline queue, so nothing ever waits.
  Stream<QueueCounts> watchQueueCounts(String userId) =>
      Stream.value(QueueCounts.empty);

  /// The combined pending count across both queues; always 0 on the web.
  Stream<int> watchPendingCount(String userId) => Stream.value(0);

  /// Nothing to mark on the web.
  Future<Set<String>> markChainPermanentlyFailed(
    String userId,
    String opId, {
    String? reason,
  }) async => const {};

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

  // The native SyncQueueDao's count surface (sync_queue_dao.dart), so code
  // written against it compiles on the web too.
  Future<bool> hasPending(String userId) async => false;
  Future<int> countPending(String userId) async => 0;
  Stream<int> watchPendingCount(String userId) => Stream.value(0);
  Stream<int> watchPermanentFailureCount(String userId) => Stream.value(0);
  Future<bool> markPermanentlyFailed(String opId, {String? reason}) async =>
      false;
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

  // The native UploadQueueDao's count surface (upload_queue_dao.dart).
  Future<bool> hasPendingUploads(String userId) async => false;
  Future<int> countPendingUploads(String userId) async => 0;
  Stream<int> watchPendingCount(String userId) => Stream.value(0);
  Future<bool> markPermanentlyFailed(String id, {String? reason}) async =>
      false;
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
