// lib/services/offline/queued_recipe_send.dart
//
// BUT-2162: how the offline queue's sender puts one recipe entry on the
// server. BUT-2213: a queued edit that meets a newer server version is not
// written; the device takes the server's recipe and the conflict is handed on.
library;

import 'dart:async';
import 'dart:convert';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';

class QueuedRecipeSend {
  QueuedRecipeSend({
    required RecipeDao recipeDao,
    required SyncQueueDao syncQueueDao,
    required this.sendTimeout,
    void Function(String recipeId)? onRecipeSent,
    RecipeConflictCallback? onRecipeConflict,
  }) : _recipeDao = recipeDao,
       _syncQueueDao = syncQueueDao,
       _onRecipeSent = onRecipeSent,
       _onRecipeConflict = onRecipeConflict;

  final RecipeDao _recipeDao;
  final SyncQueueDao _syncQueueDao;
  final Duration sendTimeout;
  final void Function(String recipeId)? _onRecipeSent;
  final RecipeConflictCallback? _onRecipeConflict;

  /// Sends [item] through [writer] and removes it from the queue once the
  /// server has answered. Returns whether the server saved it: false for an
  /// entry with nothing left to send and for a conflict. Throws when the
  /// attempt failed; the entry is then untouched.
  Future<bool> send(
    SyncQueueEntry item,
    String userId,
    QueuedRecipeWriter writer,
  ) async {
    if (item.operation == SyncOperation.delete.name) {
      try {
        await writer.delete(item.recipeId).timeout(sendTimeout);
      } on ResourceNotFoundException {
        // Already gone: a create that never reached the server, or an
        // earlier attempt whose answer was lost.
      }
      await _syncQueueDao.dequeue(item.id);
      _onRecipeSent?.call(item.recipeId);
      AppLogger.success('✅ Raderade recept: ${item.recipeId}');
      return true;
    }

    final offlineRecipe = await _recipeDao.getRecipe(item.recipeId, userId);
    if (offlineRecipe == null) {
      // The device copy is gone: the user deleted the recipe on the device,
      // and its deletion is queued behind this entry.
      await _syncQueueDao.dequeue(item.id);
      AppLogger.info('🗑️ Tog bort invalid sync entry: ${item.recipeId}');
      return false;
    }
    if (!offlineRecipe.needsSync) {
      await _syncQueueDao.dequeue(item.id);
      AppLogger.info('✅ Recept ${item.recipeId} behöver inte synkas längre');
      _onRecipeSent?.call(item.recipeId);
      return false;
    }

    final json = jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
    final recipe = Recipe.fromJson(json);
    AppLogger.info('📤 Synkar recept: ${recipe.id}');

    // One attempt: the queue's own schedule is the backoff
    // (produktregler.md:188), so a failure goes back to the queue at once.
    final created = item.operation == SyncOperation.create.name;
    final int newRev;
    try {
      newRev = created
          ? await writer.create(recipe).timeout(sendTimeout)
          : await writer.update(recipe).timeout(sendTimeout);
    } on RecipeRevisionConflictException catch (conflict) {
      await _takeServerVersion(
        item,
        userId,
        offlineRecipe.recipeJson,
        recipe,
        conflict.remote,
      );
      return false;
    }

    // Sync succeeded - mark as synced in Drift, then leave the queue.
    await _recipeDao.markSyncedIfUnchanged(
      item.recipeId,
      userId,
      offlineRecipe.recipeJson,
    );
    await _recipeDao.advanceRev(
      item.recipeId,
      userId,
      sentRev: recipe.rev,
      newRev: newRev,
      created: created,
    );
    await _syncQueueDao.dequeue(item.id);
    _onRecipeSent?.call(item.recipeId);
    AppLogger.success('✅ Synkade recept: ${recipe.id}');
    return true;
  }

  /// A conflict is not a failure (produktregler.md:189): the entry leaves
  /// the queue. While the device still holds [sentJson], the copy the entry
  /// sent, it takes the server's recipe and the device's version goes to
  /// [_onRecipeConflict] for the user to choose. A copy saved while the
  /// write was on its way is newer than [local] and is left with its own
  /// queue entry, which meets the same conflict and is handed on then.
  Future<void> _takeServerVersion(
    SyncQueueEntry item,
    String userId,
    String sentJson,
    Recipe local,
    Recipe remote,
  ) async {
    final replaced = await _recipeDao.replaceIfUnchanged(
      item.recipeId,
      userId,
      sentJson: sentJson,
      serverJson: jsonEncode(remote.toJson()),
    );
    await _syncQueueDao.dequeue(item.id);
    if (!replaced) {
      AppLogger.info('⚠️ Receptet ${item.recipeId} ändrades under sändningen');
      return;
    }
    _onRecipeSent?.call(item.recipeId);
    AppLogger.warning('⚠️ Receptet ${item.recipeId} ändrades på servern');
    try {
      _onRecipeConflict?.call(local, remote);
    } catch (e) {
      AppLogger.error('❌ Konfliktbeskedet kunde inte lämnas vidare', e);
    }
  }
}
