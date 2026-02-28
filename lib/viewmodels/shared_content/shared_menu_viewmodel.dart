/// Shared Menu ViewModel providing menu-specific shared content management.
/// This specialized ViewModel handles all shared menu operations including loading,
/// importing, dismissing, and copy-on-write collaboration. It extends the base shared
/// content ViewModel to provide menu-specific functionality while maintaining
/// consistent patterns with other content types.
/// **Responsibilities:**
/// - **Menu Loading**: Load shared menus from repository with proper filtering
/// - **Import Operations**: Handle menu import with copy-on-write support
/// - **Status Management**: Track read/unread status and dismissal state
/// - **Collaboration**: Support copy-on-write collaboration for shared menus
/// - **Search Integration**: Implement menu-specific search functionality
/// **Integration Points:**
/// - **SocialMenuCoordinator**: For invitation and sharing operations
/// - **FirebaseSharedMenuRepository**: For data persistence and retrieval
/// - **SharedMenu Model**: With full copy-on-write support
/// **Usage Example:**
/// ```dart
/// final menuViewModel = SharedMenuViewModel();
/// await menuViewModel.loadContent();
/// // Search functionality
/// menuViewModel.updateSearchQuery('veckomeny');
/// final searchResults = menuViewModel.filteredContent;
/// // Menu operations
/// await menuViewModel.importSharedMenu(sharedMenu);
/// await menuViewModel.dismissSharedMenu(sharedMenu);
/// // Copy-on-write collaboration
/// await menuViewModel.joinSharedMenu(sharedMenu);
/// ```

// lib/viewmodels/shared_content/shared_menu_viewmodel.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/viewmodels/shared_content/base_shared_content_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized ViewModel for shared menu management and operations.
/// Note (Issue #014): Uses status caching for synchronous filtering/counting.
/// Status loaded from Firestore subcollections and cached for performance.
class SharedMenuViewModel extends BaseSharedContentViewModel<SharedMenu> {
  late final SocialMenuCoordinator _socialMenuCoordinator;
  SharedMenuViewModel({
    SocialMenuCoordinator? socialMenuCoordinator,
  }) {
    _socialMenuCoordinator =
        socialMenuCoordinator ?? ServiceLocator.get<SocialMenuCoordinator>();

    AppLogger.info(
        'SharedMenuViewModel initialized with copy-on-write support');
  }
  @override
  String get contentTypeName => 'menu';

  @override
  Future<List<SharedMenu>> loadContentFromRepository() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info(
        '🔄 Loading shared menus from coordinator for user: $userId');

    // Clear stale cache before loading fresh status from Firestore
    // Bug fix: Prevents dismissed menus from reappearing after navigation
    _socialMenuCoordinator.clearStatusCache();

    final menus = await _socialMenuCoordinator.getSharedMenusForUser(userId);

    // Load status for all menus to populate cache (Issue #014)
    await _socialMenuCoordinator.loadStatusForAllMenus(menus, userId);

    // Filter out dismissed menus and optionally imported menus for cleaner inbox
    final visibleMenus = menus
        .where((menu) =>
            !_socialMenuCoordinator.isMenuDismissed(menu.id) &&
            (showImported || !_socialMenuCoordinator.isMenuImported(menu.id)))
        .toList();

    AppLogger.info(
        '✅ Loaded ${menus.length} shared menus (${visibleMenus.length} visible)');
    return visibleMenus;
  }

  @override
  String getContentTitle(SharedMenu content) {
    return content.menuTitle;
  }

  @override
  bool contentMatchesSearch(SharedMenu content, String searchQuery) {
    final query = searchQuery.toLowerCase();

    return content.menuTitle.toLowerCase().contains(query) ||
        content.sharedByDisplayName.toLowerCase().contains(query) ||
        content.categories
            .any((category) => category.toLowerCase().contains(query)) ||
        (content.shareMessage?.toLowerCase().contains(query) ?? false);
  }

  @override
  Future<List<SharedMenu>> loadContentWithPagination({
    int limit = 25,
    Object? startAfter,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    AppLogger.info('🔄 Loading shared menus (pagination not used for MVP)');

    // Clear stale cache before loading fresh status from Firestore
    _socialMenuCoordinator.clearStatusCache();

    // Use existing coordinator method - pagination not needed for MVP
    final menus = await _socialMenuCoordinator.getSharedMenusForUser(userId);

    // Load status for all menus to populate cache
    await _socialMenuCoordinator.loadStatusForAllMenus(menus, userId);

    // Filter out dismissed menus and optionally imported menus for cleaner inbox
    final visibleMenus = menus
        .where((menu) =>
            !_socialMenuCoordinator.isMenuDismissed(menu.id) &&
            (showImported || !_socialMenuCoordinator.isMenuImported(menu.id)))
        .toList();

    AppLogger.info(
        '✅ Loaded ${menus.length} shared menus (${visibleMenus.length} visible, showImported: $showImported)');
    return visibleMenus;
  }

  @override
  Object? getLastDocumentFromContent(List<SharedMenu> content) {
    return null; // Will be enhanced when repository returns document snapshots
  }

  /// Get unread menus count (using cache - Issue #014)
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;

    return content
        .where((menu) =>
            !_socialMenuCoordinator.isMenuViewed(menu.id) &&
            (showImported || !_socialMenuCoordinator.isMenuImported(menu.id)))
        .length;
  }

  /// Get menus shared by current user
  List<SharedMenu> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((menu) => menu.sharedByUserId == userId).toList();
  }

  /// Get menus that can be imported (using cache - Issue #014)
  List<SharedMenu> get importableMenus {
    final userId = currentUserId;
    if (userId == null) return [];

    return content
        .where((menu) =>
            !_socialMenuCoordinator.isMenuImported(menu.id) &&
            menu.sharedByUserId != userId)
        .toList();
  }

  /// Get menus by recipe count
  List<SharedMenu> get menusWithContent {
    return content.where((menu) => menu.hasContent).toList();
  }

  /// Get total recipes across all menus
  int get totalRecipesInMenus {
    return content.fold(0, (total, menu) => total + menu.totalRecipeCount);
  }

  /// Import shared menu using copy-on-write pattern
  /// For new copy-on-write behavior, this joins as viewer until first edit.
  /// Returns a [MenuJoinResult] indicating if this is a collaborative menu.
  Future<MenuJoinResult?> importSharedMenu(SharedMenu sharedMenu,
      {String? newTitle}) async {
    // Use per-item operating state for individual loading spinner
    setItemOperating(sharedMenu.id, true);
    try {
      AppLogger.info(
          '🔄 Starting Import menu "${getContentTitle(sharedMenu)}" for menu...');
      final result = await _socialMenuCoordinator.joinSharedMenu(
        sharedMenuId: sharedMenu.id,
        newTitle: newTitle,
      );
      AppLogger.success(
          '✅ Import menu "${getContentTitle(sharedMenu)}" completed successfully');
      return result;
    } catch (e) {
      AppLogger.error(
          '❌ Import menu "${getContentTitle(sharedMenu)}" failed: $e');
      return null;
    } finally {
      setItemOperating(sharedMenu.id, false);
    }
  }

  /// Start collaborative editing (triggers copy-on-write)
  /// This method triggers copy-on-write when user attempts first edit.
  /// Creates static copy for original owner and enables collaboration.
  Future<String?> startCollaborativeEditing(SharedMenu sharedMenu) async {
    return await executeOperation(
      'Start collaborative editing for "${getContentTitle(sharedMenu)}"',
      () async {
        return await _socialMenuCoordinator.startCollaborativeMenuEditing(
          sharedMenuId: sharedMenu.id,
        );
      },
    );
  }

  /// Dismiss shared menu from user's list
  Future<bool> dismissSharedMenu(SharedMenu sharedMenu) async {
    final result = await executeOperation(
      'Dismiss menu "${getContentTitle(sharedMenu)}"',
      () async {
        await _socialMenuCoordinator.dismissSharedMenu(sharedMenu.id);
        return true;
      },
    );

    if (result == true) {
      // Remove from local collection
      removeContent(sharedMenu);
    }

    return result ?? false;
  }

  /// Restore dismissed menu to user's list
  Future<bool> undismissSharedMenu(SharedMenu sharedMenu) async {
    final result = await executeOperation(
      'Restore menu "${getContentTitle(sharedMenu)}"',
      () async {
        await _socialMenuCoordinator.restoreSharedMenu(sharedMenu.id);
        return true;
      },
    );

    if (result == true) {
      // Add back to local collection if not already present
      if (!content.any((m) => m.id == sharedMenu.id)) {
        addContent(sharedMenu);
      }
    }

    return result ?? false;
  }

  /// Mark menu as viewed/read
  /// Note (Issue #014): Updates cache instead of local model state.
  Future<bool> markAsViewed(SharedMenu sharedMenu) async {
    final result = await executeOperation(
      'Mark menu as viewed "${getContentTitle(sharedMenu)}"',
      () async {
        // Check if already viewed to avoid unnecessary operations (using cache)
        if (_socialMenuCoordinator.isMenuViewed(sharedMenu.id)) {
          return true;
        }

        await _socialMenuCoordinator.markMenuAsViewed(sharedMenu.id);

        // Reload status to update coordinator's cache (Issue #014)
        final userId = currentUserId;
        if (userId != null) {
          await _socialMenuCoordinator.loadStatusForMenu(sharedMenu.id, userId);
        }
        notifyListeners(); // Notify UI to refresh

        return true;
      },
    );

    return result ?? false;
  }

  /// Check if menu is viewed by current user (using cache - Issue #014)
  bool isMenuViewed(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _socialMenuCoordinator.isMenuViewed(menu.id);
  }

  /// Check if menu is imported by current user (using cache - Issue #014)
  bool isMenuImported(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _socialMenuCoordinator.isMenuImported(menu.id);
  }

  /// Check if menu is dismissed by current user (using cache - Issue #014)
  bool isMenuDismissed(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return _socialMenuCoordinator.isMenuDismissed(menu.id);
  }

  /// Check if menu can be edited by current user
  bool canEditMenu(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;

    // Owner can always edit
    if (menu.sharedByUserId == userId) return true;

    // Check if collaboration is allowed
    return menu.isCollaborative;
  }

  /// Check if menu is in collaborative mode
  bool isMenuCollaborative(SharedMenu menu) {
    return menu.isCollaborative;
  }

  /// Get menu summary for display
  String getMenuSummary(SharedMenu menu) {
    return menu.menuSummary; // Uses the model's built-in Swedish summary
  }

  /// Get time ago text for menu
  String getMenuTimeAgo(SharedMenu menu) {
    return menu.timeAgoText; // Uses the model's built-in Swedish time format
  }

  /// Get menu categories as display text
  String getMenuCategories(SharedMenu menu) {
    if (menu.categories.isEmpty) return AppLocale.current.labelNoCategories;
    if (menu.categories.length == 1) return menu.categories.first;

    if (menu.categories.length <= 3) {
      return menu.categories.join(', ');
    } else {
      return '${menu.categories.take(2).join(', ')} och ${menu.categories.length - 2} till';
    }
  }

  /// Mark all menus as viewed
  /// Note (Issue #014): Uses cache to identify unviewed menus, then updates cache after marking.
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;

    await executeOperation(
      'Mark all menus as viewed',
      () async {
        final unviewedMenus = content
            .where((menu) => !_socialMenuCoordinator.isMenuViewed(menu.id))
            .toList();

        for (final menu in unviewedMenus) {
          await _socialMenuCoordinator.markMenuAsViewed(menu.id);
          // Reload status to update coordinator's cache (Issue #014)
          await _socialMenuCoordinator.loadStatusForMenu(menu.id, userId);
        }

        // Notify UI to refresh
        notifyListeners();
      },
      useOperatingState: false, // Use loading state for bulk operations
    );
  }

  /// Get menus by sharing status (using cache - Issue #014)
  List<SharedMenu> getMenusByStatus({
    bool? isViewed,
    bool? isImported,
    bool? isDismissed,
  }) {
    final userId = currentUserId;
    if (userId == null) return [];

    return content.where((menu) {
      if (isViewed != null &&
          _socialMenuCoordinator.isMenuViewed(menu.id) != isViewed) {
        return false;
      }
      if (isImported != null &&
          _socialMenuCoordinator.isMenuImported(menu.id) != isImported) {
        return false;
      }
      if (isDismissed != null &&
          _socialMenuCoordinator.isMenuDismissed(menu.id) != isDismissed) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get menus by collaboration status
  List<SharedMenu> getMenusByCollaborationStatus({
    bool collaborativeOnly = false,
    bool originalReferenceOnly = false,
  }) {
    return content.where((menu) {
      if (collaborativeOnly && !menu.isCollaborative) return false;
      if (originalReferenceOnly && !menu.isOriginalReference) return false;
      return true;
    }).toList();
  }

  /// Get specific shared menu by ID
  /// Week 2 Task 1 Completion: Loads a single SharedMenu from the coordinator.
  /// Useful for deep links and view operations where we need the full menu object.
  Future<SharedMenu?> getSharedMenuById(String menuId) async {
    return await executeOperation(
      'Load shared menu $menuId',
      () async {
        return await _socialMenuCoordinator.getSharedMenuById(menuId);
      },
    );
  }

  /// Get menu engagement statistics (using cache - Issue #014)
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};

    return {
      'total': content.length,
      'unread': content
          .where((m) => !_socialMenuCoordinator.isMenuViewed(m.id))
          .length,
      'imported': content
          .where((m) => _socialMenuCoordinator.isMenuImported(m.id))
          .length,
      'collaborative': content.where((m) => m.isCollaborative).length,
      'sharedByMe': content.where((m) => m.sharedByUserId == userId).length,
      'totalRecipes': totalRecipesInMenus,
      'withContent': content.where((m) => m.hasContent).length,
    };
  }

  /// Get category distribution statistics
  Map<String, int> getCategoryStats() {
    final categoryCount = <String, int>{};

    for (final menu in content) {
      for (final category in menu.categories) {
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
    }

    return Map.fromEntries(categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)));
  }
}
