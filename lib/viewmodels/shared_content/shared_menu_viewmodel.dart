/// Shared Menu ViewModel providing menu-specific shared content management.
///
/// This specialized ViewModel handles all shared menu operations including loading,
/// importing, dismissing, and copy-on-write collaboration. It extends the base shared
/// content ViewModel to provide menu-specific functionality while maintaining
/// consistent patterns with other content types.
///
/// **Responsibilities:**
/// - **Menu Loading**: Load shared menus from repository with proper filtering
/// - **Import Operations**: Handle menu import with copy-on-write support
/// - **Status Management**: Track read/unread status and dismissal state
/// - **Collaboration**: Support copy-on-write collaboration for shared menus
/// - **Search Integration**: Implement menu-specific search functionality
///
/// **Integration Points:**
/// - **SocialMenuCoordinator**: For invitation and sharing operations
/// - **FirebaseSharedMenuRepository**: For data persistence and retrieval
/// - **SharedMenu Model**: With full copy-on-write support
///
/// **Usage Example:**
/// ```dart
/// final menuViewModel = SharedMenuViewModel();
/// await menuViewModel.loadContent();
/// 
/// // Search functionality
/// menuViewModel.updateSearchQuery('veckomeny');
/// final searchResults = menuViewModel.filteredContent;
/// 
/// // Menu operations
/// await menuViewModel.importSharedMenu(sharedMenu);
/// await menuViewModel.dismissSharedMenu(sharedMenu);
/// 
/// // Copy-on-write collaboration
/// await menuViewModel.joinSharedMenu(sharedMenu);
/// ```

// lib/viewmodels/shared_content/shared_menu_viewmodel.dart

import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/viewmodels/shared_content/base_shared_content_viewmodel.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized ViewModel for shared menu management and operations.
class SharedMenuViewModel extends BaseSharedContentViewModel<SharedMenu> {
  
  // ===== DEPENDENCIES =====
  
  late final FirebaseSharedMenuRepository _sharedMenuRepository;
  late final SocialMenuCoordinator _socialMenuCoordinator;

  // ===== CONSTRUCTOR =====
  
  SharedMenuViewModel({
    FirebaseSharedMenuRepository? sharedMenuRepository,
    SocialMenuCoordinator? socialMenuCoordinator,
  }) {
    _sharedMenuRepository = sharedMenuRepository ?? FirebaseSharedMenuRepository();
    _socialMenuCoordinator = socialMenuCoordinator ?? ServiceLocator.get<SocialMenuCoordinator>();
    
    AppLogger.info('SharedMenuViewModel initialized with copy-on-write support');
  }

  // ===== BASE CLASS IMPLEMENTATIONS =====
  
  @override
  String get contentTypeName => 'menu';
  
  @override
  Future<List<SharedMenu>> loadContentFromRepository() async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }
    
    AppLogger.info('🔄 Loading shared menus from repository for user: $userId');
    final menus = await _sharedMenuRepository.getSharedMenusForUser(userId);
    
    // Filter out dismissed menus for main content view
    final visibleMenus = menus.where((menu) => !menu.isDismissedBy(userId)).toList();
    
    AppLogger.info('✅ Loaded ${menus.length} shared menus (${visibleMenus.length} visible)');
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
           content.categories.any((category) => category.toLowerCase().contains(query)) ||
           (content.shareMessage?.toLowerCase().contains(query) ?? false);
  }

  // ===== MENU-SPECIFIC GETTERS =====
  
  /// Get unread menus count
  int get unreadCount {
    final userId = currentUserId;
    if (userId == null) return 0;
    
    return content.where((menu) => !menu.isViewedBy(userId)).length;
  }
  
  /// Get menus shared by current user
  List<SharedMenu> get sharedByCurrentUser {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((menu) => menu.sharedByUserId == userId).toList();
  }
  
  /// Get menus that can be imported
  List<SharedMenu> get importableMenus {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((menu) => 
        !menu.isImportedBy(userId) && 
        menu.sharedByUserId != userId
    ).toList();
  }
  
  /// Get menus by recipe count
  List<SharedMenu> get menusWithContent {
    return content.where((menu) => menu.hasContent).toList();
  }
  
  /// Get total recipes across all menus
  int get totalRecipesInMenus {
    return content.fold(0, (sum, menu) => sum + menu.totalRecipeCount);
  }

  // ===== MENU OPERATIONS =====
  
  /// Import shared menu using copy-on-write pattern
  /// 
  /// For new copy-on-write behavior, this joins as viewer until first edit.
  /// For legacy compatibility, creates immediate copy with attribution.
  Future<String?> importSharedMenu(SharedMenu sharedMenu, {String? newTitle, bool legacyMode = false}) async {
    return await executeOperation(
      'Import menu "${getContentTitle(sharedMenu)}"',
      () async {
        if (legacyMode) {
          // Legacy GitHub fork-style import
          return await _socialMenuCoordinator.joinSharedMenu(
            sharedMenuId: sharedMenu.id,
            newTitle: newTitle,
          );
        } else {
          // New copy-on-write behavior - join as viewer
          return await _socialMenuCoordinator.joinSharedMenu(
            sharedMenuId: sharedMenu.id,
            newTitle: newTitle,
          );
        }
      },
    );
  }
  
  /// Start collaborative editing (triggers copy-on-write)
  /// 
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
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        await _sharedMenuRepository.markAsDismissed(sharedMenu.id, userId);
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
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        await _sharedMenuRepository.undismiss(sharedMenu.id, userId);
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
  Future<bool> markAsViewed(SharedMenu sharedMenu) async {
    final result = await executeOperation(
      'Mark menu as viewed "${getContentTitle(sharedMenu)}"',
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('No authenticated user');
        }
        
        // Check if already viewed to avoid unnecessary operations
        if (sharedMenu.isViewedBy(userId)) {
          return true;
        }
        
        await _sharedMenuRepository.markAsViewed(sharedMenu.id, userId);
        
        // Update local state
        final updatedMenu = sharedMenu.markViewedBy(userId);
        updateContent(sharedMenu, updatedMenu);
        
        return true;
      },
    );
    
    return result ?? false;
  }

  // ===== STATUS CHECKING METHODS =====
  
  /// Check if menu is viewed by current user
  bool isMenuViewed(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return menu.isViewedBy(userId);
  }
  
  /// Check if menu is imported by current user
  bool isMenuImported(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return menu.isImportedBy(userId);
  }
  
  /// Check if menu is dismissed by current user
  bool isMenuDismissed(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return menu.isDismissedBy(userId);
  }
  
  /// Check if menu can be edited by current user
  bool canEditMenu(SharedMenu menu) {
    final userId = currentUserId;
    if (userId == null) return false;
    return menu.canBeEditedBy(userId);
  }
  
  /// Check if menu is in collaborative mode
  bool isMenuCollaborative(SharedMenu menu) {
    return menu.isCollaborative;
  }

  // ===== MENU-SPECIFIC OPERATIONS =====
  
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
    if (menu.categories.isEmpty) return 'Inga kategorier';
    if (menu.categories.length == 1) return menu.categories.first;
    
    if (menu.categories.length <= 3) {
      return menu.categories.join(', ');
    } else {
      return '${menu.categories.take(2).join(', ')} och ${menu.categories.length - 2} till';
    }
  }

  // ===== BULK OPERATIONS =====
  
  /// Mark all menus as viewed
  Future<void> markAllAsViewed() async {
    final userId = currentUserId;
    if (userId == null) return;
    
    await executeOperation(
      'Mark all menus as viewed',
      () async {
        final unviewedMenus = content.where((menu) => !menu.isViewedBy(userId)).toList();
        
        for (final menu in unviewedMenus) {
          await _sharedMenuRepository.markAsViewed(menu.id, userId);
        }
        
        // Refresh content to update local state
        await loadContent();
      },
      useOperatingState: false, // Use loading state for bulk operations
    );
  }
  
  /// Get menus by sharing status
  List<SharedMenu> getMenusByStatus({
    bool? isViewed,
    bool? isImported, 
    bool? isDismissed,
  }) {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return content.where((menu) {
      if (isViewed != null && menu.isViewedBy(userId) != isViewed) return false;
      if (isImported != null && menu.isImportedBy(userId) != isImported) return false;
      if (isDismissed != null && menu.isDismissedBy(userId) != isDismissed) return false;
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

  // ===== ANALYTICS =====
  
  /// Get menu engagement statistics
  Map<String, int> getEngagementStats() {
    final userId = currentUserId;
    if (userId == null) return {};
    
    return {
      'total': content.length,
      'unread': content.where((m) => !m.isViewedBy(userId)).length,
      'imported': content.where((m) => m.isImportedBy(userId)).length,
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
    
    return Map.fromEntries(
      categoryCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
    );
  }
}