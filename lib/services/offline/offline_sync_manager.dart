// lib/services/offline/offline_sync_manager.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/recipe_unified.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/retry_helper.dart';
import '../../repositories/firestore_repository.dart';
import '../../repositories/interfaces/auth_repository.dart';
import 'sync_result.dart';

/// Handles sync operations for offline service
class OfflineSyncManager {
  
  final Box<Recipe> _recipeBox;
  final Box<String> _syncQueueBox;
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  
  bool _isSyncing = false;
  final VoidCallback? _onSyncStateChanged;
  
  OfflineSyncManager({
    required Box<Recipe> recipeBox,
    required Box<String> syncQueueBox,
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
    VoidCallback? onSyncStateChanged,
  }) : _recipeBox = recipeBox,
       _syncQueueBox = syncQueueBox,
       _firestoreRepository = firestoreRepository,
       _authRepository = authRepository,
       _onSyncStateChanged = onSyncStateChanged;
  
  // Getters
  bool get isSyncing => _isSyncing;
  bool get hasQueuedChanges => _syncQueueBox.isNotEmpty;
  int get queuedChangesCount => _syncQueueBox.length;

  /// Sync pending changes without circular dependencies
  Future<void> syncPendingChanges({required bool isOnline}) async {
    if (!isOnline || _syncQueueBox.isEmpty || _isSyncing) return;

    _isSyncing = true;
    _onSyncStateChanged?.call();

    AppLogger.info(
      '🔄 Synkroniserar ${_syncQueueBox.length} väntande ändringar...',
    );

    try {
      final userId = _authRepository.currentUserId;
      if (userId == null) {
        AppLogger.warning('⚠️ Ingen användare inloggad - hoppar över sync');
        return;
      }

      final userRecipesRef = _firestoreRepository.userRecipesCollection(userId);

      final pendingIds = _syncQueueBox.values.toList();
      int successCount = 0;
      int failureCount = 0;
      final List<String> failedRecipes = [];

      for (final id in pendingIds) {
        Recipe? recipe;
        try {
          recipe = _recipeBox.get(id);
          if (recipe != null && recipe.needsSync) {
            AppLogger.info('📤 Synkar recept: ${recipe.title}');

            // Use retry logic for Firebase operations
            await RetryHelper.retryFirebaseOperation(() async {
              await _firestoreRepository.setDocument(
                userRecipesRef.doc(recipe!.id),
                recipe.toFirestore(),
              );
            });

            // Sync succeeded
            // Note: unified Recipe doesn't have isModifiedOffline or lastSyncedAt fields
            // This sync tracking functionality would need to be implemented differently
            
            // Save updated recipe offline
            await _recipeBox.put(id, recipe);

            // Remove from sync queue
            await _syncQueueBox.delete(id);
            successCount++;
            AppLogger.success('✅ Synkade recept: ${recipe.title}');
          } else if (recipe == null) {
            // Cleanup: Remove invalid entries from queue
            await _syncQueueBox.delete(id);
            AppLogger.info('🗑️ Tog bort invalid sync entry: $id');
          } else {
            // Recipe no longer needs sync - remove from queue
            await _syncQueueBox.delete(id);
            AppLogger.info('✅ Recept $id behöver inte synkas längre');
          }
        } catch (e) {
          failureCount++;
          final recipeTitle = recipe?.title ?? id;
          failedRecipes.add('$recipeTitle: ${e.toString()}');
          AppLogger.error('❌ Fel vid synk av $id: $e');

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
            '⏰ Alla sync-försök misslyckades, använder exponential backoff...');
        
        // Use exponential backoff for retry attempts
        RetryHelper.retryWithBackoff(() async {
          if (isOnline && _syncQueueBox.isNotEmpty) {
            AppLogger.info('🔄 Retry-försök startar...');
            await syncPendingChanges(isOnline: isOnline);
          }
        }, maxRetries: 3, shouldRetry: (error) {
          // Only retry if we still have items in the queue
          return _syncQueueBox.isNotEmpty;
        });
      }
    } catch (e) {
      AppLogger.error('❌ Kritiskt fel vid synkronisering: $e');

      // Graceful degradation: Log error but don't crash app
      AppLogger.info(
          '🛡️ Synkronisering hoppar över denna omgång, försöker igen senare');
    } finally {
      _isSyncing = false;
      _onSyncStateChanged?.call();
    }
  }

  /// Manual synchronization with user feedback
  Future<SyncResult> syncNow({required bool isOnline}) async {
    if (_isSyncing) {
      AppLogger.info('🔄 Synkronisering pågår redan...');
      return SyncResult(
        success: false,
        message: 'Synkronisering pågår redan',
        isRetry: false,
      );
    }

    if (!isOnline) {
      AppLogger.warning('⚠️ Kan inte synka offline');
      return SyncResult(
        success: false,
        message: 'Du måste vara online för att synkronisera',
        isRetry: false,
      );
    }

    if (_syncQueueBox.isEmpty) {
      AppLogger.info('✅ Inga ändringar att synkronisera');
      return SyncResult(
        success: true,
        message: 'Inga väntande ändringar',
        isRetry: false,
      );
    }

    AppLogger.info('🔄 Manuell synkronisering startad...');
    final itemsToSync = _syncQueueBox.length;

    await syncPendingChanges(isOnline: isOnline);

    final remainingItems = _syncQueueBox.length;
    final syncedItems = itemsToSync - remainingItems;

    if (remainingItems == 0) {
      return SyncResult(
        success: true,
        message: 'Alla $syncedItems ändringar synkade!',
        isRetry: false,
      );
    } else if (syncedItems > 0) {
      return SyncResult(
        success: true,
        message: '$syncedItems av $itemsToSync synkade, $remainingItems kvar',
        isRetry: remainingItems > 0,
      );
    } else {
      return SyncResult(
        success: false,
        message: 'Synkronisering misslyckades, försöker igen senare',
        isRetry: true,
      );
    }
  }
}