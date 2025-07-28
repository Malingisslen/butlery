// lib/viewmodels/realtime/optimistic_update_manager.dart - FIXED för kategorier

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manager för optimistiska uppdateringar med automatic rollback
class OptimisticUpdateManager {
  final Map<String, List<Recipe>> _optimisticChanges = {};
  bool _hasOptimisticChanges = false;
  Timer? _rollbackTimer;

  /// Callback när optimistiska ändringar uppdateras
  final VoidCallback? onUpdated;

  OptimisticUpdateManager({this.onUpdated});

  /// Har vi optimistiska ändringar?
  bool get hasChanges => _hasOptimisticChanges;

  /// Alla optimistiska ändringar (för debugging)
  Map<String, List<Recipe>> get allChanges =>
      Map.unmodifiable(_optimisticChanges);

  /// Applicera optimistisk ändring för en kategori
  void applyChange(
    String categoryName,
    List<Recipe> Function(List<Recipe>) updateFunction,
    List<Recipe> currentRecipes,
  ) {
    _optimisticChanges[categoryName] = updateFunction(currentRecipes);
    _hasOptimisticChanges = true;

    // Auto-rollback efter 10 sekunder
    _rollbackTimer?.cancel();
    _rollbackTimer = Timer(const Duration(seconds: 10), clear);

    onUpdated?.call();
    AppLogger.debug('🔄 Optimistisk ändring applicerad för $categoryName');
  }

  /// Hämta recept för kategori med optimistiska ändringar
  List<Recipe> getRecipesForDay(String categoryName, List<Recipe> fallback) {
    if (_hasOptimisticChanges && _optimisticChanges.containsKey(categoryName)) {
      return _optimisticChanges[categoryName]!;
    }
    return fallback;
  }

  /// Hämta hela menyn med optimistiska ändringar tillämpade
  Map<String, List<Recipe>> applyToMenu(Map<String, List<Recipe>> baseMenu) {
    if (!_hasOptimisticChanges) return baseMenu;

    final result = Map<String, List<Recipe>>.from(baseMenu);
    result.addAll(_optimisticChanges);
    return result;
  }

  /// Rensa alla optimistiska ändringar
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

  /// Rensa optimistiska ändringar för specifik kategori
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
    clear();
    AppLogger.debug('🗑️ OptimisticUpdateManager disposed');
  }
}
