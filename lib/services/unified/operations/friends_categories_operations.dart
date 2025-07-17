/// 🔍 AI INFO BLOCK:
/// Component: Friends Categories Operations - Feature interface for managing friend categories
/// File: lib/services/unified/operations/friends_categories_operations.dart
/// Quick Guide: Handles all friend category operations including creating, managing, and organizing
/// Dependencies IN: UnifiedFriendsService, FriendCategory model, UserFriend model
/// Dependencies OUT: Used by ViewModels for category operations
/// Data flow: ViewModels -> FriendsCategoriesOperations -> UnifiedFriendsService -> Firebase
/// State management: Real-time updates for categories and assignments
/// Purpose: Separate friend categorization concerns from unified service
/// Common issues: Category validation, duplicate prevention, assignment conflicts
/// Test coverage: Unit tests for category operations and friend assignments
/// Performance: Optimistic updates with Firebase sync
/// Analytics: Category usage, organization patterns
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, Category ViewModels, Friend management
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/friend_category.dart';
import '../../../models/user_profile.dart';
import '../../../core/utils/logger.dart';
import '../unified_friends_service.dart';
import 'package:collection/collection.dart';

/// Friends categories operations feature interface
/// 
/// Handles all operations related to friend categories:
/// - Creating and managing categories
/// - Assigning friends to categories
/// - Organizing and filtering friends
/// - Category-based permissions and features
/// - Smart categorization suggestions
class FriendsCategoriesOperations {
  final UnifiedFriendsService _parent;

  FriendsCategoriesOperations(this._parent);

  // ===== CATEGORY MANAGEMENT =====

  /// Create a new friend category
  Future<String?> createCategory({
    required String name,
    String? description,
    String? color,
    String? icon,
    bool isDefault = false,
    List<String>? initialMemberIds,
  }) async {
    try {
      if (name.trim().isEmpty) {
        AppLogger.error('Category name cannot be empty');
        return null;
      }

      // Check for duplicate name
      if (_parent.getAllCategoriesInternal().any((c) => c.name.toLowerCase() == name.toLowerCase())) {
        AppLogger.error('Category with this name already exists');
        return null;
      }

      final category = FriendCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ownerId: _parent.currentUserId ?? '',
        name: name.trim(),
        description: description?.trim(),
        emoji: icon ?? '👥',
        isDefault: isDefault,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to local state
      _parent.addCategoryInternal(category);
      _parent.notifyListenersInternal();

      // Sync to Firebase
      await _parent.syncCategoryToFirebaseInternal(category);

      AppLogger.success('Created category: $name');
      return category.id;
    } catch (e) {
      AppLogger.error('Failed to create category', e);
      return null;
    }
  }

  /// Update an existing category
  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? description,
    String? color,
    String? icon,
  }) async {
    try {
      final category = _parent.getCategoryByIdInternal(categoryId);

      if (category == null) {
        AppLogger.error('Category not found');
        return false;
      }

      // Check for duplicate name if name is being changed
      if (name != null && name != category.name) {
        if (_parent.getAllCategoriesInternal().any((c) => c.id != categoryId && c.name.toLowerCase() == name.toLowerCase())) {
          AppLogger.error('Category with this name already exists');
          return false;
        }
      }

      final updatedCategory = category.copyWith(
        name: name ?? category.name,
        description: description ?? category.description,
        emoji: icon ?? category.emoji,
        updatedAt: DateTime.now(),
      );

      // Update in local state
      _parent.updateCategoryInternal(categoryId, updatedCategory);
      _parent.notifyListenersInternal();

      // Sync to Firebase
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);

      AppLogger.success('Updated category: ${updatedCategory.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update category', e);
      return false;
    }
  }

  /// Delete a category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      final category = _parent.getCategoryByIdInternal(categoryId);

      if (category == null) {
        AppLogger.error('Category not found');
        return false;
      }

      if (category.isDefault) {
        AppLogger.error('Cannot delete default category');
        return false;
      }

      // Remove category from all friends
      // Note: UserProfile doesn't have categories property, so this would need to be implemented
      // with a separate relationship table in the future

      // Remove from local state
      _parent.removeCategoryInternal(categoryId);
      _parent.notifyListenersInternal();

      // Remove from Firebase
      await _parent.deleteCategoryFromFirebaseInternal(categoryId);

      AppLogger.success('Deleted category: ${category.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete category', e);
      return false;
    }
  }

  /// Get all categories
  List<FriendCategory> getAllCategories() {
    return List.unmodifiable(_parent.getAllCategoriesInternal());
  }

  /// Get category by ID
  FriendCategory? getCategoryById(String categoryId) {
    return _parent.getCategoryByIdInternal(categoryId);
  }

  /// Get default categories
  List<FriendCategory> getDefaultCategories() {
    return _parent.getAllCategoriesInternal().where((c) => c.isDefault).toList();
  }

  /// Get custom categories
  List<FriendCategory> getCustomCategories() {
    return _parent.getAllCategoriesInternal().where((c) => !c.isDefault).toList();
  }

  // ===== FRIEND CATEGORY ASSIGNMENT =====

  /// Assign friend to category
  Future<bool> assignFriendToCategory({
    required String friendId,
    required String categoryId,
  }) async {
    try {
      final friend = _parent.friendsInternal
          .where((f) => f.uid == friendId)
          .firstOrNull;

      if (friend == null) {
        AppLogger.error('Friend not found');
        return false;
      }

      final category = _parent.getCategoryByIdInternal(categoryId);

      if (category == null) {
        AppLogger.error('Category not found');
        return false;
      }

      // Add friend to category relationship
      _parent.addFriendToCategoryInternal(friendId, categoryId);
      
      // Update category with friend count
      final updatedCategory = category.addFriend(friendId);
      _parent.updateCategoryInternal(categoryId, updatedCategory);

      _parent.notifyListenersInternal();

      // Sync to Firebase (category and relationship)
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      // Friend-category relationship is automatically synced by _addFriendToCategory method

      AppLogger.success('Assigned ${friend.displayName} to ${category.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to assign friend to category', e);
      return false;
    }
  }

  /// Remove friend from category
  Future<bool> removeFriendFromCategory({
    required String friendId,
    required String categoryId,
  }) async {
    try {
      final friend = _parent.friendsInternal
          .where((f) => f.uid == friendId)
          .firstOrNull;

      if (friend == null) {
        AppLogger.error('Friend not found');
        return false;
      }

      final category = _parent.getCategoryByIdInternal(categoryId);

      if (category == null) {
        AppLogger.error('Category not found');
        return false;
      }

      // Remove friend from category relationship
      _parent.removeFriendFromCategoryInternal(friendId, categoryId);
      
      // Update category with friend count
      final updatedCategory = category.removeFriend(friendId);
      _parent.updateCategoryInternal(categoryId, updatedCategory);

      _parent.notifyListenersInternal();

      // Sync to Firebase (category and relationship)
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      // Friend-category relationship is automatically synced by _addFriendToCategory method

      AppLogger.success('Removed ${friend.displayName} from ${category.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove friend from category', e);
      return false;
    }
  }

  /// Get friends in category
  List<UserProfile> getFriendsInCategory(String categoryId) {
    final friendIds = _parent.getFriendsInCategoryInternal(categoryId);
    return _parent.friendsInternal.where((friend) => friendIds.contains(friend.uid)).toList();
  }

  /// Get friends not in any category
  List<UserProfile> getUncategorizedFriends() {
    return _parent.friendsInternal.where((friend) {
      final categoriesForFriend = _parent.getCategoriesForFriendInternal(friend.uid);
      return categoriesForFriend.isEmpty;
    }).toList();
  }

  /// Get categories for friend
  List<FriendCategory> getCategoriesForFriend(String friendId) {
    final categoryIds = _parent.getCategoriesForFriendInternal(friendId);
    return _parent.getAllCategoriesInternal().where((category) => categoryIds.contains(category.id)).toList();
  }
  
  /// Get category by name
  FriendCategory? getCategoryByName(String name) {
    return _parent.getAllCategoriesInternal().where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;
  }
  
  /// Compatibility getter for legacy code
  List<FriendCategory> get categoriesList => getAllCategories();
  
  /// Check if category name is available
  bool isCategoryNameAvailable(String name) {
    return !_parent.getAllCategoriesInternal().any((c) => c.name.toLowerCase() == name.toLowerCase());
  }
  
  /// Refresh categories data
  Future<void> refresh() async {
    // Categories are refreshed through parent service
    await _parent.refresh();
  }

  // ===== BULK OPERATIONS =====

  /// Assign multiple friends to category
  Future<bool> assignMultipleFriendsToCategory({
    required List<String> friendIds,
    required String categoryId,
  }) async {
    try {
      bool allSuccess = true;
      for (final friendId in friendIds) {
        final success = await assignFriendToCategory(
          friendId: friendId,
          categoryId: categoryId,
        );
        if (!success) allSuccess = false;
      }
      return allSuccess;
    } catch (e) {
      AppLogger.error('Failed to assign multiple friends to category', e);
      return false;
    }
  }

  /// Remove multiple friends from category
  Future<bool> removeMultipleFriendsFromCategory({
    required List<String> friendIds,
    required String categoryId,
  }) async {
    try {
      bool allSuccess = true;
      for (final friendId in friendIds) {
        final success = await removeFriendFromCategory(
          friendId: friendId,
          categoryId: categoryId,
        );
        if (!success) allSuccess = false;
      }
      return allSuccess;
    } catch (e) {
      AppLogger.error('Failed to remove multiple friends from category', e);
      return false;
    }
  }

  // ===== CATEGORY STATISTICS =====

  /// Get category statistics
  Map<String, dynamic> getCategoryStats() {
    final totalCategories = _parent.getAllCategoriesInternal().length;
    final defaultCategories = _parent.getAllCategoriesInternal().where((c) => c.isDefault).length;
    final customCategories = totalCategories - defaultCategories;
    final totalFriends = _parent.friendsInternal.length;
    
    // Count categorized friends using the relationship mapping
    final categorizedFriendIds = <String>{};
    for (final entry in _parent.friendCategoryRelationshipsInternal.entries) {
      if (entry.value.isNotEmpty) {
        categorizedFriendIds.add(entry.key);
      }
    }
    final categorizedFriends = categorizedFriendIds.length;
    final uncategorizedFriends = totalFriends - categorizedFriends;

    final categoryUsage = <String, int>{};
    for (final category in _parent.getAllCategoriesInternal()) {
      final friendsInCategory = _parent.getFriendsInCategoryInternal(category.id);
      categoryUsage[category.name] = friendsInCategory.length;
    }

    return {
      'totalCategories': totalCategories,
      'defaultCategories': defaultCategories,
      'customCategories': customCategories,
      'totalFriends': totalFriends,
      'categorizedFriends': categorizedFriends,
      'uncategorizedFriends': uncategorizedFriends,
      'categoryUsage': categoryUsage,
    };
  }

  /// Get most used categories
  List<FriendCategory> getMostUsedCategories({int limit = 5}) {
    final categories = List<FriendCategory>.from(_parent.getAllCategoriesInternal());
    categories.sort((a, b) {
      final aCount = _parent.getFriendsInCategoryInternal(a.id).length;
      final bCount = _parent.getFriendsInCategoryInternal(b.id).length;
      return bCount.compareTo(aCount);
    });
    return categories.take(limit).toList();
  }

  /// Get empty categories
  List<FriendCategory> getEmptyCategories() {
    return _parent.getAllCategoriesInternal().where((c) {
      final friendsInCategory = _parent.getFriendsInCategoryInternal(c.id);
      return friendsInCategory.isEmpty;
    }).toList();
  }

  // ===== SMART CATEGORIZATION =====

  /// Suggest categories for friend based on mutual friends
  Future<List<FriendCategory>> suggestCategoriesForFriend(String friendId) async {
    try {
      final friend = _parent.friendsInternal
          .where((f) => f.uid == friendId)
          .firstOrNull;

      if (friend == null) return [];

      // This would implement smart categorization logic
      // For now, return empty list
      return [];
    } catch (e) {
      AppLogger.error('Failed to suggest categories for friend', e);
      return [];
    }
  }

  /// Auto-categorize friends based on patterns
  Future<bool> autoCategorizeFriends() async {
    try {
      // This would implement auto-categorization logic
      // For now, just log the action
      AppLogger.info('Auto-categorization would run here');
      return true;
    } catch (e) {
      AppLogger.error('Failed to auto-categorize friends', e);
      return false;
    }
  }
}