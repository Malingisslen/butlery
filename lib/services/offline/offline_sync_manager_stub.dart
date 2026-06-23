/// Web stub for OfflineSyncManager - no-op implementation for web platform
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/storage/drift/app_database_stub_web.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/services/offline/sync_result.dart';

/// Stub implementation of OfflineSyncManager for web platform.
class OfflineSyncManager {
  OfflineSyncManager({
    required AppDatabase database,
    required FirestoreRepository firestoreRepository,
    required auth_repo.AuthRepository authRepository,
    VoidCallback? onSyncStateChanged,
    Future<void> Function(String recipeId)? onTagRecipe,
  });

  bool get isSyncing => false;

  Future<bool> get hasQueuedChanges async => false;
  Future<int> get queuedChangesCount async => 0;

  Future<void> queueTagging({
    required String userId,
    required String recipeId,
  }) async {}

  Future<void> syncPendingChanges({required bool isOnline}) async {}

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
