// lib/viewmodels/recipe_list/recipe_delete_manager.dart

import 'package:clock/clock.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

class PendingDelete {
  final String recipeId;
  final Recipe recipe;
  final int originalIndex;
  final DateTime createdAt;

  PendingDelete({
    required this.recipeId,
    required this.recipe,
    required this.originalIndex,
    required this.createdAt,
  });
}

/// Manages optimistic recipe deletion with multi-pending undo support.
///
/// A delete stays pending until the view commits it with [commitDeletes],
/// which it does when the Ångra snackbar closes (`UndoSnackBar.showDeferred`).
/// There is no timer here: a timer of its own would commit while Ångra is
/// still on screen, because the snackbar's window starts later than the
/// delete (after its entrance animation, and only at the head of the queue).
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

  /// Optimistically delete a single recipe. It stays pending until
  /// [commitDeletes] or an undo.
  void deleteRecipe(String recipeId) {
    if (_pendingDeletes.containsKey(recipeId)) return;

    final recipe = _recipeService.getRecipeById(recipeId);
    if (recipe == null) return;

    final index = _recipeService.optimisticRemoveWithIndex(recipeId);
    _invalidateCache();
    _notifyParent();

    _pendingDeletes[recipeId] = PendingDelete(
      recipeId: recipeId,
      recipe: recipe,
      originalIndex: index,
      createdAt: clock.now(),
    );
  }

  /// Undo delete of a specific recipe by ID.
  void undoDeleteById(String recipeId) {
    final pending = _pendingDeletes.remove(recipeId);
    if (pending == null) return;

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

  /// Optimistically delete the selected recipes as one batch. Returns the ids
  /// that became pending, for [commitDeletes].
  Set<String> deleteSelected(Set<String> ids) {
    _lastBulkBatchIds = Set.from(ids);
    final batch = <String>{};

    for (final id in ids) {
      if (_pendingDeletes.containsKey(id)) continue;

      final recipe = _recipeService.getRecipeById(id);
      if (recipe == null) continue;

      final index = _recipeService.optimisticRemoveWithIndex(id);

      _pendingDeletes[id] = PendingDelete(
        recipeId: id,
        recipe: recipe,
        originalIndex: index,
        createdAt: clock.now(),
      );
      batch.add(id);
    }

    _invalidateCache();
    _notifyParent();
    return batch;
  }

  /// Commit the pending deletes among [ids]. Ids that were undone, restored
  /// or already committed are skipped.
  Future<void> commitDeletes(Iterable<String> ids) async {
    await Future.wait(ids.toList().map(_commitDelete));
  }

  /// Undo the last bulk delete batch.
  void undoBulkDelete() {
    if (_lastBulkBatchIds == null) return;

    // Restore in reverse order to maintain correct indices
    final idsToRestore = _lastBulkBatchIds!.toList();
    for (final id in idsToRestore.reversed) {
      final pending = _pendingDeletes.remove(id);
      if (pending != null) {
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
      _recipeService.optimisticRestoreAt(pending.recipe, pending.originalIndex);
    }
    _pendingDeletes.clear();
  }

  Future<void> _commitDelete(String recipeId) async {
    final pending = _pendingDeletes.remove(recipeId);
    if (pending == null) return;

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
