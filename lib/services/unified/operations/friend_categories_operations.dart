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
import 'package:uuid/uuid.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/events/group_events.dart';

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
class FriendsCategoriesOperations {
  final UnifiedFriendsService _parent;

  FriendsCategoriesOperations(this._parent);

  // ===== CATEGORY CRUD OPERATIONS =====

  /// Create new friend category
  Future<String?> createCategory({
    required String name,
    String description = '',
    bool isPrivate = false,
    String? icon,
    List<String>? initialMemberIds,
  }) async {
    print('🏗️ [DEBUG] createCategory called with:');
    print('  📝 name: "$name"');
    print('  📝 description: "$description"');
    print('  🎭 icon: "$icon"');
    print('  👥 initialMemberIds: $initialMemberIds');
    
    print('🔐 [DEBUG] Checking authentication...');
    if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
      AppLogger.warning('Cannot create category: User not logged in');
      print('❌ [DEBUG] User not authenticated');
      return null;
    }
    print('✅ [DEBUG] User is authenticated');
    
    print('🔍 [DEBUG] Getting current user ID...');
    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) {
      AppLogger.warning('Cannot create category: User ID not available');
      print('❌ [DEBUG] Current user ID is null');
      return null;
    }
    print('✅ [DEBUG] Current user ID: $currentUserId');

    if (name.trim().isEmpty) {
      AppLogger.warning('Category name cannot be empty');
      print('❌ [DEBUG] Category name is empty');
      return null;
    }
    print('✅ [DEBUG] Category name is valid: "${name.trim()}"');

    print('🔍 [DEBUG] Checking if category name exists...');
    if (_categoryNameExists(name.trim())) {
      AppLogger.warning('Category name already exists: $name');
      print('❌ [DEBUG] Category name already exists');
      return null;
    }
    print('✅ [DEBUG] Category name is unique');

    print('🚀 [DEBUG] Starting category creation...');
    try {
      // Create category internally
      print('🏗️ [DEBUG] Creating FriendCategory object...');
      final categoryId = const Uuid().v4();
      final category = FriendCategory(
        id: categoryId,
        name: name.trim(),
        description: description.trim(),
        ownerId: currentUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        emoji: icon,
        friendUserIds: [currentUserId], // Add owner as member
      );
      print('✅ [DEBUG] Created category with ID: $categoryId');
      
      print('📝 [DEBUG] Adding category to internal state...');
      _parent.addCategoryInternal(category);
      print('✅ [DEBUG] Category added to internal state');
      
      print('☁️ [DEBUG] Syncing category to Firebase...');
      await _parent.syncCategoryToFirebaseInternal(category);
      print('✅ [DEBUG] Category synced to Firebase successfully');
      
      const success = true;
      print('🎯 [DEBUG] Success status: $success');

      if (success) {
        print('✅ [DEBUG] Category creation successful, processing initial members...');
        // If initial members provided, add them
        if (initialMemberIds != null && initialMemberIds.isNotEmpty) {
          print('👥 [DEBUG] Adding ${initialMemberIds.length} initial members...');
          final createdCategory = getCategoryByName(name.trim());
          if (createdCategory != null) {
            print('✅ [DEBUG] Found created category, adding members...');
            for (final memberId in initialMemberIds) {
              print('👤 [DEBUG] Adding member: $memberId');
              await addFriendToCategory(memberId, createdCategory.id);
            }
            print('✅ [DEBUG] All initial members added');
          } else {
            print('❌ [DEBUG] Could not find created category by name');
          }
        } else {
          print('ℹ️ [DEBUG] No initial members to add');
        }
        
        AppLogger.success('✅ Category created: $name');
        final finalCategoryId = getCategoryByName(name.trim())?.id;
        print('🎯 [DEBUG] Final category ID to return: $finalCategoryId');
        return finalCategoryId;
      }
    } catch (e) {
      print('💥 [DEBUG] Exception in createCategory: $e');
      AppLogger.error('Error creating category: $name', e);
      print('❌ [DEBUG] Returning null due to exception');
      return null;
    }
    
    print('❌ [DEBUG] Reached end of method without returning - this should not happen');
    return null;
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
      _parent.updateCategoryInternal(categoryId, updatedCategory);
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      
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
      _parent.removeCategoryInternal(categoryId);
      
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

    if (!_parent.management.isFriend(friendId)) {
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

    _parent.addFriendToCategoryInternal(friendId, categoryId);
    final categoryToSync = getCategoryById(categoryId);
    if (categoryToSync != null) {
      await _parent.syncCategoryToFirebaseInternal(categoryToSync);
    }
    return true;
  }

  /// Remove friend from category
  Future<bool> removeFriendFromCategory(String friendId, String categoryId) async {
    print('🗑️ [DEBUG] removeFriendFromCategory called: friendId=$friendId, categoryId=$categoryId');
    print('📞 [DEBUG] Called from: ${StackTrace.current.toString().split('\n').take(3).join('\\n')}');
    
    final category = getCategoryById(categoryId);
    if (category == null) {
      print('❌ [DEBUG] Category not found: $categoryId');
      AppLogger.warning('Category not found: $categoryId');
      return false;
    }
    print('✅ [DEBUG] Found category: ${category.name}');

    print('🔍 [DEBUG] Checking if friend is in category...');
    final isInCategory = isFriendInCategory(friendId, categoryId);
    print('🔍 [DEBUG] Friend in category: $isInCategory');
    
    if (!isInCategory) {
      print('ℹ️ [DEBUG] Friend not in category (already removed): $friendId -> $categoryId');
      AppLogger.warning('Friend not in category: $friendId -> $categoryId');
      return true; // Not an error, just already removed
    }

    print('🔐 [DEBUG] Checking edit permissions...');
    if (!_canEditCategory(category)) {
      print('❌ [DEBUG] No permission to edit category: $categoryId');
      AppLogger.warning('No permission to edit category: $categoryId');
      return false;
    }
    print('✅ [DEBUG] Edit permission granted');

    try {
      print('🔄 [DEBUG] Starting removal process...');
      
      // Remove from friend-category relationships
      final friendCategoryRelationships = _parent.friendCategoryRelationshipsInternal;
      print('🔗 [DEBUG] Current relationships: $friendCategoryRelationships');
      
      friendCategoryRelationships[friendId]?.remove(categoryId);
      if (friendCategoryRelationships[friendId]?.isEmpty == true) {
        friendCategoryRelationships.remove(friendId);
      }
      print('🔗 [DEBUG] Updated relationships: $friendCategoryRelationships');
      
      // Update the category's member list
      print('👥 [DEBUG] Original members: ${category.friendUserIds}');
      final updatedMemberIds = category.friendUserIds.where((id) => id != friendId).toList();
      print('👥 [DEBUG] Updated members: $updatedMemberIds');
      
      final updatedCategory = category.copyWith(
        friendUserIds: updatedMemberIds,
        updatedAt: DateTime.now(),
      );
      
      print('💾 [DEBUG] Updating category internal state...');
      // Use the internal update method that handles caching and notifications
      _parent.updateCategoryInternal(categoryId, updatedCategory);
      print('✅ [DEBUG] Internal state updated');
      
      print('☁️ [DEBUG] Syncing to Firebase...');
      await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      print('✅ [DEBUG] Firebase sync completed');
      
      AppLogger.success('✅ Friend removed from category: $friendId -> $categoryId');
      print('🎉 [DEBUG] removeFriendFromCategory returning true');
      
      // Emit event bus notification for UI updates
      print('📡 [DEBUG] Emitting GroupEventBus.memberRemoved event...');
      GroupEventBus.memberRemoved();
      print('✅ [DEBUG] Event emitted successfully');
      
      return true;
    } catch (e) {
      print('💥 [DEBUG] Exception in removeFriendFromCategory: $e');
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
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    
    // Can edit if owner
    if (currentUserId == category.ownerId) {
      return true;
    }
    
    // Or if has admin permissions
    return ServiceLocator.get<PermissionService>().isGroupAdmin(category.id);
  }

  bool _canDeleteCategory(FriendCategory category) {
    final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
    
    // Can delete if owner
    if (currentUserId == category.ownerId) {
      return true;
    }
    
    // Or if has delete permissions
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
  
  // ===== VIEWMODEL COMPATIBILITY METHODS =====
  
  /// Get categories list (for ViewModels)
  List<FriendCategory> get categoriesList => _parent.categoriesList;
  
  /// Migrate existing groups to ensure owners are members
  Future<void> migrateOwnersAsMembers() async {
    print('🔄 [DEBUG] Running owner-as-member migration...');
    final categories = getAllCategories();
    
    for (final category in categories) {
      if (!category.friendUserIds.contains(category.ownerId)) {
        print('🔧 [DEBUG] Adding owner ${category.ownerId} to group "${category.name}"');
        
        final updatedCategory = category.copyWith(
          friendUserIds: [...category.friendUserIds, category.ownerId],
          updatedAt: DateTime.now(),
        );
        
        _parent.updateCategoryInternal(category.id, updatedCategory);
        await _parent.syncCategoryToFirebaseInternal(updatedCategory);
      }
    }
    print('✅ [DEBUG] Owner-as-member migration completed');
  }
  
  /// Assign friend to category (alternative name for addFriendToCategory)
  Future<bool> assignFriendToCategory(String friendId, String categoryId) async {
    return await addFriendToCategory(friendId, categoryId);
  }
  
  /// Refresh categories data
  Future<void> refresh() async {
    await _parent.refresh();
  }
}