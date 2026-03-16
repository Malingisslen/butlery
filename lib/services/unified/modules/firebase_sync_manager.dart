// lib/services/unified/modules/firebase_sync_manager.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

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
/// - **Selective Sync**: Granular control over personal and collaborative recipe synchronization streams
/// **What This Module Does NOT Handle:**
/// - Local cache operations and storage (handled by CacheOperations)
/// - Debounced write operations and batching (handled by DebouncedSyncOperations)
/// - Cache cleanup and optimization (handled by CacheOptimization)
/// - Authentication and user management (handled by parent services)
/// **Firebase Sync Features:**
/// - **Real-time Streams**: Live Firebase document streaming with automatic reconnection and error recovery
/// - **Repository Integration**: Seamless integration with personal and collaborative recipe repositories
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
    required FirebaseFirestore firestore,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
  }) async {
    try {
      AppLogger.info('🔄 Starting Firebase sync for user: $currentUserId');

      final subscriptions = <String, StreamSubscription>{};

      // STEP 1: Start real-time listeners FIRST so UI renders from cache immediately (BUT-198)
      // ignore: cancel_subscriptions - returned in Map for caller to manage
      final personalSub = _startPersonalRecipesSync(
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
        onSyncStatusChanged: onSyncStatusChanged,
      );
      subscriptions['personal_recipes'] = personalSub;

      // ignore: cancel_subscriptions - returned in Map for caller to manage
      final collaborativeSub = _startCollaborativeRecipesSync(
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
        firestore: firestore,
      );
      subscriptions['collaborative_recipes'] = collaborativeSub;

      AppLogger.success(
        '✅ Repository sync started (${subscriptions.length} streams)',
      );

      // STEP 2: Fire-and-forget initial fetch to backfill cache (BUT-198)
      // Real-time listeners already active so no data is missed.
      // ignore: unawaited_futures
      _fetchExistingRecipes(
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onSyncError: onSyncError,
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

  /// Fetches existing recipes from Firestore to backfill cache (BUT-198).
  /// Runs as fire-and-forget after listeners are active.
  static Future<void> _fetchExistingRecipes({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, dynamic) onSyncError,
  }) async {
    try {
      final recipeRepository = GetIt.instance<RecipeRepository>();
      AppLogger.info('📥 Fetching existing recipes from Firestore...');

      final existingRecipes = await recipeRepository.fetchUserRecipes(
        currentUserId,
      );

      AppLogger.info('📥 Fetched ${existingRecipes.length} existing recipes');

      for (final recipe in existingRecipes) {
        onRecipeUpdated(recipe, 'initial_fetch');
      }

      AppLogger.success(
        '✅ Initial fetch complete: ${existingRecipes.length} recipes loaded',
      );
    } catch (e) {
      AppLogger.error('❌ Error fetching existing recipes: $e');
      onSyncError('initial_fetch', e);
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

  /// Start syncing collaborative recipes
  static StreamSubscription _startCollaborativeRecipesSync({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
    required FirebaseFirestore firestore,
  }) {
    try {
      final firestoreInstance = firestore;

      // Watch for collaborative recipes where user is a participant
      // Use participantIds array for proper Firestore rules validation
      final subscription = firestoreInstance
          .collection(FirestoreCollections.realtimeRecipes)
          .where('participantIds', arrayContains: currentUserId)
          .snapshots()
          .listen(
            (snapshot) => _handleCollaborativeRecipeChanges(
              snapshot: snapshot,
              onRecipeUpdated: onRecipeUpdated,
              onRecipeRemoved: onRecipeRemoved,
            ),
            onError: (error) => onSyncError('collaborative_recipes', error),
          );

      AppLogger.debug('Collaborative recipes sync started');
      return subscription;
    } catch (e) {
      AppLogger.error('Error starting collaborative recipes sync: $e');
      rethrow;
    }
  }

  /// Handle collaborative recipe changes
  static void _handleCollaborativeRecipeChanges({
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
  }) {
    try {
      for (final docChange in snapshot.docChanges) {
        switch (docChange.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            final realtimeRecipe = RealtimeRecipe.fromFirestore(docChange.doc);
            onRecipeUpdated(realtimeRecipe.recipe, 'collaborative');
            break;
          case DocumentChangeType.removed:
            onRecipeRemoved(docChange.doc.id, 'collaborative');
            break;
        }
      }
    } catch (e) {
      AppLogger.error('Error handling collaborative recipe changes: $e');
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
      'collaborativeSyncActive': subscriptions.containsKey(
        'collaborative_recipes',
      ),
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

  /// Check if collaborative recipes are syncing
  static bool isCollaborativeSyncActive(
    Map<String, StreamSubscription> subscriptions,
  ) {
    return subscriptions.containsKey('collaborative_recipes');
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

  /// Start only collaborative recipes sync
  static StreamSubscription startCollaborativeSyncOnly({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
    required FirebaseFirestore firestore,
  }) {
    return _startCollaborativeRecipesSync(
      currentUserId: currentUserId,
      onRecipeUpdated: onRecipeUpdated,
      onRecipeRemoved: onRecipeRemoved,
      onSyncError: onSyncError,
      firestore: firestore,
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
    required FirebaseFirestore firestore,
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
  }) async {
    try {
      final expectedSyncs = ['personal_recipes', 'collaborative_recipes'];
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
          } else if (syncType == 'collaborative_recipes') {
            // ignore: cancel_subscriptions - added to subscriptions Map for management
            final sub = _startCollaborativeRecipesSync(
              currentUserId: currentUserId,
              onRecipeUpdated: onRecipeUpdated,
              onRecipeRemoved: onRecipeRemoved,
              onSyncError: onSyncError,
              firestore: firestore,
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
