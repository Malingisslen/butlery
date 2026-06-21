// lib/viewmodels/menu/menu_social_manager.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/viewmodels/menu/menu_storage.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Focused module for menu social features
/// This module handles ONLY social integration:
/// - Social menu sharing and importing
/// - Friend collaboration on menus
/// - Social menu discovery and statistics
/// - Imported menu management
/// ❌ DOES NOT CONTAIN: Core state management, local storage, menu generation
class MenuSocialManager {
  final SocialMenuOperations _socialMenuOps;

  MenuSocialManager({
    required SocialMenuOperations socialMenuOps,
  }) : _socialMenuOps = socialMenuOps;

  /// Share menu with friends
  Future<bool> shareMenuWithFriends({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    required String menuName,
    String? shareMessage,
  }) async {
    try {
      final shareSuccess = await _socialMenuOps.shareMenuWithFriends(
        menu: menu,
        friendUserIds: friendUserIds,
        message: shareMessage?.trim(),
        customTitle: menuName,
      );

      if (shareSuccess) {
        AppLogger.success(
            '✅ Meny delad med ${friendUserIds.length} vänner: $menuName');
        return true;
      } else {
        AppLogger.warning('⚠️ Social delning misslyckades');
        return false;
      }
    } catch (e) {
      AppLogger.warning('⚠️ Social delning misslyckades: $e');
      rethrow;
    }
  }

  /// Get available shared menus from friends
  Future<List<Map<String, dynamic>>> getAvailableSharedMenus() async {
    try {
      return await _socialMenuOps.getMenusSharedWithMe();
    } catch (e) {
      AppLogger.error('Failed to get available shared menus', e);
      return [];
    }
  }

  /// Import shared menu from friend
  Future<bool> importSharedMenu(String sharedMenuId) async {
    try {
      final success = await _socialMenuOps.importSharedMenu(sharedMenuId);

      if (success) {
        AppLogger.success('✅ Meny importerad från vän: $sharedMenuId');
      } else {
        AppLogger.warning('⚠️ Kunde inte importera meny: $sharedMenuId');
      }

      return success;
    } catch (e) {
      AppLogger.error('Import shared menu failed', e);
      rethrow;
    }
  }

  /// Mark shared menu as viewed
  Future<void> markSharedMenuAsViewed(String sharedMenuId) async {
    try {
      await _socialMenuOps.markMenuAsViewed(sharedMenuId);
      AppLogger.info('📖 Meny markerad som visad: $sharedMenuId');
    } catch (e) {
      AppLogger.error('Mark menu as viewed failed', e);
    }
  }

  /// Load imported menus from social operations
  Future<List<SavedMenuInfo>> loadImportedMenus() async {
    try {
      final importedMenusData = await _socialMenuOps.getMenusSharedWithMe();
      final menuInfos = <SavedMenuInfo>[];

      // Filter for imported menus only
      final importedOnly = importedMenusData
          .where((menu) => menu['isImported'] == true)
          .toList();

      for (final menuData in importedOnly) {
        try {
          menuInfos.add(SavedMenuInfo(
            key: menuData['id'] as String,
            name: menuData['title'] as String,
            savedDate:
                SerializationUtils.safeRequiredDateTime(menuData, 'sharedAt'),
            recipeCount: menuData['totalRecipes'] as int,
            comment: (menuData['description'] as String?).orEmpty(),
            originalAuthor: menuData['sharedByDisplayName'] as String?,
            isModified: false,
            isOwned: false, // Imported menus are not owned by current user
            firebaseId: menuData['id'] as String?,
          ));
        } catch (e) {
          AppLogger.warning('⚠️ Kunde inte läsa importerad meny: $e');
        }
      }

      AppLogger.success('✅ ${menuInfos.length} importerade menyer laddade');
      return menuInfos;
    } catch (e) {
      AppLogger.error('❌ Fel vid laddning av importerade menyer: $e');
      return [];
    }
  }

  /// Load specific imported menu data
  ///
  /// [menuKey] is the shared-menu document id (same key surfaced by
  /// [loadImportedMenus]). Returns the full menu structure as a
  /// [SavedMenuData] so the load-menu flow can populate it like a local menu,
  /// or null when the key isn't among the menus shared with this user.
  Future<SavedMenuData?> loadImportedMenuData(String menuKey) async {
    try {
      final sharedData = await _socialMenuOps.getSharedMenuData(menuKey);
      if (sharedData == null) {
        AppLogger.debug('Imported menu not found: $menuKey');
        return null;
      }

      // getSharedMenuData already parses 'menu' into Recipe objects.
      final menu = (sharedData['menu'] as Map<String, List<Recipe>>?) ??
          <String, List<Recipe>>{};

      return SavedMenuData(
        name: (sharedData['title'] as String?).orEmpty(),
        savedDate:
            SerializationUtils.safeRequiredDateTime(sharedData, 'sharedAt'),
        recipeCount: (sharedData['totalRecipes'] as int?) ??
            menu.values.fold(0, (total, recipes) => total + recipes.length),
        menu: menu,
        lastPrompt: '', // Shared menus don't carry the original prompt.
        comment: (sharedData['description'] as String?).orEmpty(),
        originalAuthor: sharedData['sharedByDisplayName'] as String?,
        originalAuthorId: sharedData['sharedByUserId'] as String?,
        isModified: false,
        firebaseId: sharedData['id'] as String?,
      );
    } catch (e) {
      AppLogger.error('Load imported menu data failed', e);
      return null;
    }
  }

  /// Get sharing statistics
  Future<Map<String, dynamic>> getSharingStats() async {
    try {
      return await _socialMenuOps.getSharingStats();
    } catch (e) {
      AppLogger.error('Get sharing stats failed', e);
      return {};
    }
  }

  /// Get social activity summary
  Future<Map<String, dynamic>> getSocialActivitySummary() async {
    try {
      final stats = await getSharingStats();
      final sharedMenus = await getAvailableSharedMenus();
      final importedMenus = await loadImportedMenus();

      return {
        'menusShared': stats['menusShared'] ?? 0,
        'menusReceived': sharedMenus.length,
        'menusImported': importedMenus.length,
        'totalSocialInteractions': (stats['menusShared'] ?? 0) +
            sharedMenus.length +
            importedMenus.length,
        'lastActivity':
            _getLastSocialActivity(stats, sharedMenus, importedMenus),
      };
    } catch (e) {
      AppLogger.error('Get social activity summary failed', e);
      return {};
    }
  }

  DateTime? _getLastSocialActivity(
    Map<String, dynamic> stats,
    List<Map<String, dynamic>> sharedMenus,
    List<SavedMenuInfo> importedMenus,
  ) {
    DateTime? lastActivity;

    // Check last shared activity
    if (stats['lastSharedAt'] != null) {
      try {
        lastActivity =
            DateTime.tryParse((stats['lastSharedAt'] as String?).orEmpty());
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Check last received menu
    for (final menu in sharedMenus) {
      try {
        final sharedAt =
            DateTime.tryParse((menu['sharedAt'] as String?).orEmpty());
        if (sharedAt != null &&
            (lastActivity == null || sharedAt.isAfter(lastActivity))) {
          lastActivity = sharedAt;
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    // Check last imported menu
    for (final menu in importedMenus) {
      if (lastActivity == null || menu.savedDate.isAfter(lastActivity)) {
        lastActivity = menu.savedDate;
      }
    }

    return lastActivity;
  }

  /// Validate sharing prerequisites
  bool validateSharingPrerequisites({
    required Map<String, List<Recipe>> menu,
    required List<String> friendUserIds,
    required String menuName,
  }) {
    if (menu.isEmpty) {
      throw ArgumentError(AppLocale.current.errorNoMenuToShare);
    }

    if (menuName.trim().isEmpty) {
      throw ArgumentError(AppLocale.current.errorFillRequiredFields);
    }

    if (friendUserIds.isEmpty) {
      throw ArgumentError(AppLocale.current.errorSelectAtLeastOneFriend);
    }

    return true;
  }

  /// Check if menu can be shared
  bool canShareMenu(Map<String, List<Recipe>> menu) {
    if (menu.isEmpty) return false;

    // Check that menu has at least one recipe
    final totalRecipes =
        menu.values.fold(0, (total, recipes) => total + recipes.length);
    return totalRecipes > 0;
  }

  /// Check if social features are available
  Future<bool> areSocialFeaturesAvailable() async {
    try {
      // This could check network connectivity, user permissions, etc.
      return true; // Simplified for now
    } catch (e) {
      return false;
    }
  }
}
