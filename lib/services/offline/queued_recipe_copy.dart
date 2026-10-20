// lib/services/offline/queued_recipe_copy.dart
//
// "Spara som kopia", split out of sync_queue_reader.dart
// to keep that file under the size limit. sync_queue_reader.dart re-exports it,
// so callers keep one import.
library;

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/queued_change.dart';

/// "Spara som kopia": the device's content of the
/// recipe [change] writes is kept as a new recipe of the user's own, queued
/// as a create, and the failed entry leaves the queue. The recipe's other
/// entries stay as they are.
///
/// The copy gets a new id ([newId], else a UUID v4), is the user's personal
/// recipe (no sharing, created by her) and keeps everything else, the shared
/// description included; its title is [copyTitle] of the original's (Q6-14 =
/// C: "(kopia)" appended, so the user sees which one is the copy). One
/// transaction: either the copy is queued and the failure is gone, or
/// nothing changed. Throws [StateError] when the device has no copy of the
/// recipe to keep; the failure then stays.
Future<String> saveQueuedChangeAsCopy(
  AppDatabase db,
  String userId,
  QueuedChange change, {
  String? newId,
  String Function(String title)? copyTitle,
}) {
  if (change.kind != QueuedChangeKind.recipe) {
    throw ArgumentError.value(change.kind, 'change.kind', 'not a recipe');
  }
  return db.transaction(() async {
    final entry =
        await (db.select(db.syncQueueEntries)..where(
              (e) => e.userId.equals(userId) & e.opId.equals(change.id),
            ))
            .getSingleOrNull();
    if (entry == null) throw StateError('The change is no longer queued');
    final stored = await db.recipeDao.getRecipe(entry.recipeId, userId);
    if (stored == null) throw StateError('The device has no copy to keep');

    final id = newId ?? const Uuid().v4();
    final copy = ownCopyOfRecipeJson(
      jsonDecode(stored.recipeJson) as Map<String, dynamic>,
      id: id,
      userId: userId,
      copyTitle: copyTitle,
    );
    await db.recipeDao.upsertRecipe(
      id: id,
      userId: userId,
      recipeJson: jsonEncode(copy),
      needsSync: true,
    );
    await db.syncQueueDao.enqueue(
      userId: userId,
      recipeId: id,
      operation: SyncOperation.create,
    );
    await (db.delete(
      db.syncQueueEntries,
    )..where((e) => e.id.equals(entry.id))).go();
    return id;
  });
}

/// A stored recipe as the user's own new recipe [id]: personal, created by
/// [userId], with no sharing, collaboration or offline state carried over.
/// Reads the stored shape through [Recipe.fromJson], so a nested or a flat
/// record both work.
///
/// Q6-14 = C (produktbeslut 2026-09-27b): the shared description
/// (socialData.descriptionCollaborative) comes along, and the title is
/// [copyTitle] of the original's when given. Who the recipe was shared with
/// (memberPermissions, grants and the share groups in categoryIds) does not:
/// the copy is private, and a group id without a grant would be a revoke row
/// that matches nobody (RecipeShareGrants.mergeCategoryIds).
Map<String, dynamic> ownCopyOfRecipeJson(
  Map<String, dynamic> stored, {
  required String id,
  required String userId,
  String Function(String title)? copyTitle,
}) {
  final recipe = Recipe.fromJson(stored);
  final now = clock.now().toIso8601String();
  final core = recipe.core.toJson()
    ..['id'] = id
    ..['createdBy'] = userId
    ..['isPublic'] = false
    ..['createdAt'] = now
    ..['updatedAt'] = now;
  if (copyTitle != null) core['title'] = copyTitle(recipe.title);
  final sharedDescription = recipe.socialData?.descriptionCollaborative;
  return Recipe.fromJson({
    'core': core,
    'type': RecipeType.personal.index,
    if (sharedDescription != null && sharedDescription.isNotEmpty)
      'socialData': RecipeSocialData(
        ownerId: userId,
        descriptionCollaborative: sharedDescription,
      ).toJson(),
  }).toJson();
}
