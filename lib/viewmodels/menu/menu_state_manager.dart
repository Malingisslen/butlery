// lib/viewmodels/menu/menu_state_manager.dart
import 'package:butlery/core/mixins/stream_management_mixin.dart';

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Focused module for menu state management
/// This module handles ONLY state management:
/// - Menu state variables and getters
/// - Error state management
/// - Loading state management
/// - State notifications and updates
/// ❌ DOES NOT CONTAIN: Business logic, external service calls, persistence
class MenuStateManager extends ChangeNotifier with StreamManagementMixin {
  // Core state variables
  Map<String, List<Recipe>> _menu = {};
  bool _isGenerating = false;
  String? _error;
  String _lastPrompt = '';
  List<SavedMenuInfo> _savedMenus = [];
  Map<String, List<Recipe>> get menu => Map.unmodifiable(_menu);
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasMenu => _menu.isNotEmpty;
  String get lastPrompt => _lastPrompt;
  List<SavedMenuInfo> get savedMenus => List.unmodifiable(_savedMenus);

  int get totalRecipeCount =>
      _menu.values.fold(0, (total, recipes) => total + recipes.length);
  void setMenu(Map<String, List<Recipe>> menu) {
    _menu = menu;
    notifyListeners();
  }

  void updateMenuSection(String section, List<Recipe> recipes) {
    _menu[section] = recipes;
    notifyListeners();
  }

  void setGenerating(bool isGenerating) {
    _isGenerating = isGenerating;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setLastPrompt(String prompt) {
    _lastPrompt = prompt;
  }

  void setSavedMenus(List<SavedMenuInfo> menus) {
    _savedMenus = menus;
    notifyListeners();
  }

  void clearMenu() {
    _menu = {};
    _lastPrompt = '';
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void loadMenuFromData({
    required Map<String, List<Recipe>> menu,
    required String lastPrompt,
  }) {
    _menu = menu;
    _lastPrompt = lastPrompt;
    _error = null;
    notifyListeners();
  }

  bool validateMenuForSaving() {
    return hasMenu;
  }

  bool validatePrompt(String prompt) {
    return prompt.trim().isNotEmpty;
  }

  void handleOperationError(String operation, dynamic error) {
    setError('$operation: ${error.toString()}');
  }

  void clearErrorAfterSuccess() {
    if (hasError) {
      clearError();
    }
  }

  @override
  void dispose() {
    disposeStreamResources();
    super.dispose();
  }
}

/// Data class for saved menu information
class SavedMenuInfo {
  final String key;
  final String name;
  final DateTime savedDate;
  final int recipeCount;
  final String comment;
  final String? originalAuthor;
  final bool isModified;
  final bool isOwned;
  final String? firebaseId;

  SavedMenuInfo({
    required this.key,
    required this.name,
    required this.savedDate,
    required this.recipeCount,
    required this.comment,
    this.originalAuthor,
    this.isModified = false,
    this.isOwned = true,
    this.firebaseId,
  });

  /// Get attribution color type for UI
  String get attributionColorType {
    if (isOwned && isModified) return 'modified';
    if (isOwned) return 'owned';
    return 'shared';
  }

  /// Get status icon type for UI
  String get statusIcon {
    if (isOwned && isModified) return 'autoFixHigh';
    if (isOwned) return 'restaurantMenu';
    return 'person';
  }
}
