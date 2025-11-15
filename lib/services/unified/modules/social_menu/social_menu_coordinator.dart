/// Social Menu Coordinator implementing standardized coordination patterns.
///
/// This coordinator provides unified menu sharing and collaboration functionality
/// following the established pattern from SocialRecipeCoordinator. It uses the
/// BaseSocialCoordinator to provide consistent invitation system, import operations,
/// and notification coordination for menu content.
///
/// **Architecture Benefits:**
/// - **Consistent API**: Unified operations matching SocialRecipeCoordinator patterns
/// - **Standardized Coordination**: Common social coordination patterns across content types
/// - **Menu-Specific Logic**: Customized behavior for menu sharing and collaboration
/// - **Service Integration**: Seamless integration with UnifiedMenuService and focused services
///
/// **Menu Coordination Features:**
/// - **Menu Invitation System**: Swedish-style menu sharing with complete recipe snapshots
/// - **Copy-on-Write Import**: Fork-style menu import with proper attribution
/// - **Collaboration Support**: Team-based menu planning and editing capabilities
/// - **Analytics Integration**: Menu engagement tracking and user interaction metrics
///
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
/// 
/// // Create menu invitation
/// final invitationId = await menuCoordinator.createMenuInvitation(
///   menuId: 'menu_123',
///   inviteeUserIds: ['user1', 'user2'],
///   message: 'Min veckomeny för nästa vecka!',
/// );
/// 
/// // Import shared menu
/// final menuId = await menuCoordinator.importSharedMenu(
///   sharedMenuId: 'shared_menu_456',
///   newTitle: 'Min importerade veckomeny',
/// );
/// ```

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/services/unified/modules/social_coordination/base_social_coordinator.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Menu-specific service adapter for menu operations
class MenuServiceAdapter {
  final UnifiedMenuService _menuService;

  MenuServiceAdapter({UnifiedMenuService? menuService})
      : _menuService = menuService ?? ServiceLocator.get<UnifiedMenuService>();

  /// Get menu by ID from the unified menu service
  Future<Map<String, List<Recipe>>?> getMenuById(String menuId) async {
    try {
      // Implementation depends on how menus are stored in UnifiedMenuService
      // This is a placeholder - the actual implementation would need to be
      // coordinated with the UnifiedMenuService API
      AppLogger.info('📋 Getting menu by ID: $menuId (using $_menuService)');
      return null; // Placeholder - needs actual implementation
    } catch (e) {
      AppLogger.error('Failed to get menu by ID $menuId: $e');
      return null;
    }
  }

  /// Save menu using the unified menu service
  Future<String?> saveMenu(Map<String, List<Recipe>> menu) async {
    try {
      // Implementation depends on how menus are saved in UnifiedMenuService
      // This is a placeholder - the actual implementation would need to be
      // coordinated with the UnifiedMenuService API
      AppLogger.info('💾 Saving menu with ${_getMenuRecipeCount(menu)} recipes (using $_menuService)');
      return null; // Placeholder - needs actual implementation
    } catch (e) {
      AppLogger.error('Failed to save menu: $e');
      return null;
    }
  }

  /// Get total recipe count in menu for logging
  int _getMenuRecipeCount(Map<String, List<Recipe>> menu) {
    return menu.values.fold(0, (sum, recipes) => sum + recipes.length);
  }
}

/// Social Menu Coordinator extending BaseSocialCoordinator for consistent patterns
class SocialMenuCoordinator extends BaseSocialCoordinator<Map<String, List<Recipe>>, SharedMenu> {
  @override
  String get serviceName => 'SocialMenuCoordinator';

  // Menu-specific dependencies
  final MenuServiceAdapter _serviceAdapter;
  late final FirebaseSharedMenuRepository _sharedMenuRepository;
  final Future<Map<String, List<Recipe>>?> Function(String) _getMenu;
  final Future<String?> Function(Map<String, List<Recipe>>) _saveMenu;

  SocialMenuCoordinator({
    required super.getCurrentUserId,
    required super.getCurrentUserDisplayName,
    required super.setError,
    required super.notifyListeners,
    required Future<Map<String, List<Recipe>>?> Function(String) getMenu,
    required Future<String?> Function(Map<String, List<Recipe>>) saveMenu,
    JsonCacheHelper? cacheHelper,
    MenuServiceAdapter? serviceAdapter,
  })  : _serviceAdapter = serviceAdapter ?? MenuServiceAdapter(),
        _getMenu = getMenu,
        _saveMenu = saveMenu {
    
    // Initialize SharedMenu repository
    _sharedMenuRepository = FirebaseSharedMenuRepository();

    AppLogger.info('✅ SocialMenuCoordinator initialized for menu sharing and collaboration using $_serviceAdapter');
  }

  // ===== BASE SOCIAL COORDINATOR IMPLEMENTATIONS =====

  @override
  String get contentTypeName => 'menu';

  @override
  String getContentTitle(Map<String, List<Recipe>> content) {
    // Generate descriptive title from menu content
    final categories = content.keys.toList();
    final totalRecipes = content.values.fold(0, (sum, recipes) => sum + recipes.length);
    
    if (categories.isEmpty) return 'Tom meny';
    if (categories.length == 1) {
      return '${categories.first} meny ($totalRecipes recept)';
    }
    
    return 'Veckomeny med ${categories.join(', ')} ($totalRecipes recept)';
  }

  @override
  BaseSharedContentRepository<SharedMenu> get sharedRepository => _sharedMenuRepository;

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
    final menuTitle = additionalData?['menuTitle'] ?? getContentTitle(contentSnapshot);
    
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
    final importedMenu = Map<String, List<Recipe>>.from(sharedContent.menuSnapshot);
    
    // Add attribution information to each recipe
    final attributedMenu = <String, List<Recipe>>{};
    importedMenu.forEach((category, recipes) {
      attributedMenu[category] = recipes.map((recipe) {
        // Create copy of recipe with attribution (simplified for now)
        // Note: The actual copyWith implementation depends on Recipe model
        return recipe; // Placeholder - needs actual Recipe.copyWith implementation
      }).toList();
    });

    AppLogger.info('📋 Created imported menu with ${_getTotalRecipeCount(attributedMenu)} recipes and attribution');
    return attributedMenu;
  }

  @override
  Future<String?> saveImportedContent(Map<String, List<Recipe>> content) async {
    return await _saveMenu(content);
  }

  // ===== MENU-SPECIFIC INVITATION OPERATIONS =====

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

  /// Join shared menu for viewing (true copy-on-write collaboration)
  /// 
  /// This implements TRUE copy-on-write where users initially view the original
  /// menu until someone attempts to edit it, which triggers copy creation.
  Future<String?> joinSharedMenu({
    required String sharedMenuId,
    String? newTitle,
  }) async {
    final menuId = await importSharedContent(
      sharedContentId: sharedMenuId,
      newTitle: newTitle,
    );
    
    if (menuId != null) {
      AppLogger.success('✅ Joined shared menu as viewer (copy-on-write ready): $menuId');
    }
    
    return menuId;
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
  /// 
  /// This maintains the old behavior for existing code that hasn't been updated
  /// to use the new copy-on-write pattern. Creates immediate copy with attribution.
  @Deprecated('Use joinSharedMenu for true copy-on-write behavior')
  Future<String?> importSharedMenu({
    required String sharedMenuId,
    String? newTitle,
  }) async {
    AppLogger.warning('⚠️ Using legacy import mode - consider using joinSharedMenu for true copy-on-write');
    
    try {
      AppLogger.info('📥 Importing shared menu $sharedMenuId (legacy mode)');

      // Get shared menu
      final sharedMenu = await _sharedMenuRepository.read(sharedMenuId);
      if (sharedMenu == null) {
        AppLogger.error('Shared menu not found: $sharedMenuId');
        return null;
      }

      // Create imported menu with attribution (GitHub fork style)
      final importedMenu = sharedMenu.createImportMenu(newOwnerId: currentUserId!);
      
      // Save imported menu
      final menuId = await _serviceAdapter.saveMenu(importedMenu);
      if (menuId == null) {
        AppLogger.error('Failed to save imported menu');
        return null;
      }

      // Mark as imported in SharedMenu
      await _sharedMenuRepository.markAsImportedOrJoined(sharedMenuId, currentUserId!);

      AppLogger.success('✅ Menu imported successfully with attribution (legacy mode)');
      return menuId;
    } catch (e) {
      AppLogger.error('Failed to import shared menu: $e');
      return null;
    }
  }

  /// Get menu invitations received by current user
  Future<List<SharedMenu>> getReceivedMenuInvitations() async {
    return await getReceivedInvitations();
  }

  /// Get all shared menus for a specific user
  ///
  /// Phase 3 Session 1: Content loading method for ViewModel migration.
  /// Wraps repository call with error handling and logging.
  Future<List<SharedMenu>> getSharedMenusForUser(String userId) async {
    try {
      AppLogger.info('📥 Loading shared menus for user $userId');
      return await _sharedMenuRepository.getSharedContentForUser(userId);
    } catch (e) {
      AppLogger.error('Failed to load shared menus for user $userId', e);
      return [];
    }
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

  // ===== MENU-SPECIFIC OPERATIONS =====

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
    if (menu.isEmpty) return 'Tom meny';

    final parts = <String>[];
    menu.forEach((category, recipes) {
      if (recipes.isNotEmpty) {
        parts.add('${recipes.length} ${category.toLowerCase()}');
      }
    });

    return parts.isEmpty ? 'Tom meny' : parts.join(', ');
  }

  // ===== UTILITY METHODS =====

  /// Get total recipe count in menu
  int _getTotalRecipeCount(Map<String, List<Recipe>> menu) {
    return menu.values.fold(0, (sum, recipes) => sum + recipes.length);
  }

  // ===== COPY-ON-WRITE ABSTRACT METHOD IMPLEMENTATIONS =====

  @override
  Map<String, List<Recipe>> getOriginalContentFromShared(SharedMenu sharedContent) {
    return sharedContent.menuSnapshot;
  }

  @override
  Future<String?> createStaticCopyForOwner(dynamic originalContent, String ownerId) async {
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

  // ===== NOTIFICATION PLACEHOLDERS =====

  /// Send menu invitation notifications
  Future<void> sendMenuInvitationNotifications(String menuId, List<String> inviteeUserIds) async {
    await sendInvitationNotifications(menuId, inviteeUserIds);
  }

  /// Send menu sharing notifications
  Future<void> sendMenuSharingNotifications(String menuId, List<String> sharedWithUserIds) async {
    await sendSharingNotifications(menuId, sharedWithUserIds);
  }
}