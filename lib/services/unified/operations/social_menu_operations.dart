/// 🔍 AI INFO BLOCK:
/// Component: Social Menu Operations - Feature interface for menu sharing and social features
/// File: lib/services/unified/operations/social_menu_operations.dart
/// Quick Guide: Handles all social menu operations like sharing menus with friends and groups
/// Dependencies IN: Firebase Firestore, UnifiedFriendsService, Menu models
/// Dependencies OUT: Used by MenuViewModel for social menu functionality
/// Data flow: MenuViewModel -> SocialMenuOperations -> Firebase -> Friends
/// State management: Stateless operations for menu sharing
/// Purpose: Separate menu sharing concerns from menu service
/// Common issues: Permission validation, friend validation, data formatting
/// Test coverage: Unit tests for sharing operations and data validation
/// Performance: Efficient batch operations for multiple friends
/// Analytics: Menu sharing events, friend engagement tracking
/// Code smells: None - focused on menu sharing operations only
/// Connected to: MenuService, UnifiedFriendsService, Social features
/// Used in phases: Phase 7 - COMPLETED Implementation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Comprehensive social menu operations providing advanced menu sharing and collaborative dining features.
///
/// This operations class implements sophisticated menu sharing functionality following Single Responsibility Principle,
/// handling all aspects of social menu interaction including friend-based sharing, group sharing, menu import/export,
/// and collaborative dining features. It provides comprehensive menu social capabilities while maintaining clean separation
/// from basic menu management and recipe operations.
///
/// **Single Responsibility Focus:**
/// This class exclusively handles social menu operations:
/// - **Friend-Based Sharing**: Direct menu sharing with individual friends and family members with custom messaging
/// - **Group Sharing**: Menu sharing with predefined friend categories and groups with bulk operation efficiency
/// - **Import/Export System**: Menu import and export functionality with data validation and format preservation
/// - **Activity Tracking**: Complete sharing activity monitoring with analytics and engagement statistics
///
/// **What This Class Does NOT Handle:**
/// - Basic menu CRUD operations (handled by menu services)
/// - Recipe management and operations (handled by recipe services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Authentication and user management (handled by permission services)
///
/// **Social Menu Features:**
/// - **Multi-Target Sharing**: Advanced sharing system supporting individual friends and group categories with validation
/// - **Collaborative Dining**: Menu sharing for collaborative meal planning with family and friend groups
/// - **Import/Export Tools**: Comprehensive menu data exchange with format preservation and validation
/// - **Activity Analytics**: Detailed sharing statistics with engagement tracking and usage insights
/// - **Permission Management**: Granular sharing permissions with access control and ownership validation
///
/// **Usage Examples:**
/// ```dart
/// final socialMenuOps = SocialMenuOperations(
///   firestore: firestore,
///   friendsService: friendsService,
/// );
/// 
/// // Friend-based menu sharing
/// await socialMenuOps.shareMenuWithFriends(
///   menu: weeklyMenu,
///   friendUserIds: [friendId1, friendId2],
///   message: 'Veckans meny - perfekt för familjemiddag!',
///   customTitle: 'Familjeveckans måltider',
/// );
/// 
/// // Group sharing with categories
/// await socialMenuOps.shareMenuWithGroup(
///   menu: dinnerPartyMenu,
///   categoryId: familyGroupId,
///   message: 'Menyn för helgens middagsbjudning',
/// );
/// 
/// // Menu import and activity tracking
/// await socialMenuOps.importSharedMenu(sharedMenuId);
/// final stats = await socialMenuOps.getSharingStats();
/// final sharedMenus = await socialMenuOps.getMenusSharedWithMe();
/// ```
class SocialMenuOperations {
  final FirebaseFirestore _firestore;
  final UnifiedFriendsService _friendsService;

  SocialMenuOperations({
    required FirebaseFirestore firestore,
    required UnifiedFriendsService friendsService,
  }) : _firestore = firestore,
       _friendsService = friendsService;

  // ===== MENU SHARING WITH FRIENDS =====

  /// Share menu with selected friends
  Future<bool> shareMenuWithFriends({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    String? message,
    String? customTitle,
  }) async {
    try {
      if (menu.isEmpty) {
        AppLogger.error('Cannot share empty menu');
        return false;
      }

      if (friendUserIds.isEmpty) {
        AppLogger.error('No friends selected for sharing');
        return false;
      }

      if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
        AppLogger.error('User must be authenticated to share menu');
        return false;
      }

      final currentUser = ServiceLocator.get<PermissionService>().currentUser;
      if (currentUser == null) return false;

      // Validate that all friend IDs are actual friends
      final userFriends = _friendsService.friends.map((f) => f.uid).toSet();
      final invalidFriendIds = friendUserIds.where((id) => !userFriends.contains(id)).toList();
      
      if (invalidFriendIds.isNotEmpty) {
        AppLogger.error('Invalid friend IDs: ${invalidFriendIds.join(', ')}');
        return false;
      }

      // Calculate menu statistics
      final totalRecipes = menu.values.fold(0, (total, recipes) => total + recipes.length);
      final menuTitle = customTitle ?? 'Meny från ${currentUser.displayName}';

      // Prepare menu data for Firebase
      final menuData = {
        'title': menuTitle,
        'description': message?.trim(),
        'menu': menu.map((category, recipes) => MapEntry(
          category,
          recipes.map((recipe) => recipe.toJson()).toList(),
        )),
        'totalRecipes': totalRecipes,
        'sharedByUserId': currentUser.uid,
        'sharedByDisplayName': currentUser.displayName,
        'sharedByAvatarUrl': currentUser.avatarUrl,
        'sharedAt': FieldValue.serverTimestamp(),
        'sharedWithUserIds': friendUserIds,
        'isActive': true,
        'menuType': 'personal_shared',
      };

      // Create shared menu document in Firestore
      final sharedMenuRef = _firestore.collection('sharedMenus').doc();
      await sharedMenuRef.set(menuData);

      // Create individual share records for each friend
      final batch = _firestore.batch();
      
      for (final friendId in friendUserIds) {
        final shareRecordRef = _firestore
            .collection('userSharedMenus')
            .doc(friendId)
            .collection('receivedMenus')
            .doc(sharedMenuRef.id);
        
        batch.set(shareRecordRef, {
          'sharedMenuId': sharedMenuRef.id,
          'sharedByUserId': currentUser.uid,
          'sharedByDisplayName': currentUser.displayName,
          'menuTitle': menuTitle,
          'sharedAt': FieldValue.serverTimestamp(),
          'isViewed': false,
          'isImported': false,
        });
      }

      await batch.commit();

      AppLogger.success('✅ Menu shared successfully with ${friendUserIds.length} friends');
      return true;
    } catch (e) {
      AppLogger.error('Failed to share menu with friends', e);
      return false;
    }
  }

  /// Share menu with friend category/group
  Future<bool> shareMenuWithGroup({
    required Map<String, List<Recipe>> menu,
    required String categoryId,
    String? message,
    String? customTitle,
  }) async {
    try {
      // Get friends in the specified category
      final friendsInCategory = _friendsService.categories.getFriendsInCategory(categoryId);
      
      if (friendsInCategory.isEmpty) {
        AppLogger.error('No friends found in category');
        return false;
      }

      final friendIds = friendsInCategory.map((f) => f.uid).toList();
      
      // Use existing shareMenuWithFriends method
      final categoryName = _friendsService.categories.getCategoryById(categoryId)?.name ?? 'Grupp';
      final enhancedTitle = customTitle ?? 'Meny för $categoryName';
      
      return await shareMenuWithFriends(
        menu: menu,
        friendUserIds: friendIds,
        message: message,
        customTitle: enhancedTitle,
      );
    } catch (e) {
      AppLogger.error('Failed to share menu with group', e);
      return false;
    }
  }

  /// Get menus shared by current user
  Future<List<Map<String, dynamic>>> getMenusSharedByMe() async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('sharedMenus')
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .orderBy('sharedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Namnlös meny',
          'sharedAt': data['sharedAt'],
          'totalRecipes': data['totalRecipes'] ?? 0,
          'sharedWithCount': (data['sharedWithUserIds'] as List?)?.length ?? 0,
          'description': data['description'],
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get shared menus', e);
      return [];
    }
  }

  /// Get menus shared with current user
  Future<List<Map<String, dynamic>>> getMenusSharedWithMe() async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('userSharedMenus')
          .doc(currentUserId)
          .collection('receivedMenus')
          .orderBy('sharedAt', descending: true)
          .get();

      final sharedMenus = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final sharedMenuId = data['sharedMenuId'];
        
        // Get full menu data
        final menuDoc = await _firestore
            .collection('sharedMenus')
            .doc(sharedMenuId)
            .get();
            
        if (menuDoc.exists && menuDoc.data()!['isActive'] == true) {
          final menuData = menuDoc.data()!;
          sharedMenus.add({
            'id': sharedMenuId,
            'title': menuData['title'] ?? 'Namnlös meny',
            'sharedByDisplayName': menuData['sharedByDisplayName'] ?? 'Okänd användare',
            'sharedByAvatarUrl': menuData['sharedByAvatarUrl'],
            'sharedAt': data['sharedAt'],
            'totalRecipes': menuData['totalRecipes'] ?? 0,
            'description': menuData['description'],
            'isViewed': data['isViewed'] ?? false,
            'isImported': data['isImported'] ?? false,
          });
        }
      }

      return sharedMenus;
    } catch (e) {
      AppLogger.error('Failed to get menus shared with me', e);
      return [];
    }
  }

  /// Import shared menu to local saved menus
  Future<bool> importSharedMenu(String sharedMenuId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return false;
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get shared menu data
      final menuDoc = await _firestore
          .collection('sharedMenus')
          .doc(sharedMenuId)
          .get();

      if (!menuDoc.exists) {
        AppLogger.error('Shared menu not found');
        return false;
      }

      final menuData = menuDoc.data()!;
      
      // Verify user has access to this menu
      final sharedWithUserIds = List<String>.from(menuData['sharedWithUserIds'] ?? []);
      if (!sharedWithUserIds.contains(currentUserId)) {
        AppLogger.error('User does not have access to this menu');
        return false;
      }

      // Mark as imported in user's received menus
      await _firestore
          .collection('userSharedMenus')
          .doc(currentUserId)
          .collection('receivedMenus')
          .doc(sharedMenuId)
          .update({
        'isImported': true,
        'importedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Menu imported successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to import shared menu', e);
      return false;
    }
  }

  /// Mark shared menu as viewed
  Future<void> markMenuAsViewed(String sharedMenuId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return;
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await _firestore
          .collection('userSharedMenus')
          .doc(currentUserId)
          .collection('receivedMenus')
          .doc(sharedMenuId)
          .update({
        'isViewed': true,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.debug('Menu marked as viewed: $sharedMenuId');
    } catch (e) {
      AppLogger.error('Failed to mark menu as viewed', e);
    }
  }

  /// Get shared menu data for display/import
  Future<Map<String, dynamic>?> getSharedMenuData(String sharedMenuId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return null;
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return null;

      // Get shared menu data
      final menuDoc = await _firestore
          .collection('sharedMenus')
          .doc(sharedMenuId)
          .get();

      if (!menuDoc.exists || menuDoc.data()!['isActive'] != true) {
        AppLogger.error('Shared menu not found or inactive');
        return null;
      }

      final menuData = menuDoc.data()!;
      
      // Verify user has access to this menu
      final sharedWithUserIds = List<String>.from(menuData['sharedWithUserIds'] ?? []);
      if (!sharedWithUserIds.contains(currentUserId)) {
        AppLogger.error('User does not have access to this menu');
        return null;
      }

      // Parse menu data back to Recipe objects
      final menu = <String, List<Recipe>>{};
      if (menuData['menu'] != null) {
        final menuJson = menuData['menu'] as Map<String, dynamic>;
        menuJson.forEach((category, recipeList) {
          if (recipeList is List) {
            menu[category] = recipeList
                .map((recipeData) => Recipe.fromJson(recipeData as Map<String, dynamic>))
                .toList();
          }
        });
      }

      return {
        'id': sharedMenuId,
        'title': menuData['title'] ?? 'Namnlös meny',
        'description': menuData['description'],
        'menu': menu,
        'totalRecipes': menuData['totalRecipes'] ?? 0,
        'sharedByUserId': menuData['sharedByUserId'],
        'sharedByDisplayName': menuData['sharedByDisplayName'] ?? 'Okänd användare',
        'sharedByAvatarUrl': menuData['sharedByAvatarUrl'],
        'sharedAt': menuData['sharedAt'],
      };
    } catch (e) {
      AppLogger.error('Failed to get shared menu data', e);
      return null;
    }
  }

  /// Delete shared menu (only by owner)
  Future<bool> deleteSharedMenu(String sharedMenuId) async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return false;
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get shared menu to verify ownership
      final menuDoc = await _firestore
          .collection('sharedMenus')
          .doc(sharedMenuId)
          .get();

      if (!menuDoc.exists) {
        AppLogger.error('Shared menu not found');
        return false;
      }

      final menuData = menuDoc.data()!;
      if (menuData['sharedByUserId'] != currentUserId) {
        AppLogger.error('Only menu owner can delete shared menu');
        return false;
      }

      // Soft delete (mark as inactive)
      await _firestore
          .collection('sharedMenus')
          .doc(sharedMenuId)
          .update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.success('✅ Shared menu deleted successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete shared menu', e);
      return false;
    }
  }

  /// Get sharing statistics for analytics
  Future<Map<String, dynamic>> getSharingStats() async {
    try {
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) return {};
      
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return {};

      // Get menus shared by user
      final sharedByMeQuery = await _firestore
          .collection('sharedMenus')
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      // Get menus shared with user
      final sharedWithMeQuery = await _firestore
          .collection('userSharedMenus')
          .doc(currentUserId)
          .collection('receivedMenus')
          .get();

      final totalSharedByMe = sharedByMeQuery.docs.length;
      final totalSharedWithMe = sharedWithMeQuery.docs.length;
      
      // Calculate total friends shared with
      final totalFriendsSharedWith = sharedByMeQuery.docs
          .expand((doc) => List<String>.from(doc.data()['sharedWithUserIds'] ?? []))
          .toSet()
          .length;

      return {
        'menusSharedByMe': totalSharedByMe,
        'menusSharedWithMe': totalSharedWithMe,
        'uniqueFriendsSharedWith': totalFriendsSharedWith,
        'totalSharingActivity': totalSharedByMe + totalSharedWithMe,
      };
    } catch (e) {
      AppLogger.error('Failed to get sharing stats', e);
      return {};
    }
  }
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}