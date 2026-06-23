// lib/viewmodels/recipe_list/recipe_delete_manager.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

class PendingDelete {
  final String recipeId;
  final Recipe recipe;
  final int originalIndex;
  final Timer timer;
  final DateTime createdAt;

  PendingDelete({
    required this.recipeId,
    required this.recipe,
    required this.originalIndex,
    required this.timer,
    required this.createdAt,
  });
}

/// Manages optimistic recipe deletion with multi-pending undo support.
class RecipeDeleteManager {
  final UnifiedRecipeService _recipeService;
  final void Function() _invalidateCache;
  final void Function() _notifyParent;
  final void Function(String) _onError;

  final Map<String, PendingDelete> _pendingDeletes = {};

  // Track the last bulk batch for undo
  Set<String>? _lastBulkBatchIds;

  RecipeDeleteManager({
    required UnifiedRecipeService recipeService,
    required void Function() invalidateCache,
    required void Function() notifyParent,
    required void Function(String) onError,
  }) : _recipeService = recipeService,
       _invalidateCache = invalidateCache,
       _notifyParent = notifyParent,
       _onError = onError;

  bool get hasPendingDeletes => _pendingDeletes.isNotEmpty;

  /// Delete a single recipe with 5-second undo window.
  void deleteRecipe(String recipeId) {
    if (_pendingDeletes.containsKey(recipeId)) return;

    final recipe = _recipeService.getRecipeById(recipeId);
    if (recipe == null) return;

    final index = _recipeService.optimisticRemoveWithIndex(recipeId);
    _invalidateCache();
    _notifyParent();

    final timer = Timer(const Duration(seconds: 5), () {
      _commitDelete(recipeId);
    });

    _pendingDeletes[recipeId] = PendingDelete(
      recipeId: recipeId,
      recipe: recipe,
      originalIndex: index,
      timer: timer,
      createdAt: clock.now(),
    );
  }

  /// Undo delete of a specific recipe by ID.
  void undoDeleteById(String recipeId) {
    final pending = _pendingDeletes.remove(recipeId);
    if (pending == null) return;

    pending.timer.cancel();
    _recipeService.optimisticRestoreAt(pending.recipe, pending.originalIndex);
    _invalidateCache();
    _notifyParent();
  }

  /// Undo the most recently created pending delete.
  void undoLastDelete() {
    if (_pendingDeletes.isEmpty) return;

    final lastEntry = _pendingDeletes.entries.reduce(
      (a, b) => a.value.createdAt.isAfter(b.value.createdAt) ? a : b,
    );
    undoDeleteById(lastEntry.key);
  }

  /// Bulk delete selected recipes with 7-second undo window.
  void deleteSelected(Set<String> ids) {
    _lastBulkBatchIds = Set.from(ids);

    for (final id in ids) {
      if (_pendingDeletes.containsKey(id)) continue;

      final recipe = _recipeService.getRecipeById(id);
      if (recipe == null) continue;

      final index = _recipeService.optimisticRemoveWithIndex(id);

      final timer = Timer(const Duration(seconds: 7), () {
        _commitDelete(id);
      });

      _pendingDeletes[id] = PendingDelete(
        recipeId: id,
        recipe: recipe,
        originalIndex: index,
        timer: timer,
        createdAt: clock.now(),
      );
    }

    _invalidateCache();
    _notifyParent();
  }

  /// Undo the last bulk delete batch.
  void undoBulkDelete() {
    if (_lastBulkBatchIds == null) return;

    // Restore in reverse order to maintain correct indices
    final idsToRestore = _lastBulkBatchIds!.toList();
    for (final id in idsToRestore.reversed) {
      final pending = _pendingDeletes.remove(id);
      if (pending != null) {
        pending.timer.cancel();
        _recipeService.optimisticRestoreAt(
          pending.recipe,
          pending.originalIndex,
        );
      }
    }

    _lastBulkBatchIds = null;
    _invalidateCache();
    _notifyParent();
  }

  /// Cancel all pending deletes and restore recipes. Used in dispose.
  void cancelAll() {
    for (final pending in _pendingDeletes.values) {
      pending.timer.cancel();
      _recipeService.optimisticRestoreAt(pending.recipe, pending.originalIndex);
    }
    _pendingDeletes.clear();
  }

  Future<void> _commitDelete(String recipeId) async {
    final pending = _pendingDeletes.remove(recipeId);
    if (pending == null) return;

    pending.timer.cancel();
    try {
      await _recipeService.deleteRecipe(recipeId);
    } catch (e) {
      AppLogger.error('Failed to delete recipe $recipeId: $e');
      _recipeService.optimisticRestoreAt(pending.recipe, pending.originalIndex);
      _invalidateCache();
      _notifyParent();
      _onError(recipeId);
    }
  }

  void dispose() {
    cancelAll();
  }
}
