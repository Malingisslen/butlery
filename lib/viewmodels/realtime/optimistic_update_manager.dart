// lib/viewmodels/realtime/optimistic_update_manager.dart - FIXED for categories

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manager for optimistic updates with automatic rollback
class OptimisticUpdateManager {
  final Map<String, List<Recipe>> _optimisticChanges = {};
  bool _hasOptimisticChanges = false;
  Timer? _rollbackTimer;

  /// Callback when optimistic changes are updated
  final VoidCallback? onUpdated;

  OptimisticUpdateManager({this.onUpdated});

  /// Do we have optimistic changes?
  bool get hasChanges => _hasOptimisticChanges;

  /// All optimistic changes (for debugging)
  Map<String, List<Recipe>> get allChanges =>
      Map.unmodifiable(_optimisticChanges);

  /// Apply optimistic change for a category
  void applyChange(
    String categoryName,
    List<Recipe> Function(List<Recipe>) updateFunction, [
    List<Recipe>? currentRecipes,
  ]) {
    final baseRecipes =
        currentRecipes ?? _optimisticChanges[categoryName] ?? [];
    _optimisticChanges[categoryName] = updateFunction(baseRecipes);
    _hasOptimisticChanges = true;

    // Auto-rollback efter 10 sekunder
    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(seconds: 10), clear);

    onUpdated?.call();
    AppLogger.debug('🔄 Optimistisk ändring applicerad för $categoryName');
  }

  /// Get recipes for category with optimistic changes
  List<Recipe> getRecipesForDay(String categoryName, List<Recipe> fallback) {
    if (_hasOptimisticChanges && _optimisticChanges.containsKey(categoryName)) {
      return _optimisticChanges[categoryName]!;
    }
    return fallback;
  }

  /// Get the full menu with optimistic changes applied
  Map<String, List<Recipe>> applyToMenu(Map<String, List<Recipe>> baseMenu) {
    if (!_hasOptimisticChanges) return baseMenu;

    final result = Map<String, List<Recipe>>.from(baseMenu);
    result.addAll(_optimisticChanges);
    return result;
  }

  /// Clear all optimistic changes
  void clear() {
    if (_hasOptimisticChanges) {
      _optimisticChanges.clear();
      _hasOptimisticChanges = false;
      _rollbackTimer?.cancel();
      onUpdated?.call();
      AppLogger.debug('🧹 Optimistiska ändringar rensade');
    }
  }

  /// Rollback med felmeddelande
  void rollback() {
    clear();
    AppLogger.warning('⏪ Optimistiska ändringar rullades tillbaka');
  }

  /// Clear optimistic changes for specific category
  void clearCategory(String categoryName) {
    if (_optimisticChanges.remove(categoryName) != null) {
      if (_optimisticChanges.isEmpty) {
        _hasOptimisticChanges = false;
        _rollbackTimer?.cancel();
      }
      onUpdated?.call();
      AppLogger.debug('🧹 Optimistiska ändringar rensade för $categoryName');
    }
  }

  void dispose() {
    _rollbackTimer?.cancel();
    _rollbackTimer = null;
    clear();
    AppLogger.debug('🗑️ OptimisticUpdateManager disposed');
  }
}
