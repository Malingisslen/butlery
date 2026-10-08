import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/recipe_revision_record.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/daos/upload_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Handles user-specific storage operations for offline service
/// Now uses Drift database instead of Hive
class OfflineUserStorage {
  final AppDatabase _database;
  final RecipeDao _recipeDao;
  final SyncQueueDao _syncQueueDao;
  final UploadQueueDao _uploadQueueDao;
  final Future<Directory> Function() _uploadsRoot;

  /// [uploadsRoot] is where queued images are kept on the device until they
  /// reach the server; by default a folder in the app's documents, which
  /// the system does not clear the way it clears the picker's cache.
  OfflineUserStorage({
    required AppDatabase database,
    Future<Directory> Function()? uploadsRoot,
  }) : _database = database,
       _recipeDao = database.recipeDao,
       _syncQueueDao = database.syncQueueDao,
       _uploadQueueDao = database.uploadQueueDao,
       _uploadsRoot = uploadsRoot ?? _defaultUploadsRoot;

  static Future<Directory> _defaultUploadsRoot() async => Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'offline_uploads'),
  );

  /// Get recipes for specific user
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    try {
      final offlineRecipes = await _recipeDao.getRecipesForUser(userId);
      final recipes = <Recipe>[];

      for (final offlineRecipe in offlineRecipes) {
        try {
          final json =
              jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
          recipes.add(Recipe.fromJson(json));
        } catch (e) {
          AppLogger.warning('Failed to parse recipe ${offlineRecipe.id}: $e');
        }
      }

      AppLogger.info(
        '📦 Found ${recipes.length} offline recipes for user: ${userId.maskedUserId}',
      );
      return recipes;
    } catch (e) {
      AppLogger.error('❌ Error getting user recipes: $e');
      return [];
    }
  }

  /// Keeps [recipe] on the device and queues its write to the server, online
  /// as offline (BUT-2162): the queue sends it at once when there is a
  /// network and keeps it across restarts when there is none. Returns the
  /// write's opId.
  ///
  /// With [queueTagging], a recipe whose tags still have to be made also gets
  /// a tagging entry that waits for the write (`dependsOn`). The retagging
  /// itself saves without it, so a recipe that tags to zero coverage does not
  /// queue itself again.
  Future<String> saveRecipeForUser(
    Recipe recipe,
    String userId, {
    SyncOperation operation = SyncOperation.update,
    bool queueTagging = true,
  }) async {
    try {
      // The base is read, and the copy and its entry written, in one
      // transaction, so a send finishing in between cannot move the copy's
      // revision under the base taken from it (BUT-2213).
      return await _database.transaction(
        () => _saveRecipe(recipe, userId, operation, queueTagging),
      );
    } catch (e) {
      AppLogger.error('❌ Error saving recipe offline: $e');
      rethrow;
    }
  }

  Future<String> _saveRecipe(
    Recipe recipe,
    String userId,
    SyncOperation operation,
    bool queueTagging,
  ) async {
    final recipeJson = await _withRevisionBase(recipe, userId, operation);
    final opId = const Uuid().v4();
    // An edit of a recipe whose create has not reached the server goes
    // down with that create if it fails for good (produktregler.md:187).
    final createOpId = operation == SyncOperation.create
        ? null
        : await _syncQueueDao.pendingCreateOpId(userId, recipe.id);

    await _recipeDao.upsertRecipe(
      id: recipe.id,
      userId: userId,
      recipeJson: recipeJson,
      needsSync: true,
    );
    await _syncQueueDao.enqueue(
      userId: userId,
      recipeId: recipe.id,
      operation: operation,
      opId: opId,
      dependsOn: [?createOpId],
    );

    // H9: Queue for tagging if recipe has failed/pending tagging
    final tagResult = recipe.core.tagResult;
    if (queueTagging && tagResult != null && _needsRetagging(tagResult)) {
      await _syncQueueDao.enqueue(
        userId: userId,
        recipeId: recipe.id,
        operation: SyncOperation.tag,
        dependsOn: [opId],
      );
      AppLogger.debug(
        '📋 Queued offline tagging for recipe: ${recipe.title}',
      );
    }

    AppLogger.info(
      '💾 Recipe queued for user ${userId.maskedUserId}: ${recipe.title}',
    );
    return opId;
  }

  /// Removes the recipe from the device and queues its deletion on the
  /// server. A create of it that has not reached the server is named in
  /// `dependsOn`, so the server never deletes before it creates and a create
  /// that fails for good takes the deletion with it (produktregler.md:187).
  ///
  /// Returns false, and queues nothing, when its deletion is already queued.
  /// The recipe's images still waiting to go up are cancelled: there is no
  /// recipe left to show them on.
  Future<bool> queueDeleteForUser(String recipeId, String userId) async {
    if (await _syncQueueDao.hasQueuedDelete(userId, recipeId)) return false;
    final createOpId = await _syncQueueDao.pendingCreateOpId(userId, recipeId);
    await _recipeDao.deleteRecipe(recipeId, userId);
    for (final upload in await _uploadQueueDao.getUploadsForEntity(
      recipeId,
      SyncQueueEntityType.recipe,
    )) {
      if (upload.userId != userId) continue;
      await _uploadQueueDao.cancelUpload(upload.id);
      await deleteUploadFile(upload.localPath);
    }
    await _syncQueueDao.enqueue(
      userId: userId,
      recipeId: recipeId,
      operation: SyncOperation.delete,
      dependsOn: [?createOpId],
    );
    AppLogger.info(
      '🗑️ Recipe deletion queued for user ${userId.maskedUserId}: $recipeId',
    );
    return true;
  }

  /// Keeps a copy of the image at [imagePath] on the device and queues its
  /// upload as an image of the recipe [recipeId] (BUT-2162). The upload waits for a create of
  /// the recipe that has not reached the server, so it goes down with that
  /// create if it fails for good (produktregler.md:187). Returns the
  /// upload's id.
  Future<String> queueRecipeImageForUser(
    String imagePath,
    String recipeId,
    String userId,
  ) async {
    final image = File(imagePath);
    final id = const Uuid().v4();
    final folder = Directory(p.join((await _uploadsRoot()).path, userId));
    await folder.create(recursive: true);
    final copy = await image.copy(
      p.join(folder.path, '$id${p.extension(image.path)}'),
    );
    final createOpId = await _syncQueueDao.pendingCreateOpId(userId, recipeId);
    await _uploadQueueDao.queueUpload(
      id: id,
      userId: userId,
      localPath: copy.path,
      targetPath: 'users/$userId/recipes',
      fileSizeBytes: await copy.length(),
      entityId: recipeId,
      entityType: SyncQueueEntityType.recipe,
      dependsOn: [?createOpId],
    );
    AppLogger.info('📷 Image queued for recipe $recipeId');
    return id;
  }

  /// Removes a queued image's copy from the device. A copy that is already
  /// gone is fine.
  Future<void> deleteUploadFile(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Whether the device holds a write of the recipe the server has not
  /// confirmed.
  Future<bool> hasUnsentWrite(String recipeId, String userId) =>
      _syncQueueDao.hasEntriesForRecipe(userId, recipeId);

  /// H9: Check if a recipe needs retagging based on its tagResult.
  ///
  /// The marker set must stay in sync with every PRODUCER that writes one —
  /// the two ingredient cascades AND the bulk-retag drain callable, which is
  /// where `outdated` comes from. "Cascade" alone under-described the list
  /// it heads.
  /// `stale-properties` (written by `on-ingredient-properties-changed.ts`) was
  /// missing: those recipes were marked and then never retagged, and the
  /// `coverage == 0.0` fallback does not rescue them because the existing
  /// tagResult keeps its coverage. That cascade exists to keep ALLERGEN data
  /// current when an ingredient's properties change, so the silently-skipped
  /// recipes were the allergen-relevant ones. It was dormant only because the
  /// cascade's query read a collection that does not exist (BUT-1781).
  bool _needsRetagging(TagResult tagResult) {
    // Check for explicit failure markers
    final version = tagResult.generatorVersion;
    if (version == 'failed' ||
        version == 'pending' ||
        version == 'stale-ingredient' ||
        version == 'stale-properties' ||
        // Written by the bulk-retag drain callable. `STALE_TAG_MARKERS` in
        // cleanup-deleted-ingredients.ts names all three and says this list is
        // its counterpart — so omitting it made that comment false. The online
        // path catches it anyway via TagResult's version-mismatch branch; this
        // is the offline enqueue, which matches on the literal.
        version == 'outdated') {
      return true;
    }

    // Zero coverage also indicates needs retagging
    if (tagResult.coverage == 0.0) {
      return true;
    }

    return false;
  }

  /// Tags the device's copy of [recipeId] with what [tag] makes of it and
  /// queues the result. Returns false when there was nothing to tag, or the
  /// copy changed or went while [tag] ran.
  ///
  /// BUT-2296: [tag] is a network call. A recipe the user threw away in the
  /// meantime must not come back into the queue, and an edit made in the
  /// meantime must not be overwritten by tags of the older text.
  Future<bool> retagRecipeForUser(
    String recipeId,
    String userId,
    Future<TagResult?> Function(Recipe recipe) tag,
  ) async {
    final before = await _recipeDao.getRecipe(recipeId, userId);
    if (before == null) return false;
    final Recipe recipe;
    try {
      recipe = Recipe.fromJson(
        jsonDecode(before.recipeJson) as Map<String, dynamic>,
      );
    } catch (e) {
      AppLogger.error('❌ Error reading recipe $recipeId: $e');
      return false;
    }
    final tagResult = await tag(recipe);
    if (tagResult == null) return false;
    return _database.transaction(() async {
      final now = await _recipeDao.getRecipe(recipeId, userId);
      if (now?.recipeJson != before.recipeJson) return false;
      await saveRecipeForUser(
        Recipe(
          core: recipe.core.copyWith(tagResult: tagResult),
          type: recipe.type,
          socialData: recipe.socialData,
          realtimeData: recipe.realtimeData,
          offlineData: recipe.offlineData,
          rev: recipe.rev,
        ),
        userId,
        queueTagging: false,
      );
      return true;
    });
  }

  /// The device copy's JSON for [recipe]: a create carries no revision, and
  /// an update the revision it is built on ([RecipeRevisionRecord.baseFor]),
  /// with the record of the revisions this device produced kept.
  Future<String> _withRevisionBase(
    Recipe recipe,
    String userId,
    SyncOperation operation,
  ) async {
    final json = recipe.toJson();
    if (operation == SyncOperation.create) {
      return jsonEncode(json..remove('rev'));
    }
    final row = await _recipeDao.getRecipe(recipe.id, userId);
    final stored = row == null
        ? null
        : jsonDecode(row.recipeJson) as Map<String, dynamic>;
    final base = RecipeRevisionRecord.baseFor(recipe.rev, stored);
    if (base == null) {
      json.remove('rev');
    } else {
      json['rev'] = base;
    }
    final own = stored?[RecipeRevisionRecord.key];
    if (own != null) json[RecipeRevisionRecord.key] = own;
    return jsonEncode(json);
  }

  /// Get specific offline recipe for user
  Future<Recipe?> getRecipeForUser(String recipeId, String userId) async {
    try {
      final offlineRecipe = await _recipeDao.getRecipe(recipeId, userId);
      if (offlineRecipe == null) return null;

      final json = jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
      return Recipe.fromJson(json);
    } catch (e) {
      AppLogger.error('❌ Error getting recipe $recipeId: $e');
      return null;
    }
  }

  /// Clear data for specific user.
  ///
  /// Throws when any part fails: "Logga ut och släng" must not report a
  /// discard that left changes or image copies on the device.
  Future<void> clearUserData(String userId) async {
    final count = await _recipeDao.countForUser(userId);
    await _database.clearUserData(userId);
    // The queue's copies of the user's images, "Försök mindre" copies too.
    final uploads = Directory(p.join((await _uploadsRoot()).path, userId));
    try {
      if (await uploads.exists()) await uploads.delete(recursive: true);
    } on FileSystemException catch (e) {
      // The path names the uid, and callers hand the error to Crashlytics.
      throw FileSystemException(
        'Could not delete queued images',
        '',
        e.osError,
      );
    }

    AppLogger.success(
      '✅ Cleared offline data for user: ${userId.maskedUserId} ($count recipes)',
    );
  }

  /// Get count of offline recipes for user
  Future<int> getRecipeCountForUser(String userId) async {
    return await _recipeDao.countForUser(userId);
  }

  /// Watch recipes for a user (reactive stream)
  Stream<List<Recipe>> watchRecipesForUser(String userId) {
    return _recipeDao.watchRecipesForUser(userId).map((offlineRecipes) {
      final recipes = <Recipe>[];
      for (final offlineRecipe in offlineRecipes) {
        try {
          final json =
              jsonDecode(offlineRecipe.recipeJson) as Map<String, dynamic>;
          recipes.add(Recipe.fromJson(json));
        } catch (e) {
          AppLogger.warning('Failed to parse recipe ${offlineRecipe.id}: $e');
        }
      }
      return recipes;
    });
  }
}
