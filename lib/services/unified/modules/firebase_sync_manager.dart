// lib/services/unified/modules/firebase_sync_manager.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:get_it/get_it.dart';

/// Specialized Firebase synchronization manager providing real-time data streaming and subscription management.
/// This module implements comprehensive Firebase synchronization following Single Responsibility Principle,
/// handling all aspects of real-time data streaming including subscription management, change processing,
/// and health monitoring. It provides robust Firebase streaming capabilities ensuring real-time data
/// consistency while maintaining clean separation from cache operations and debounced synchronization.
/// **Single Responsibility Focus:**
/// This module exclusively handles Firebase real-time synchronization:
/// - **Stream Management**: Complete Firebase stream setup, lifecycle management, and subscription handling
/// - **Change Processing**: Real-time document change processing with type-safe recipe conversion
/// - **Health Monitoring**: Sync health assessment with automatic restart and recovery mechanisms
/// - **Selective Sync**: Granular control over the personal recipe synchronization stream
/// **What This Module Does NOT Handle:**
/// - Local cache operations and storage (handled by CacheOperations)
/// - Debounced write operations and batching (handled by DebouncedSyncOperations)
/// - Cache cleanup and optimization (handled by CacheOptimization)
/// - Authentication and user management (handled by parent services)
/// **Firebase Sync Features:**
/// - **Real-time Streams**: Live Firebase document streaming with automatic reconnection and error recovery
/// - **Repository Integration**: Seamless integration with the personal recipe repository
/// - **Health Monitoring**: Comprehensive sync health monitoring with automatic recovery and restart
/// - **Selective Control**: Granular control over individual sync streams for optimal performance
/// - **Error Handling**: Robust error handling with detailed logging and recovery mechanisms
/// **Usage Examples:**
/// ```dart
/// // Start complete Firebase synchronization
/// final subscriptions = await FirebaseSyncManager.startFirebaseSync(
///   currentUserId: userId,
///   onRecipeUpdated: handleRecipeUpdate,
///   onRecipeRemoved: handleRecipeRemoval,
///   onSyncError: handleSyncError,
/// );
/// // Start selective sync streams
/// final personalSub = FirebaseSyncManager.startPersonalSyncOnly(
///   currentUserId: userId,
///   onRecipeUpdated: handleUpdate,
///   onRecipeRemoved: handleRemoval,
///   onSyncError: handleError,
/// );
/// // Monitor and maintain sync health
/// await FirebaseSyncManager.ensureSyncHealth(
///   subscriptions: subscriptions,
///   currentUserId: userId,
///   // ... callback handlers
/// );
/// ```
class FirebaseSyncManager {
  /// Start Firebase synchronization for user's recipes
  static Future<Map<String, StreamSubscription>> startFirebaseSync({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
  }) async {
    try {
      AppLogger.info(
        '🔄 Starting Firebase sync for user: ${currentUserId.maskedUserId}',
      );

      final subscriptions = <String, StreamSubscription>{};

      // Start real-time listeners — initial snapshot populates cache
      // ignore: cancel_subscriptions - returned in Map for caller to manage
      final personalSub = _startPersonalRecipesSync(
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
        onSyncStatusChanged: onSyncStatusChanged,
      );
      subscriptions['personal_recipes'] = personalSub;

      AppLogger.success(
        '✅ Repository sync started (${subscriptions.length} streams)',
      );

      return subscriptions;
    } catch (e) {
      AppLogger.error('❌ Error starting repository sync: $e');
      rethrow;
    }
  }

  /// Stop all Firebase synchronization
  static Future<void> stopFirebaseSync({
    required Map<String, StreamSubscription> subscriptions,
  }) async {
    try {
      // Cancel all active subscriptions
      for (final subscription in subscriptions.values) {
        await subscription.cancel();
      }
      subscriptions.clear();

      AppLogger.info('Repository sync stopped');
    } catch (e) {
      AppLogger.error('Error stopping repository sync: $e');
      rethrow;
    }
  }

  /// Start syncing personal recipes
  static StreamSubscription _startPersonalRecipesSync({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
  }) {
    try {
      final recipeRepository = GetIt.instance<RecipeRepository>();

      final subscription = recipeRepository.subscribeToUserRecipes(
        currentUserId,
        (recipeChanges) => _handlePersonalRecipeChanges(
          changes: recipeChanges,
          onRecipeUpdated: onRecipeUpdated,
          onRecipeRemoved: onRecipeRemoved,
        ),
        onError: (error) => onSyncError('personal_recipes', error),
        onSyncStatusChanged: onSyncStatusChanged,
      );

      AppLogger.debug('Personal recipes sync started');
      return subscription;
    } catch (e) {
      AppLogger.error('Error starting personal recipes sync: $e');
      rethrow;
    }
  }

  /// Handle personal recipe changes
  static void _handlePersonalRecipeChanges({
    required List<RecipeChange> changes,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
  }) {
    try {
      for (final change in changes) {
        switch (change.type) {
          case RecipeChangeType.added:
          case RecipeChangeType.modified:
            onRecipeUpdated(change.recipe, 'personal');
            break;
          case RecipeChangeType.removed:
            onRecipeRemoved(change.recipe.id, 'personal');
            break;
        }
      }
    } catch (e) {
      AppLogger.error('Error handling personal recipe changes: $e');
    }
  }

  // Removed old Firebase-specific document change handling
  // Recipe changes now handled by repository-specific methods above
  /// Get sync status information
  static Map<String, dynamic> getSyncStatus({
    required Map<String, StreamSubscription> subscriptions,
    required String? currentUserId,
  }) {
    return {
      'activeSubscriptions': subscriptions.keys.toList(),
      'subscriptionCount': subscriptions.length,
      'currentUserId': currentUserId,
      'isSyncing': subscriptions.isNotEmpty,
      'personalSyncActive': subscriptions.containsKey('personal_recipes'),
    };
  }

  /// Check if currently syncing
  static bool isSyncing(Map<String, StreamSubscription> subscriptions) {
    return subscriptions.isNotEmpty;
  }

  /// Check if personal recipes are syncing
  static bool isPersonalSyncActive(
    Map<String, StreamSubscription> subscriptions,
  ) {
    return subscriptions.containsKey('personal_recipes');
  }

  /// Get active subscription names
  static List<String> getActiveSubscriptions(
    Map<String, StreamSubscription> subscriptions,
  ) {
    return subscriptions.keys.toList();
  }

  /// Start only personal recipes sync
  static StreamSubscription startPersonalSyncOnly({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
  }) {
    return _startPersonalRecipesSync(
      currentUserId: currentUserId,
      onRecipeUpdated: onRecipeUpdated,
      onRecipeRemoved: onRecipeRemoved,
      onSyncError: onSyncError,
      onSyncStatusChanged: onSyncStatusChanged,
    );
  }

  /// Stop specific sync stream
  static Future<void> stopSpecificSync({
    required Map<String, StreamSubscription> subscriptions,
    required String syncType,
  }) async {
    try {
      final subscription = subscriptions[syncType];
      if (subscription != null) {
        await subscription.cancel();
        subscriptions.remove(syncType);
        AppLogger.info('Stopped $syncType sync');
      }
    } catch (e) {
      AppLogger.error('Error stopping $syncType sync: $e');
      rethrow;
    }
  }

  /// Monitor sync health and restart if needed
  static Future<void> ensureSyncHealth({
    required Map<String, StreamSubscription> subscriptions,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
  }) async {
    try {
      final expectedSyncs = ['personal_recipes'];
      final missingSyncs = <String>[];

      for (final syncType in expectedSyncs) {
        if (!subscriptions.containsKey(syncType)) {
          missingSyncs.add(syncType);
        }
      }

      if (missingSyncs.isNotEmpty) {
        AppLogger.warning(
          'Restarting missing syncs: ${missingSyncs.join(', ')}',
        );

        for (final syncType in missingSyncs) {
          if (syncType == 'personal_recipes') {
            // ignore: cancel_subscriptions - added to subscriptions Map for management
            final sub = _startPersonalRecipesSync(
              currentUserId: currentUserId,
              onRecipeUpdated: onRecipeUpdated,
              onRecipeRemoved: onRecipeRemoved,
              onSyncError: onSyncError,
              onSyncStatusChanged: onSyncStatusChanged,
            );
            subscriptions[syncType] = sub;
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error ensuring sync health: $e');
    }
  }
}
