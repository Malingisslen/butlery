/// Repository for user block relationships using dedicated `blocks` collection.
/// Uses composite-key documents (`{blockerId}_{blockedId}`) for O(1) lookups.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/block_record.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

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
          String userId, BlockRecord entity) async =>
      userId == entity.blockerId;

  @override
  Future<bool> validateReadPermission(
          String userId, String resourceId, BlockRecord? entity) async =>
      true; // Security rules enforce access

  @override
  Future<bool> validateUpdatePermission(
          String userId, String resourceId, BlockRecord entity) async =>
      false; // Block records are immutable

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
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

  /// Stream of blocked user IDs for real-time updates.
  Stream<Set<String>> watchBlockedUserIds() {
    final uid = currentUserId;
    if (uid == null) return Stream.value({});

    return collection.where('blockerId', isEqualTo: uid).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) =>
                BlockRecord.fromFirestore(doc.data(), doc.id).blockedId)
            .toSet());
  }

  /// Delete all block records involving a user (for account deletion / GDPR).
  Future<void> deleteAllBlocksForUser(String userId) async {
    final uid = requireCurrentUserId();
    if (uid != userId) {
      throw PermissionDeniedException('Can only delete own block records');
    }

    // Delete blocks where user is the blocker
    final asBlocker =
        await collection.where('blockerId', isEqualTo: userId).get();
    // Delete blocks where user is the blocked
    final asBlocked =
        await collection.where('blockedId', isEqualTo: userId).get();

    final batch = firestore.batch();
    for (final doc in [...asBlocker.docs, ...asBlocked.docs]) {
      batch.delete(doc.reference);
    }

    if (asBlocker.docs.isNotEmpty || asBlocked.docs.isNotEmpty) {
      await batch.commit();
      AppLogger.info(
          'Deleted ${asBlocker.docs.length + asBlocked.docs.length} block records for user ${userId.maskedUserId}');
    }
  }
}
