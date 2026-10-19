// lib/services/offline/upload_completion.dart
//
// BUT-2294: the second step of an upload-queue row. The first step puts the
// image in Storage; this one uses it (adds it to a recipe, a cook snap, a
// comment, a message or the profile). The queue picks the handler by the
// row's entity type.
library;

import 'dart:convert';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';

enum CompletionOutcome {
  /// The image is in use; the row and its file on the device are done with.
  done,

  /// Other rows of the same group are not up yet. The row stays `uploaded`
  /// and is completed with the last of them.
  waitingForGroup,

  /// The row was thrown away or taken out of the queue before the image was
  /// used; nothing was written. The queue takes the image back.
  discarded,

  /// What the image was for no longer exists. Nothing was written and the
  /// image is not in use; the queue takes it back and drops the row.
  targetGone,
}

/// The statuses of a row the queue still sends.
const _liveStatuses = ['pending', 'uploading', 'uploaded', 'failed'];

/// Whether [row] is still the queue's to send: it exists, is [userId]'s, is
/// not waiting for the user and was not thrown away.
bool uploadRowIsLive(UploadQueueEntry? row, String userId) =>
    row != null &&
    row.userId == userId &&
    !row.permanentlyFailed &&
    _liveStatuses.contains(row.status);

/// The statuses [uploadRowIsLive] accepts, for queries.
const liveUploadStatuses = _liveStatuses;

/// Uses an uploaded image. Throws when it could not: a failure
/// `permanentFailureReason` recognises waits for the user, any other is
/// retried on the queue's schedule without uploading the image again.
abstract interface class UploadCompletion {
  /// [row] has status `uploaded`, so `uploadedUrl` is set.
  Future<CompletionOutcome> complete(UploadQueueEntry row, String userId);
}

/// An image of a recipe: its address goes into the recipe on the device and
/// into the sync queue, and the upload and its file on the device are done
/// with. One transaction, so a restart never leaves the upload gone without
/// the address queued.
class RecipeImageCompletion implements UploadCompletion {
  RecipeImageCompletion({
    required AppDatabase database,
    required OfflineUserStorage storage,
  }) : _db = database,
       _storage = storage;

  final AppDatabase _db;
  final OfflineUserStorage _storage;

  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async {
    final url = row.uploadedUrl!;
    final outcome = await _db.transaction(() async {
      // Read again inside the transaction: a discard since the queue last
      // looked must not publish the image.
      final current = await _db.uploadQueueDao.getUpload(row.id);
      if (!uploadRowIsLive(current, userId)) {
        return CompletionOutcome.discarded;
      }
      final recipeId = row.entityType == SyncQueueEntityType.recipe
          ? row.entityId
          : null;
      final stored = recipeId == null
          ? null
          : await _db.recipeDao.getRecipe(recipeId, userId);
      if (stored == null) {
        AppLogger.warning(
          '⚠️ Receptet finns inte på enheten; bilden läggs inte till',
        );
        return CompletionOutcome.targetGone;
      }
      final recipe = Recipe.fromJson(
        jsonDecode(stored.recipeJson) as Map<String, dynamic>,
      );
      if (!recipe.imageUrls.contains(url)) {
        recipe.core
          ..imageUrls = [...recipe.imageUrls, url]
          ..thumbnailUrl ??= row.uploadedThumbnailUrl;
        await _storage.saveRecipeForUser(
          recipe,
          userId,
          queueTagging: false,
        );
      }
      await _db.uploadQueueDao.markCompleted(row.id);
      return CompletionOutcome.done;
    });
    if (outcome != CompletionOutcome.discarded) {
      await _storage.deleteUploadFile(row.localPath);
    }
    return outcome;
  }
}
