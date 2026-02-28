// lib/services/cache/permission_cache_invalidator.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/cache/permission_cache_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Listens to Firestore document changes and invalidates relevant cache entries.
///
/// This service sets up real-time listeners for permission-relevant documents
/// (like sharedRecipes, sharedMenus, etc.) and invalidates the permission cache
/// when sharing permissions change.
///
/// Usage:
/// ```dart
/// final invalidator = PermissionCacheInvalidator(
///   firestore: firestore,
///   permissionCache: cacheService,
/// );
/// await invalidator.startListening(userId);
/// // Later...
/// invalidator.stopListening();
/// ```
class PermissionCacheInvalidator {
  final FirebaseFirestore _firestore;
  final PermissionCacheService _permissionCache;

  /// Active stream subscriptions
  final List<StreamSubscription<QuerySnapshot>> _subscriptions = [];

  /// Currently listening user
  String? _currentUserId;

  PermissionCacheInvalidator({
    required FirebaseFirestore firestore,
    required PermissionCacheService permissionCache,
  })  : _firestore = firestore,
        _permissionCache = permissionCache;

  /// Start listening for permission changes for a user.
  ///
  /// Sets up listeners for:
  /// - Shared recipes where user is a participant
  /// - Shared menus where user is a participant
  /// - Shared shopping lists where user is a participant
  Future<void> startListening(String userId) async {
    if (_currentUserId == userId) return;

    stopListening(); // Clear existing listeners
    _currentUserId = userId;

    if (!_permissionCache.isEnabled) {
      AppLogger.debug(
          'Permission cache invalidator: caching disabled, not starting listeners');
      return;
    }

    // Listen to shared recipes
    _subscriptions.add(
      _firestore
          .collection(FirestoreCollections.sharedRecipesDenorm)
          .where('participantIds', arrayContains: userId)
          .snapshots()
          .listen(
            (snapshot) => _handleDocumentChanges(snapshot, 'shared_recipe'),
            onError: (e) => AppLogger.warning(
                'Permission invalidator error (sharedRecipes): $e'),
          ),
    );

    // Listen to shared menus
    _subscriptions.add(
      _firestore
          .collection(FirestoreCollections.sharedMenusDenorm)
          .where('participantIds', arrayContains: userId)
          .snapshots()
          .listen(
            (snapshot) => _handleDocumentChanges(snapshot, 'shared_menu'),
            onError: (e) => AppLogger.warning(
                'Permission invalidator error (sharedMenus): $e'),
          ),
    );

    // Listen to shared shopping lists
    _subscriptions.add(
      _firestore
          .collection(FirestoreCollections.sharedShoppingListsDenorm)
          .where('participantIds', arrayContains: userId)
          .snapshots()
          .listen(
            (snapshot) => _handleDocumentChanges(snapshot, 'shared_shopping'),
            onError: (e) => AppLogger.warning(
                'Permission invalidator error (sharedShoppingLists): $e'),
          ),
    );

    AppLogger.debug(
        'Permission cache invalidator: started listening for user $userId');
  }

  /// Stop all listeners.
  void stopListening() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _currentUserId = null;
    AppLogger.debug('Permission cache invalidator: stopped listening');
  }

  /// Handle document changes by invalidating relevant cache entries.
  void _handleDocumentChanges(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String resourceType,
  ) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.modified ||
          change.type == DocumentChangeType.removed) {
        _permissionCache.invalidateResource(
          resourceType: resourceType,
          resourceId: change.doc.id,
        );

        AppLogger.debug(
            'Permission cache: invalidated $resourceType:${change.doc.id} '
            'due to ${change.type.name}');
      }
    }
  }

  /// Manually invalidate cache for a specific resource.
  ///
  /// Use this when you know a resource's permissions have changed
  /// but before the Firestore listener fires.
  void invalidateResourceNow({
    required String resourceType,
    required String resourceId,
  }) {
    _permissionCache.invalidateResource(
      resourceType: resourceType,
      resourceId: resourceId,
    );
  }

  /// Dispose of all resources.
  void dispose() {
    stopListening();
  }
}
