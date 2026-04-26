/// Firebase repository for collaborative shopping presence tracking (BUT-238).
/// Mirrors [FirebaseRecipePresenceRepository] but scoped to shopping lists.
/// **Collection Structure:**
/// ```
/// shoppingPresence/{listId}/activeUsers/{userId}
/// ```
/// **What This Repository Handles:**
/// - Setting user presence when they open a collaborative shopping list
/// - Periodic heartbeat updates (30s TTL) via `set(merge: true)`
/// - Removing presence when the user leaves the list
/// - Streaming active users for "Anna handlar nu" indicators
///
/// Per-list (not per-item) presence — one doc per list, one row per active shopper.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/_presence_ttl.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for collaborative shopping presence tracking (BUT-238).
///
/// **TTL contract (BUT-477):** every write sets `expiresAt = now + 60s`.
/// Clients refresh at 30 s heartbeat (twice within the TTL window so a
/// missed tick does not flicker). Server-side TTL policy on `expiresAt`
/// is the authoritative GC; client read paths also filter rows where
/// `expiresAt < now` to mask stale data while the server-side sweeper
/// catches up.
class FirebaseShoppingPresenceRepository {
  final FirestoreRepository _firestoreRepository;
  final TimestampProvider _timestampProvider;

  FirebaseShoppingPresenceRepository({
    FirestoreRepository? firestoreRepository,
    TimestampProvider? timestampProvider,
  })  : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>(),
        _timestampProvider =
            timestampProvider ?? const ServerTimestampProvider();

  FirebaseFirestore get _firestore => _firestoreRepository.firestore;

  /// Mark a user as present on a shopping list.
  /// Uses set(merge: true) so repeated calls act as heartbeat upserts.
  Future<void> setUserPresence({
    required String listId,
    required String userId,
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .set({
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'joinedAt': _timestampProvider.serverTimestamp(),
        'lastSeen': _timestampProvider.serverTimestamp(),
        'expiresAt': PresenceTtl.computeExpiresAt(),
        'isActive': true,
      }, SetOptions(merge: true));
      AppLogger.debug(
          'Shopping presence set for ${userId.maskedUserId} on list $listId');
    } catch (e) {
      AppLogger.error('Failed to set shopping presence: $e');
      rethrow;
    }
  }

  /// Mark a user as no longer active (shopper closed the list).
  Future<void> markUserInactive({
    required String listId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .set({
        'isActive': false,
        'leftAt': _timestampProvider.serverTimestamp(),
        // Force immediate TTL eviction — the user explicitly left.
        'expiresAt': Timestamp.fromDate(DateTime.now().toUtc()),
      }, SetOptions(merge: true));
      AppLogger.debug(
          'Shopping presence cleared for ${userId.maskedUserId} on list $listId');
    } catch (e) {
      AppLogger.error('Failed to clear shopping presence: $e');
      rethrow;
    }
  }

  /// Heartbeat — refresh lastSeen while the user has the list open.
  Future<void> updatePresenceHeartbeat({
    required String listId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .set({
        'lastSeen': _timestampProvider.serverTimestamp(),
        'expiresAt': PresenceTtl.computeExpiresAt(),
        'isActive': true,
      }, SetOptions(merge: true));
    } catch (e) {
      AppLogger.error('Failed to update shopping presence heartbeat: $e');
      rethrow;
    }
  }

  /// One-shot read of active shoppers on a list.
  Future<List<Map<String, dynamic>>> getActiveUsers(String listId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .where('isActive', isEqualTo: true)
          .get();
      return PresenceTtl.filterStaleRows(
          snapshot.docs.map((doc) => doc.data()));
    } catch (e) {
      AppLogger.error('Failed to get active shoppers: $e');
      return [];
    }
  }

  /// Live stream of active shoppers for real-time UI updates.
  Stream<List<Map<String, dynamic>>> watchActiveUsers(String listId) {
    return _firestore
        .collection(FirestoreCollections.shoppingPresence)
        .doc(listId)
        .collection(FirestoreCollections.activeUsers)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => PresenceTtl.filterStaleRows(
            snapshot.docs.map((doc) => doc.data())));
  }
}
