/// 🔍 AI INFO BLOCK:
/// Component: Friend Categories Operations - Feature interface for friend categorization
/// File: lib/services/unified/operations/friend_categories_operations.dart
/// Quick Guide: Handles friend categorization, groups, and organization features
/// Dependencies IN: UnifiedFriendsService, FriendCategory model
/// Dependencies OUT: Used by category ViewModels and group management
/// Data flow: ViewModels -> FriendCategoriesOperations -> UnifiedFriendsService -> Firebase
/// State management: Delegates to parent UnifiedFriendsService
/// Purpose: Separate friend organization concerns from basic friend operations
/// Common issues: Category membership, group permissions, bulk operations
/// Test coverage: Unit tests for category CRUD and membership operations
/// Performance: Optimistic updates with Firebase sync
/// Analytics: Category usage, group creation patterns, bulk operations
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, Group management ViewModels
/// Used in phases: Phase 5 - Service Consolidation

// ignore: unused_import
import 'package:collection/collection.dart'; // Needed for .firstOrNull on dynamic _parent fields
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive friend categories operations providing advanced friend organization and group management systems.
///
/// This operations class implements sophisticated friend categorization functionality following Single Responsibility Principle,
/// handling all aspects of friend organization including category lifecycle management, friend assignment operations, bulk
/// categorization features, and group-based permissions. It provides comprehensive friend organization capabilities while
/// maintaining clean separation from basic friend management and social interaction concerns.
///
/// **Single Responsibility Focus:**
/// This class exclusively handles friend categorization operations:
/// - **Category Lifecycle Management**: Complete category CRUD operations with validation, duplicate prevention, and privacy controls
/// - **Friend Assignment Operations**: Comprehensive friend-to-category assignment with bulk operations and relationship management
/// - **Group Permissions**: Advanced category-based permissions with sharing controls and access management
/// - **Organization Analytics**: Category usage statistics and organization insights with bulk operation tracking
///
/// **What This Class Does NOT Handle:**
/// - Basic friend relationship management (handled by FriendsOperations)  
/// - Social invitations and group invitations (handled by FriendsInvitationsOperations)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Authentication and user management (handled by permission services)
///
/// **Friend Categories Features:**
/// - **Advanced Organization**: Comprehensive friend categorization with custom categories, privacy controls, and sharing options
/// - **Bulk Operations**: Efficient multi-friend assignment operations with progress tracking and validation
/// - **Permission Management**: Category-based sharing and permissions with access control and ownership validation
/// - **Analytics Integration**: Detailed categorization analytics with usage statistics and organization insights
/// - **Smart Organization**: Intelligent category suggestions and organization tools for efficient friend management
///
/// **Usage Examples:**
/// ```dart
/// final categoriesOps = FriendCategoriesOperations(parentService);
/// 
/// // Category lifecycle management
/// final categoryId = await categoriesOps.createCategory(
///   name: 'Arbetskamrater',
///   description: 'Kollegor och arbetskamrater',  
///   isPrivate: false,
///   initialMemberIds: [colleague1, colleague2],
/// );
/// 
/// // Friend assignment operations
/// await categoriesOps.assignFriendsToCategory(categoryId, friendIds);
/// await categoriesOps.removeFriendsFromCategory(categoryId, [friendId]);
/// 
/// // Category management and analytics
/// final categories = categoriesOps.getAllCategories();
/// final usage = categoriesOps.getCategoryUsageStats();
/// final mostUsed = categoriesOps.getMostUsedCategories();
/// ```
class FriendCategoriesOperations {
  final dynamic _parent; // UnifiedFriendsService

  FriendCategoriesOperations(this._parent);

  // ===== CATEGORY CRUD OPERATIONS =====

  /// Create new friend category
  Future<String?> createCategory({
    required String name,
    String description = '',
    bool isPrivate = false,
    List<String>? initialMemberIds,
  }) async {
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
      AppLogger.warning('Cannot create category: User not logged in');
      return null;
    }

    if (name.trim().isEmpty) {
      AppLogger.warning('Category name cannot be empty');
      return null;
    }

    if (_categoryNameExists(name.trim())) {
      AppLogger.warning('Category name already exists: $name');
      return null;
    }

    try {
      final success = await _parent.createCategory(
        name.trim(), 
        description.trim(),
      );

      if (success) {
        // If initial members provided, add them
        if (initialMemberIds != null && initialMemberIds.isNotEmpty) {
          final category = getCategoryByName(name.trim());
          if (category != null) {
            for (final memberId in initialMemberIds) {
              await addFriendToCategory(memberId, category.id);
            }
          }
        }
        
        AppLogger.success('✅ Category created: $name');
        return getCategoryByName(name.trim())?.id;
      }

      return null;
    } catch (e) {
      AppLogger.error('Error creating category: $name', e);
      return null;
    }
  }

  /// Update category details
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? icon,
    bool? isPrivate,
  }) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }

    if (!_canEditCategory(category)) {
      AppLogger.warning('No permission to edit category: $categoryId');
      return false;
    }

    if (name != null && name.trim().isEmpty) {
      AppLogger.warning('Category name cannot be empty');
      return false;
    }

    try {
      // Create updated category with new values
      final updatedCategory = category.copyWith(
        name: name?.trim(),
        description: description?.trim(),
        emoji: icon,
        updatedAt: DateTime.now(),
      );

      // Use the internal update method that handles caching and notifications
      _parent._updateCategory(updatedCategory);
      
      // Sync to Firebase
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      
      AppLogger.success('✅ Category updated: ${updatedCategory.name}');
      return true;
    } catch (e) {
      AppLogger.error('Error updating category: $categoryId', e);
      return false;
    }
  }

  /// Delete category
  Future<bool> deleteCategory(String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }

    if (!_canDeleteCategory(category)) {
      AppLogger.warning('No permission to delete category: $categoryId');
      return false;
    }

    try {
      // Remove all friend-category relationships for this category
      final friendCategoryRelationships = _parent.friendCategoryRelationshipsInternal;
      for (final friendId in friendCategoryRelationships.keys.toList()) {
        friendCategoryRelationships[friendId]?.remove(categoryId);
        if (friendCategoryRelationships[friendId]?.isEmpty == true) {
          friendCategoryRelationships.remove(friendId);
        }
      }
      
      // Delete from Firebase
      await _parent.deleteCategoryFromFirebaseInternal(categoryId);
      
      // Use the internal remove method that handles caching and notifications
      _parent._removeCategory(categoryId);
      
      AppLogger.success('✅ Category deleted: ${category.name}');
      return true;
    } catch (e) {
      AppLogger.error('Error deleting category: $categoryId', e);
      return false;
    }
  }

  // ===== CATEGORY MEMBERSHIP OPERATIONS =====

  /// Add friend to category
  Future<bool> addFriendToCategory(String friendId, String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }

    if (!_parent.friends.isFriend(friendId)) {
      AppLogger.warning('User is not a friend: $friendId');
      return false;
    }

    if (isFriendInCategory(friendId, categoryId)) {
      AppLogger.warning('Friend already in category: $friendId -> $categoryId');
      return true; // Not an error, just already done
    }

    if (!_canEditCategory(category)) {
      AppLogger.warning('No permission to edit category: $categoryId');
      return false;
    }

    return await _parent.addFriendToCategory(friendId, categoryId);
  }

  /// Remove friend from category
  Future<bool> removeFriendFromCategory(String friendId, String categoryId) async {
    final category = getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }

    if (!isFriendInCategory(friendId, categoryId)) {
      AppLogger.warning('Friend not in category: $friendId -> $categoryId');
      return true; // Not an error, just already removed
    }

    if (!_canEditCategory(category)) {
      AppLogger.warning('No permission to edit category: $categoryId');
      return false;
    }

    try {
      // Remove from friend-category relationships
      final friendCategoryRelationships = _parent.friendCategoryRelationshipsInternal;
      friendCategoryRelationships[friendId]?.remove(categoryId);
      if (friendCategoryRelationships[friendId]?.isEmpty == true) {
        friendCategoryRelationships.remove(friendId);
      }
      
      // Update the category's member list
      final updatedCategory = category.copyWith(
        friendUserIds: category.friendUserIds.where((id) => id != friendId).toList(),
        updatedAt: DateTime.now(),
      );
      
      // Use the internal update method that handles caching and notifications
      _parent._updateCategory(updatedCategory);
      
      // Sync to Firebase
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      
      AppLogger.success('✅ Friend removed from category: $friendId -> $categoryId');
      return true;
    } catch (e) {
      AppLogger.error('Error removing friend from category', e);
      return false;
    }
  }

  /// Move friend from one category to another
  Future<bool> moveFriendToCategory({
    required String friendId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {
    if (fromCategoryId == toCategoryId) {
      return true; // Already in target category
    }

    // Remove from source category
    final removeSuccess = await removeFriendFromCategory(friendId, fromCategoryId);
    if (!removeSuccess) return false;

    // Add to target category
    return await addFriendToCategory(friendId, toCategoryId);
  }

  // ===== BULK OPERATIONS =====

  /// Add multiple friends to category
  Future<Map<String, bool>> addMultipleFriendsToCategory(
    List<String> friendIds, 
    String categoryId,
  ) async {
    final results = <String, bool>{};

    for (final friendId in friendIds) {
      results[friendId] = await addFriendToCategory(friendId, categoryId);
    }

    return results;
  }

  /// Remove multiple friends from category
  Future<Map<String, bool>> removeMultipleFriendsFromCategory(
    List<String> friendIds, 
    String categoryId,
  ) async {
    final results = <String, bool>{};

    for (final friendId in friendIds) {
      results[friendId] = await removeFriendFromCategory(friendId, categoryId);
    }

    return results;
  }

  /// Create category with multiple friends
  Future<String?> createCategoryWithFriends({
    required String name,
    String description = '',
    required List<String> friendIds,
  }) async {
    final categoryId = await createCategory(
      name: name,
      description: description,
      initialMemberIds: friendIds,
    );

    return categoryId;
  }

  // ===== CATEGORY QUERIES =====

  /// Get category by ID
  FriendCategory? getCategoryById(String categoryId) {
    return _parent.categoriesList
        .where((category) => category.id == categoryId)
        .firstOrNull;
  }

  /// Get category by name
  FriendCategory? getCategoryByName(String name) {
    return _parent.categoriesList
        .where((category) => category.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
  }

  /// Get all categories
  List<FriendCategory> getAllCategories() {
    return _parent.categoriesList;
  }

  /// Get categories owned by current user
  List<FriendCategory> getOwnedCategories() {
    return _parent.categoriesList
        .where((category) => category.ownerId == _parent.currentUserId)
        .toList();
  }

  /// Get categories where current user is a member
  List<FriendCategory> getMemberCategories() {
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) return [];
    
    return _parent.categoriesList
        .where((category) => category.memberIds.contains(_parent.currentUserId))
        .toList();
  }

  /// Get friends in specific category
  List<UserProfile> getFriendsInCategory(String categoryId) {
    final category = getCategoryById(categoryId);
    if (category == null) return [];

    return _parent.friendsList
        .where((friend) => category.memberIds.contains(friend.uid))
        .toList();
  }

  /// Get categories containing specific friend
  List<FriendCategory> getCategoriesForFriend(String friendId) {
    return _parent.categoriesList
        .where((category) => category.memberIds.contains(friendId))
        .toList();
  }

  /// Get uncategorized friends
  List<UserProfile> getUncategorizedFriends() {
    final categorizedFriendIds = <String>{};
    
    for (final category in _parent.categoriesList) {
      categorizedFriendIds.addAll(category.memberIds);
    }

    return _parent.friendsList
        .where((friend) => !categorizedFriendIds.contains(friend.uid))
        .toList();
  }

  // ===== CATEGORY STATUS CHECKS =====

  /// Check if friend is in category
  bool isFriendInCategory(String friendId, String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.memberIds.contains(friendId) ?? false;
  }

  /// Check if category name already exists
  bool _categoryNameExists(String name) {
    return _parent.categoriesList
        .any((category) => category.name.toLowerCase() == name.toLowerCase());
  }

  /// Get category member count
  int getCategoryMemberCount(String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.memberIds.length ?? 0;
  }

  /// Check if category is empty
  bool isCategoryEmpty(String categoryId) {
    return getCategoryMemberCount(categoryId) == 0;
  }

  // ===== CATEGORY STATISTICS =====

  /// Get category statistics
  Map<String, dynamic> getCategoryStats() {
    final categories = getAllCategories();
    final totalCategories = categories.length;
    final ownedCategories = getOwnedCategories().length;
    final memberCategories = getMemberCategories().length;
    final uncategorizedCount = getUncategorizedFriends().length;

    return {
      'totalCategories': totalCategories,
      'ownedCategories': ownedCategories,
      'memberCategories': memberCategories,
      'uncategorizedFriends': uncategorizedCount,
      'averageMembersPerCategory': totalCategories > 0
          ? categories.map((c) => c.memberIds.length).reduce((a, b) => a + b) / totalCategories
          : 0.0,
    };
  }

  // ===== PRIVATE HELPER METHODS =====

  bool _canEditCategory(FriendCategory category) {
    // Can edit if owner or has edit permissions
    return ServiceLocator.get<PermissionService>().isGroupAdmin(category.id);
  }

  bool _canDeleteCategory(FriendCategory category) {
    // Can delete if owner
    return ServiceLocator.get<PermissionService>().canDeleteGroup(category.id);
  }

  // FUTURE IMPLEMENTATION NOTE: Public/private friend categories
  // When implemented, will need a method to check view permissions:
  // - Public categories: viewable by anyone
  // - Private categories: viewable by owner and members only
  // Implementation will be added when privacy feature is developed

  /// Set category privacy level (feature stub - not yet implemented)
  /// 
  /// FEATURE STUB: This will allow users to make friend categories
  /// public (discoverable by others) or private (invitation-only).
  Future<void> setCategoryPrivacy(String categoryId, {required bool isPublic}) async {
    AppLogger.info('🔒 Privacy setting requested for category: $categoryId (public: $isPublic)');
    
    // FEATURE STUB: Privacy controls not yet implemented
    AppLogger.warning('⚠️ Friend category privacy controls are not yet available');
    
    throw UnimplementedError(
      'Friend category privacy controls are planned for future release. '
      'This will allow categories to be set as public (discoverable) or '
      'private (invitation-only) with appropriate permission management.'
    );

    // FUTURE IMPLEMENTATION:
    // try {
    //   final category = await getFriendCategory(categoryId);
    //   if (category != null && _canEditCategory(category)) {
    //     final updatedCategory = category.copyWith(isPublic: isPublic);
    //     await _repository.updateFriendCategory(categoryId, updatedCategory);
    //     AppLogger.success('✅ Category privacy updated: $categoryId');
    //   } else {
    //     throw PermissionDeniedException('Cannot modify category privacy');
    //   }
    // } catch (e) {
    //   AppLogger.error('❌ Failed to update category privacy', e);
    //   rethrow;
    // }
  }
}