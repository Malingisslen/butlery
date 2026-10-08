/// Web stub for OfflineSyncManager - no-op implementation for web platform
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/services/offline/offline_user_storage_stub.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:butlery/services/offline/sync_result.dart';

/// Stub implementation of OfflineSyncManager for web platform.
class OfflineSyncManager {
  OfflineSyncManager({
    required AppDatabase database,
    required auth_repo.AuthRepository authRepository,
    VoidCallback? onSyncStateChanged,
    Future<void> Function(String recipeId, String userId)? onTagRecipe,
    void Function(String recipeId)? onRecipeSent,
    RecipeConflictCallback? onRecipeConflict,
    QueuedImageUploader? uploadImage,
    OfflineUserStorage? userStorage,
    bool Function()? isOnlineNow,
    this.recipeWriter,
  });

  QueuedRecipeWriter? recipeWriter;

  bool get isSyncing => false;

  Future<bool> get hasQueuedChanges async => false;
  Future<int> get queuedChangesCount async => 0;

  Future<void> syncPendingChanges({
    required bool isOnline,
    bool force = false,
  }) async {}

  Future<SyncResult> syncNow({required bool isOnline}) async {
    return const SyncResult(
      success: true,
      syncedCount: 0,
      failedCount: 0,
      isRetry: false,
      message: 'Web platform - offline sync not supported',
    );
  }

  void dispose() {}
}
