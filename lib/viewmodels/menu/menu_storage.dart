// lib/viewmodels/menu/menu_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Focused module for menu local storage
/// This module handles ONLY local storage operations:
/// - SharedPreferences save/load/delete operations
/// - Menu serialization/deserialization
/// - Local storage validation and error handling
/// - Storage key management
/// ❌ DOES NOT CONTAIN: State management, social features, menu generation
class MenuStorage {
  final FirestoreRepository _firestoreRepository;

  /// Creates MenuStorage with dependency injection support
  /// [firestoreRepository] Optional FirestoreRepository for testing.
  /// If not provided, uses ServiceLocator to get the instance.
  MenuStorage({FirestoreRepository? firestoreRepository})
      : _firestoreRepository = firestoreRepository ?? ServiceLocator.get<FirestoreRepository>();
  
  // ===== SAVE OPERATIONS =====

  /// Save menu to Firestore
  Future<String> saveMenuLocally({
    required String menuName,
    required String comment,
    required Map<String, List<Recipe>> menu,
    required String lastPrompt,
    required int totalRecipeCount,
  }) async {
    // Get current user
    final permissionService = ServiceLocator.get<PermissionService>();
    final userId = permissionService.currentUserId;
    final userName = permissionService.currentUserDisplayName ?? 'Unknown';

    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create SharedMenu
    final sharedMenu = SharedMenu.create(
      sharedByUserId: userId,
      sharedByDisplayName: userName,
      sharedToUserIds: [], // Not shared yet
      shareMessage: comment.trim(),
      menuTitle: menuName.trim(),
      menuSnapshot: menu,
    );

    // Save to Firestore using repository
    final docRef = await _firestoreRepository.collection('menus').add(
      sharedMenu.toFirestore(),
    );

    AppLogger.success('✅ Meny sparad till Firestore: $menuName med $totalRecipeCount recept');

    return docRef.id; // Return Firestore document ID instead of local key
  }

  /// Load menu from local storage by key
  Future<SavedMenuData?> loadMenuByKey(String menuKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final menuJson = prefs.getString(menuKey);

      if (menuJson != null) {
        final menuData = SavedMenuData.fromJson(jsonDecode(menuJson));
        AppLogger.success('✅ Lokal meny laddad: ${menuData.name}');
        return menuData;
      }

      return null;
    } catch (e) {
      AppLogger.error('Load menu failed', e);
      rethrow;
    }
  }

  /// Delete menu from local storage
  Future<bool> deleteMenuByKey(String menuKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(menuKey);

      AppLogger.success('✅ Meny borttagen: $menuKey');
      return true;
    } catch (e) {
      AppLogger.error('Delete menu failed', e);
      return false;
    }
  }

  /// Mark menu as modified
  Future<bool> markMenuAsModified(String menuKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final menuJson = prefs.getString(menuKey);

      if (menuJson != null) {
        final menuData = SavedMenuData.fromJson(jsonDecode(menuJson));
        final modifiedData = SavedMenuData(
          name: menuData.name,
          savedDate: menuData.savedDate,
          recipeCount: menuData.recipeCount,
          menu: menuData.menu,
          lastPrompt: menuData.lastPrompt,
          comment: menuData.comment,
          originalAuthor: menuData.originalAuthor,
          originalAuthorId: menuData.originalAuthorId,
          isModified: true,
          firebaseId: menuData.firebaseId,
        );

        final modifiedJson = jsonEncode(modifiedData.toJson());
        await prefs.setString(menuKey, modifiedJson);

        AppLogger.success('✅ Meny markerad som modifierad: $menuKey');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Mark menu as modified failed', e);
      return false;
    }
  }

  // ===== LOAD OPERATIONS =====

  /// Load all menus from Firestore (owned by user)
  Future<List<SavedMenuInfo>> loadLocalMenus() async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.debug('No user ID available for loading menus');
        return [];
      }

      // Query menus from Firestore using repository
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

  /// Load imported menu data by key
  Future<SavedMenuData?> loadImportedMenuByKey(String menuKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final importedMenusJson = prefs.getString('imported_menus');

      if (importedMenusJson != null) {
        final importedMenusData = jsonDecode(importedMenusJson) as Map<String, dynamic>;
        
        if (importedMenusData.containsKey(menuKey)) {
          final menuData = SavedMenuData.fromJson(
            importedMenusData[menuKey] as Map<String, dynamic>
          );
          return menuData;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('Load imported menu failed', e);
      return null;
    }
  }

  // ===== STORAGE VALIDATION =====

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

  /// Get storage size information
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final menuKeys = keys.where((key) => key.startsWith('saved_menu_')).toList();

      int totalSize = 0;
      for (final key in menuKeys) {
        final menuJson = prefs.getString(key);
        if (menuJson != null) {
          totalSize += menuJson.length;
        }
      }

      return {
        'menuCount': menuKeys.length,
        'totalSizeBytes': totalSize,
        'totalSizeKB': totalSize / 1024,
        'averageSizePerMenu': menuKeys.isNotEmpty ? totalSize.toDouble() / menuKeys.length.toDouble() : 0.0,
      };
    } catch (e) {
      AppLogger.error('Get storage info failed', e);
      return {};
    }
  }

  // ===== CLEANUP OPERATIONS =====

  /// Clean up orphaned or corrupted menu data
  Future<int> cleanupStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final menuKeys = keys.where((key) => key.startsWith('saved_menu_')).toList();

      int cleaned = 0;
      for (final key in menuKeys) {
        try {
          final menuJson = prefs.getString(key);
          if (menuJson != null) {
            // Try to parse - if it fails, it's corrupted
            SavedMenuData.fromJson(jsonDecode(menuJson));
          } else {
            // Empty key, remove it
            await prefs.remove(key);
            cleaned++;
          }
        } catch (e) {
          // Corrupted data, remove it
          await prefs.remove(key);
          cleaned++;
          AppLogger.warning('⚠️ Removed corrupted menu data: $key');
        }
      }

      if (cleaned > 0) {
        AppLogger.success('✅ Cleaned up $cleaned corrupted menu entries');
      }

      return cleaned;
    } catch (e) {
      AppLogger.error('Storage cleanup failed', e);
      return 0;
    }
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
      savedDate: DateTime.fromMillisecondsSinceEpoch((json['savedDate'] as int?).orZero()),
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