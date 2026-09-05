/// Repository for user block relationships using dedicated `blocks` collection.
/// Uses composite-key documents (`{blockerId}_{blockedId}`) for O(1) lookups.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/block_record.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

class FirebaseBlockRepository extends BaseFirebaseRepository<BlockRecord> {
  FirebaseBlockRepository({super.firestore, required super.authRepository});

  @override
  String get collectionName => FirestoreCollections.blocks;

  @override
  BlockRecord fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return BlockRecord.fromFirestore(doc.data() ?? {}, doc.id);
  }

  @override
  Map<String, dynamic> toFirestore(BlockRecord entity) => entity.toFirestore();

  @override
  String getId(BlockRecord entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(
    String userId,
    BlockRecord entity,
  ) async => userId == entity.blockerId;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    BlockRecord? entity,
  ) async => true; // Security rules enforce access

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    BlockRecord entity,
  ) async => false; // Block records are immutable

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Split on first '_' only to avoid false matches if UID contains '_'
    final separatorIndex = resourceId.indexOf('_');
    if (separatorIndex < 0) return false;
    final blockerId = resourceId.substring(0, separatorIndex);
    return blockerId == userId;
  }

  Future<void> blockUser(String targetId) async {
    final uid = requireCurrentUserId();
    final record = BlockRecord.create(blockerId: uid, blockedId: targetId);

    try {
      await collection.doc(record.id).set(record.toFirestore());
      AppLogger.info('Blocked user: $targetId');
    } catch (e) {
      AppLogger.error('Failed to block user: $targetId', e);
      rethrow;
    }
  }

  Future<void> unblockUser(String targetId) async {
    final uid = requireCurrentUserId();
    final docId = BlockRecord.compositeId(uid, targetId);

    try {
      await collection.doc(docId).delete();
      AppLogger.info('Unblocked user: $targetId');
    } catch (e) {
      AppLogger.error('Failed to unblock user: $targetId', e);
      rethrow;
    }
  }

  Future<bool> isBlocked(String targetId) async {
    final uid = requireCurrentUserId();
    final docId = BlockRecord.compositeId(uid, targetId);
    try {
      final doc = await collection.doc(docId).get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('Failed to check block status for $targetId', e);
      return false;
    }
  }

  Future<bool> isBlockedBy(String targetId) async {
    final uid = requireCurrentUserId();
    final docId = BlockRecord.compositeId(targetId, uid);
    try {
      final doc = await collection.doc(docId).get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('Failed to check blockedBy status for $targetId', e);
      return false;
    }
  }

  /// Get all users blocked by the current user.
  Future<Set<String>> getBlockedUserIds() async {
    final uid = requireCurrentUserId();
    final snapshot = await collection.where('blockerId', isEqualTo: uid).get();

    return snapshot.docs
        .map((doc) => BlockRecord.fromFirestore(doc.data(), doc.id).blockedId)
        .toSet();
  }

  /// The same list, but it must come from the SERVER.
  ///
  /// BUT-1922. A plain `get()` answers from the local cache WITHOUT an error
  /// while the device is offline, so a caller that only knows how to refuse an
  /// unreadable list cannot tell a current answer from a stale one. Offline
  /// this throws `unavailable` instead, which is what `closePoll`'s refusal
  /// needs to fire. Display paths must NOT use this: offline it throws, and the
  /// fail-open catch above them then serves the chat UNFILTERED, so a blocked
  /// person's messages come back.
  Future<Set<String>> getBlockedUserIdsFromServer() async {
    final uid = requireCurrentUserId();
    final snapshot = await collection
        .where('blockerId', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((doc) => BlockRecord.fromFirestore(doc.data(), doc.id).blockedId)
        .toSet();
  }

  /// Stream of blocked user IDs for real-time updates.
  Stream<Set<String>> watchBlockedUserIds() {
    final uid = currentUserId;
    if (uid == null) return Stream.value({});

    return collection
        .where('blockerId', isEqualTo: uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    BlockRecord.fromFirestore(doc.data(), doc.id).blockedId,
              )
              .toSet(),
        );
  }

  // BUT-1917: `deleteAllBlocksForUser` used to sit here, and account deletion
  // never called it. It could not have worked either — it deleted rows in BOTH
  // directions, and `firestore.rules` allows a delete only to the row's
  // blocker, so the leg that clears other people's blocks OF this user would
  // have been refused and taken the whole atomic batch down with it.
  //
  // Erasing those rows is a server job, and it is done in the account cascade
  // (`deleteBlocks`, `functions/src/account/account-deletion-cascade.ts`),
  // which runs with the Admin SDK. Do not reinstate a client-side version.
}
