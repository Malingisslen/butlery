// lib/services/realtime/realtime_menu_service.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

// Focused modules
import 'package:butlery/services/realtime/modules/menu_operations.dart';
import 'package:butlery/services/realtime/modules/menu_participants.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Clean facade for realtime menu management using focused modules
///
/// This facade provides a unified API that delegates to focused modules:
/// - MenuOperations: Menu content management (categories, recipes, basic info)
/// - MenuParticipants: Participant management (adding, removing, permissions)
///
/// ❌ DOES NOT CONTAIN: Complex business logic, direct implementation details
class RealtimeMenuService extends ChangeNotifier with StreamManagementMixin {
  final RealtimeSyncService _syncService;
  final AuthService _authService;

  // State management
  bool _isProcessing = false;
  MenuOperationError? _lastError;
  RealtimeMenu? _currentMenu; // Cache for current menu

  RealtimeMenuService({
    required RealtimeSyncService syncService,
    required AuthService authService,
  })  : _syncService = syncService,
        _authService = authService;

  /// Is menu operation in progress?
  bool get isProcessing => _isProcessing;
  /// Latest menu operation error
  MenuOperationError? get lastError => _lastError;
  /// Current user ID
  String? get _currentUserId => _authService.currentUserId;
  /// Current user display name
  String get _currentUserDisplayName =>
      ServiceLocator.get<PermissionService>().currentUser?.displayName ?? 'Okänd användare';
  /// Get category names from current menu
  List<String> get categoryNames => _currentMenu?.categories ?? [];

  /// Create realtime menu from existing category menu
  Future<RealtimeMenu> createRealtimeMenu({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    DateTime? createdForDate,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw MenuOperationError(
        operation: MenuOperationType.createFromExisting,
        message: 'Användare inte inloggad',
      );
    }

    _setProcessing(true);
    _clearError();
    try {
      AppLogger.info('📅 Skapar realtidsmeny: $menuTitle');
      // Create RealtimeMenu from category data
      final realtimeMenu = RealtimeMenu.fromMenuCategories(
        menuTitle: menuTitle,
        menuSnapshot: menuSnapshot,
        ownerId: userId,
        ownerDisplayName: _currentUserDisplayName,
        editorUserIds: editorUserIds,
        viewerUserIds: viewerUserIds,
        menuNotes: menuNotes,
        favoriteRecipeIds: favoriteRecipeIds,
        originalPrompt: originalPrompt,
        createdForDate: createdForDate,
      );
      // Use RealtimeSyncService for saving (SRP - delegate synchronization)
      await _syncService.updateResource(realtimeMenu);
      // Cache the menu
      _currentMenu = realtimeMenu;
      AppLogger.success('✅ Realtidsmeny skapad: ${realtimeMenu.id}');
      return realtimeMenu;
    } catch (e) {
      _handleError(
        MenuOperationType.createFromExisting,
        'Kunde inte skapa realtidsmeny: $e',
        originalError: e,
      );
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Watch realtime menu with live updates
  Stream<RealtimeMenu> watchRealtimeMenu(String resourceId) {
    AppLogger.info('👀 Startar watching av realtidsmeny: $resourceId');
    try {
      return _syncService.watchResource<RealtimeMenu>(resourceId).map((menu) {
        // Cache the menu for later use
        _currentMenu = menu;
        return menu;
      });
    } catch (e) {
      _handleError(
        MenuOperationType.createFromExisting, // Generic operation
        'Kunde inte starta watching av meny: $e',
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }

  /// Update basic menu information
  Future<void> updateBasicInfo({
    required String resourceId,
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.updateBasicInfo,
      operationName: 'uppdatera grundinfo',
      updateFunction: (menu) => MenuOperations.updateBasicInfo(
        menu,
        menuTitle: menuTitle,
        createdForDate: createdForDate,
        menuNotes: menuNotes,
        favoriteRecipeIds: favoriteRecipeIds,
        originalPrompt: originalPrompt,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Add recipe to specific category
  Future<void> addRecipeToCategory({
    required String resourceId,
    required String categoryName,
    required Recipe recipe,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.addRecipeToCategory,
      operationName: 'lägga till recept i $categoryName',
      updateFunction: (menu) => MenuOperations.addRecipeToCategory(
        menu,
        categoryName: categoryName,
        recipe: recipe,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Remove recipe from specific category
  Future<void> removeRecipeFromCategory({
    required String resourceId,
    required String categoryName,
    required int recipeIndex,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.removeRecipeFromCategory,
      operationName: 'ta bort recept från $categoryName',
      updateFunction: (menu) => MenuOperations.removeRecipeFromCategory(
        menu,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Move recipe between categories
  Future<void> moveRecipeBetweenCategories({
    required String resourceId,
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.moveRecipeBetweenCategories,
      operationName: 'flytta recept från $fromCategory till $toCategory',
      updateFunction: (menu) => MenuOperations.moveRecipeBetweenCategories(
        menu,
        fromCategory: fromCategory,
        fromIndex: fromIndex,
        toCategory: toCategory,
        toIndex: toIndex,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Replace recipe in specific category and position
  Future<void> replaceRecipeInCategory({
    required String resourceId,
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.replaceRecipeInCategory,
      operationName: 'ersätta recept i $categoryName',
      updateFunction: (menu) => MenuOperations.replaceRecipeInCategory(
        menu,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        newRecipe: newRecipe,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Clear entire category
  Future<void> clearCategory({
    required String resourceId,
    required String categoryName,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.clearCategory,
      operationName: 'rensa $categoryName',
      updateFunction: (menu) => MenuOperations.clearCategory(
        menu,
        categoryName: categoryName,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Update entire category with new recipes
  Future<void> updateWholeCategory({
    required String resourceId,
    required String categoryName,
    required List<Recipe> recipes,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.updateWholeCategory,
      operationName: 'uppdatera hela $categoryName',
      updateFunction: (menu) => MenuOperations.updateWholeCategory(
        menu,
        categoryName: categoryName,
        recipes: recipes,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Regenerate category with new AI-generated recipes
  Future<void> regenerateCategory({
    required String resourceId,
    required String categoryName,
    required List<Recipe> newRecipes,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.regenerateCategory,
      operationName: 'regenerera $categoryName',
      updateFunction: (menu) => MenuOperations.regenerateCategory(
        menu,
        categoryName: categoryName,
        newRecipes: newRecipes,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Add participant to realtime menu
  Future<void> addParticipant({
    required String resourceId,
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.addParticipant,
      operationName: 'lägga till deltagare',
      updateFunction: (menu) => MenuParticipants.addParticipant(
        menu,
        userId: userId,
        userDisplayName: userDisplayName,
        permission: permission,
      ),
    );
  }

  /// Remove participant from realtime menu
  Future<void> removeParticipant({
    required String resourceId,
    required String userId,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.removeParticipant,
      operationName: 'ta bort deltagare',
      updateFunction: (menu) => MenuParticipants.removeParticipant(
        menu,
        userId: userId,
      ),
    );
  }

  /// Update participant permission
  Future<void> updateParticipantPermission({
    required String resourceId,
    required String userId,
    required ResourcePermission newPermission,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.updatePermissions,
      operationName: 'uppdatera behörighet',
      updateFunction: (menu) => MenuParticipants.updateParticipantPermission(
        menu,
        userId: userId,
        newPermission: newPermission,
      ),
    );
  }

  /// Create personal copy of realtime menu
  Map<String, List<Recipe>> createPersonalCopy(RealtimeMenu realtimeMenu) {
    final userId = _currentUserId;
    if (userId == null) {
      throw MenuOperationError(
        operation: MenuOperationType.createFromExisting,
        message: 'Användare inte inloggad',
        resourceId: realtimeMenu.id,
      );
    }

    return MenuOperations.createPersonalCopy(realtimeMenu);
  }

  /// Check if menu has changed since timestamp
  bool hasMenuChangedSince(RealtimeMenu menu, DateTime timestamp) {
    return MenuOperations.hasMenuChangedSince(menu, timestamp);
  }

  /// Get summary of recent changes
  String getMenuChangesSummary(RealtimeMenu menu) {
    return MenuOperations.getMenuChangesSummary(menu);
  }

  /// Generic method for performing menu operations with error handling
  Future<void> _performMenuOperation({
    required String resourceId,
    required MenuOperationType operation,
    required String operationName,
    required RealtimeMenu Function(RealtimeMenu) updateFunction,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw MenuOperationError(
        operation: operation,
        message: 'Användare inte inloggad',
        resourceId: resourceId,
      );
    }
    _setProcessing(true);
    _clearError();
    try {
      AppLogger.info('🔄 $operationName för meny: $resourceId');
      // Get current menu from cache or Firebase
      final currentMenu = _currentMenu ??
          _syncService.getCachedResource<RealtimeMenu>(resourceId);
      if (currentMenu == null) {
        throw MenuOperationError(
          operation: operation,
          message: 'Menyn hittades inte',
          resourceId: resourceId,
        );
      }
      // Check permission (from model, not business logic here)
      if (!MenuParticipants.canUserEdit(currentMenu, userId)) {
        throw MenuOperationError(
          operation: operation,
          message: 'Ingen redigeringsbehörighet',
          resourceId: resourceId,
        );
      }
      // Perform update
      final updatedMenu = updateFunction(currentMenu);
      // Use RealtimeSyncService for synchronization (SRP)
      await _syncService.updateResource(updatedMenu);
      // Update cache
      _currentMenu = updatedMenu;
      AppLogger.success('✅ $operationName slutförd för: $resourceId');
    } catch (e) {
      _handleError(operation, 'Kunde inte $operationName: $e',
          resourceId: resourceId, originalError: e);
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  /// Delete realtime menu completely
  Future<void> deleteRealtimeMenu(String resourceId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw MenuOperationError(
        operation: MenuOperationType.removeParticipant, // Closest operation
        message: 'Användare inte inloggad',
        resourceId: resourceId,
      );
    }
    AppLogger.info('🗑️ Tar bort realtidsmeny: $resourceId');
    try {
      // Delegate to RealtimeSyncService (SRP) - Use menu type
      await _syncService.deleteResource(resourceId, RealtimeResourceType.menu);

      // Clear cache
      _currentMenu = null;

      AppLogger.success('✅ Realtidsmeny borttaget: $resourceId');
    } catch (e) {
      _handleError(
        MenuOperationType.removeParticipant, // Closest operation
        'Kunde inte ta bort realtidsmeny: $e',
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }

  /// Set processing state
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// Handle error
  void _handleError(
    MenuOperationType operation,
    String message, {
    String? resourceId,
    String? categoryName,
    dynamic originalError,
  }) {
    _lastError = MenuOperationError(
      operation: operation,
      message: message,
      resourceId: resourceId,
      categoryName: categoryName,
      originalError: originalError,
    );

    AppLogger.error('🔥 MenuOperationError: $message', originalError);
    notifyListeners();
  }

  /// Clear error
  void _clearError() {
    _lastError = null;
  }

  /// Clear error status (public method)
  void clearError() {
    _clearError();
    notifyListeners();
  }
  @override
  void dispose() {
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
