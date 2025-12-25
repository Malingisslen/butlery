/// ViewModel managing real-time collaborative menu editing with focused module delegation.

// lib/viewmodels/realtime_menu_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/viewmodels/realtime/optimistic_update_manager.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';

// Focused modules for clean architecture separation
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_state.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_stream_manager.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_menu_operations.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_participant_manager.dart';

class RealtimeMenuViewModel extends ChangeNotifier {
  final RealtimeMenuService _menuService;

  late final RealtimeMenuState _state;
  late final RealtimeStreamManager _streamManager;
  late final RealtimeMenuOperations _operations;
  late final RealtimeParticipantManager _participantManager;
  late final OptimisticUpdateManager _optimisticManager;
  late final ParticipantTracker _participantTracker;
  late final ConnectionMonitor _connectionMonitor;

  RealtimeMenuViewModel({
    required RealtimeMenuService menuService,
    required RealtimeSyncService syncService,
    required AuthService authService,
  }) : _menuService = menuService {
    _optimisticManager = OptimisticUpdateManager(onUpdated: notifyListeners);
    _participantTracker = ParticipantTracker(onUpdated: notifyListeners);
    _connectionMonitor = ConnectionMonitor(
      syncService: syncService,
      onConnectionChanged: _onConnectionChanged,
    );

    _state = RealtimeMenuState();

    _streamManager = RealtimeStreamManager(
      menuService: _menuService,
      onMenuUpdated: _onMenuUpdated,
      onMenuError: _onMenuError,
      onStreamStarted: () => _state.transitionToWatching(),
      onStreamStopped: () => _state.setStatus(RealtimeMenuStatus.idle),
    );

    _operations = RealtimeMenuOperations(
      menuService: _menuService,
      optimisticManager: _optimisticManager,
    );

    _participantManager = RealtimeParticipantManager(
      menuService: _menuService,
      participantTracker: _participantTracker,
    );

    _state.addListener(() => notifyListeners());
    _initialize();
  }

  // State accessors
  RealtimeMenu? get currentMenu => _state.currentMenu;
  RealtimeMenuStatus get status => _state.status;
  String? get errorMessage => _state.errorMessage;
  String? get selectedCategory => _state.selectedCategory;
  bool get showParticipants => _state.showParticipants;
  bool get isLoading => _state.isLoading;
  bool get hasUnsavedChanges => _operations.hasOptimisticChanges;
  List<String> get categories => _state.categories;

  // Connection status
  bool get isOnline => _connectionMonitor.isOnline;
  String get connectionStatusDescription =>
      _connectionMonitor.statusDescription;
  String get connectionStatusEmoji => _connectionMonitor.statusEmoji;

  // Permission system
  String? get currentUserId => _participantManager.currentUserId;
  bool get canEdit =>
      currentMenu != null && _participantManager.canEdit(currentMenu!.id);
  bool get canManageParticipants =>
      currentMenu != null &&
      _participantManager.canManageParticipants(currentMenu!.id);

  // Participant tracking
  int get activeParticipantCount => _participantManager.activeParticipantCount;
  List<ParticipantActivity> get participantActivities =>
      _participantManager.participantActivities;
  List<String> get onlineParticipants => _participantManager.onlineParticipants;

  // Recipe getters with optimistic updates
  List<Recipe> get selectedCategoryRecipes {
    if (selectedCategory == null) return [];

    final baseRecipes = _state.selectedCategoryRecipes;
    return _operations.getRecipesForCategory(selectedCategory!, baseRecipes);
  }

  Map<String, List<Recipe>> get menuWithOptimisticChanges {
    if (currentMenu == null) return {};
    return _operations.applyOptimisticChanges(currentMenu!.menuSnapshot);
  }

  Future<void> startWatching(String menuId) async {
    _state.transitionToLoading();
    _state.clearError();

    try {
      await _streamManager.startWatching(menuId);
    } catch (e) {
      _state.transitionToError('Kunde inte starta watching: $e');
      AppLogger.error('❌ Failed to start watching', e);
    }
  }

  Future<void> stopWatching() async {
    await _streamManager.stopWatching();
    _state.resetState();
    AppLogger.info('🛑 Watching stopped');
  }

  Future<void> addRecipeToCategory({
    required String categoryName,
    required Recipe recipe,
  }) async {
    if (!_canPerformUpdate()) return;

    try {
      await _operations.addRecipeToCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        recipe: recipe,
      );
    } catch (e) {
      _state.setError('Kunde inte lägga till recept: $e');
    }
  }

  Future<void> removeRecipeFromCategory({
    required String categoryName,
    required int recipeIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        currentMenu?.getRecipesForCategory(categoryName) ?? [];

    try {
      await _operations.removeRecipeFromCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        recipeIndex: recipeIndex,
        currentRecipes: currentRecipes,
      );
    } catch (e) {
      _state.setError('Kunde inte ta bort recept: $e');
    }
  }

  Future<void> moveRecipeBetweenCategories({
    required String fromCategory,
    required int fromIndex,
    required String toCategory,
    int? toIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final fromRecipes = currentMenu?.getRecipesForCategory(fromCategory) ?? [];
    final toRecipes = currentMenu?.getRecipesForCategory(toCategory) ?? [];

    try {
      await _operations.moveRecipeBetweenCategories(
        menuId: currentMenu!.id,
        fromCategory: fromCategory,
        fromIndex: fromIndex,
        toCategory: toCategory,
        fromRecipes: fromRecipes,
        toRecipes: toRecipes,
        toIndex: toIndex,
      );
    } catch (e) {
      _state.setError('Kunde inte flytta recept: $e');
    }
  }

  Future<void> reorderRecipeInCategory({
    required String categoryName,
    required int fromIndex,
    required int toIndex,
  }) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        currentMenu?.getRecipesForCategory(categoryName) ?? [];

    try {
      await _operations.reorderRecipesInCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        fromIndex: fromIndex,
        toIndex: toIndex,
        currentRecipes: currentRecipes,
      );
    } catch (e) {
      _state.setError('Kunde inte ändra ordning på recept: $e');
    }
  }

  Future<void> clearCategory(String categoryName) async {
    if (!_canPerformUpdate()) return;

    final currentRecipes =
        currentMenu?.getRecipesForCategory(categoryName) ?? [];

    try {
      await _operations.clearCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
        currentRecipes: currentRecipes,
      );
    } catch (e) {
      _state.setError('Kunde inte rensa kategori: $e');
    }
  }

  Future<void> regenerateCategory(String categoryName) async {
    if (!_canPerformUpdate()) return;

    _state.transitionToUpdating();

    try {
      await _operations.regenerateCategory(
        menuId: currentMenu!.id,
        categoryName: categoryName,
      );
    } catch (e) {
      _state.setError('Kunde inte regenerera kategori: $e');
    } finally {
      if (_state.status == RealtimeMenuStatus.updating) {
        _state.transitionToWatching();
      }
    }
  }

  Future<void> addParticipant({
    required String userId,
    required String userDisplayName,
    required ResourcePermission permission,
  }) async {
    if (currentMenu == null) {
      _state.setError('Ingen meny laddad');
      return;
    }

    try {
      await _participantManager.addParticipant(
        menuId: currentMenu!.id,
        userId: userId,
        userDisplayName: userDisplayName,
        permission: permission,
      );
    } catch (e) {
      _state.setError('Kunde inte lägga till deltagare: $e');
    }
  }

  Future<void> removeParticipant(String userId) async {
    if (currentMenu == null) {
      _state.setError('Ingen meny laddad');
      return;
    }

    try {
      await _participantManager.removeParticipant(
        menuId: currentMenu!.id,
        userId: userId,
      );
    } catch (e) {
      _state.setError('Kunde inte ta bort deltagare: $e');
    }
  }

  void selectCategory(String? categoryName) =>
      _state.selectCategory(categoryName);
  void toggleParticipants() => _state.toggleParticipants();
  void clearError() => _state.clearError();
  void refreshConnection() => _connectionMonitor.forceConnectionCheck();
  Map<String, List<Recipe>>? createPersonalCopy() {
    if (currentMenu == null) return null;
    return _menuService.createPersonalCopy(currentMenu!);
  }

  Future<void> deleteMenu() async {
    if (currentMenu == null || !canManageParticipants) return;

    try {
      await _menuService.deleteRealtimeMenu(currentMenu!.id);
      await stopWatching();
      AppLogger.success('✅ Meny borttagen');
    } catch (e) {
      _state.setError('Kunde inte ta bort meny: $e');
    }
  }

  Future<void> updateBasicInfo({
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    String? originalPrompt,
  }) async {
    if (!_canPerformUpdate()) return;

    _state.transitionToUpdating();

    try {
      await _menuService.updateBasicInfo(
        resourceId: currentMenu!.id,
        menuTitle: menuTitle,
        createdForDate: createdForDate,
        menuNotes: menuNotes,
        originalPrompt: originalPrompt,
      );
      AppLogger.success('✅ Menyinfo uppdaterad');
    } catch (e) {
      _state.setError('Kunde inte uppdatera menyinfo: $e');
    } finally {
      if (_state.status == RealtimeMenuStatus.updating) {
        _state.transitionToWatching();
      }
    }
  }

  void _initialize() {
    _menuService.addListener(_onServiceStateChanged);
  }

  void _onServiceStateChanged() {
    final error = _menuService.lastError;
    if (error != null) {
      _state.setError('Menu service fel: ${error.message}');
    }
  }

  void _onConnectionChanged(bool isOnline) {
    if (!isOnline && _state.status == RealtimeMenuStatus.watching) {
      _state.transitionToOffline();
    } else if (isOnline && _state.status == RealtimeMenuStatus.offline) {
      _state.transitionToWatching();
    }
    notifyListeners();
  }

  void _onMenuUpdated(RealtimeMenu menu) {
    _state.setCurrentMenu(menu);

    // Clear optimistic changes when real update arrives
    _operations.clearOptimisticChanges();
    _participantManager.updateFromMenu(menu);

    if (_state.status != RealtimeMenuStatus.watching) {
      _state.transitionToWatching();
    }

    AppLogger.info('📥 Menu updated: ${menu.menuTitle}');
  }

  void _onMenuError(dynamic error) {
    _state.transitionToError('Real-time fel: $error');
    AppLogger.error('❌ Menu watching error', error);
  }

  bool _canPerformUpdate() {
    if (currentMenu == null) {
      _state.setError('Ingen meny laddad');
      return false;
    }

    if (!canEdit) {
      _state.setError('Ingen redigeringsbehörighet');
      return false;
    }

    if (!isOnline) {
      _state.setError('Ingen internetanslutning');
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    AppLogger.info('🗑️ RealtimeMenuViewModel disposing...');

    _streamManager.dispose();
    _menuService.removeListener(_onServiceStateChanged);

    // Dispose focused modules
    _state.dispose();

    // Dispose legacy managers
    _optimisticManager.dispose();
    _participantManager.dispose();
    _connectionMonitor.dispose();

    super.dispose();
  }
}
