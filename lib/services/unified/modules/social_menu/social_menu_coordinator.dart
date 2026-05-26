/// Social Menu Coordinator implementing standardized coordination patterns.
/// This coordinator provides unified menu sharing and collaboration functionality
/// following the established pattern from SocialRecipeCoordinator. It uses the
/// BaseSocialCoordinator to provide consistent invitation system, import operations,
/// and notification coordination for menu content.
/// **Architecture Benefits:**
/// - **Consistent API**: Unified operations matching SocialRecipeCoordinator patterns
/// - **Standardized Coordination**: Common social coordination patterns across content types
/// - **Menu-Specific Logic**: Customized behavior for menu sharing and collaboration
/// - **Service Integration**: Seamless integration with UnifiedMenuService and focused services
/// **Menu Coordination Features:**
/// - **Menu Invitation System**: Swedish-style menu sharing with complete recipe snapshots
/// - **Copy-on-Write Import**: Fork-style menu import with proper attribution
/// - **Collaboration Support**: Team-based menu planning and editing capabilities
/// - **Analytics Integration**: Menu engagement tracking and user interaction metrics
/// **Usage Example:**
/// ```dart
/// final menuCoordinator = SocialMenuCoordinator(
///   getCurrentUserId: () => authService.currentUserId,
///   getCurrentUserDisplayName: () => userProfile.displayName,
///   setError: (error) => _error = error,
///   notifyListeners: () => notifyListeners(),
///   getMenuById: (id) => menuService.getMenuById(id),
///   saveMenu: (menu) => menuService.saveMenu(menu),
/// );
/// // Create menu invitation
/// final invitationId = await menuCoordinator.createMenuInvitation(
///   menuId: 'menu_123',
///   inviteeUserIds: ['user1', 'user2'],
///   message: 'Min veckomeny för nästa vecka!',
/// );
/// // Import shared menu
/// final menuId = await menuCoordinator.importSharedMenu(
///   sharedMenuId: 'shared_menu_456',
///   newTitle: 'Min importerade veckomeny',
/// );
/// ```

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/services/unified/modules/social_coordination/base_social_coordinator.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Result of joining a shared menu.
/// Indicates whether the join connected to a collaborative realtime session.
class MenuJoinResult {
  /// The ID of the joined menu (either sharedMenuId or realtimeMenuId).
  final String menuId;

  /// Whether this is a collaborative realtime menu (true) or a regular shared menu (false).
  final bool isCollaborative;

  const MenuJoinResult({
    required this.menuId,
    required this.isCollaborative,
  });
}

/// Social Menu Coordinator extending BaseSocialCoordinator for consistent patterns
class SocialMenuCoordinator
    extends BaseSocialCoordinator<Map<String, List<Recipe>>, SharedMenu> {
  @override
  String get serviceName => 'SocialMenuCoordinator';

  late final BaseSharedContentRepository<SharedMenu> _sharedMenuRepository;
  final Future<Map<String, List<Recipe>>?> Function(String) _getMenu;
  final Future<String?> Function(Map<String, List<Recipe>>) _saveMenu;

  /// Cached viewed status (menuId → bool)
  final Map<String, bool> _viewedStatusCache = {};

  /// Cached imported status (menuId → bool)
  final Map<String, bool> _importedStatusCache = {};

  /// Cached dismissed status (menuId → bool)
  final Map<String, bool> _dismissedStatusCache = {};

  SocialMenuCoordinator({
    required super.getCurrentUserId,
    required super.getCurrentUserDisplayName,
    required super.setError,
    required super.notifyListeners,
    required Future<Map<String, List<Recipe>>?> Function(String) getMenu,
    required Future<String?> Function(Map<String, List<Recipe>>) saveMenu,
    BaseSharedContentRepository<SharedMenu>? sharedMenuRepository,
    JsonCacheHelper? cacheHelper,
  })  : _getMenu = getMenu,
        _saveMenu = saveMenu {
    _sharedMenuRepository =
        sharedMenuRepository ?? FirebaseSharedMenuRepository();

    AppLogger.info(
        '✅ SocialMenuCoordinator initialized for menu sharing and collaboration');
  }
  @override
  String get contentTypeName => 'menu';

  @override
  String getContentTitle(Map<String, List<Recipe>> content) {
    // Generate descriptive title from menu content
    final categories = content.keys.toList();
    final totalRecipes =
        content.values.fold(0, (sum, recipes) => sum + recipes.length);

    if (categories.isEmpty) return AppLocale.current.menuTitleEmpty;
    if (categories.length == 1) {
      return AppLocale.current
          .menuTitleSingleCategory(categories.first, totalRecipes);
    }

    return AppLocale.current
        .menuTitleMultiCategory(categories.join(', '), totalRecipes);
  }

  @override
  BaseSharedContentRepository<SharedMenu> get sharedRepository =>
      _sharedMenuRepository;

  @override
  Future<Map<String, List<Recipe>>?> getContentById(String contentId) async {
    return await _getMenu(contentId);
  }

  @override
  SharedMenu createSharedContentModel({
    required String originalContentId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    required Map<String, List<Recipe>> contentSnapshot,
    Map<String, dynamic>? additionalData,
  }) {
    final allowCollaboration = additionalData?['allowCollaboration'] ?? false;
    final menuTitle =
        additionalData?['menuTitle'] ?? getContentTitle(contentSnapshot);

    return SharedMenu.create(
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage,
      menuTitle: menuTitle,
      menuSnapshot: contentSnapshot,
      allowCollaboration: allowCollaboration,
    );
  }

  @override
  Map<String, List<Recipe>> createImportedContent({
    required SharedMenu sharedContent,
    required String newOwnerId,
    String? newTitle,
  }) {
    // For menus, we copy the entire menu structure with attribution
    final importedMenu =
        Map<String, List<Recipe>>.from(sharedContent.menuSnapshot);

    // Add attribution information to each recipe
    final attributedMenu = <String, List<Recipe>>{};
    importedMenu.forEach((category, recipes) {
      attributedMenu[category] = recipes.map((recipe) {
        // Create copy of recipe with attribution (simplified for now)
        // Note: The actual copyWith implementation depends on Recipe model
        return recipe; // Placeholder - needs actual Recipe.copyWith implementation
      }).toList();
    });

    AppLogger.info(
        '📋 Created imported menu with ${_getTotalRecipeCount(attributedMenu)} recipes and attribution');
    return attributedMenu;
  }

  @override
  Future<String?> saveImportedContent(Map<String, List<Recipe>> content) async {
    return await _saveMenu(content);
  }

  /// Create menu invitation using SharedMenu model
  Future<String?> createMenuInvitation({
    required String menuId,
    required List<String> inviteeUserIds,
    String? message,
    String? menuTitle,
    bool allowCollaboration = false,
  }) async {
    return await createInvitation(
      contentId: menuId,
      inviteeUserIds: inviteeUserIds,
      message: message,
      additionalData: {
        'menuTitle': menuTitle,
        'allowCollaboration': allowCollaboration,
      },
    );
  }

  /// Share menu with friends
  Future<bool> shareMenuWithFriends({
    required String menuId,
    required List<String> friendIds,
    String? message,
    String? menuTitle,
    bool allowCollaboration = false,
  }) async {
    return await shareWithFriends(
      contentId: menuId,
      friendIds: friendIds,
      message: message,
      additionalData: {
        'menuTitle': menuTitle,
        'allowCollaboration': allowCollaboration,
      },
    );
  }

  /// Join shared menu - creates a local copy for static menus
  /// For collaborative menus (with realtimeMenuId), joins the session.
  /// For static menus, creates an immediate copy (like GitHub fork).
  /// Returns a [MenuJoinResult] with the menu ID and whether it's collaborative.
  Future<MenuJoinResult?> joinSharedMenu({
    required String sharedMenuId,
    String? newTitle,
  }) async {
    try {
      // Get the shared menu to check if it's collaborative
      final sharedMenu = await _sharedMenuRepository.read(sharedMenuId);
      if (sharedMenu == null) {
        AppLogger.error('Shared menu not found: $sharedMenuId');
        return null;
      }

      // Check if this is a collaborative menu with a realtime session
      if (sharedMenu.realtimeMenuId != null) {
        AppLogger.info(
            '📡 Joining collaborative menu session: ${sharedMenu.realtimeMenuId}');

        // Add user as participant to the realtime menu (Bug fix: without this, the menu doesn't appear in saved menus)
        try {
          final realtimeMenuService = ServiceLocator.get<RealtimeMenuService>();
          await realtimeMenuService.addParticipant(
            resourceId: sharedMenu.realtimeMenuId!,
            userId: currentUserId!,
            userDisplayName: currentUserDisplayName ?? '?',
            permission: ResourcePermission.editor,
          );
          AppLogger.success('✅ Added user as participant to realtime menu');
        } catch (e) {
          AppLogger.error('Failed to add participant to realtime menu: $e');
          // Continue anyway - the user can still view the menu via shared link
        }

        // Mark as joined in the shared menu
        await _sharedMenuRepository.markAsImportedOrJoined(
            sharedMenuId, currentUserId!);
        AppLogger.success(
            '✅ Joined collaborative menu session: ${sharedMenu.realtimeMenuId}');
        return MenuJoinResult(
          menuId: sharedMenu.realtimeMenuId!,
          isCollaborative: true,
        );
      }

      // Static menu import - create an actual copy (like GitHub fork)
      AppLogger.info('📥 Importing static menu $sharedMenuId');

      // Use UnifiedMenuService.importSharedMenu for proper import with all data
      final menuService = ServiceLocator.get<UnifiedMenuService>();
      final importResult = await menuService.importSharedMenu(
        sharedMenuId: sharedMenuId,
        newTitle: newTitle,
      );

      if (importResult == null) {
        AppLogger.error('Failed to import menu via UnifiedMenuService');
        return null;
      }

      AppLogger.success('✅ Menu imported successfully: ${importResult.menuId}');

      return MenuJoinResult(
        menuId: importResult.menuId,
        isCollaborative: importResult.isCollaborative,
      );
    } catch (e) {
      // Auth-expired / permission-denied / offline → surface a sanitised
      // banner instead of letting the throw escape to the UI.
      AppLogger.error('Failed to join shared menu: $e');
      setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Trigger copy-on-write when user attempts to edit shared menu
  Future<String?> startCollaborativeMenuEditing({
    required String sharedMenuId,
  }) async {
    return await triggerCopyOnWrite(
      sharedContentId: sharedMenuId,
      editingUserId: currentUserId!,
    );
  }

  /// Legacy import method for backward compatibility (GitHub fork style)
  /// This maintains the old behavior for existing code that hasn't been updated
  /// to use the new copy-on-write pattern. Creates immediate copy with attribution.
  @Deprecated('Use joinSharedMenu for true copy-on-write behavior')
  Future<String?> importSharedMenu({
    required String sharedMenuId,
    String? newTitle,
  }) async {
    AppLogger.warning(
        '⚠️ Using legacy import mode - consider using joinSharedMenu for true copy-on-write');

    try {
      AppLogger.info('📥 Importing shared menu $sharedMenuId (legacy mode)');

      // Get shared menu
      final sharedMenu = await _sharedMenuRepository.read(sharedMenuId);
      if (sharedMenu == null) {
        AppLogger.error('Shared menu not found: $sharedMenuId');
        return null;
      }

      // Create imported menu with attribution (GitHub fork style)
      final importedMenu =
          sharedMenu.createImportMenu(newOwnerId: currentUserId!);

      // Save imported menu
      final menuId = await _saveMenu(importedMenu);
      if (menuId == null) {
        AppLogger.error('Failed to save imported menu');
        return null;
      }

      // Mark as imported in SharedMenu
      await _sharedMenuRepository.markAsImportedOrJoined(
          sharedMenuId, currentUserId!);

      AppLogger.success(
          '✅ Menu imported successfully with attribution (legacy mode)');
      return menuId;
    } catch (e) {
      // BUT-1124: surface failures through the shared error banner. Mirrors
      // the BUT-1094 fix on the non-legacy paths and the canonical pattern
      // in BaseSocialCoordinator. Legacy path is `@deprecated` but stays
      // active until removed, so silent swallows would mislead users.
      AppLogger.error('Failed to import shared menu: $e');
      setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Get menu invitations received by current user
  Future<List<SharedMenu>> getReceivedMenuInvitations() async {
    return await getReceivedInvitations();
  }

  /// Get all shared menus for a specific user
  /// Phase 3 Session 1: Content loading method for ViewModel migration.
  /// Wraps repository call with error handling and logging.
  Future<List<SharedMenu>> getSharedMenusForUser(String userId) async {
    try {
      AppLogger.info('📥 Loading shared menus for user ${userId.maskedUserId}');
      return await _sharedMenuRepository.getSharedContentForUser(userId);
    } catch (e) {
      // BUT-1094: surface inbox-load failures via the shared error banner.
      AppLogger.error(
          'Failed to load shared menus for user ${userId.maskedUserId}', e);
      setError(sanitizeErrorForUser(e));
      return [];
    }
  }

  /// Get specific shared menu by ID
  /// Week 2 Task 1 Completion: Menu fetching method for View/ViewModel access.
  /// Wraps repository read call with error handling and logging.
  /// Used for deep links and view operations where we need the full menu object.
  Future<SharedMenu?> getSharedMenuById(String menuId) async {
    try {
      AppLogger.info('📥 Loading shared menu by ID: $menuId');
      return await _sharedMenuRepository.read(menuId);
    } catch (e) {
      // BUT-1094: surface deep-link load failures consistently.
      AppLogger.error('Failed to load shared menu $menuId', e);
      setError(sanitizeErrorForUser(e));
      return null;
    }
  }

  /// Clear all status caches
  /// Call this before reloading menus to ensure fresh dismissal/viewed/imported status.
  /// Bug fix: Prevents stale cached values from causing dismissed menus to reappear.
  void clearStatusCache() {
    _viewedStatusCache.clear();
    _importedStatusCache.clear();
    _dismissedStatusCache.clear();
    AppLogger.info('🗑️ Cleared menu status caches');
  }

  /// Load status for a menu from repository and cache it
  /// Phase 3 Session 2: Status caching method for ViewModel migration.
  /// Loads viewed, imported, and dismissed status from repository and caches locally.
  Future<void> loadStatusForMenu(String menuId, String userId) async {
    try {
      final results = await Future.wait([
        _sharedMenuRepository.hasViewed(menuId, userId),
        _sharedMenuRepository.hasEngaged(menuId, userId),
        _sharedMenuRepository.hasDismissed(menuId, userId),
      ]);
      _viewedStatusCache[menuId] = results[0];
      _importedStatusCache[menuId] = results[1];
      _dismissedStatusCache[menuId] = results[2];
    } catch (e) {
      AppLogger.error('Failed to load status for menu $menuId', e);
    }
  }

  /// Load status for all menus in bulk
  /// Phase 3 Session 2: Bulk status loading method for ViewModel migration.
  /// Loads status for multiple menus to populate cache efficiently.
  Future<void> loadStatusForAllMenus(
      List<SharedMenu> menus, String userId) async {
    const batchSize = 5;
    for (var i = 0; i < menus.length; i += batchSize) {
      final end = (i + batchSize < menus.length) ? i + batchSize : menus.length;
      final batch = menus.sublist(i, end);
      await Future.wait(
        batch.map((menu) => loadStatusForMenu(menu.id, userId)),
      );
    }
  }

  /// Check if menu is dismissed using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isMenuDismissed(String menuId) {
    return _dismissedStatusCache[menuId] ?? false;
  }

  /// Check if menu is viewed using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isMenuViewed(String menuId) {
    return _viewedStatusCache[menuId] ?? false;
  }

  void setViewedStatus(String menuId, bool viewed) {
    _viewedStatusCache[menuId] = viewed;
  }

  /// Check if menu is imported using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isMenuImported(String menuId) {
    return _importedStatusCache[menuId] ?? false;
  }

  /// Dismiss shared menu from user's list
  Future<bool> dismissSharedMenu(String sharedMenuId) async {
    return await dismissSharedContent(sharedMenuId);
  }

  /// Restore dismissed shared menu
  Future<bool> restoreSharedMenu(String sharedMenuId) async {
    return await restoreSharedContent(sharedMenuId);
  }

  /// Mark shared menu as viewed
  Future<bool> markMenuAsViewed(String sharedMenuId) async {
    return await markAsViewed(sharedMenuId);
  }

  /// Get unread menu invitation count
  Future<int> getUnreadMenuCount() async {
    return await getUnreadCount();
  }

  /// Validate menu content for sharing
  bool validateMenuForSharing(Map<String, List<Recipe>> menu) {
    if (menu.isEmpty) {
      AppLogger.warning('Cannot share empty menu');
      return false;
    }

    final totalRecipes = _getTotalRecipeCount(menu);
    if (totalRecipes == 0) {
      AppLogger.warning('Cannot share menu with no recipes');
      return false;
    }

    // Validate that all recipes have required fields
    for (final entry in menu.entries) {
      for (final recipe in entry.value) {
        if (recipe.title.isEmpty) {
          AppLogger.warning('Cannot share menu with unnamed recipes');
          return false;
        }
      }
    }

    return true;
  }

  /// Get menu summary for display
  String getMenuSummary(Map<String, List<Recipe>> menu) {
    if (menu.isEmpty) return AppLocale.current.labelEmptyMenu;

    final parts = <String>[];
    menu.forEach((category, recipes) {
      if (recipes.isNotEmpty) {
        parts.add('${recipes.length} ${category.toLowerCase()}');
      }
    });

    return parts.isEmpty ? AppLocale.current.labelEmptyMenu : parts.join(', ');
  }

  /// Get total recipe count in menu
  int _getTotalRecipeCount(Map<String, List<Recipe>> menu) {
    return menu.values.fold(0, (sum, recipes) => sum + recipes.length);
  }

  @override
  Map<String, List<Recipe>> getOriginalContentFromShared(
      SharedMenu sharedContent) {
    return sharedContent.menuSnapshot;
  }

  @override
  Future<String?> createStaticCopyForOwner(
      dynamic originalContent, String ownerId) async {
    final menu = originalContent as Map<String, List<Recipe>>;

    // Add "(Min kopia)" suffix to indicate owner's static copy
    final staticMenu = <String, List<Recipe>>{};
    menu.forEach((category, recipes) {
      staticMenu['$category (Min kopia)'] = recipes.map((recipe) {
        return recipe.copyWith(
          title: '${recipe.title} (Min kopia)',
          lastCookedAt: null, // Reset cooking history for static copy
        );
      }).toList();
    });

    return await _saveMenu(staticMenu);
  }

  @override
  String getSharedByUserId(SharedMenu sharedContent) {
    return sharedContent.sharedByUserId;
  }

  @override
  SharedMenu? triggerCopyOnWriteForContent({
    required SharedMenu sharedContent,
    required String editingUserId,
    required String staticCopyId,
  }) {
    return sharedContent.triggerCopyOnWrite(
      editingUserId: editingUserId,
      staticCopyId: staticCopyId,
    );
  }

  @override
  Future<void> updateSharedContent(SharedMenu sharedContent) async {
    await _sharedMenuRepository.update(sharedContent);
  }

  /// Send menu invitation notifications
  Future<void> sendMenuInvitationNotifications(
      String menuId, List<String> inviteeUserIds) async {
    await sendInvitationNotifications(menuId, inviteeUserIds);
  }

  /// Send menu sharing notifications
  Future<void> sendMenuSharingNotifications(
      String menuId, List<String> sharedWithUserIds) async {
    await sendSharingNotifications(menuId, sharedWithUserIds);
  }
}
