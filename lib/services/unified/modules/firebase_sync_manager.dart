// lib/services/unified/modules/firebase_sync_manager.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
// Removed unused collaborative repository import
import 'package:butlery/core/utils/logger.dart';
import 'package:get_it/get_it.dart';

/// Focused module for Firebase synchronization
/// 
/// This module handles ONLY Firebase real-time synchronization:
/// - Firebase stream setup and management
/// - Personal and collaborative recipe sync streams
/// - Document change handling and processing
/// - Sync subscription lifecycle management
/// 
/// ❌ DOES NOT CONTAIN: Cache operations, debounced sync, cleanup, statistics
class FirebaseSyncManager {

  // ===== SYNC STREAM MANAGEMENT =====

  /// Start Firebase synchronization for user's recipes
  static Future<Map<String, StreamSubscription>> startFirebaseSync({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) async {
    try {
      AppLogger.info('🔄 Starting Firebase sync for user: $currentUserId');

      final subscriptions = <String, StreamSubscription>{};

      // Start personal recipes sync
      // ignore: cancel_subscriptions - returned in Map for caller to manage
      final personalSub = _startPersonalRecipesSync(
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
      );
      subscriptions['personal_recipes'] = personalSub;

      // Start collaborative recipes sync
      // ignore: cancel_subscriptions - returned in Map for caller to manage
      final collaborativeSub = _startCollaborativeRecipesSync(
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
      );
      subscriptions['collaborative_recipes'] = collaborativeSub;

      AppLogger.success('✅ Repository sync started (${subscriptions.length} streams)');
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

  // ===== PERSONAL RECIPES SYNC =====

  /// Start syncing personal recipes
  static StreamSubscription _startPersonalRecipesSync({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
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

  // ===== COLLABORATIVE RECIPES SYNC =====

  /// Start syncing collaborative recipes
  static StreamSubscription _startCollaborativeRecipesSync({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) {
    try {
      // TODO: Implement collaborative recipe streaming via repository
      // For now, create a dummy stream that doesn't do anything
      final controller = StreamController<void>();
      final subscription = controller.stream.listen(
        (_) {}, // No-op listener
        onError: (error) => onSyncError('collaborative_recipes', error),
      );
      
      // Schedule the controller to be closed when the subscription is cancelled
      subscription.onDone(() => controller.close());

      AppLogger.debug('Collaborative recipes sync started (placeholder)');
      return subscription;
    } catch (e) {
      AppLogger.error('Error starting collaborative recipes sync: $e');
      rethrow;
    }
  }

  // Removed unused _handleCollaborativeRecipeChanges method
  // Collaborative recipe change handling will be implemented when repository supports it

  // ===== RECIPE CHANGE HANDLING =====
  // Removed old Firebase-specific document change handling
  // Recipe changes now handled by repository-specific methods above

  // ===== SYNC STATUS AND DIAGNOSTICS =====

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
      'collaborativeSyncActive': subscriptions.containsKey('collaborative_recipes'),
    };
  }

  /// Check if currently syncing
  static bool isSyncing(Map<String, StreamSubscription> subscriptions) {
    return subscriptions.isNotEmpty;
  }

  /// Check if personal recipes are syncing
  static bool isPersonalSyncActive(Map<String, StreamSubscription> subscriptions) {
    return subscriptions.containsKey('personal_recipes');
  }

  /// Check if collaborative recipes are syncing
  static bool isCollaborativeSyncActive(Map<String, StreamSubscription> subscriptions) {
    return subscriptions.containsKey('collaborative_recipes');
  }

  /// Get active subscription names
  static List<String> getActiveSubscriptions(Map<String, StreamSubscription> subscriptions) {
    return subscriptions.keys.toList();
  }

  // ===== SELECTIVE SYNC CONTROL =====

  /// Start only personal recipes sync
  static StreamSubscription startPersonalSyncOnly({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) {
    return _startPersonalRecipesSync(
      currentUserId: currentUserId,
      onRecipeUpdated: onRecipeUpdated,
      onRecipeRemoved: onRecipeRemoved,
      onSyncError: onSyncError,
    );
  }

  /// Start only collaborative recipes sync
  static StreamSubscription startCollaborativeSyncOnly({
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) {
    return _startCollaborativeRecipesSync(
      currentUserId: currentUserId,
      onRecipeUpdated: onRecipeUpdated,
      onRecipeRemoved: onRecipeRemoved,
      onSyncError: onSyncError,
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

  // ===== SYNC HEALTH MONITORING =====

  /// Monitor sync health and restart if needed
  static Future<void> ensureSyncHealth({
    required Map<String, StreamSubscription> subscriptions,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
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
        AppLogger.warning('Restarting missing syncs: ${missingSyncs.join(', ')}');
        
        for (final syncType in missingSyncs) {
          if (syncType == 'personal_recipes') {
            // ignore: cancel_subscriptions - added to subscriptions Map for management
            final sub = _startPersonalRecipesSync(
              currentUserId: currentUserId,
              onRecipeUpdated: onRecipeUpdated,
              onRecipeRemoved: onRecipeRemoved,
              onSyncError: onSyncError,
            );
            subscriptions[syncType] = sub;
          } else if (syncType == 'collaborative_recipes') {
            // ignore: cancel_subscriptions - added to subscriptions Map for management
            final sub = _startCollaborativeRecipesSync(
              currentUserId: currentUserId,
              onRecipeUpdated: onRecipeUpdated,
              onRecipeRemoved: onRecipeRemoved,
              onSyncError: onSyncError,
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