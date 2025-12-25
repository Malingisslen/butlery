// lib/viewmodels/menu/menu_storage.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart'
    show SavedMenuInfo;

/// Firestore-based menu storage module
///
/// This module handles menu persistence using Firestore:
/// - Save menus to Firestore 'menus' collection
/// - Load user's menus from Firestore
/// - Delete menus from Firestore
/// - Menu validation
///
/// Architecture: Firestore-only for cloud sync and social sharing support.
/// All menus are stored in Firebase, enabling cross-device access and sharing.
class MenuStorage {
  final FirestoreRepository _firestoreRepository;

  /// Creates MenuStorage with dependency injection support
  MenuStorage({FirestoreRepository? firestoreRepository})
      : _firestoreRepository =
            firestoreRepository ?? ServiceLocator.get<FirestoreRepository>();

  /// Save menu to Firestore
  ///
  /// Returns the Firestore document ID for the saved menu.
  /// Throws if user is not authenticated.
  Future<String> saveMenu({
    required String menuName,
    required String comment,
    required Map<String, List<Recipe>> menu,
    required String lastPrompt,
    required int totalRecipeCount,
  }) async {
    final permissionService = ServiceLocator.get<PermissionService>();
    final userId = permissionService.currentUserId;
    final userName = permissionService.currentUserDisplayName ?? 'Unknown';

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create SharedMenu model
    final sharedMenu = SharedMenu.create(
      sharedByUserId: userId,
      sharedByDisplayName: userName,
      sharedToUserIds: [], // Not shared yet - sharing handled separately
      shareMessage: comment.trim(),
      menuTitle: menuName.trim(),
      menuSnapshot: menu,
    );

    // Save to Firestore
    final docRef = await _firestoreRepository.collection('menus').add(
          sharedMenu.toFirestore(),
        );

    AppLogger.success(
        '✅ Menu saved to Firestore: $menuName ($totalRecipeCount recipes)');
    return docRef.id;
  }

  /// Legacy method name - delegates to saveMenu
  @Deprecated('Use saveMenu instead')
  Future<String> saveMenuLocally({
    required String menuName,
    required String comment,
    required Map<String, List<Recipe>> menu,
    required String lastPrompt,
    required int totalRecipeCount,
  }) =>
      saveMenu(
        menuName: menuName,
        comment: comment,
        menu: menu,
        lastPrompt: lastPrompt,
        totalRecipeCount: totalRecipeCount,
      );

  /// Load a specific menu by its Firestore document ID
  ///
  /// Returns SavedMenuData if found, null otherwise.
  Future<SavedMenuData?> loadMenuByKey(String menuId) async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.warning('No user ID available for loading menu');
        return null;
      }

      // Load from Firestore
      final doc =
          await _firestoreRepository.collection('menus').doc(menuId).get();

      if (!doc.exists || doc.data() == null) {
        AppLogger.debug('Menu not found: $menuId');
        return null;
      }

      final data = doc.data()!;

      // Verify ownership
      if (data['sharedByUserId'] != userId) {
        AppLogger.warning('Menu $menuId does not belong to current user');
        return null;
      }

      // Parse SharedMenu and convert to SavedMenuData
      final sharedMenu = SharedMenu.fromFirestore(data, doc.id);

      final menuData = SavedMenuData(
        name: sharedMenu.menuTitle,
        savedDate: sharedMenu.sharedAt,
        recipeCount: sharedMenu.totalRecipeCount,
        menu: sharedMenu.menuSnapshot,
        lastPrompt: '', // Not stored in SharedMenu - could be added later
        comment: sharedMenu.shareMessage ?? '',
        originalAuthor: null,
        originalAuthorId: null,
        isModified: false,
        firebaseId: doc.id,
      );

      AppLogger.success('✅ Menu loaded from Firestore: ${menuData.name}');
      return menuData;
    } catch (e) {
      AppLogger.error('Failed to load menu: $menuId', e);
      return null;
    }
  }

  /// Load all menus owned by the current user from Firestore
  Future<List<SavedMenuInfo>> loadUserMenus() async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.debug('No user ID available for loading menus');
        return [];
      }

      // Query user's menus from Firestore
      final snapshot = await _firestoreRepository
          .collection('menus')
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      final menuInfos = <SavedMenuInfo>[];

      for (final doc in snapshot.docs) {
        try {
          final menu = SharedMenu.fromFirestore(doc.data(), doc.id);
          menuInfos.add(SavedMenuInfo(
            key: doc.id,
            name: menu.menuTitle,
            savedDate: menu.sharedAt,
            recipeCount: menu.totalRecipeCount,
            comment: menu.shareMessage ?? '',
            originalAuthor: null,
            isModified: false,
            isOwned: true,
            firebaseId: doc.id,
          ));
        } catch (e) {
          AppLogger.warning('⚠️ Could not parse menu ${doc.id}: $e');
        }
      }

      AppLogger.info('Loaded ${menuInfos.length} menus from Firestore');
      return menuInfos;
    } catch (e) {
      AppLogger.error('❌ Failed to load menus from Firestore: $e');
      return [];
    }
  }

  /// Legacy method name - delegates to loadUserMenus
  @Deprecated('Use loadUserMenus instead')
  Future<List<SavedMenuInfo>> loadLocalMenus() => loadUserMenus();

  /// Delete a menu from Firestore by document ID
  ///
  /// Returns true if deletion succeeds, false otherwise.
  Future<bool> deleteMenuByKey(String menuId) async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.warning('No user ID available for deleting menu');
        return false;
      }

      // Verify ownership before deletion
      final doc =
          await _firestoreRepository.collection('menus').doc(menuId).get();

      if (!doc.exists) {
        AppLogger.warning('Menu not found for deletion: $menuId');
        return false;
      }

      final data = doc.data();
      if (data?['sharedByUserId'] != userId) {
        AppLogger.warning(
            'Cannot delete menu $menuId - not owned by current user');
        return false;
      }

      // Delete from Firestore
      await _firestoreRepository.collection('menus').doc(menuId).delete();

      AppLogger.success('✅ Menu deleted from Firestore: $menuId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete menu: $menuId', e);
      return false;
    }
  }

  /// Mark menu as modified (updates Firestore document)
  Future<bool> markMenuAsModified(String menuId) async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) return false;

      // Verify ownership
      final doc =
          await _firestoreRepository.collection('menus').doc(menuId).get();
      if (!doc.exists || doc.data()?['sharedByUserId'] != userId) {
        return false;
      }

      // Update the document with modified flag
      await _firestoreRepository.collection('menus').doc(menuId).update({
        'isModified': true,
        'modifiedAt': DateTime.now().toIso8601String(),
      });

      AppLogger.success('✅ Menu marked as modified: $menuId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark menu as modified: $menuId', e);
      return false;
    }
  }

  /// Validate menu name for storage
  bool validateMenuName(String menuName) {
    final trimmed = menuName.trim();
    return trimmed.isNotEmpty && trimmed.length <= 100;
  }

  /// Validate menu data for storage
  bool validateMenuData(Map<String, List<Recipe>> menu) {
    if (menu.isEmpty) return false;

    // Check that each section has at least one recipe
    for (final recipes in menu.values) {
      if (recipes.isEmpty) return false;
    }

    return true;
  }

  /// Load imported menu data by key (menus shared with you)
  /// These are stored locally after being imported from social shares
  Future<SavedMenuData?> loadImportedMenuByKey(String menuKey) async {
    // TODO(imported-menu-flow): Implement imported menu loading from shared_menus collection
    // Status: Deferred - current social menu flow handles sharing separately
    // Returns null as imported menus use a different data flow
    return null;
  }
}

/// Data class for saved menu with complete information
class SavedMenuData {
  final String name;
  final DateTime savedDate;
  final int recipeCount;
  final Map<String, List<Recipe>> menu;
  final String lastPrompt;
  final String comment;
  final String? originalAuthor;
  final String? originalAuthorId;
  final bool isModified;
  final String? firebaseId;

  const SavedMenuData({
    required this.name,
    required this.savedDate,
    required this.recipeCount,
    required this.menu,
    required this.lastPrompt,
    required this.comment,
    this.originalAuthor,
    this.originalAuthorId,
    this.isModified = false,
    this.firebaseId,
  });

  bool get isOwned => originalAuthor == null;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'savedDate': savedDate.millisecondsSinceEpoch,
      'recipeCount': recipeCount,
      'menu': menu.map((key, recipes) => MapEntry(
            key,
            recipes.map((recipe) => recipe.toJson()).toList(),
          )),
      'lastPrompt': lastPrompt,
      'comment': comment,
      'originalAuthor': originalAuthor,
      'originalAuthorId': originalAuthorId,
      'isModified': isModified,
      'firebaseId': firebaseId,
    };
  }

  static SavedMenuData fromJson(Map<String, dynamic> json) {
    final menuMap = <String, List<Recipe>>{};

    if (json['menu'] != null) {
      final menuJson = json['menu'] as Map<String, dynamic>;
      menuJson.forEach((key, recipeList) {
        if (recipeList is List) {
          menuMap[key] = recipeList
              .map((recipeJson) =>
                  Recipe.fromJson(recipeJson as Map<String, dynamic>))
              .toList();
        }
      });
    }

    return SavedMenuData(
      name: (json['name'] as String?).orEmpty(),
      savedDate: DateTime.fromMillisecondsSinceEpoch(
          (json['savedDate'] as int?).orZero()),
      recipeCount: (json['recipeCount'] as int?).orZero(),
      menu: menuMap,
      lastPrompt: (json['lastPrompt'] as String?).orEmpty(),
      comment: (json['comment'] as String?).orEmpty(),
      originalAuthor: json['originalAuthor'],
      originalAuthorId: json['originalAuthorId'],
      isModified: (json['isModified'] as bool?).orFalse(),
      firebaseId: json['firebaseId'],
    );
  }
}

// SavedMenuInfo is defined in menu_state_manager.dart
