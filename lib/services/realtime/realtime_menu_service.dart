// lib/services/realtime/realtime_menu_service.dart

import 'package:flutter/foundation.dart';
import '../../models/realtime/realtime_menu.dart';
import '../../models/realtime/realtime_resource.dart';
import '../../models/recipe.dart';
import '../../models/permissions/resource_permission.dart';
import '../realtime_sync_service.dart';
import '../auth_service.dart';
import '../user_service.dart';
import '../../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Realtime Menu Service - UPPDATERAD för kategori-baserade menyer
/// File: services/realtime/realtime_menu_service.dart
/// Quick Guide: SINGLE RESPONSIBILITY - bara menu business logic för kategori-baserade realtidsmenyer
/// Dependencies IN: RealtimeSyncService, AuthService, UserService, realtime models
/// Dependencies OUT: RealtimeMenuViewModel, menu collaboration views
/// Data flow: Menu operations → RealtimeMenu updates → RealtimeSyncService → Firebase
/// State management: ChangeNotifier för menu-specific events
/// Purpose: SRP - bara menu operations för kategorier, delegerar synkronisering till RealtimeSyncService
/// Common issues: Category validation, recipe conflicts, concurrent editing
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Efficient category-based operations, cached user info
/// Analytics: Menu collaboration patterns, category usage frequency, family planning
/// Code smells: ✅ Clean delegation - bara menu logic, ingen synkronisering
/// Connected to: RealtimeSyncService, kategori-baserade menu models, collaborative views
/// Used in phases: Fas 3 (Menyer + Inköpslistor) - Category-specific real-time operations

/// Typ av menu-operationer för analytics och logging
enum MenuOperationType {
  createFromExisting,
  updateBasicInfo,
  addRecipeToCategory,
  removeRecipeFromCategory,
  moveRecipeBetweenCategories,
  replaceRecipeInCategory,
  clearCategory,
  updateWholeCategory,
  regenerateCategory,
  addParticipant,
  removeParticipant,
  updatePermissions,
}

/// Menu-specifika fel
class MenuOperationError {
  final MenuOperationType operation;
  final String message;
  final String? resourceId;
  final String? categoryName;
  final dynamic originalError;

  MenuOperationError({
    required this.operation,
    required this.message,
    this.resourceId,
    this.categoryName,
    this.originalError,
  });

  @override
  String toString() => 'MenuOperationError(${operation.name}): $message';
}

/// RealtimeMenuService - SINGLE RESPONSIBILITY: Kategori-baserade menu-operationer
///
/// Denna service hanterar BARA:
/// - Menu business logic för kategori-baserade realtidsmenyer
/// - Category-based recipe operations och validation
/// - Menu-specifika CRUD operationer
/// - User context för menu operations
///
/// Den hanterar INTE:
/// - Firebase synkronisering (det gör RealtimeSyncService)
/// - UI logic eller presentation
/// - Generic realtidsoperationer
/// - Permission management (det finns i modellerna)
class RealtimeMenuService extends ChangeNotifier {
  final RealtimeSyncService _syncService;
  final AuthService _authService;
  final UserService _userService;

  // State för menu-specifika operationer
  bool _isProcessing = false;
  MenuOperationError? _lastError;
  RealtimeMenu? _currentMenu; // Cache för current menu

  RealtimeMenuService({
    required RealtimeSyncService syncService,
    required AuthService authService,
    required UserService userService,
  })  : _syncService = syncService,
        _authService = authService,
        _userService = userService;

  // ===== GETTERS =====

  /// Pågår menu operation?
  bool get isProcessing => _isProcessing;

  /// Senaste menu operation error
  MenuOperationError? get lastError => _lastError;

  /// Aktuell användare
  String? get _currentUserId => _authService.currentUser?.uid;

  /// Aktuell användarens display name
  String get _currentUserDisplayName =>
      _userService.currentUserProfile?.displayName ?? 'Okänd användare';

  /// Få kategori-namn från aktuell meny
  List<String> get categoryNames => _currentMenu?.categories ?? [];

  // ===== CORE MENU OPERATIONS =====

  /// Skapa realtidsmeny från befintlig kategori-meny (från MenuViewModel)
  ///
  /// Tar en vanlig kategori-meny och gör den till en RealtimeMenu som kan delas
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

      // Skapa RealtimeMenu från kategori-data
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

      // Använd RealtimeSyncService för att spara (SRP - vi delegerar synkronisering)
      await _syncService.updateResource(realtimeMenu);

      // Cache menyn
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

  /// Titta på realtidsmeny med live updates
  ///
  /// Wrapper runt RealtimeSyncService.watchResource för type safety
  Stream<RealtimeMenu> watchRealtimeMenu(String resourceId) {
    AppLogger.info('👀 Startar watching av realtidsmeny: $resourceId');

    try {
      return _syncService.watchResource<RealtimeMenu>(resourceId).map((menu) {
        // Cache menyn för senare användning
        _currentMenu = menu;
        return menu;
      });
    } catch (e) {
      _handleError(
        MenuOperationType.createFromExisting, // Generisk operation
        'Kunde inte starta watching av meny: $e',
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }

  // ===== MENU CONTENT OPERATIONS =====

  /// Uppdatera grundläggande menyinformation
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
      updateFunction: (menu) => menu.updateBasicInfo(
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

  /// Lägg till recept till specifik kategori
  Future<void> addRecipeToCategory({
    required String resourceId,
    required String categoryName,
    required Recipe recipe,
  }) async {
    if (!_isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.addRecipeToCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: resourceId,
        categoryName: categoryName,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.addRecipeToCategory,
      operationName: 'lägga till recept i $categoryName',
      updateFunction: (menu) => menu.addRecipeToCategory(
        categoryName: categoryName,
        recipe: recipe,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Ta bort recept från specifik kategori
  Future<void> removeRecipeFromCategory({
    required String resourceId,
    required String categoryName,
    required int recipeIndex,
  }) async {
    if (!_isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.removeRecipeFromCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: resourceId,
        categoryName: categoryName,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.removeRecipeFromCategory,
      operationName: 'ta bort recept från $categoryName',
      updateFunction: (menu) => menu.removeRecipeFromCategory(
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Flytta recept mellan kategorier
  Future<void> moveRecipeBetweenCategories({
    required String resourceId,
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) async {
    if (!_isValidCategoryName(fromCategory) ||
        !_isValidCategoryName(toCategory)) {
      throw MenuOperationError(
        operation: MenuOperationType.moveRecipeBetweenCategories,
        message: 'Ogiltiga kategorinamn: $fromCategory -> $toCategory',
        resourceId: resourceId,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.moveRecipeBetweenCategories,
      operationName: 'flytta recept från $fromCategory till $toCategory',
      updateFunction: (menu) => menu.moveRecipeBetweenCategories(
        fromCategory: fromCategory,
        fromIndex: fromIndex,
        toCategory: toCategory,
        toIndex: toIndex,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Ersätt recept i specifik kategori och position
  Future<void> replaceRecipeInCategory({
    required String resourceId,
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
  }) async {
    if (!_isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.replaceRecipeInCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: resourceId,
        categoryName: categoryName,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.replaceRecipeInCategory,
      operationName: 'ersätta recept i $categoryName',
      updateFunction: (menu) => menu.replaceRecipeInCategory(
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        newRecipe: newRecipe,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Rensa hela kategorin
  Future<void> clearCategory({
    required String resourceId,
    required String categoryName,
  }) async {
    if (!_isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.clearCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: resourceId,
        categoryName: categoryName,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.clearCategory,
      operationName: 'rensa $categoryName',
      updateFunction: (menu) => menu.clearCategory(
        categoryName: categoryName,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Uppdatera hela kategorin med nya recept
  Future<void> updateWholeCategory({
    required String resourceId,
    required String categoryName,
    required List<Recipe> recipes,
  }) async {
    if (!_isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.updateWholeCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: resourceId,
        categoryName: categoryName,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.updateWholeCategory,
      operationName: 'uppdatera hela $categoryName',
      updateFunction: (menu) => menu.updateWholeCategory(
        categoryName: categoryName,
        recipes: recipes,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  /// Regenerera kategori med nya AI-genererade recept
  Future<void> regenerateCategory({
    required String resourceId,
    required String categoryName,
    required List<Recipe> newRecipes,
  }) async {
    if (!_isValidCategoryName(categoryName)) {
      throw MenuOperationError(
        operation: MenuOperationType.regenerateCategory,
        message: 'Ogiltigt kategorinamn: $categoryName',
        resourceId: resourceId,
        categoryName: categoryName,
      );
    }

    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.regenerateCategory,
      operationName: 'regenerera $categoryName',
      updateFunction: (menu) => menu.regenerateCategory(
        categoryName: categoryName,
        newRecipes: newRecipes,
        editedBy: _currentUserId!,
        editedByDisplayName: _currentUserDisplayName,
      ),
    );
  }

  // ===== PARTICIPANT MANAGEMENT =====

  /// Lägg till deltagare till realtidsmeny
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
      updateFunction: (menu) => menu.addParticipant(
        userId,
        userDisplayName,
        permission,
      ),
    );
  }

  /// Ta bort deltagare från realtidsmeny
  Future<void> removeParticipant({
    required String resourceId,
    required String userId,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.removeParticipant,
      operationName: 'ta bort deltagare',
      updateFunction: (menu) => menu.removeParticipant(userId),
    );
  }

  /// Uppdatera deltagares behörighet
  Future<void> updateParticipantPermission({
    required String resourceId,
    required String userId,
    required ResourcePermission newPermission,
  }) async {
    await _performMenuOperation(
      resourceId: resourceId,
      operation: MenuOperationType.updatePermissions,
      operationName: 'uppdatera behörighet',
      updateFunction: (menu) => menu.updateParticipantPermission(
        userId,
        newPermission,
      ),
    );
  }

  // ===== UTILITY METHODS =====

  /// Skapa personlig kopia av realtidsmeny
  ///
  /// Använder RealtimeMenu.createPersonalMenuCopy för att skapa vanlig meny
  Map<String, List<Recipe>> createPersonalCopy(RealtimeMenu realtimeMenu) {
    final userId = _currentUserId;
    if (userId == null) {
      throw MenuOperationError(
        operation: MenuOperationType.createFromExisting,
        message: 'Användare inte inloggad',
        resourceId: realtimeMenu.id,
      );
    }

    AppLogger.info('📋 Skapar personlig kopia av: ${realtimeMenu.menuTitle}');

    return realtimeMenu.createPersonalMenuCopy();
  }

  /// Kontrollera om menyn har ändrats sedan tidpunkt
  bool hasMenuChangedSince(RealtimeMenu menu, DateTime timestamp) {
    return menu.hasChangedSince(timestamp);
  }

  /// Få sammanfattning av senaste ändringar
  String getMenuChangesSummary(RealtimeMenu menu) {
    return menu.getChangesSummary();
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Validera kategorinamn
  bool _isValidCategoryName(String categoryName) {
    // Acceptera alla icke-tomma kategorier (flexibelt system)
    return categoryName.trim().isNotEmpty;
  }

  /// Generisk metod för att utföra menu-operationer med error handling
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

      // Hämta nuvarande meny från cache eller Firebase
      final currentMenu = _currentMenu ??
          _syncService.getCachedResource<RealtimeMenu>(resourceId);

      if (currentMenu == null) {
        throw MenuOperationError(
          operation: operation,
          message: 'Menyn hittades inte',
          resourceId: resourceId,
        );
      }

      // Kontrollera behörighet (från modellen, inte business logic här)
      if (!currentMenu.canUserEdit(userId)) {
        throw MenuOperationError(
          operation: operation,
          message: 'Ingen redigeringsbehörighet',
          resourceId: resourceId,
        );
      }

      // Utför uppdatering
      final updatedMenu = updateFunction(currentMenu);

      // Använd RealtimeSyncService för synkronisering (SRP)
      await _syncService.updateResource(updatedMenu);

      // Uppdatera cache
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

  /// Sätt processing state
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// Hantera fel
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

  /// Rensa fel
  void _clearError() {
    _lastError = null;
  }

  // ===== PUBLIC UTILITY METHODS =====

  /// Rensa felstatus
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Ta bort realtidsmeny helt
  Future<void> deleteRealtimeMenu(String resourceId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw MenuOperationError(
        operation: MenuOperationType.removeParticipant, // Närmaste operation
        message: 'Användare inte inloggad',
        resourceId: resourceId,
      );
    }

    AppLogger.info('🗑️ Tar bort realtidsmeny: $resourceId');

    try {
      // Delegera till RealtimeSyncService (SRP) - Använd menu type
      await _syncService.deleteResource(resourceId, RealtimeResourceType.menu);

      // Rensa cache
      _currentMenu = null;

      AppLogger.success('✅ Realtidsmeny borttaget: $resourceId');
    } catch (e) {
      _handleError(
        MenuOperationType.removeParticipant, // Närmaste operation
        'Kunde inte ta bort realtidsmeny: $e',
        resourceId: resourceId,
        originalError: e,
      );
      rethrow;
    }
  }
}
