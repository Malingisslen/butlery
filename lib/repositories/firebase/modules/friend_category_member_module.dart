// lib/repositories/firebase/modules/friend_category_member_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_category_member.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Module for managing friend category members using subcollections.
///
/// Uses two-way indexing for efficient queries:
/// 1. `users/{ownerId}/friendCategories/{categoryId}/members/{friendId}` - Get members in category
/// 2. `users/{friendId}/categoryMemberships/{categoryId}` - Get categories a friend is in
///
/// This replaces inline `friendUserIds` arrays for categories exceeding the threshold,
/// scaling better for:
/// - Large friend categories (50+ friends)
/// - Users with many category memberships
/// - Independent member metadata updates
class FriendCategoryMemberModule {
  final FirebaseFirestore firestore;
  final FeatureFlagService featureFlags;

  FriendCategoryMemberModule({
    required this.firestore,
    required this.featureFlags,
  });

  bool get _isEnabled =>
      featureFlags.isEnabled(FeatureFlags.enableFriendCategorySubcollection);

  int get _maxInlineMembers =>
      featureFlags.getInt(FeatureFlags.maxInlineCategoryMembers);

  /// Get reference to category members subcollection
  CollectionReference<Map<String, dynamic>> _membersRef(
    String ownerId,
    String categoryId,
  ) =>
      firestore
          .collection(FirestoreCollections.users)
          .doc(ownerId)
          .collection(FirestoreCollections.userFriendCategories)
          .doc(categoryId)
          .collection(FirestoreCollections.members);

  /// Get reference to user's category memberships
  CollectionReference<Map<String, dynamic>> _membershipsRef(String userId) =>
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userCategoryMemberships);

  /// Add a member to a category using subcollections.
  /// Creates entries in both the category's members subcollection
  /// and the friend's categoryMemberships subcollection.
  Future<void> addMember({
    required String ownerId,
    required String categoryId,
    required String categoryName,
    String? categoryEmoji,
    required String friendId,
    String? displayName,
    String? avatarUrl,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    // 1. Add to category's members subcollection
    final member = FriendCategoryMember.create(
      friendId: friendId,
      categoryId: categoryId,
      ownerId: ownerId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    final memberRef = _membersRef(ownerId, categoryId).doc(friendId);
    batch.set(memberRef, member.toFirestore());

    // 2. Add to friend's categoryMemberships subcollection (inverse index)
    final membership = CategoryMembership(
      categoryId: categoryId,
      ownerId: ownerId,
      categoryName: categoryName,
      categoryEmoji: categoryEmoji,
      addedAt: DateTime.now(),
    );

    final membershipRef = _membershipsRef(friendId).doc(categoryId);
    batch.set(membershipRef, membership.toFirestore());

    // 3. Update member count in category document
    final categoryRef = firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.userFriendCategories)
        .doc(categoryId);
    batch.update(categoryRef, {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
    AppLogger.debug(
        'Added member $friendId to category $categoryId (subcollection)');
  }

  /// Add multiple members to a category.
  Future<void> addMembers({
    required String ownerId,
    required String categoryId,
    required String categoryName,
    String? categoryEmoji,
    required List<String> friendIds,
    Map<String, String>? displayNames,
    Map<String, String?>? avatarUrls,
  }) async {
    if (!_isEnabled || friendIds.isEmpty) return;

    final batch = firestore.batch();
    final categoryRef = firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.userFriendCategories)
        .doc(categoryId);

    for (final friendId in friendIds) {
      // 1. Add to category's members subcollection
      final member = FriendCategoryMember.create(
        friendId: friendId,
        categoryId: categoryId,
        ownerId: ownerId,
        displayName: displayNames?[friendId],
        avatarUrl: avatarUrls?[friendId],
      );

      final memberRef = _membersRef(ownerId, categoryId).doc(friendId);
      batch.set(memberRef, member.toFirestore());

      // 2. Add to friend's categoryMemberships subcollection
      final membership = CategoryMembership(
        categoryId: categoryId,
        ownerId: ownerId,
        categoryName: categoryName,
        categoryEmoji: categoryEmoji,
        addedAt: DateTime.now(),
      );

      final membershipRef = _membershipsRef(friendId).doc(categoryId);
      batch.set(membershipRef, membership.toFirestore());
    }

    // 3. Update member count
    batch.update(categoryRef, {
      'memberCount': FieldValue.increment(friendIds.length),
    });

    await batch.commit();
    AppLogger.debug(
        'Added ${friendIds.length} members to category $categoryId (subcollection)');
  }

  /// Remove a member from a category.
  Future<void> removeMember({
    required String ownerId,
    required String categoryId,
    required String friendId,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    // 1. Remove from category's members subcollection
    final memberRef = _membersRef(ownerId, categoryId).doc(friendId);
    batch.delete(memberRef);

    // 2. Remove from friend's categoryMemberships subcollection
    final membershipRef = _membershipsRef(friendId).doc(categoryId);
    batch.delete(membershipRef);

    // 3. Update member count
    final categoryRef = firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.userFriendCategories)
        .doc(categoryId);
    batch.update(categoryRef, {
      'memberCount': FieldValue.increment(-1),
    });

    await batch.commit();
    AppLogger.debug(
        'Removed member $friendId from category $categoryId (subcollection)');
  }

  /// Remove multiple members from a category.
  Future<void> removeMembers({
    required String ownerId,
    required String categoryId,
    required List<String> friendIds,
  }) async {
    if (!_isEnabled || friendIds.isEmpty) return;

    final batch = firestore.batch();
    final categoryRef = firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.userFriendCategories)
        .doc(categoryId);

    for (final friendId in friendIds) {
      // Remove from members subcollection
      final memberRef = _membersRef(ownerId, categoryId).doc(friendId);
      batch.delete(memberRef);

      // Remove from friend's categoryMemberships
      final membershipRef = _membershipsRef(friendId).doc(categoryId);
      batch.delete(membershipRef);
    }

    // Update member count
    batch.update(categoryRef, {
      'memberCount': FieldValue.increment(-friendIds.length),
    });

    await batch.commit();
    AppLogger.debug(
        'Removed ${friendIds.length} members from category $categoryId (subcollection)');
  }

  /// Get all members for a category.
  Future<List<FriendCategoryMember>> getMembers(
    String ownerId,
    String categoryId,
  ) async {
    if (!_isEnabled) return [];

    final snapshot = await _membersRef(ownerId, categoryId)
        .orderBy('addedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => FriendCategoryMember.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Get member IDs only (more efficient when full data not needed).
  Future<List<String>> getMemberIds(
    String ownerId,
    String categoryId,
  ) async {
    if (!_isEnabled) return [];

    final snapshot = await _membersRef(ownerId, categoryId).get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Stream members for a category.
  Stream<List<FriendCategoryMember>> watchMembers(
    String ownerId,
    String categoryId,
  ) {
    if (!_isEnabled) return const Stream.empty();

    return _membersRef(ownerId, categoryId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(
                (doc) => FriendCategoryMember.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Get category memberships for a friend (inverse index query).
  Future<List<CategoryMembership>> getFriendMemberships(String friendId) async {
    if (!_isEnabled) return [];

    final snapshot = await _membershipsRef(friendId).get();

    return snapshot.docs
        .map((doc) => CategoryMembership.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Check if a friend is in a category.
  Future<bool> isMember({
    required String ownerId,
    required String categoryId,
    required String friendId,
  }) async {
    if (!_isEnabled) return false;

    final doc = await _membersRef(ownerId, categoryId).doc(friendId).get();
    return doc.exists;
  }

  /// Migrate an existing category's members to subcollections.
  /// Called when a category exceeds maxInlineMembers.
  Future<void> migrateToSubcollection({
    required FriendCategory category,
    Map<String, String>? displayNames,
    Map<String, String?>? avatarUrls,
  }) async {
    if (!_isEnabled) return;

    final batch = firestore.batch();

    for (final friendId in category.friendUserIds) {
      // Create member entry
      final member = FriendCategoryMember.create(
        friendId: friendId,
        categoryId: category.id,
        ownerId: category.ownerId,
        displayName: displayNames?[friendId],
        avatarUrl: avatarUrls?[friendId],
      );

      final memberRef =
          _membersRef(category.ownerId, category.id).doc(friendId);
      batch.set(memberRef, member.toFirestore());

      // Create membership entry (inverse index)
      final membership = CategoryMembership(
        categoryId: category.id,
        ownerId: category.ownerId,
        categoryName: category.name,
        categoryEmoji: category.emoji,
        addedAt: DateTime.now(),
      );

      final membershipRef = _membershipsRef(friendId).doc(category.id);
      batch.set(membershipRef, membership.toFirestore());
    }

    // Mark category as migrated and store member count
    final categoryRef = firestore
        .collection(FirestoreCollections.users)
        .doc(category.ownerId)
        .collection(FirestoreCollections.userFriendCategories)
        .doc(category.id);

    batch.update(categoryRef, {
      'usesSubcollectionMembers': true,
      'memberCount': category.friendUserIds.length,
      // Keep legacy array for backward compatibility during transition
      // but it will no longer be the source of truth
    });

    await batch.commit();
    AppLogger.info('Migrated category ${category.id} to subcollection members '
        '(${category.friendUserIds.length} members)');
  }

  /// Check if should use subcollection based on member count.
  bool shouldUseSubcollection(int memberCount) {
    return _isEnabled && memberCount > _maxInlineMembers;
  }

  /// Delete all member entries when deleting a category.
  Future<void> deleteAllMembers({
    required String ownerId,
    required String categoryId,
  }) async {
    if (!_isEnabled) return;

    // Get all members first to also delete their inverse indexes
    final members = await getMembers(ownerId, categoryId);
    if (members.isEmpty) return;

    final batch = firestore.batch();

    for (final member in members) {
      // Delete from members subcollection
      final memberRef = _membersRef(ownerId, categoryId).doc(member.friendId);
      batch.delete(memberRef);

      // Delete from friend's categoryMemberships
      final membershipRef = _membershipsRef(member.friendId).doc(categoryId);
      batch.delete(membershipRef);
    }

    await batch.commit();
    AppLogger.debug(
        'Deleted all ${members.length} members from category $categoryId');
  }
}
