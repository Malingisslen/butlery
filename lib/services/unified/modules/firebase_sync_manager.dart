// lib/services/unified/modules/firebase_sync_manager.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/recipe_unified.dart';
import '../../../core/utils/logger.dart';

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
  static Future<Map<String, StreamSubscription<QuerySnapshot>>> startFirebaseSync({
    required FirebaseFirestore firestore,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) async {
    try {
      AppLogger.info('🔄 Starting Firebase sync for user: $currentUserId');

      final subscriptions = <String, StreamSubscription<QuerySnapshot>>{};

      // Start personal recipes sync
      final personalSub = await _startPersonalRecipesSync(
        firestore: firestore,
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
      );
      subscriptions['personal_recipes'] = personalSub;

      // Start collaborative recipes sync
      final collaborativeSub = await _startCollaborativeRecipesSync(
        firestore: firestore,
        currentUserId: currentUserId,
        onRecipeUpdated: onRecipeUpdated,
        onRecipeRemoved: onRecipeRemoved,
        onSyncError: onSyncError,
      );
      subscriptions['collaborative_recipes'] = collaborativeSub;

      AppLogger.success('✅ Firebase sync started (${subscriptions.length} streams)');
      return subscriptions;
    } catch (e) {
      AppLogger.error('❌ Error starting Firebase sync: $e');
      rethrow;
    }
  }

  /// Stop all Firebase synchronization
  static Future<void> stopFirebaseSync({
    required Map<String, StreamSubscription<QuerySnapshot>> subscriptions,
  }) async {
    try {
      // Cancel all active subscriptions
      for (final subscription in subscriptions.values) {
        await subscription.cancel();
      }
      subscriptions.clear();

      AppLogger.info('Firebase sync stopped');
    } catch (e) {
      AppLogger.error('Error stopping Firebase sync: $e');
      rethrow;
    }
  }

  // ===== PERSONAL RECIPES SYNC =====

  /// Start syncing personal recipes
  static Future<StreamSubscription<QuerySnapshot>> _startPersonalRecipesSync({
    required FirebaseFirestore firestore,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) async {
    try {
      final subscription = firestore
          .collection('users')
          .doc(currentUserId)
          .collection('unified_recipes')
          .snapshots()
          .listen(
            (snapshot) => _handlePersonalRecipesSnapshot(
              snapshot: snapshot,
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

  /// Handle personal recipes snapshot changes
  static void _handlePersonalRecipesSnapshot({
    required QuerySnapshot snapshot,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
  }) {
    try {
      for (final change in snapshot.docChanges) {
        _handleRecipeDocumentChange(
          change: change,
          source: 'personal',
          onRecipeUpdated: onRecipeUpdated,
          onRecipeRemoved: onRecipeRemoved,
        );
      }
    } catch (e) {
      AppLogger.error('Error handling personal recipes snapshot: $e');
    }
  }

  // ===== COLLABORATIVE RECIPES SYNC =====

  /// Start syncing collaborative recipes
  static Future<StreamSubscription<QuerySnapshot>> _startCollaborativeRecipesSync({
    required FirebaseFirestore firestore,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) async {
    try {
      final subscription = firestore
          .collection('unified_collaborative_recipes')
          .where('memberPermissions.$currentUserId', isNotEqualTo: null)
          .snapshots()
          .listen(
            (snapshot) => _handleCollaborativeRecipesSnapshot(
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

  /// Handle collaborative recipes snapshot changes
  static void _handleCollaborativeRecipesSnapshot({
    required QuerySnapshot snapshot,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
  }) {
    try {
      for (final change in snapshot.docChanges) {
        _handleRecipeDocumentChange(
          change: change,
          source: 'collaborative',
          onRecipeUpdated: onRecipeUpdated,
          onRecipeRemoved: onRecipeRemoved,
        );
      }
    } catch (e) {
      AppLogger.error('Error handling collaborative recipes snapshot: $e');
    }
  }

  // ===== DOCUMENT CHANGE HANDLING =====

  /// Handle individual recipe document changes
  static void _handleRecipeDocumentChange({
    required DocumentChange change,
    required String source,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
  }) {
    try {
      final doc = change.doc;
      
      switch (change.type) {
        case DocumentChangeType.added:
        case DocumentChangeType.modified:
          final recipe = Recipe.fromMap(doc.id, doc.data()! as Map<String, dynamic>);
          onRecipeUpdated(recipe, source);
          AppLogger.debug('Recipe ${change.type.name} from $source: ${recipe.title}');
          break;
          
        case DocumentChangeType.removed:
          onRecipeRemoved(doc.id, source);
          AppLogger.debug('Recipe removed from $source: ${doc.id}');
          break;
      }
    } catch (e) {
      AppLogger.error('Error handling recipe document change: $e');
    }
  }

  // ===== SYNC STATUS AND DIAGNOSTICS =====

  /// Get sync status information
  static Map<String, dynamic> getSyncStatus({
    required Map<String, StreamSubscription<QuerySnapshot>> subscriptions,
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
  static bool isSyncing(Map<String, StreamSubscription<QuerySnapshot>> subscriptions) {
    return subscriptions.isNotEmpty;
  }

  /// Check if personal recipes are syncing
  static bool isPersonalSyncActive(Map<String, StreamSubscription<QuerySnapshot>> subscriptions) {
    return subscriptions.containsKey('personal_recipes');
  }

  /// Check if collaborative recipes are syncing
  static bool isCollaborativeSyncActive(Map<String, StreamSubscription<QuerySnapshot>> subscriptions) {
    return subscriptions.containsKey('collaborative_recipes');
  }

  /// Get active subscription names
  static List<String> getActiveSubscriptions(Map<String, StreamSubscription<QuerySnapshot>> subscriptions) {
    return subscriptions.keys.toList();
  }

  // ===== SELECTIVE SYNC CONTROL =====

  /// Start only personal recipes sync
  static Future<StreamSubscription<QuerySnapshot>> startPersonalSyncOnly({
    required FirebaseFirestore firestore,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) async {
    return await _startPersonalRecipesSync(
      firestore: firestore,
      currentUserId: currentUserId,
      onRecipeUpdated: onRecipeUpdated,
      onRecipeRemoved: onRecipeRemoved,
      onSyncError: onSyncError,
    );
  }

  /// Start only collaborative recipes sync
  static Future<StreamSubscription<QuerySnapshot>> startCollaborativeSyncOnly({
    required FirebaseFirestore firestore,
    required String currentUserId,
    required void Function(Recipe, String) onRecipeUpdated,
    required void Function(String, String) onRecipeRemoved,
    required void Function(String, dynamic) onSyncError,
  }) async {
    return await _startCollaborativeRecipesSync(
      firestore: firestore,
      currentUserId: currentUserId,
      onRecipeUpdated: onRecipeUpdated,
      onRecipeRemoved: onRecipeRemoved,
      onSyncError: onSyncError,
    );
  }

  /// Stop specific sync stream
  static Future<void> stopSpecificSync({
    required Map<String, StreamSubscription<QuerySnapshot>> subscriptions,
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
    required Map<String, StreamSubscription<QuerySnapshot>> subscriptions,
    required FirebaseFirestore firestore,
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
            final sub = await _startPersonalRecipesSync(
              firestore: firestore,
              currentUserId: currentUserId,
              onRecipeUpdated: onRecipeUpdated,
              onRecipeRemoved: onRecipeRemoved,
              onSyncError: onSyncError,
            );
            subscriptions[syncType] = sub;
          } else if (syncType == 'collaborative_recipes') {
            final sub = await _startCollaborativeRecipesSync(
              firestore: firestore,
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