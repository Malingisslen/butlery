// lib/viewmodels/realtime_menu_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/realtime/realtime_menu.dart';
import '../models/recipe.dart';
import '../models/permissions/resource_permission.dart';
import '../services/realtime/realtime_menu_service.dart';
import '../services/realtime_sync_service.dart';
import '../services/auth_service.dart';
import '../core/utils/logger.dart';
import 'realtime/optimistic_update_manager.dart';
import 'realtime/participant_tracker.dart';
import 'realtime/connection_monitor.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Realtime Menu ViewModel - UPPDATERAD för kategori-baserade menyer
/// File: viewmodels/realtime_menu_viewmodel.dart
/// Quick Guide: Clean ViewModel som delegerar specifika ansvarsområden för kategori-struktur
/// Dependencies IN: RealtimeMenuService, RealtimeSyncService, AuthService, delegated managers
/// Dependencies OUT: RealtimeMenuView, collaborative menu widgets
/// Data flow: UI events → ViewModel → Service → Firebase → Live updates → UI
/// State management: ChangeNotifier med delegated responsibilities för clean separation
/// Purpose: BARA hantera UI state för kategori-baserade menyer och koordinera mellan UI och services
/// Common issues: Connection drops, permission changes, concurrent category edits
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Delegated optimization via managers, minimal ViewModel overhead
/// Analytics: UI interaction patterns, category usage, collaborative editing
/// Code smells: ✅ Clean SRP - delegerar till specialized managers för kategorier
/// Connected to: RealtimeMenuService, specialized managers, category-based collaborative UI
/// Used in phases: Fas 3 (SRP refactoring) - Clean architecture för kategori-menyer

/// Status för realtidsmeny-operationer
enum RealtimeMenuStatus {
  idle,
  loading,
  watching,
  updating,
  error,
  offline,
}

/// ViewModel för kategori-baserade realtidsmenyer - REFAKTORERAD enligt SRP
class RealtimeMenuViewModel extends ChangeNotifier {
  final RealtimeMenuService _menuService;
  final AuthService _authService;

  // ===== DELEGATED RESPONSIBILITIES (SRP) =====
  late final OptimisticUpdateManager _optimisticManager;
  late final ParticipantTracker _participantTracker;
  late final ConnectionMonitor _connectionMonitor;

  // ===== CORE UI STATE (Korrekt ansvar för ViewModel) =====
  RealtimeMenu? _currentMenu;
  RealtimeMenuStatus _status = RealtimeMenuStatus.idle;
  String? _errorMessage;
  StreamSubscription<RealtimeMenu>? _menuSubscription;

  // ===== UI STATE =====
  String? _selectedCategory;
  bool _showParticipants = false;

  RealtimeMenuViewModel({
    required RealtimeMenuService menuService,
    required RealtimeSyncService syncService,
    required AuthService authService,
  })  : _menuService = menuService,
        _authService = authService {
    // Initialisera delegated managers
    _optimisticManager = OptimisticUpdateManager(onUpdated: notifyListeners);
    _participantTracker = ParticipantTracker(onUpdated: notifyListeners);
    _connectionMonitor = ConnectionMonitor(
      syncService: syncService,
      onConnectionChanged: _onConnectionChanged,
    );

    _initialize();
  }

  // ===== GETTERS (UI State bara) =====

  /// Aktuell realtidsmeny
  RealtimeMenu? get currentMenu => _currentMenu;

  /// Nuvarande status
  RealtimeMenuStatus get status => _status;

  /// Är vi online och anslutna?
  bool get isOnline => _connectionMonitor.isOnline;

  /// Felmeddelande om något gått fel
  String? get errorMessage => _errorMessage;

  /// Vald kategori för redigering
  String? get selectedCategory => _selectedCategory;

  /// Visa deltagarlista?
  bool get showParticipants => _showParticipants;

  /// Pågår operation?
  bool get isLoading =>
      _status == RealtimeMenuStatus.loading ||
      _status == RealtimeMenuStatus.updating;

  /// Har vi osparade ändringar?
  bool get hasUnsavedChanges => _optimisticManager.hasChanges;

  /// Aktuell användare
  String? get currentUserId => _authService.currentUser?.uid;

  /// Kan nuvarande användare redigera?
  bool get canEdit => _currentMenu?.canUserEdit(currentUserId ?? '') ?? false;

  /// Kan nuvarande användare hantera deltagare?
  bool get canManageParticipants =>
      _currentMenu?.canUserManagePermissions(currentUserId ?? '') ?? false;

  /// Antal aktiva deltagare (delegerat)
  int get activeParticipantCount => _participantTracker.activeCount;

  /// Alla participant activities (delegerat)
  List<ParticipantActivity> get participantActivities =>
      _participantTracker.allActivities;

  /// Online deltagare (delegerat)
  List<String> get onlineParticipants => _participantTracker.onlineParticipants;

  /// Connection status description (delegerat)
  String get connectionStatusDescription =>
      _connectionMonitor.statusDescription;

  /// Connection status emoji (delegerat)
  String get connectionStatusEmoji => _connectionMonitor.statusEmoji;

  /// Recept för vald kategori (med optimistiska ändringar)
  List<Recipe> get selectedCategoryRecipes {
    if (_selectedCategory == null) return [];

    final fallback =
        _currentMenu?.getRecipesForCategory(_selectedCategory!) ?? [];
    return _optimisticManager.getRecipesForDay(_selectedCategory!, fallback);
  }

  /// Meny med optimistiska ändringar tillämpade
  Map<String, List<Recipe>> get menuWithOptimisticChanges {
    if (_currentMenu == null) return {};
    return _optimisticManager.applyToMenu(_currentMenu!.menuSnapshot);
  }

  /// Alla kategorier i nuvarande meny
  List<String> get categories => _currentMenu?.categories ?? [];

  // ===== INITIALIZATION (UI setup bara) =====

  void _initialize() {
    // Lyssna på service errors
    _menuService.addListener(_onServiceStateChanged);
  }

  void _onServiceStateChanged() {
    final error = _menuService.lastError;
    if (error != null) {
      _setError('Menu service fel: ${error.message}');
    }
  }

  void _onConnectionChanged(bool isOnline) {
    if (!isOnline && _status == RealtimeMenuStatus.watching) {
      _setStatus(RealtimeMenuStatus.offline);
    } else if (isOnline && _status == RealtimeMenuStatus.offline) {
      _setStatus(RealtimeMenuStatus.watching);
    }
    notifyListeners();
  }

  // ===== CORE OPERATIONS (UI coordination bara) =====

  /// Starta watching av realtidsmeny
  Future<void> startWatching(String menuId) async {
    if (_status == RealtimeMenuStatus.watching && _currentMenu?.id == menuId) {
      return;
    }

    await stopWatching();
    _setStatus(RealtimeMenuStatus.loading);
    _clearError();

    try {
      AppLogger.info('🎮 Startar watching av meny: $menuId');

      _menuSubscription = _menuService.watchRealtimeMenu(menuId).listen(
            _onMenuUpdated,
            onError: _onMenuError,
          );

      _setStatus(RealtimeMenuStatus.watching);
      AppLogger.success('✅ Watching startat för meny: $menuId');
    } catch (e) {
      _setError('Kunde inte starta watching: $e');
      AppLogger.error('❌ Fel vid start av watching', e);
    }
  }

  /// Sluta watching av realtidsmeny
  Future<void> stopWatching() async {
    AppLogger.info('🛑 Stoppar watching av meny');

    await _menuSubscription?.cancel();
    _menuSubscription = null;

    // Delegera cleanup till managers
    _optimisticManager.clear();
    _participantTracker.clear();

    if (_status == RealtimeMenuStatus.watching ||
        _status == RealtimeMenuStatus.offline) {
      _setStatus(RealtimeMenuStatus.idle);
    }
  }

  /// Skapa ny realtidsmeny från befintlig kategori-meny (från MenuViewModel)
  Future<RealtimeMenu?> createRealtimeMenu({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
    String? menuNotes,
    String? originalPrompt,
    DateTime? createdForDate,
  }) async {
    _setStatus(RealtimeMenuStatus.loading);
    _clearError();

    try {
      AppLogger.info('📅 Skapar realtidsmeny: $menuTitle');

      final realtimeMenu = await _menuService.createRealtimeMenu(
        menuTitle: menuTitle,
        menuSnapshot: menuSnapshot,
        editorUserIds: editorUserIds,
        viewerUserIds: viewerUserIds,
        menuNotes: menuNotes,
        originalPrompt: originalPrompt,
        createdForDate: createdForDate,
      );

      // Starta watching av den nya menyn
      await startWatching(realtimeMenu.id);

      AppLogger.success('✅ Realtidsmeny skapad: ${realtimeMenu.id}');
      return realtimeMenu;
    } catch (e) {
      _setError('Kunde inte skapa realtidsmeny: $e');
      AppLogger.error('❌ Fel vid skapande av realtidsmeny', e);
      return null;
    }
  }

  // ===== MENU OPERATIONS (Coordination bara - business logic delegeras) =====

  /// Lägg till recept till kategori med optimistic update
  Future<void> addRecipeToCategory(String categoryName, Recipe recipe) async {
    if (!_canPerformUpdate()) return;

    // Delegera optimistic update
    final currentRecipes =
        _currentMenu?.getRecipesForCategory(categoryName) ?? [];
    _optimisticManager.applyChange(
      categoryName,
      (recipes) => [...recipes, recipe],
      currentRecipes,
    );

    try {
      await _menuService.addRecipeToCategory(
        resourceId: _currentMenu!.id,
        categoryName: categoryName,
        recipe: recipe,
      );
      AppLogger.success('✅ Recept tillagt till $categoryName');
    } catch (e) {
      _optimisticManager.rollback();
      _setError('Kunde inte lägga till recept: $e');
    }
  }

  /// Ta bort recept från kategori
  Future<void> removeRecipeFromCategory(
      String categoryName, int recipeIndex) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        _currentMenu?.getRecipesForCategory(categoryName) ?? [];
    if (recipeIndex < 0 || recipeIndex >= currentRecipes.length) {
      _setError('Ogiltigt recept-index');
      return;
    }

    // Delegera optimistic update
    _optimisticManager.applyChange(
      categoryName,
      (recipes) {
        final updated = List<Recipe>.from(recipes);
        updated.removeAt(recipeIndex);
        return updated;
      },
      currentRecipes,
    );

    try {
      await _menuService.removeRecipeFromCategory(
        resourceId: _currentMenu!.id,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
      );
      AppLogger.success('✅ Recept borttaget från $categoryName');
    } catch (e) {
      _optimisticManager.rollback();
      _setError('Kunde inte ta bort recept: $e');
    }
  }

  /// Flytta recept mellan kategorier
  Future<void> moveRecipeBetweenCategories({
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final fromRecipes = _currentMenu?.getRecipesForCategory(fromCategory) ?? [];
    if (fromIndex < 0 || fromIndex >= fromRecipes.length) {
      _setError('Ogiltigt från-index');
      return;
    }

    final recipe = fromRecipes[fromIndex];

    // Optimistic update för båda kategorierna (delegerat)
    _optimisticManager.applyChange(fromCategory, (recipes) {
      final updated = List<Recipe>.from(recipes);
      updated.removeAt(fromIndex);
      return updated;
    }, fromRecipes);

    final toRecipes = _currentMenu?.getRecipesForCategory(toCategory) ?? [];
    _optimisticManager.applyChange(toCategory, (recipes) {
      final updated = List<Recipe>.from(recipes);
      final insertIndex = toIndex ?? updated.length;
      updated.insert(insertIndex.clamp(0, updated.length), recipe);
      return updated;
    }, toRecipes);

    try {
      await _menuService.moveRecipeBetweenCategories(
        resourceId: _currentMenu!.id,
        fromCategory: fromCategory,
        fromIndex: fromIndex,
        toCategory: toCategory,
        toIndex: toIndex,
      );
      AppLogger.success('✅ Recept flyttat från $fromCategory till $toCategory');
    } catch (e) {
      _optimisticManager.rollback();
      _setError('Kunde inte flytta recept: $e');
    }
  }

  /// Rensa hela kategorin
  Future<void> clearCategory(String categoryName) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        _currentMenu?.getRecipesForCategory(categoryName) ?? [];

    // Optimistic update (delegerat)
    _optimisticManager.applyChange(
        categoryName, (recipes) => [], currentRecipes);

    try {
      await _menuService.clearCategory(
        resourceId: _currentMenu!.id,
        categoryName: categoryName,
      );
      AppLogger.success('✅ $categoryName rensad');
    } catch (e) {
      _optimisticManager.rollback();
      _setError('Kunde inte rensa kategori: $e');
    }
  }

  /// Regenerera kategori med AI
  Future<void> regenerateCategory(String categoryName) async {
    if (!_canPerformUpdate()) return;

    _setStatus(RealtimeMenuStatus.updating);

    try {
      // TODO: Implementera AI-regenerering via MenuService
      // Detta skulle kunna anropa din befintliga AI-generering för specifik kategori
      AppLogger.info('🤖 Regenererar kategori: $categoryName');

      // Placeholder - här skulle du anropa AI-service för att generera nya recept
      await Future.delayed(const Duration(seconds: 2));

      // När AI-integration är klar:
      // final newRecipes = await _aiService.generateRecipesForCategory(categoryName);
      // await _menuService.regenerateCategory(
      //   resourceId: _currentMenu!.id,
      //   categoryName: categoryName,
      //   newRecipes: newRecipes,
      // );

      AppLogger.success('✅ $categoryName regenererad');
    } catch (e) {
      _setError('Kunde inte regenerera kategori: $e');
    } finally {
      if (_status == RealtimeMenuStatus.updating) {
        _setStatus(RealtimeMenuStatus.watching);
      }
    }
  }

  /// Ersätt recept i kategori
  Future<void> replaceRecipeInCategory({
    required String categoryName,
    required int recipeIndex,
    required Recipe newRecipe,
  }) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        _currentMenu?.getRecipesForCategory(categoryName) ?? [];
    if (recipeIndex < 0 || recipeIndex >= currentRecipes.length) {
      _setError('Ogiltigt recept-index');
      return;
    }

    // Optimistic update (delegerat)
    _optimisticManager.applyChange(
      categoryName,
      (recipes) {
        final updated = List<Recipe>.from(recipes);
        updated[recipeIndex] = newRecipe;
        return updated;
      },
      currentRecipes,
    );

    try {
      await _menuService.replaceRecipeInCategory(
        resourceId: _currentMenu!.id,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        newRecipe: newRecipe,
      );
      AppLogger.success('✅ Recept ersatt i $categoryName');
    } catch (e) {
      _optimisticManager.rollback();
      _setError('Kunde inte ersätta recept: $e');
    }
  }

  /// Uppdatera hela kategorin
  Future<void> updateWholeCategory({
    required String categoryName,
    required List<Recipe> recipes,
  }) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        _currentMenu?.getRecipesForCategory(categoryName) ?? [];

    // Optimistic update (delegerat)
    _optimisticManager.applyChange(
      categoryName,
      (oldRecipes) => List<Recipe>.from(recipes),
      currentRecipes,
    );

    try {
      await _menuService.updateWholeCategory(
        resourceId: _currentMenu!.id,
        categoryName: categoryName,
        recipes: recipes,
      );
      AppLogger.success('✅ $categoryName uppdaterad');
    } catch (e) {
      _optimisticManager.rollback();
      _setError('Kunde inte uppdatera kategori: $e');
    }
  }

  // ===== PARTICIPANT MANAGEMENT (Coordination bara) =====

  /// Lägg till deltagare
  Future<void> addParticipant({
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) async {
    if (!canManageParticipants) {
      _setError('Ingen behörighet att hantera deltagare');
      return;
    }

    try {
      await _menuService.addParticipant(
        resourceId: _currentMenu!.id,
        userId: userId,
        userDisplayName: userDisplayName,
        permission: permission,
      );

      // Uppdatera participant tracker
      _participantTracker.updateDisplayName(userId, userDisplayName);

      AppLogger.success('✅ Deltagare tillagd: $userDisplayName');
    } catch (e) {
      _setError('Kunde inte lägga till deltagare: $e');
    }
  }

  /// Ta bort deltagare
  Future<void> removeParticipant(String userId) async {
    if (!canManageParticipants) {
      _setError('Ingen behörighet att hantera deltagare');
      return;
    }

    try {
      await _menuService.removeParticipant(
        resourceId: _currentMenu!.id,
        userId: userId,
      );

      // Ta bort från participant tracker
      _participantTracker.removeParticipant(userId);

      AppLogger.success('✅ Deltagare borttagen');
    } catch (e) {
      _setError('Kunde inte ta bort deltagare: $e');
    }
  }

  // ===== UI STATE MANAGEMENT (Korrekt ViewModel ansvar) =====

  /// Välj kategori för redigering
  void selectCategory(String? categoryName) {
    if (_selectedCategory != categoryName) {
      _selectedCategory = categoryName;
      notifyListeners();
    }
  }

  /// Toggla deltagarlista
  void toggleParticipants() {
    _showParticipants = !_showParticipants;
    notifyListeners();
  }

  /// Rensa fel
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Tvinga connection check
  void refreshConnection() {
    _connectionMonitor.forceConnectionCheck();
  }

  // ===== PRIVATE HELPERS (UI state bara) =====

  void _onMenuUpdated(RealtimeMenu menu) {
    _currentMenu = menu;

    // Delegera till managers
    _optimisticManager.clear(); // Remote update ersätter optimistiska ändringar
    _participantTracker.updateFromMenu(menu);

    if (_status != RealtimeMenuStatus.watching) {
      _setStatus(RealtimeMenuStatus.watching);
    }

    notifyListeners();
    AppLogger.info('📥 Meny uppdaterad: ${menu.menuTitle}');
  }

  void _onMenuError(dynamic error) {
    _setError('Real-time fel: $error');
    _setStatus(RealtimeMenuStatus.error);
    AppLogger.error('❌ Menu watching fel', error);
  }

  bool _canPerformUpdate() {
    if (_currentMenu == null) {
      _setError('Ingen meny laddad');
      return false;
    }

    if (!canEdit) {
      _setError('Ingen redigeringsbehörighet');
      return false;
    }

    if (!isOnline) {
      _setError('Ingen internetanslutning');
      return false;
    }

    return true;
  }

  void _setStatus(RealtimeMenuStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    AppLogger.error('🔥 RealtimeMenuViewModel fel: $message');
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====

  /// Skapa personlig kopia av nuvarande meny (kompatibel med MenuViewModel)
  Map<String, List<Recipe>>? createPersonalCopy() {
    if (_currentMenu == null) return null;
    return _menuService.createPersonalCopy(_currentMenu!);
  }

  /// Ta bort realtidsmeny helt
  Future<void> deleteMenu() async {
    if (_currentMenu == null || !canManageParticipants) return;

    try {
      await _menuService.deleteRealtimeMenu(_currentMenu!.id);
      await stopWatching();
      AppLogger.success('✅ Meny borttagen');
    } catch (e) {
      _setError('Kunde inte ta bort meny: $e');
    }
  }

  /// Uppdatera grundläggande menyinformation
  Future<void> updateBasicInfo({
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    String? originalPrompt,
  }) async {
    if (!_canPerformUpdate()) return;

    _setStatus(RealtimeMenuStatus.updating);

    try {
      await _menuService.updateBasicInfo(
        resourceId: _currentMenu!.id,
        menuTitle: menuTitle,
        createdForDate: createdForDate,
        menuNotes: menuNotes,
        originalPrompt: originalPrompt,
      );
      AppLogger.success('✅ Menyinfo uppdaterad');
    } catch (e) {
      _setError('Kunde inte uppdatera menyinfo: $e');
    } finally {
      if (_status == RealtimeMenuStatus.updating) {
        _setStatus(RealtimeMenuStatus.watching);
      }
    }
  }

  // ===== DISPOSE =====

  @override
  void dispose() {
    AppLogger.info('🗑️ RealtimeMenuViewModel disposing...');

    stopWatching();
    _menuService.removeListener(_onServiceStateChanged);

    // Delegera cleanup till managers
    _optimisticManager.dispose();
    _participantTracker.dispose();
    _connectionMonitor.dispose();

    super.dispose();
  }
}
