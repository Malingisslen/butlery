/// Firebase implementation for friend category management.
/// Uses user-scoped subcollections (`users/{userId}/friendCategories`) for data isolation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/friend_category_member.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/modules/friend_category_member_module.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

class FriendCategoryRepository extends BaseFirebaseRepository<FriendCategory> {
  /// Module for handling subcollection-based members
  late final FriendCategoryMemberModule? _memberModule;

  /// Creates a friend category repository with dependency injection support.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Optional authentication repository, defaults to FirebaseAuthRepository
  /// [featureFlags] Optional feature flag service for subcollection member support
  FriendCategoryRepository({
    super.firestore,
    AuthRepository? authRepository,
    FeatureFlagService? featureFlags,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        ) {
    // Initialize member module if feature flags provided
    if (featureFlags != null) {
      _memberModule = FriendCategoryMemberModule(
        firestore: firestore,
        featureFlags: featureFlags,
      );
    } else {
      _memberModule = null;
    }
  }

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) =>
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriendCategories);
  @override
  String get collectionName => FirestoreCollections.userFriendCategories;

  @override
  FriendCategory fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FriendCategory.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(FriendCategory entity) =>
      entity.toFirestore();

  @override
  String getId(FriendCategory entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
      String userId, FriendCategory entity) async {
    return userId == entity.ownerId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, FriendCategory? entity) async {
    if (entity == null) return false;
    return entity.ownerId == userId || entity.friendUserIds.contains(userId);
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, FriendCategory entity) async {
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Only the owner can delete — fetch to check ownership
    try {
      final doc = await _categoriesRef(userId).doc(resourceId).get();
      if (!doc.exists) return false;
      final category = FriendCategory.fromMap(doc.id, doc.data() ?? {});
      return userId == category.ownerId;
    } catch (e) {
      return false;
    }
  }

  /// Save a friend category for a user (owner-only full write).
  Future<void> saveCategory(String userId, FriendCategory category) async {
    final currentUser = requireCurrentUserId();

    // Only the owner can do a full document write
    if (currentUser != userId) {
      throw PermissionDeniedException(
          'Only the owner can fully save a category. '
          'Use addSelfToCategory() for member self-addition.');
    }

    // Validate required fields
    validateRequiredFields(
      data: category.toFirestore(),
      requiredFields: ['name', 'friendUserIds'],
      resourceType: 'friend category',
    );

    await _categoriesRef(userId).doc(category.id).set(category.toFirestore());

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'create',
      granted: true,
      details: 'Category: ${category.id}, Owner: $userId',
    );
  }

  /// Add the current user to a category's member list (for invitation acceptance).
  /// Only modifies the friendUserIds field — cannot rename, change owner, or remove members.
  Future<void> addSelfToCategory(String ownerId, String categoryId) async {
    final currentUser = requireCurrentUserId();

    await _categoriesRef(ownerId).doc(categoryId).update({
      'friendUserIds': FieldValue.arrayUnion([currentUser]),
      'updatedAt': timestampProvider.serverTimestamp(),
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'add_self_as_member',
      granted: true,
      details: 'Category: $categoryId, Owner: $ownerId',
    );
  }

  /// Update a friend category.
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data) async {
    // Validate user owns the category they're updating
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update friend category',
    );

    await _categoriesRef(userId).doc(categoryId).update(data);

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'update',
      granted: true,
      details: 'Category: $categoryId',
    );
  }

  /// Delete a friend category.
  Future<void> deleteCategory(String userId, String categoryId) async {
    // Validate user owns the category they're deleting
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'delete friend category',
    );

    await _categoriesRef(userId).doc(categoryId).delete();

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'delete',
      granted: true,
      details: 'Category: $categoryId',
    );
  }

  /// Fetch all categories for a user.
  Future<List<FriendCategory>> fetchCategories(String userId) async {
    final snap = await _categoriesRef(userId).get();
    return snap.docs
        .map((doc) => FriendCategory.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// BUG-018 FIX: Fetch all categories where user is a member (across all users).
  /// Uses collectionGroup query to find categories in any user's collection
  /// where friendUserIds contains the specified userId.
  /// Note: The Firestore field is 'friendUserIds', not 'memberIds'.
  Future<List<FriendCategory>> fetchMemberCategories(String userId) async {
    final snap = await firestore
        .collectionGroup('friendCategories')
        .where('friendUserIds', arrayContains: userId)
        .get();
    return snap.docs
        .map((doc) => FriendCategory.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Create a new category for a user.
  Future<void> createCategoryForUser(
      String userId, FriendCategory category) async {
    // Validate user is creating their own category
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'create friend category',
    );

    // Validate required fields
    validateRequiredFields(
      data: category.toFirestore(),
      requiredFields: ['name', 'friendUserIds'],
      resourceType: 'friend category',
    );

    await _categoriesRef(userId).doc(category.id).set(category.toFirestore());

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'create',
      granted: true,
    );
  }

  /// Update category members.
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds) async {
    // Validate user owns the category they're updating
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update friend category members',
    );

    await _categoriesRef(userId).doc(categoryId).update({
      'friendUserIds': memberIds,
      'updatedAt': timestampProvider.serverTimestamp(),
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'update_members',
      granted: true,
      details: 'Category: $categoryId, Members: ${memberIds.length}',
    );
  }

  /// Get a specific category.
  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    final doc = await _categoriesRef(userId).doc(categoryId).get();
    if (!doc.exists) return null;
    return FriendCategory.fromMap(doc.id, doc.data() ?? {});
  }

  /// Add a friend to a category.
  Future<void> addFriendToCategory(
      String userId, String categoryId, String friendId) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    final updatedFriendIds = List<String>.from(category.friendUserIds);
    if (!updatedFriendIds.contains(friendId)) {
      updatedFriendIds.add(friendId);
      await updateCategoryMembers(userId, categoryId, updatedFriendIds);
    }
  }

  /// Remove a friend from a category.
  Future<void> removeFriendFromCategory(
      String userId, String categoryId, String friendId) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    final updatedFriendIds = List<String>.from(category.friendUserIds);
    if (updatedFriendIds.remove(friendId)) {
      await updateCategoryMembers(userId, categoryId, updatedFriendIds);
    }
  }

  /// Atomically transfer group ownership via Firestore transaction.
  /// Only the current owner can initiate a transfer. The transaction verifies
  /// ownership hasn't changed since read (prevents TOCTOU race conditions).
  Future<void> transferOwnership(
      String currentOwnerId, String categoryId, String newOwnerId) async {
    final currentUser = requireCurrentUserId();
    if (currentUser != currentOwnerId) {
      throw PermissionDeniedException(
          'Only the current owner can transfer ownership');
    }

    final docRef = _categoriesRef(currentOwnerId).doc(categoryId);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw ResourceNotFoundException('Group not found',
            resourceType: 'friend_category', resourceId: categoryId);
      }

      final category = FriendCategory.fromMap(snapshot.id, snapshot.data()!);
      if (category.ownerId != currentUser) {
        throw PermissionDeniedException('Ownership has already changed');
      }

      transaction.update(docRef, {
        'ownerId': newOwnerId,
        'updatedAt': timestampProvider.serverTimestamp(),
      });
    });

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'transfer_ownership',
      granted: true,
      details: 'Category: $categoryId, From: $currentOwnerId, To: $newOwnerId',
    );
  }

  /// Get categories that contain a specific friend.
  Future<List<FriendCategory>> getCategoriesContainingFriend(
      String userId, String friendId) async {
    final categories = await fetchCategories(userId);
    return categories
        .where((category) => category.friendUserIds.contains(friendId))
        .toList();
  }

  /// Stream categories for real-time updates (owned by user).
  Stream<List<FriendCategory>> categoriesStream(String userId) {
    return _categoriesRef(userId).snapshots().map((snapshot) => snapshot.docs
        .map((doc) => FriendCategory.fromMap(doc.id, doc.data()))
        .toList());
  }

  /// BUG-018 FIX: Stream categories where user is a member (across all users).
  /// Uses collectionGroup query to find categories in any user's collection
  /// where friendUserIds contains the specified userId.
  /// Note: The Firestore field is 'friendUserIds', not 'memberIds' (which is just a Dart alias).
  Stream<List<FriendCategory>> memberCategoriesStream(String userId) {
    return firestore
        .collectionGroup('friendCategories')
        .where('friendUserIds', arrayContains: userId)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendCategory.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Get category statistics for a user.
  Future<Map<String, dynamic>> getCategoryStatistics(String userId) async {
    final categories = await fetchCategories(userId);
    final totalMembers = categories.fold<int>(
        0, (total, cat) => total + cat.friendUserIds.length);
    final averageSize =
        categories.isNotEmpty ? (totalMembers / categories.length).round() : 0;
    final largestCategory = categories.isNotEmpty
        ? categories.reduce(
            (a, b) => a.friendUserIds.length > b.friendUserIds.length ? a : b)
        : null;

    return {
      'totalCategories': categories.length,
      'totalMembers': totalMembers,
      'averageSize': averageSize,
      'largestCategorySize': largestCategory?.friendUserIds.length ?? 0,
      'largestCategoryName': largestCategory?.name,
      'hasCategories': categories.isNotEmpty,
    };
  }

  /// Search categories by name.
  Future<List<FriendCategory>> searchCategories(
      String userId, String query) async {
    final categories = await fetchCategories(userId);
    final lowercaseQuery = query.toLowerCase();

    return categories.where((category) {
      return category.name.toLowerCase().contains(lowercaseQuery) ||
          (category.description?.toLowerCase().contains(lowercaseQuery) ??
              false);
    }).toList();
  }

  /// Get empty categories (categories with no members).
  Future<List<FriendCategory>> getEmptyCategories(String userId) async {
    final categories = await fetchCategories(userId);
    return categories
        .where((category) => category.friendUserIds.isEmpty)
        .toList();
  }

  /// Get largest categories (sorted by member count).
  Future<List<FriendCategory>> getLargestCategories(String userId,
      {int limit = 5}) async {
    final categories = await fetchCategories(userId);
    categories.sort(
        (a, b) => b.friendUserIds.length.compareTo(a.friendUserIds.length));
    return categories.take(limit).toList();
  }

  /// Check if a category name already exists for a user.
  Future<bool> categoryNameExists(String userId, String name,
      {String? excludeCategoryId}) async {
    final categories = await fetchCategories(userId);
    return categories.any((category) =>
        category.name.toLowerCase() == name.toLowerCase() &&
        category.id != excludeCategoryId);
  }

  /// Bulk update multiple categories.
  Future<void> bulkUpdateCategories(
      String userId, Map<String, Map<String, dynamic>> updates) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'bulk update categories',
    );

    final batch = firestore.batch();

    for (final entry in updates.entries) {
      final categoryId = entry.key;
      final updateData = entry.value;
      batch.update(_categoriesRef(userId).doc(categoryId), updateData);
    }

    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'bulk_update',
      granted: true,
      details: 'Categories: ${updates.length}',
    );
  }

  /// Get member IDs for a category using hybrid access.
  /// Returns from subcollection if usesSubcollectionMembers, otherwise from inline array.
  Future<List<String>> getCategoryMemberIds(
    String userId,
    String categoryId,
  ) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return [];

    if (category.usesSubcollectionMembers && _memberModule != null) {
      return _memberModule.getMemberIds(userId, categoryId);
    }

    return category.friendUserIds;
  }

  /// Get full member data for a category.
  /// Returns from subcollection if usesSubcollectionMembers.
  Future<List<FriendCategoryMember>> getCategoryMembers(
    String userId,
    String categoryId,
  ) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return [];

    if (category.usesSubcollectionMembers && _memberModule != null) {
      return _memberModule.getMembers(userId, categoryId);
    }

    // Convert inline IDs to member objects (limited data)
    return category.friendUserIds
        .map((friendId) => FriendCategoryMember(
              friendId: friendId,
              categoryId: categoryId,
              ownerId: userId,
              addedAt: category.createdAt, // Approximate
            ))
        .toList();
  }

  /// Add friend to category with automatic migration to subcollection if threshold exceeded.
  Future<void> addFriendToCategoryHybrid({
    required String userId,
    required String categoryId,
    required String friendId,
    String? displayName,
    String? avatarUrl,
  }) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    // Check if already uses subcollection
    if (category.usesSubcollectionMembers && _memberModule != null) {
      await _memberModule.addMember(
        ownerId: userId,
        categoryId: categoryId,
        categoryName: category.name,
        categoryEmoji: category.emoji,
        friendId: friendId,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      return;
    }

    // Check if should migrate to subcollection
    if (_memberModule != null &&
        _memberModule
            .shouldUseSubcollection(category.friendUserIds.length + 1)) {
      AppLogger.info(
          'Category $categoryId exceeded threshold, migrating to subcollection');

      // Migrate existing members first
      await _memberModule.migrateToSubcollection(category: category);

      // Add new member to subcollection
      await _memberModule.addMember(
        ownerId: userId,
        categoryId: categoryId,
        categoryName: category.name,
        categoryEmoji: category.emoji,
        friendId: friendId,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      return;
    }

    // Use inline array (default/legacy behavior)
    await addFriendToCategory(userId, categoryId, friendId);
  }

  /// Remove friend from category using hybrid approach.
  Future<void> removeFriendFromCategoryHybrid({
    required String userId,
    required String categoryId,
    required String friendId,
  }) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    if (category.usesSubcollectionMembers && _memberModule != null) {
      await _memberModule.removeMember(
        ownerId: userId,
        categoryId: categoryId,
        friendId: friendId,
      );
      return;
    }

    // Use inline array (default/legacy behavior)
    await removeFriendFromCategory(userId, categoryId, friendId);
  }

  /// Delete a category and all its subcollection members.
  Future<void> deleteCategoryWithMembers(
      String userId, String categoryId) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    // Delete subcollection members if applicable
    if (category.usesSubcollectionMembers && _memberModule != null) {
      await _memberModule.deleteAllMembers(
        ownerId: userId,
        categoryId: categoryId,
      );
    }

    // Delete the category document
    await deleteCategory(userId, categoryId);
  }

  /// Get categories that a friend belongs to (inverse lookup).
  Future<List<CategoryMembership>> getFriendCategoryMemberships(
    String friendId,
  ) async {
    if (_memberModule == null) return [];
    return _memberModule.getFriendMemberships(friendId);
  }
}
