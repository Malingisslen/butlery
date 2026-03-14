/// Firebase repository for recipe presence tracking operations.
/// This repository handles Firebase operations for tracking which users are currently
/// viewing or editing collaborative recipes. It provides a clean separation between
/// presence tracking business logic and Firebase data operations.
/// **Collection Structure:**
/// ```
/// recipePresence/{recipeId}/activeUsers/{userId}
/// ```
/// **What This Repository Handles:**
/// - Setting user presence when they start viewing/editing
/// - Updating presence heartbeat to keep users marked as active
/// - Removing presence when users stop viewing/editing
/// - Query operations for active users (future enhancement)
/// **What This Repository Does NOT Handle:**
/// - Business logic for presence cleanup and expiry (handled by PresenceTrackingModule)
/// - UI state management (handled by ViewModels)
/// - Permission checks (presence is view-level, not permission-gated)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for recipe presence tracking operations
class FirebaseRecipePresenceRepository {
  final FirestoreRepository _firestoreRepository;
  final TimestampProvider _timestampProvider;

  FirebaseRecipePresenceRepository({
    FirestoreRepository? firestoreRepository,
    TimestampProvider? timestampProvider,
  })  : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>(),
        _timestampProvider =
            timestampProvider ?? const ServerTimestampProvider();

  /// Get Firestore instance via repository
  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  /// Set user presence in a recipe (user starts viewing/editing)
  /// Creates or updates a presence document for the user in the recipe's active users collection.
  /// Uses merge: true to allow updating existing presence without overwriting all fields.
  /// **Parameters:**
  /// - [recipeId]: ID of the recipe the user is viewing
  /// - [userId]: ID of the user
  /// - [displayName]: User's display name for UI
  /// - [avatarUrl]: User's avatar URL (optional)
  /// **Throws:** FirebaseException if write fails
  Future<void> setUserPresence({
    required String recipeId,
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .set({
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'joinedAt': _timestampProvider.serverTimestamp(),
        'lastSeen': _timestampProvider.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      AppLogger.debug('Set presence for user $userId in recipe $recipeId');
    } catch (e) {
      AppLogger.error('Failed to set user presence: $e');
      rethrow;
    }
  }

  /// Update user presence to inactive (user stops viewing/editing)
  /// Marks the user as inactive and records when they left.
  /// Does not delete the document to maintain history.
  /// **Parameters:**
  /// - [recipeId]: ID of the recipe
  /// - [userId]: ID of the user
  /// **Throws:** FirebaseException if update fails
  Future<void> markUserInactive({
    required String recipeId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .update({
        'isActive': false,
        'leftAt': _timestampProvider.serverTimestamp(),
      });

      AppLogger.debug('Marked user $userId inactive in recipe $recipeId');
    } catch (e) {
      AppLogger.error('Failed to mark user inactive: $e');
      rethrow;
    }
  }

  /// Update presence heartbeat (keep user marked as active)
  /// Updates the lastSeen timestamp to indicate the user is still actively viewing the recipe.
  /// Should be called periodically (e.g., every 30 seconds) while user is present.
  /// **Parameters:**
  /// - [recipeId]: ID of the recipe
  /// - [userId]: ID of the user
  /// **Throws:** FirebaseException if update fails
  Future<void> updatePresenceHeartbeat({
    required String recipeId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .update({
        'lastSeen': _timestampProvider.serverTimestamp(),
      });

      AppLogger.debug('Updated heartbeat for user $userId in recipe $recipeId');
    } catch (e) {
      AppLogger.error('Failed to update presence heartbeat: $e');
      rethrow;
    }
  }

  /// Get active users in a recipe (future enhancement)
  /// Query for all currently active users in a recipe.
  /// Can be used for real-time presence displays.
  /// **Parameters:**
  /// - [recipeId]: ID of the recipe
  /// **Returns:** List of active user presence documents
  Future<List<Map<String, dynamic>>> getActiveUsers(String recipeId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      AppLogger.error('Failed to get active users: $e');
      return [];
    }
  }

  /// Stream active users in a recipe (future enhancement)
  /// Real-time stream of active users for live presence indicators.
  /// **Parameters:**
  /// - [recipeId]: ID of the recipe
  /// **Returns:** Stream of active user lists
  Stream<List<Map<String, dynamic>>> watchActiveUsers(String recipeId) {
    return _firestore
        .collection(FirestoreCollections.recipePresence)
        .doc(recipeId)
        .collection(FirestoreCollections.activeUsers)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Delete all presence data for a recipe (cleanup operation)
  /// Removes all presence documents for a recipe. Typically used when a recipe is deleted
  /// or for administrative cleanup.
  /// **Parameters:**
  /// - [recipeId]: ID of the recipe
  /// **Note:** This is a batch delete operation that may fail partially
  Future<void> deleteRecipePresence(String recipeId) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection(FirestoreCollections.recipePresence)
          .doc(recipeId)
          .collection(FirestoreCollections.activeUsers)
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      AppLogger.debug('Deleted all presence data for recipe $recipeId');
    } catch (e) {
      AppLogger.error('Failed to delete recipe presence: $e');
      rethrow;
    }
  }
}
