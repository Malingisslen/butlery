// lib/services/offline/offline_sync_manager.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/sync_result.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/parsing/sanitizers/recipe_sanitizer.dart';

/// Handles sync operations for offline service
/// Now uses Drift database instead of Hive
class OfflineSyncManager {
  final AppDatabase _database;
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

  /// Whether the device is online now, read when a retry timer fires. Null
  /// reads as online.
  final bool Function()? _isOnlineNow;

  /// The jitter source (queueRetryDelay).
  final Random? _random;

  /// The next scheduled pass, for the earliest retry time in the queue.
  Timer? _retryTimer;

  /// How many entries the last pass saved on the server.
  int _lastPassSent = 0;

  OfflineSyncManager({
    required AppDatabase database,
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
    VoidCallback? onSyncStateChanged,
    Future<void> Function(String recipeId)? onTagRecipe,
    bool Function()? isOnlineNow,
    Random? random,
  }) : _database = database,
       _isOnlineNow = isOnlineNow,
       _random = random,
       _recipeDao = database.recipeDao,
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

  /// Sends the queue: one pass over the user's entries, oldest first.
  ///
  /// The rules are produktregler.md:186-189 (queue_retry_policy.dart): an
  /// entry waits for its dependencies and for earlier entries to the same
  /// entity; a failed attempt is retried on the schedule 2 s → 4 s → 8 s →
  /// 30 s → 2 min → 10 min with jitter, for at most 24 h from the first
  /// failure; an error the server will always give again (4xx other than
  /// 408/429) makes the entry and everything that depends on it a permanent
  /// failure that waits for the user. Nothing is deleted without the
  /// server's confirmation (produktregler.md:192).
  ///
  /// Coming back online runs a pass, but an entry whose retry time has not
  /// come is left for its timer: "Ingen omförsöksstorm vid återkommande
  /// nät" (produktregler.md:188). [force] ("Försök synka nu") ignores the
  /// retry times, never the order or the dependencies.
  ///
  /// Uses an async lock to prevent concurrent sync operations.
  Future<void> syncPendingChanges({
    required bool isOnline,
    bool force = false,
  }) async {
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
    _retryTimer?.cancel();
    _retryTimer = null;
    _onSyncStateChanged?.call();

    final pendingCount = await _syncQueueDao.countPending(userId);
    AppLogger.info(
      '🔄 Synkroniserar $pendingCount väntande ändringar...',
    );

    try {
      final now = clock.now();
      final pendingItems = await _syncQueueDao.getPendingForUser(userId);
      final ids = await _database.queuedOpIds(userId);
      final waiting = {...ids.waiting};
      final failed = {...ids.failed};
      final blockedEntities = <String>{};
      int successCount = 0;
      int failureCount = 0;

      for (final item in pendingItems) {
        final entityKey = '${item.entityType}:${item.recipeId}';
        final decision = decideQueueEntry(
          QueueEntryState(
            opId: item.opId,
            entityKey: entityKey,
            dependsOn: SyncQueueDao.dependsOnOf(item),
            nextAttemptAt: item.nextAttemptAt,
          ),
          now: now,
          waiting: waiting,
          failed: failed,
          blockedEntities: blockedEntities,
          force: force,
        );
        switch (decision) {
          case QueueEntryDecision.dependencyFailed:
            // "aldrig halvvägs" (produktregler.md:187).
            _moveToFailed(
              await _database.markChainPermanentlyFailed(
                userId,
                item.opId,
                reason: QueuedChangeReason.dependencyFailed.code,
              ),
              waiting,
              failed,
            );
            continue;
          case QueueEntryDecision.waits:
          case QueueEntryDecision.backoff:
            blockedEntities.add(entityKey);
            continue;
          case QueueEntryDecision.send:
            break;
        }

        try {
          await _send(item, userId);
          waiting.remove(item.opId);
          successCount++;
        } catch (e) {
          failureCount++;
          AppLogger.error(
            '❌ Fel vid synk av ${item.recipeId}: ${queueErrorCode(e)}',
          );
          final permanent = permanentFailureReason(e);
          final firstFailedAt = item.firstFailedAt ?? now;
          if (permanent != null || queueRetriesExhausted(firstFailedAt, now)) {
            final reason = permanent ?? QueuedChangeReason.retriesExhausted;
            _moveToFailed(
              await _database.markChainPermanentlyFailed(
                userId,
                item.opId,
                reason: QueuedChangeReason.dependencyFailed.code,
                rootReason: reason.code,
              ),
              waiting,
              failed,
            );
          } else {
            final failures = item.retryCount + 1;
            await _syncQueueDao.scheduleRetry(
              item.id,
              retryCount: failures,
              nextAttemptAt: now.add(
                queueRetryDelay(failures, random: _random),
              ),
              firstFailedAt: firstFailedAt,
              errorCode: queueErrorCode(e),
            );
            blockedEntities.add(entityKey);
          }
        }
      }

      _lastPassSent = successCount;
      if (successCount > 0) {
        AppLogger.success('🎉 Synkade $successCount ändringar');
      }
      if (failureCount > 0) {
        AppLogger.warning('⚠️ $failureCount ändringar kunde inte synkas');
      }

      await _scheduleNextAttempt(userId);
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

  static void _moveToFailed(
    Set<String> marked,
    Set<String> waiting,
    Set<String> failed,
  ) {
    waiting.removeAll(marked);
    failed.addAll(marked);
  }

  /// Sends one entry and removes it from the queue once the server has it.
  /// Throws when the attempt failed; the entry is then untouched.
  Future<void> _send(SyncQueueEntry item, String userId) async {
    // H9: Handle tag operations separately
    if (item.operation == SyncOperation.tag.name) {
      if (_onTagRecipe != null) {
        AppLogger.info('🏷️ Processing pending tagging for: ${item.recipeId}');
        await _onTagRecipe(item.recipeId);
        AppLogger.success('✅ Tagging completed for: ${item.recipeId}');
      } else {
        AppLogger.warning(
          '⚠️ Tag callback not configured, skipping: ${item.recipeId}',
        );
      }
      await _syncQueueDao.dequeue(item.id);
      return;
    }

    // Get recipe from Drift
    final offlineRecipe = await _recipeDao.getRecipe(item.recipeId, userId);
    if (offlineRecipe == null) {
      // The device copy is gone: the user deleted the recipe on the device,
      // which also clears its queue entries (OfflineUserStorage).
      await _syncQueueDao.dequeue(item.id);
      AppLogger.info('🗑️ Tog bort invalid sync entry: ${item.recipeId}');
      return;
    }
    if (!offlineRecipe.needsSync) {
      await _syncQueueDao.dequeue(item.id);
      AppLogger.info('✅ Recept ${item.recipeId} behöver inte synkas längre');
      return;
    }

    final json = jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
    final recipe = Recipe.fromJson(json);
    AppLogger.info('📤 Synkar recept: ${recipe.id}');

    // One attempt: the queue's own schedule is the backoff
    // (produktregler.md:188), so a failure goes back to the queue at once.
    //
    // BUT-1819: this write goes STRAIGHT at `/users/{uid}/recipes` and never
    // touches `FirebaseRecipeRepository`, so that class's `toFirestore`
    // override — the sanitization chokepoint for this collection — does not
    // run. Sanitize here or a recipe created offline syncs with its raw
    // title, description and sourceUrl, which is the path most likely to be
    // carrying unreviewed imported text.
    //
    // Deliberately NOT routed through the repository instead: `update()`
    // reads the doc first (a read per synced recipe), enforces ownership and
    // runs `_enforceShareCap`; and an offline-CREATED recipe has no document
    // yet, so `update()` would throw outright. The create-or-update
    // `setDocument` is the right primitive here.
    final userRecipesRef = _firestoreRepository.userRecipesCollection(userId);
    await _firestoreRepository.setDocument(
      userRecipesRef.doc(recipe.id),
      sanitizeRecipeText(recipe).toFirestore(),
    );

    // Sync succeeded - mark as synced in Drift, then leave the queue.
    await _recipeDao.markSynced(item.recipeId, userId);
    await _syncQueueDao.dequeue(item.id);
    AppLogger.success('✅ Synkade recept: ${recipe.id}');
  }

  /// Starts a timer for the earliest retry time among the entries still
  /// waiting, so the queue sends them when their time comes
  /// (produktregler.md:188). When the timer fires offline it does nothing;
  /// coming back online starts a pass.
  Future<void> _scheduleNextAttempt(String userId) async {
    final remaining = await _syncQueueDao.getPendingForUser(userId);
    final now = clock.now();
    DateTime? earliest;
    for (final entry in remaining) {
      final next = entry.nextAttemptAt;
      if (next == null) continue;
      if (earliest == null || next.isBefore(earliest)) earliest = next;
    }
    if (earliest == null) return;
    var delay = earliest.difference(now);
    if (delay.isNegative) delay = Duration.zero;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      final online = _isOnlineNow?.call() ?? true;
      if (online) unawaited(syncPendingChanges(isOnline: online));
    });
  }

  /// Whether a pass is scheduled for the next retry time.
  @visibleForTesting
  bool get hasScheduledRetry => _retryTimer?.isActive ?? false;

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
    _lastPassSent = 0;
    final itemsToSync = await _syncQueueDao.countPending(userId);

    await syncPendingChanges(isOnline: isOnline, force: true);

    // What reached the server, counted in the pass: an entry that became a
    // permanent failure also leaves the pending count, but was not saved.
    final syncedItems = min(_lastPassSent, itemsToSync);
    final remainingItems = itemsToSync - syncedItems;

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
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_syncLock != null && !_syncLock!.isCompleted) {
      _syncLock!.complete();
    }
    _syncLock = null;
    _isSyncing = false;
  }
}
