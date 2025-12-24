// lib/viewmodels/realtime_menu/realtime_menu_state.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

/// Status för realtidsmeny-operationer
enum RealtimeMenuStatus {
  idle,
  loading,
  watching,
  updating,
  error,
  offline,
}

/// Focused module for realtime menu state management
/// This module handles ONLY core state management:
/// - RealtimeMenu state tracking
/// - Status management and transitions
/// - Error state handling
/// - UI state variables (selected category, show participants)
/// ❌ DOES NOT CONTAIN: Service operations, streaming, participant logic
class RealtimeMenuState extends ChangeNotifier with StreamManagementMixin {
  // Core menu state
  RealtimeMenu? _currentMenu;
  RealtimeMenuStatus _status = RealtimeMenuStatus.idle;
  String? _errorMessage;

  // UI state
  String? _selectedCategory;
  bool _showParticipants = false;

  // ===== STATE GETTERS =====

  RealtimeMenu? get currentMenu => _currentMenu;
  RealtimeMenuStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get selectedCategory => _selectedCategory;
  bool get showParticipants => _showParticipants;

  bool get isLoading =>
      _status == RealtimeMenuStatus.loading ||
      _status == RealtimeMenuStatus.updating;

  bool get hasError => _errorMessage != null;
  bool get isWatching => _status == RealtimeMenuStatus.watching;
  bool get isOffline => _status == RealtimeMenuStatus.offline;

  /// Alla kategorier i nuvarande meny
  List<String> get categories => _currentMenu?.categories ?? [];

  /// Recept för vald kategori
  List<Recipe> get selectedCategoryRecipes {
    if (_selectedCategory == null || _currentMenu == null) return [];
    return _currentMenu!.getRecipesForCategory(_selectedCategory!);
  }

  // ===== STATE SETTERS =====

  void setCurrentMenu(RealtimeMenu? menu) {
    _currentMenu = menu;
    notifyListeners();
  }

  void setStatus(RealtimeMenuStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }

  void setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ===== UI STATE MANAGEMENT =====

  void selectCategory(String? categoryName) {
    if (_selectedCategory != categoryName) {
      _selectedCategory = categoryName;
      notifyListeners();
    }
  }

  void toggleParticipants() {
    _showParticipants = !_showParticipants;
    notifyListeners();
  }

  void setShowParticipants(bool show) {
    if (_showParticipants != show) {
      _showParticipants = show;
      notifyListeners();
    }
  }

  // ===== STATE VALIDATION =====

  bool hasMenu() => _currentMenu != null;

  bool canPerformOperations() {
    return hasMenu() && !isLoading && !hasError;
  }

  bool isMenuReady() {
    return hasMenu() && isWatching;
  }

  // ===== STATE TRANSITIONS =====

  void transitionToLoading() {
    setStatus(RealtimeMenuStatus.loading);
    clearError();
  }

  void transitionToWatching() {
    setStatus(RealtimeMenuStatus.watching);
    clearError();
  }

  void transitionToUpdating() {
    setStatus(RealtimeMenuStatus.updating);
  }

  void transitionToError(String message) {
    setError(message);
    setStatus(RealtimeMenuStatus.error);
  }

  void transitionToOffline() {
    setStatus(RealtimeMenuStatus.offline);
  }

  void transitionBackOnline() {
    if (_status == RealtimeMenuStatus.offline) {
      setStatus(RealtimeMenuStatus.watching);
    }
  }

  // ===== BATCH UPDATES =====

  void updateMenuAndStatus(RealtimeMenu menu, RealtimeMenuStatus newStatus) {
    _currentMenu = menu;
    _status = newStatus;
    _errorMessage = null;
    notifyListeners();
  }

  void resetState() {
    _currentMenu = null;
    _status = RealtimeMenuStatus.idle;
    _errorMessage = null;
    _selectedCategory = null;
    _showParticipants = false;
    notifyListeners();
  }

  // ===== UTILITY METHODS =====

  /// Get current menu snapshot as map
  Map<String, List<Recipe>> get menuSnapshot {
    return _currentMenu?.menuSnapshot ?? {};
  }

  /// Check if category exists in current menu
  bool hasCategorySelected() {
    return _selectedCategory != null && categories.contains(_selectedCategory);
  }

  /// Get recipe count for selected category
  int get selectedCategoryRecipeCount {
    return selectedCategoryRecipes.length;
  }

  /// Get total recipe count across all categories
  int get totalRecipeCount {
    if (_currentMenu == null) return 0;
    return menuSnapshot.values.fold(0, (sum, recipes) => sum + recipes.length);
  }

  /// Get menu title for display
  String get menuTitle {
    return _currentMenu?.menuTitle ?? 'Namnlös meny';
  }

  /// Get menu creation date
  DateTime? get menuCreatedAt {
    return _currentMenu?.createdAt;
  }

  /// Check if menu was created for specific date
  bool get hasCreatedForDate {
    return _currentMenu?.createdForDate != null;
  }

  /// Get formatted menu date for display
  String get menuDateDisplay {
    final date = _currentMenu?.createdForDate ?? _currentMenu?.createdAt;
    if (date == null) return 'Inget datum';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final menuDate = DateTime(date.year, date.month, date.day);

    if (menuDate == today) {
      return 'Idag';
    } else if (menuDate.isAfter(today)) {
      final diff = menuDate.difference(today).inDays;
      return diff == 1 ? 'Imorgon' : '$diff dagar framåt';
    } else {
      final diff = today.difference(menuDate).inDays;
      return diff == 1 ? 'Igår' : '$diff dagar sedan';
    }
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
