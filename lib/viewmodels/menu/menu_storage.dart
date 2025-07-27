// lib/viewmodels/menu/menu_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';

/// Focused module for menu local storage
/// 
/// This module handles ONLY local storage operations:
/// - SharedPreferences save/load/delete operations
/// - Menu serialization/deserialization
/// - Local storage validation and error handling
/// - Storage key management
/// 
/// ❌ DOES NOT CONTAIN: State management, social features, menu generation
class MenuStorage {
  
  // ===== SAVE OPERATIONS =====

  /// Save menu to local storage
  Future<String> saveMenuLocally({
    required String menuName,
    required String comment,
    required Map<String, List<Recipe>> menu,
    required String lastPrompt,
    required int totalRecipeCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final menuKey = 'saved_menu_${menuName.replaceAll(' ', '_')}_$timestamp';

    final savedMenu = SavedMenuData(
      name: menuName.trim(),
      savedDate: DateTime.now(),
      recipeCount: totalRecipeCount,
      menu: menu,
      lastPrompt: lastPrompt,
      comment: comment.trim(),
    );

    final menuJson = jsonEncode(savedMenu.toJson());
    await prefs.setString(menuKey, menuJson);

    AppLogger.success(
        '✅ Meny sparad lokalt: $menuName med $totalRecipeCount recept');

    return menuKey;
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

  /// Load all local menus (owned by user)
  Future<List<SavedMenuInfo>> loadLocalMenus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final menuKeys =
          keys.where((key) => key.startsWith('saved_menu_')).toList();

      final menuInfos = <SavedMenuInfo>[];

      for (final key in menuKeys) {
        try {
          final menuJson = prefs.getString(key);
          if (menuJson != null) {
            final menuData = SavedMenuData.fromJson(jsonDecode(menuJson));

            // Only owned menus (not imported ones that became saved locally)
            if (menuData.isOwned) {
              menuInfos.add(SavedMenuInfo(
                key: key,
                name: menuData.name,
                savedDate: menuData.savedDate,
                recipeCount: menuData.recipeCount,
                comment: menuData.comment,
                originalAuthor: menuData.originalAuthor,
                isModified: menuData.isModified,
                isOwned: menuData.isOwned,
                firebaseId: menuData.firebaseId,
              ));
            }
          }
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte läsa lokal meny $key: $e');
        }
      }

      return menuInfos;
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av lokala menyer: $e');
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
        'averageSizePerMenu': menuKeys.isNotEmpty ? totalSize / menuKeys.length : 0,
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
      name: json['name'] ?? '',
      savedDate: DateTime.fromMillisecondsSinceEpoch(json['savedDate'] ?? 0),
      recipeCount: json['recipeCount'] ?? 0,
      menu: menuMap,
      lastPrompt: json['lastPrompt'] ?? '',
      comment: json['comment'] ?? '',
      originalAuthor: json['originalAuthor'],
      originalAuthorId: json['originalAuthorId'],
      isModified: json['isModified'] ?? false,
      firebaseId: json['firebaseId'],
    );
  }
}