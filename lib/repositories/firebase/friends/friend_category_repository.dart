// lib/repositories/firebase/friends/friend_category_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Friend Category Repository
/// 
/// Handles ONLY friend category operations and management.
/// This includes creating, updating, deleting, and managing friend categories.
class FriendCategoryRepository extends BaseFirebaseRepository<FriendCategory> {
  FriendCategoryRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) =>
      firestore
          .collection('users')
          .doc(userId)
          .collection('friendCategories');

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'friendCategories';

  @override
  FriendCategory fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FriendCategory.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(FriendCategory entity) => entity.toFirestore();

  @override
  String getId(FriendCategory entity) => entity.id;

  // ===== FRIEND CATEGORY OPERATIONS =====

  /// Save a friend category for a user.
  Future<void> saveCategory(String userId, FriendCategory category) async {
    // Validate user is saving their own category
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'save friend category',
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
    return snap.docs.map((doc) => FriendCategory.fromMap(doc.id, doc.data())).toList();
  }

  /// Create a new category for a user.
  Future<void> createCategoryForUser(String userId, FriendCategory category) async {
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
      'updatedAt': FieldValue.serverTimestamp(),
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
  Future<void> addFriendToCategory(String userId, String categoryId, String friendId) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    final updatedFriendIds = List<String>.from(category.friendUserIds);
    if (!updatedFriendIds.contains(friendId)) {
      updatedFriendIds.add(friendId);
      await updateCategoryMembers(userId, categoryId, updatedFriendIds);
    }
  }

  /// Remove a friend from a category.
  Future<void> removeFriendFromCategory(String userId, String categoryId, String friendId) async {
    final category = await getCategory(userId, categoryId);
    if (category == null) return;

    final updatedFriendIds = List<String>.from(category.friendUserIds);
    if (updatedFriendIds.remove(friendId)) {
      await updateCategoryMembers(userId, categoryId, updatedFriendIds);
    }
  }

  /// Get categories that contain a specific friend.
  Future<List<FriendCategory>> getCategoriesContainingFriend(String userId, String friendId) async {
    final categories = await fetchCategories(userId);
    return categories.where((category) => category.friendUserIds.contains(friendId)).toList();
  }

  /// Stream categories for real-time updates.
  Stream<List<FriendCategory>> categoriesStream(String userId) {
    return _categoriesRef(userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendCategory.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Get category statistics for a user.
  Future<Map<String, dynamic>> getCategoryStatistics(String userId) async {
    final categories = await fetchCategories(userId);
    final totalMembers = categories.fold<int>(0, (total, cat) => total + cat.friendUserIds.length);
    final averageSize = categories.isNotEmpty ? (totalMembers / categories.length).round() : 0;
    final largestCategory = categories.isNotEmpty 
        ? categories.reduce((a, b) => a.friendUserIds.length > b.friendUserIds.length ? a : b)
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
  Future<List<FriendCategory>> searchCategories(String userId, String query) async {
    final categories = await fetchCategories(userId);
    final lowercaseQuery = query.toLowerCase();
    
    return categories.where((category) {
      return category.name.toLowerCase().contains(lowercaseQuery) ||
             (category.description?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  /// Get empty categories (categories with no members).
  Future<List<FriendCategory>> getEmptyCategories(String userId) async {
    final categories = await fetchCategories(userId);
    return categories.where((category) => category.friendUserIds.isEmpty).toList();
  }

  /// Get largest categories (sorted by member count).
  Future<List<FriendCategory>> getLargestCategories(String userId, {int limit = 5}) async {
    final categories = await fetchCategories(userId);
    categories.sort((a, b) => b.friendUserIds.length.compareTo(a.friendUserIds.length));
    return categories.take(limit).toList();
  }

  /// Check if a category name already exists for a user.
  Future<bool> categoryNameExists(String userId, String name, {String? excludeCategoryId}) async {
    final categories = await fetchCategories(userId);
    return categories.any((category) => 
        category.name.toLowerCase() == name.toLowerCase() && 
        category.id != excludeCategoryId);
  }

  /// Bulk update multiple categories.
  Future<void> bulkUpdateCategories(String userId, Map<String, Map<String, dynamic>> updates) async {
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
}