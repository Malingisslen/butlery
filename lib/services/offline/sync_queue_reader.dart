// lib/services/offline/sync_queue_reader.dart
//
// P4-U19: the native side of the "Väntar på synk" view. Reads both queues of
// schema 3 (P5-U35) and acts on one entry at the user's request. The web has
// no offline queue (sync_queue_reader_web.dart).
//
// P6-U08b: schema 4's retry time, and the two actions a permanent failure
// gains: "Spara som kopia" and "Försök mindre"
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/services/offline/image_group_queue.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/offline/unsent_image_expiry.dart';

export 'package:butlery/services/offline/queued_recipe_copy.dart';

/// Upload statuses that still count as waiting, as in
/// AppDatabase.watchQueueCounts. "uploaded" is in Storage but not yet used,
/// and the sign-out warning counts it, so the list must show it too.
const _waitingUploadStatuses = ['pending', 'uploading', 'uploaded', 'failed'];

/// Every change of [userId] that has not reached the server, live, across
/// the sync queue and the upload queue. Re-read whenever either table (or a
/// recipe title) changes.
Stream<List<QueuedChange>> watchQueuedChanges(AppDatabase db, String userId) {
  return db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.syncQueueEntries,
          db.uploadQueueEntries,
          db.offlineRecipes,
        },
      )
      .watch()
      .asyncMap((_) => readQueuedChanges(db, userId));
}

/// One read of [watchQueuedChanges].
Future<List<QueuedChange>> readQueuedChanges(
  AppDatabase db,
  String userId,
) async {
  final syncRows = await (db.select(
    db.syncQueueEntries,
  )..where((e) => e.userId.equals(userId))).get();
  final uploadRows =
      await (db.select(db.uploadQueueEntries)..where(
            (e) =>
                e.userId.equals(userId) &
                (e.status.isIn(_waitingUploadStatuses) |
                    (e.permanentlyFailed.equals(true) &
                        e.status.isNotIn(const ['completed', 'cancelled']))),
          ))
          .get();

  final recipeIds = <String>{
    for (final row in syncRows)
      if (row.entityType == SyncQueueEntityType.recipe) row.recipeId,
    for (final row in uploadRows)
      if (row.entityType == SyncQueueEntityType.recipe && row.entityId != null)
        row.entityId!,
  };
  final titles = await _recipeTitles(db, userId, recipeIds);

  // An entry waits on an earlier one when one of its dependsOn opIds is still
  // in either queue.
  final queuedIds = <String>{
    for (final row in syncRows) row.opId,
    for (final row in uploadRows) row.id,
  };
  bool waits(String? stored) => decodeDependsOn(stored).any(queuedIds.contains);

  return [
    for (final row in syncRows)
      QueuedChange(
        kind: QueuedChangeKind.recipe,
        id: row.opId,
        operation: _operation(row.operation),
        queuedAt: row.queuedAt,
        subject: row.entityType == SyncQueueEntityType.recipe
            ? titles[row.recipeId]
            : null,
        needsUser: row.permanentlyFailed,
        reason: QueuedChangeReason.parse(row.lastError),
        waitsOnEarlier: !row.permanentlyFailed && waits(row.dependsOn),
        nextAttemptAt: row.permanentlyFailed ? null : row.nextAttemptAt,
      ),
    for (final row in uploadRows.where((r) => !isImageGroupRow(r)))
      QueuedChange(
        kind: QueuedChangeKind.image,
        id: row.id,
        operation: QueuedOperation.upload,
        queuedAt: row.queuedAt,
        subject: row.entityType == SyncQueueEntityType.recipe
            ? titles[row.entityId]
            : null,
        needsUser: row.permanentlyFailed,
        reason: QueuedChangeReason.parse(row.lastError),
        waitsOnEarlier: !row.permanentlyFailed && waits(row.dependsOn),
        entityType: row.entityType,
        entityId: row.entityId,
        unsentSince: row.permanentlyFailed
            ? unsentImageSince(
                row.firstFailedAt,
                row.queuedAt,
                retriedAt: row.retriedAt,
              )
            : null,
      ),
    for (final group in imageGroups(uploadRows).values)
      imageGroupChange(group, waits),
  ];
}

/// "Försök igen": the entry leaves "Väntar på dig" and the queue sends it
/// again from the start. Nothing is deleted.
Future<void> retryQueuedChange(
  AppDatabase db,
  QueuedChange change, {
  required String userId,
}) async {
  switch (change.kind) {
    case QueuedChangeKind.recipe:
      await (db.update(
        db.syncQueueEntries,
      )..where((e) => e.opId.equals(change.id))).write(
        const SyncQueueEntriesCompanion(
          permanentlyFailed: Value(false),
          retryCount: Value(0),
          lastError: Value(null),
          // A fresh start: sent at the next pass, with a new 24 h window.
          nextAttemptAt: Value(null),
          firstFailedAt: Value(null),
        ),
      );
    case QueuedChangeKind.image when change.isImageGroup:
      await retryImageGroup(db, userId, change.entityType!, change.entityId!);
    case QueuedChangeKind.image:
      await (db.update(
        db.uploadQueueEntries,
      )..where((e) => e.id.equals(change.id))).write(
        UploadQueueEntriesCompanion(
          permanentlyFailed: const Value(false),
          status: const Value('pending'),
          retryCount: const Value(0),
          lastError: const Value(null),
          nextAttemptAt: const Value(null),
          // A new 24 h limit, and the 30 days an unsent photo waits start over.
          firstFailedAt: const Value(null),
          retriedAt: Value(clock.now()),
        ),
      );
  }
}

/// "Släng ändringen", chosen by the user and not undone within the Ångra
/// window (class 1). What depended on the change can
/// never be sent without it, so its dependants are marked as failed and stay
/// for her to decide on ("aldrig halvvägs"). Only the
/// chosen entry itself goes.
///
/// One transaction: either the chain is marked and the entry is gone, or
/// nothing changed. The chosen entry is removed inside it, so it never stays
/// behind with its own cause overwritten by "dependency-failed".
///
/// Q6-11 = B: an entry that creates a recipe the server has never had
/// ([QueuedChange.isNeverSyncedRecipe]) takes that recipe with it, since the
/// device's copy is the only one and the user chose to throw it away after a
/// confirmation that said so. Otherwise it would stay on the phone and never
/// be sent. What was queued behind that create for the same recipe (later
/// edits of it, its photo uploads) goes with it in the same transaction:
/// they belong to the recipe she threw away and could never be sent or
/// kept as a copy, so leaving them under Väntar på dig would only offer
/// choices that fail.
///
/// Returns the id of the recipe whose queued write was thrown away, so the
/// recipe screens can drop the local version (BUT-2295). Null for an image.
Future<String?> discardQueuedChange(
  AppDatabase db,
  String userId,
  QueuedChange change,
) async {
  // BUT-2295: the cancelled uploads' copies on the device, removed once the
  // transaction has committed so a rollback never loses a file it still needs.
  final cancelledFiles = <String>[];
  String? discardedRecipeId;
  await db.transaction(() async {
    // A group's id is the snap's or comment's, which no row or dependsOn names.
    final chain = change.isImageGroup
        ? <String>{change.id}
        : await db.markChainPermanentlyFailed(
            userId,
            change.id,
            reason: QueuedChangeReason.dependencyFailed.code,
          );
    switch (change.kind) {
      case QueuedChangeKind.recipe:
        final entry =
            await (db.select(db.syncQueueEntries)..where(
                  (e) => e.userId.equals(userId) & e.opId.equals(change.id),
                ))
                .getSingleOrNull();
        await (db.delete(
          db.syncQueueEntries,
        )..where((e) => e.opId.equals(change.id))).go();
        discardedRecipeId = entry?.recipeId;
        if (entry != null && change.isNeverSyncedRecipe) {
          final dependants = chain.difference({change.id}).toList();
          if (dependants.isNotEmpty) {
            // Only the recipe's own entries: anything else in the chain
            // keeps its "dependency-failed" mark and waits for her.
            await (db.delete(db.syncQueueEntries)..where(
                  (e) =>
                      e.userId.equals(userId) &
                      e.opId.isIn(dependants) &
                      e.recipeId.equals(entry.recipeId),
                ))
                .go();
            final uploads =
                await (db.select(db.uploadQueueEntries)..where(
                      (e) => e.userId.equals(userId) & e.id.isIn(dependants),
                    ))
                    .get();
            for (final upload in uploads) {
              await db.uploadQueueDao.cancelUpload(upload.id);
              cancelledFiles.add(upload.localPath);
            }
          }
          await db.recipeDao.deleteRecipe(entry.recipeId, userId);
        }
      case QueuedChangeKind.image when change.isImageGroup:
        // A snap or comment with fewer photos than the user took is not what
        // they sent, so the group goes as one.
        final group = await db.uploadQueueDao.getGroup(
          userId,
          change.entityType!,
          change.entityId!,
        );
        for (final photo in group) {
          if (photo.status == 'completed' || photo.status == 'cancelled') {
            continue;
          }
          await db.uploadQueueDao.cancelUpload(photo.id);
          cancelledFiles.add(photo.localPath);
        }
      case QueuedChangeKind.image:
        final upload =
            await (db.select(db.uploadQueueEntries)..where(
                  (e) => e.userId.equals(userId) & e.id.equals(change.id),
                ))
                .getSingleOrNull();
        await db.uploadQueueDao.cancelUpload(change.id);
        if (upload != null) cancelledFiles.add(upload.localPath);
    }
  });
  for (final path in cancelledFiles) {
    await _deleteQuietly(path);
  }
  return discardedRecipeId;
}

/// A queued image's copy that is already gone is fine.
Future<void> _deleteQuietly(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Already gone.
  }
}

/// The recipe-image budget: "Receptbild, komprimerad ≤ 250 kB, långsida
/// ≤ 1600 px".
const int kRecipeImageMaxBytes = 250 * 1024;
const int kRecipeImageMaxSide = 1600;

/// Makes the image at a path smaller, or returns null when it cannot.
typedef ImageShrinker = Future<Uint8List?> Function(String path);

/// Width and height from an image's header, or null for a format
/// package:image cannot read (HEIC, a broken file).
(int, int)? recipeImageSize(Uint8List bytes) {
  final img.DecodeInfo? info;
  try {
    info = img.findDecoderForData(bytes)?.startDecode(bytes);
  } on Object {
    // package:image throws RangeError on a truncated header.
    return null;
  }
  if (info == null || info.width <= 0 || info.height <= 0) return null;
  return (info.width, info.height);
}

/// Whether [bytes] is an image within the recipe-image budget: at most
/// 250 kB and a long side of at most 1600 px.
bool fitsRecipeImageBudget(Uint8List bytes) {
  if (bytes.length > kRecipeImageMaxBytes) return false;
  final size = recipeImageSize(bytes);
  return size != null && math.max(size.$1, size.$2) <= kRecipeImageMaxSide;
}

/// The value to pass FlutterImageCompress as both minWidth and minHeight so
/// the long side of a [width] x [height] image ends at most 1600 px.
///
/// The plugin treats both values as a floor: it divides each side by
/// max(1, min(w / minWidth, h / minHeight))
/// (flutter_image_compress_common BitmapCompressExt.kt calcScale), so
/// 1600/1600 would make the SHORT side 1600. With both set to
/// short * 1600 / long, rounded down, the scale is at least long / 1600
/// whichever way the photo is turned.
int recipeImageMinSide(int width, int height) {
  final long = math.max(width, height);
  final short = math.min(width, height);
  return math.max(1, short * kRecipeImageMaxSide ~/ long);
}

/// Shrinks to the recipe-image budget: long side at most 1600 px, JPEG
/// quality stepped down until the file is at most 250 kB. Returns null
/// when no attempt fits the budget, so a too-large image is never queued
/// again as it was.
Future<Uint8List?> shrinkToRecipeImageBudget(String path) async {
  final size = recipeImageSize(await File(path).readAsBytes());
  final side = size == null
      ? kRecipeImageMaxSide
      : recipeImageMinSide(size.$1, size.$2);
  for (final quality in const [85, 75, 65, 55, 45]) {
    final bytes = await FlutterImageCompress.compressWithFile(
      path,
      minWidth: side,
      minHeight: side,
      quality: quality,
    );
    if (bytes == null) return null;
    if (fitsRecipeImageBudget(bytes)) return bytes;
  }
  return null;
}

/// "Försök mindre" (#synkko): the image the server refused as too large is
/// written again, smaller, next to the original, and the upload goes back
/// into the queue from the start. The original file is left where it is.
///
/// Throws [StateError] when the upload is gone or the image cannot be made
/// smaller than it is, or not within the budget; the failure then stays.
Future<void> retrySmallerQueuedChange(
  AppDatabase db,
  String userId,
  QueuedChange change, {
  ImageShrinker shrink = shrinkToRecipeImageBudget,
}) async {
  if (!change.canTrySmaller) {
    throw ArgumentError.value(change, 'change', 'not a too-large image');
  }
  final upload =
      await (db.select(db.uploadQueueEntries)..where(
            (e) => e.userId.equals(userId) & e.id.equals(change.id),
          ))
          .getSingleOrNull();
  if (upload == null) throw StateError('The image is no longer queued');
  final bytes = await shrink(upload.localPath);
  if (bytes == null ||
      bytes.length >= upload.fileSizeBytes ||
      !fitsRecipeImageBudget(bytes)) {
    throw StateError('The image could not be made smaller');
  }
  final smaller = File(_smallerPath(upload.localPath));
  await smaller.writeAsBytes(bytes, flush: true);
  await (db.update(
    db.uploadQueueEntries,
  )..where((e) => e.id.equals(upload.id))).write(
    UploadQueueEntriesCompanion(
      localPath: Value(smaller.path),
      fileSizeBytes: Value(bytes.length),
      contentType: const Value('image/jpeg'),
      permanentlyFailed: const Value(false),
      status: const Value('pending'),
      retryCount: const Value(0),
      lastError: const Value(null),
      nextAttemptAt: const Value(null),
      firstFailedAt: const Value(null),
      retriedAt: Value(clock.now()),
    ),
  );
  // BUT-2295: the queue now points at the smaller copy.
  if (upload.localPath != smaller.path) await _deleteQuietly(upload.localPath);
}

/// `/a/b/photo.png` → `/a/b/photo-mindre.jpg`.
String _smallerPath(String path) {
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf(RegExp(r'[/\\]'));
  final stem = dot > slash ? path.substring(0, dot) : path;
  return '$stem-mindre.jpg';
}

QueuedOperation _operation(String stored) => switch (stored) {
  'create' => QueuedOperation.create,
  'delete' => QueuedOperation.delete,
  'tag' => QueuedOperation.tag,
  _ => QueuedOperation.update,
};

/// The titles of the device copies of [ids], by recipe id. A recipe the
/// device has no copy of has no entry.
Future<Map<String, String>> _recipeTitles(
  AppDatabase db,
  String userId,
  Set<String> ids,
) async {
  if (ids.isEmpty) return const {};
  final rows = await (db.select(
    db.offlineRecipes,
  )..where((r) => r.userId.equals(userId) & r.id.isIn(ids))).get();
  final titles = <String, String>{};
  for (final row in rows) {
    try {
      final decoded = jsonDecode(row.recipeJson);
      // The device stores Recipe.toJson, with the title under "core"
      // (recipe_serialization.dart); an older flat record has it at the top.
      final core = decoded is Map ? decoded['core'] : null;
      final title = core is Map
          ? core['title']
          : (decoded is Map ? decoded['title'] : null);
      if (title is String && title.trim().isNotEmpty) {
        titles[row.id] = title.trim();
      }
    } on FormatException {
      // A copy that cannot be read has no title; the row says "Ett recept".
    }
  }
  return titles;
}
