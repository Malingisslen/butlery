import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Social menu operations for friend-based and group sharing with import/export and activity tracking.
/// Follows SRP - handles only social menu interactions (not basic CRUD or recipe operations).
/// ```dart
/// await ops.shareMenuWithFriends(menu: m, friendUserIds: [id1], message: 'Veckans meny');
/// await ops.shareMenuWithGroup(menu: m, categoryId: groupId);
/// await ops.importSharedMenu(sharedMenuId);
/// ```
class SocialMenuOperations {
  final FirebaseFirestore _firestore;
  final UnifiedFriendsService _friendsService;

  SocialMenuOperations({
    required FirebaseFirestore firestore,
    required UnifiedFriendsService friendsService,
  }) : _firestore = firestore,
       _friendsService = friendsService;

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

      // BUT-1775, applying BUT-1705/BUT-1736: `profileDisplayName`, NOT
      // `PermissionService.currentUser`, which is synthesized straight from
      // `FirebaseAuth.currentUser` and therefore carries the legal name on the
      // user's Google/Apple account — never a name they chose to expose. This
      // value is PERSISTED as `sharedByDisplayName` on documents every
      // recipient reads and lands verbatim in their GDPR export, and it is the
      // PROFILE name that `on-profile-updated.ts` renames and that account
      // deletion scrubs, so an Auth-sourced stamp would be both unconsented and
      // un-erasable. `tryGet` keeps this working before/without the service
      // graph; an unresolved name stamps the localized unknown-user label.
      final sharedByDisplayName =
          ServiceLocator.tryGet<UserService>()?.profileDisplayName ??
          AppLocale.current.displayUnknownUser;

      // Validate that all friend IDs are actual friends
      final userFriends = _friendsService.friends.map((f) => f.uid).toSet();
      final invalidFriendIds = friendUserIds
          .where((id) => !userFriends.contains(id))
          .toList();

      if (invalidFriendIds.isNotEmpty) {
        AppLogger.error('Invalid friend IDs: ${invalidFriendIds.join(', ')}');
        return false;
      }

      // Calculate menu statistics
      final totalRecipes = menu.values.fold(
        0,
        (total, recipes) => total + recipes.length,
      );
      // Same source as `sharedByDisplayName` above, for the same reason. This
      // one is easy to miss because it reads as CONTENT rather than
      // attribution — but the default title is persisted on the shared document,
      // rendered to every recipient, and exported verbatim, and
      // `on-profile-updated.ts` does not rename a title. An Auth-sourced legal
      // name here would be the one copy the rename propagator and the deletion
      // cascade can never reach.
      final menuTitle =
          customTitle ??
          AppLocale.current.menuDefaultTitle(sharedByDisplayName);

      // Prepare menu data for Firebase
      final menuData = {
        'contentType': 'menu',
        'title': menuTitle,
        'description': message?.trim(),
        'menu': menu.map(
          (category, recipes) => MapEntry(
            category,
            recipes.map((recipe) => recipe.toJson()).toList(),
          ),
        ),
        'totalRecipes': totalRecipes,
        'sharedByUserId': currentUser.uid,
        'sharedByDisplayName': sharedByDisplayName,
        'sharedByAvatarUrl': currentUser.avatarUrl,
        'sharedAt': FieldValue.serverTimestamp(),
        // Same list under the spelling `firestore.rules` (:722/:727) and the
        // GDPR export both speak — see the note in `recipe_sharing_manager`.
        // Without it a shared menu is unreadable AND unexportable to the very
        // people it was shared with.
        'sharedToUserIds': friendUserIds,
        'isActive': true,
        'menuType': 'personal_shared',
      };

      // Create shared menu document in Firestore
      final sharedMenuRef = _firestore
          .collection(FirestoreCollections.sharedContent)
          .doc();
      await sharedMenuRef.set(menuData);

      // Create individual share records for each friend
      final batch = _firestore.batch();

      for (final friendId in friendUserIds) {
        final shareRecordRef = _firestore
            .collection(FirestoreCollections.userSharedMenus)
            .doc(friendId)
            .collection(FirestoreCollections.receivedMenus)
            .doc(sharedMenuRef.id);

        batch.set(shareRecordRef, {
          'sharedMenuId': sharedMenuRef.id,
          'sharedByUserId': currentUser.uid,
          'sharedByDisplayName': sharedByDisplayName,
          'menuTitle': menuTitle,
          'sharedAt': FieldValue.serverTimestamp(),
          'isViewed': false,
          'isImported': false,
        });
      }

      await batch.commit();

      AppLogger.success(
        '✅ Menu shared successfully with ${friendUserIds.length} friends',
      );
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
      final friendsInCategory = _friendsService.categories.getFriendsInCategory(
        categoryId,
      );

      if (friendsInCategory.isEmpty) {
        AppLogger.error('No friends found in category');
        return false;
      }

      final friendIds = friendsInCategory.map((f) => f.uid).toList();

      // Use existing shareMenuWithFriends method
      final categoryName =
          _friendsService.categories.getCategoryById(categoryId)?.name ??
          AppLocale.current.menuShareGroupFallback;
      final enhancedTitle =
          customTitle ?? AppLocale.current.menuShareGroupTitle(categoryName);

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

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .where('contentType', isEqualTo: 'menu')
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .orderBy('sharedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '?',
          'sharedAt': data['sharedAt'],
          'totalRecipes': data['totalRecipes'] ?? 0,
          'sharedWithCount': (data['sharedToUserIds'] as List?)?.length ?? 0,
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

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection(FirestoreCollections.userSharedMenus)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedMenus)
          .orderBy('sharedAt', descending: true)
          .get();

      final pointerDocs = querySnapshot.docs;
      if (pointerDocs.isEmpty) return [];

      final pointerDataById = <String, Map<String, dynamic>>{};
      final sharedMenuIds = <String>[];
      for (final doc in pointerDocs) {
        final data = doc.data();
        final sharedMenuId = data['sharedMenuId'] as String?;
        if (sharedMenuId != null) {
          pointerDataById[sharedMenuId] = data;
          sharedMenuIds.add(sharedMenuId);
        }
      }

      if (sharedMenuIds.isEmpty) return [];

      final menuDocsById = <String, Map<String, dynamic>>{};
      for (final chunk in sharedMenuIds.chunked(kFirestoreWhereInLimit)) {
        final menuQuery = await _firestore
            .collection(FirestoreCollections.sharedContent)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final menuDoc in menuQuery.docs) {
          menuDocsById[menuDoc.id] = menuDoc.data();
        }
      }

      final sharedMenus = <Map<String, dynamic>>[];
      for (final sharedMenuId in sharedMenuIds) {
        final menuData = menuDocsById[sharedMenuId];
        if (menuData != null && menuData['isActive'] == true) {
          final pointerData = pointerDataById[sharedMenuId]!;
          sharedMenus.add({
            'id': sharedMenuId,
            'title': menuData['title'] ?? '?',
            'sharedByDisplayName': menuData['sharedByDisplayName'] ?? '?',
            'sharedByAvatarUrl': menuData['sharedByAvatarUrl'],
            'sharedAt': pointerData['sharedAt'],
            'totalRecipes': menuData['totalRecipes'] ?? 0,
            'description': menuData['description'],
            'isViewed': pointerData['isViewed'] ?? false,
            'isImported': pointerData['isImported'] ?? false,
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
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
        return false;
      }

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get shared menu data
      final menuDoc = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .doc(sharedMenuId)
          .get();

      if (!menuDoc.exists) {
        AppLogger.error('Shared menu not found');
        return false;
      }

      final menuData = menuDoc.data()!;

      // Verify user has access to this menu
      final sharedToUserIds = List<String>.from(
        menuData['sharedToUserIds'] ?? [],
      );
      if (!sharedToUserIds.contains(currentUserId)) {
        AppLogger.error('User does not have access to this menu');
        return false;
      }

      // Mark as imported in user's received menus
      await _firestore
          .collection(FirestoreCollections.userSharedMenus)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedMenus)
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

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return;

      await _firestore
          .collection(FirestoreCollections.userSharedMenus)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedMenus)
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

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return null;

      // Get shared menu data
      final menuDoc = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .doc(sharedMenuId)
          .get();

      if (!menuDoc.exists || menuDoc.data()!['isActive'] != true) {
        AppLogger.error('Shared menu not found or inactive');
        return null;
      }

      final menuData = menuDoc.data()!;

      // Verify user has access to this menu
      final sharedToUserIds = List<String>.from(
        menuData['sharedToUserIds'] ?? [],
      );
      if (!sharedToUserIds.contains(currentUserId)) {
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
                .map(
                  (recipeData) =>
                      Recipe.fromJson(recipeData as Map<String, dynamic>),
                )
                .toList();
          }
        });
      }

      return {
        'id': sharedMenuId,
        'title': menuData['title'] ?? '?',
        'description': menuData['description'],
        'menu': menu,
        'totalRecipes': menuData['totalRecipes'] ?? 0,
        'sharedByUserId': menuData['sharedByUserId'],
        'sharedByDisplayName': menuData['sharedByDisplayName'] ?? '?',
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
      if (!ServiceLocator.get<PermissionService>().isAuthenticated) {
        return false;
      }

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      // Get shared menu to verify ownership
      final menuDoc = await _firestore
          .collection(FirestoreCollections.sharedContent)
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
          .collection(FirestoreCollections.sharedContent)
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

      final currentUserId =
          ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return {};

      // Get menus shared by user
      final sharedByMeQuery = await _firestore
          .collection(FirestoreCollections.sharedContent)
          .where('contentType', isEqualTo: 'menu')
          .where('sharedByUserId', isEqualTo: currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      // Get menus shared with user
      final sharedWithMeQuery = await _firestore
          .collection(FirestoreCollections.userSharedMenus)
          .doc(currentUserId)
          .collection(FirestoreCollections.receivedMenus)
          .get();

      final totalSharedByMe = sharedByMeQuery.docs.length;
      final totalSharedWithMe = sharedWithMeQuery.docs.length;

      // Calculate total friends shared with
      final totalFriendsSharedWith = sharedByMeQuery.docs
          .expand(
            (doc) => List<String>.from(doc.data()['sharedToUserIds'] ?? []),
          )
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
}
