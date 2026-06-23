// lib/services/offline/offline_sync_manager.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/retry_helper.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/sync_result.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Handles sync operations for offline service
/// Now uses Drift database instead of Hive
class OfflineSyncManager {
  final RecipeDao _recipeDao;
  final SyncQueueDao _syncQueueDao;
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;

  bool _isSyncing = false;
  final VoidCallback? _onSyncStateChanged;

  /// H9: Callback to retag a recipe when connectivity is restored.
  /// Injected from OfflineService to avoid circular dependency with TaggingService.
  final Future<void> Function(String recipeId)? _onTagRecipe;

  /// Async lock to prevent concurrent sync operations.
  /// Uses a Completer-based mutex pattern for thread-safe sync.
  Completer<void>? _syncLock;

  OfflineSyncManager({
    required AppDatabase database,
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
    VoidCallback? onSyncStateChanged,
    Future<void> Function(String recipeId)? onTagRecipe,
  }) : _recipeDao = database.recipeDao,
       _syncQueueDao = database.syncQueueDao,
       _firestoreRepository = firestoreRepository,
       _authRepository = authRepository,
       _onSyncStateChanged = onSyncStateChanged,
       _onTagRecipe = onTagRecipe;

  // Getters
  bool get isSyncing => _isSyncing;

  Future<bool> get hasQueuedChanges async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return false;
    return await _syncQueueDao.hasPending(userId);
  }

  Future<int> get queuedChangesCount async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return 0;
    return await _syncQueueDao.countPending(userId);
  }

  /// Sync pending changes without circular dependencies.
  /// Uses an async lock to prevent concurrent sync operations.
  Future<void> syncPendingChanges({required bool isOnline}) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      AppLogger.warning('⚠️ Ingen användare inloggad - hoppar över sync');
      return;
    }

    final hasPending = await _syncQueueDao.hasPending(userId);
    if (!isOnline || !hasPending) return;

    // Acquire async lock - if another sync is in progress, wait for it
    if (_syncLock != null) {
      AppLogger.debug('🔄 SYNC: Waiting for ongoing sync to complete...');
      await _syncLock!.future;
      // After waiting, check if we still need to sync
      final stillHasPending = await _syncQueueDao.hasPending(userId);
      if (!stillHasPending) {
        AppLogger.debug('🔄 SYNC: No pending changes after wait, skipping');
        return;
      }
    }

    // Create new lock - this atomically prevents new sync operations
    _syncLock = Completer<void>();
    _isSyncing = true;
    _onSyncStateChanged?.call();

    final pendingCount = await _syncQueueDao.countPending(userId);
    AppLogger.info(
      '🔄 Synkroniserar $pendingCount väntande ändringar...',
    );

    try {
      final userRecipesRef = _firestoreRepository.userRecipesCollection(userId);

      final pendingItems = await _syncQueueDao.getPendingForUser(userId);
      int successCount = 0;
      int failureCount = 0;
      final List<String> failedRecipes = [];

      for (final item in pendingItems) {
        Recipe? recipe;
        try {
          // H9: Handle tag operations separately
          if (item.operation == SyncOperation.tag.name) {
            if (_onTagRecipe != null) {
              AppLogger.info(
                '🏷️ Processing pending tagging for: ${item.recipeId}',
              );
              await _onTagRecipe(item.recipeId);
              await _syncQueueDao.dequeue(item.id);
              successCount++;
              AppLogger.success('✅ Tagging completed for: ${item.recipeId}');
            } else {
              AppLogger.warning(
                '⚠️ Tag callback not configured, skipping: ${item.recipeId}',
              );
              await _syncQueueDao.dequeue(item.id);
            }
            continue;
          }

          // Get recipe from Drift
          final offlineRecipe = await _recipeDao.getRecipe(
            item.recipeId,
            userId,
          );

          if (offlineRecipe != null) {
            final json =
                jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
            recipe = Recipe.fromJson(json);

            if (offlineRecipe.needsSync) {
              AppLogger.info('📤 Synkar recept: ${recipe.id}');

              // Use retry logic for Firebase operations
              await RetryHelper.retryFirebaseOperation(() async {
                await _firestoreRepository.setDocument(
                  userRecipesRef.doc(recipe!.id),
                  recipe.toFirestore(),
                );
              });

              // Sync succeeded - mark as synced in Drift
              await _recipeDao.markSynced(item.recipeId, userId);

              // Remove from sync queue
              await _syncQueueDao.dequeue(item.id);
              successCount++;
              AppLogger.success('✅ Synkade recept: ${recipe.id}');
            } else {
              // Recipe no longer needs sync - remove from queue
              await _syncQueueDao.dequeue(item.id);
              AppLogger.info(
                '✅ Recept ${item.recipeId} behöver inte synkas längre',
              );
            }
          } else {
            // Recipe doesn't exist - remove from queue
            await _syncQueueDao.dequeue(item.id);
            AppLogger.info('🗑️ Tog bort invalid sync entry: ${item.recipeId}');
          }
        } catch (e) {
          failureCount++;
          final recipeTitle = recipe?.title ?? item.recipeId;
          failedRecipes.add('$recipeTitle: ${e.toString()}');
          AppLogger.error('❌ Fel vid synk av ${item.recipeId}: $e');

          // Record failure in sync queue
          await _syncQueueDao.recordFailure(item.id, e.toString());

          // Robust error handling: Continue with next recipe
          continue;
        }
      }

      // Detailed reporting
      if (successCount > 0) {
        AppLogger.success('🎉 Synkade $successCount recept framgångsrikt!');
      }

      if (failureCount > 0) {
        AppLogger.warning('⚠️ $failureCount recept kunde inte synkas:');
        for (final failure in failedRecipes.take(3)) {
          AppLogger.warning('  • $failure');
        }
        if (failedRecipes.length > 3) {
          AppLogger.warning('  • ... och ${failedRecipes.length - 3} till');
        }
      }

      // Smart retry: If all failed, use exponential backoff
      if (successCount == 0 && failureCount > 0) {
        AppLogger.info(
          '⏰ Alla sync-försök misslyckades, använder exponential backoff...',
        );

        // Use exponential backoff for retry attempts
        RetryHelper.retryWithBackoff(
          () async {
            final stillHasPending = await _syncQueueDao.hasPending(userId);
            if (isOnline && stillHasPending) {
              AppLogger.info('🔄 Retry-försök startar...');
              await syncPendingChanges(isOnline: isOnline);
            }
          },
          maxRetries: 3,
          shouldRetry: (error) {
            // Retry on any error - sync state will be checked inside the operation
            return true;
          },
        );
      }
    } catch (e) {
      AppLogger.error('❌ Kritiskt fel vid synkronisering: $e');

      // Graceful degradation: Log error but don't crash app
      AppLogger.info(
        '🛡️ Synkronisering hoppar över denna omgång, försöker igen senare',
      );
    } finally {
      _isSyncing = false;
      // Release the lock so waiting operations can proceed
      _syncLock?.complete();
      _syncLock = null;
      _onSyncStateChanged?.call();
    }
  }

  /// Manual synchronization with user feedback
  Future<SyncResult> syncNow({required bool isOnline}) async {
    final l = AppLocale.current;
    if (_isSyncing) {
      AppLogger.info('🔄 Synkronisering pågår redan...');
      return SyncResult(
        success: false,
        message: l.syncAlreadyInProgress,
        isRetry: false,
      );
    }

    if (!isOnline) {
      AppLogger.warning('⚠️ Kan inte synka offline');
      return SyncResult(
        success: false,
        message: l.syncMustBeOnline,
        isRetry: false,
      );
    }

    final userId = _authRepository.currentUserId;
    if (userId == null) {
      return SyncResult(
        success: false,
        message: l.syncNoUserLoggedIn,
        isRetry: false,
      );
    }

    final hasPending = await _syncQueueDao.hasPending(userId);
    if (!hasPending) {
      AppLogger.info('✅ Inga ändringar att synkronisera');
      return SyncResult(
        success: true,
        message: l.syncNoPendingChanges,
        isRetry: false,
      );
    }

    AppLogger.info('🔄 Manuell synkronisering startad...');
    final itemsToSync = await _syncQueueDao.countPending(userId);

    await syncPendingChanges(isOnline: isOnline);

    final remainingItems = await _syncQueueDao.countPending(userId);
    final syncedItems = itemsToSync - remainingItems;

    if (remainingItems == 0) {
      return SyncResult(
        success: true,
        message: l.syncAllSynced(syncedItems),
        isRetry: false,
      );
    } else if (syncedItems > 0) {
      return SyncResult(
        success: true,
        message: l.syncPartialSuccess(syncedItems, itemsToSync, remainingItems),
        isRetry: remainingItems > 0,
      );
    } else {
      return SyncResult(
        success: false,
        message: l.syncFailedRetryLater,
        isRetry: true,
      );
    }
  }

  /// Get failed operations for diagnostic purposes
  /// [maxRetries] - Operations with retry count above this are considered failed
  Future<List<SyncQueueEntry>> getFailedOperations({int maxRetries = 3}) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return [];
    return await _syncQueueDao.getFailedOperations(userId, maxRetries);
  }

  /// Queue a tagging operation for when connectivity is restored.
  ///
  /// Used for recipes saved offline that need tags generated.
  /// The recipe will be tagged when the device goes back online.
  Future<void> queueTagging({
    required String userId,
    required String recipeId,
  }) async {
    await _syncQueueDao.enqueue(
      userId: userId,
      recipeId: recipeId,
      operation: SyncOperation.tag,
    );
    AppLogger.debug('📋 Queued tagging operation for recipe: $recipeId');
  }

  void dispose() {
    if (_syncLock != null && !_syncLock!.isCompleted) {
      _syncLock!.complete();
    }
    _syncLock = null;
    _isSyncing = false;
  }
}
