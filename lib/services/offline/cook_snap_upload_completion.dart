// lib/services/offline/cook_snap_upload_completion.dart
//
// BUT-2294: the second step of a queued cook snap. Every photo of the album is
// a row of one group named after the snap; the snap is created once all of
// them are in Storage.
library;

import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/upload_completion.dart';

/// The name and picture the snap shows for its author.
typedef CookSnapAuthor = ({String displayName, String? avatarUrl});

class CookSnapUploadCompletion implements UploadCompletion {
  /// [spacing] is the least time between two snap creates: the rules refuse a
  /// second one inside five seconds, and that refusal looks like any other.
  CookSnapUploadCompletion({
    required AppDatabase database,
    required OfflineUserStorage storage,
    required CookSnapRepository Function() repository,
    required CookSnapAuthor Function(String userId) author,
    required void Function(
      CookSnap snap, {
      required String recipeAuthorId,
      required String recipeName,
      required String senderName,
    })
    announce,
    this.spacing = const Duration(seconds: 6),
  }) : _db = database,
       _storage = storage,
       _repository = repository,
       _author = author,
       _announce = announce;

  final Duration spacing;
  final AppDatabase _db;
  final OfflineUserStorage _storage;
  final CookSnapRepository Function() _repository;
  final CookSnapAuthor Function(String userId) _author;
  final void Function(
    CookSnap snap, {
    required String recipeAuthorId,
    required String recipeName,
    required String senderName,
  })
  _announce;

  DateTime? _lastCreate;

  /// The earliest time each snap may be tried again after a refusal that may
  /// have been the guard. Kept per snap, not per row: every photo of the
  /// album calls [complete], and one of them spending the single extra try
  /// must not leave the next one to meet the guard unprepared.
  final Map<String, DateTime> _notBefore = {};

  /// Snaps whose create was refused once and given another try after the
  /// spacing; a second refusal is taken as the real answer.
  final Set<String> _refusedOnce = {};

  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async {
    final snapId = row.entityId!;
    var group = await _group(userId, snapId);
    if (!_isLive(group, row.id, userId)) return CompletionOutcome.discarded;
    final albumDead = group.any((r) => r.status == 'cancelled');
    if (!albumDead && group.any((r) => r.status != 'uploaded')) {
      return CompletionOutcome.waitingForGroup;
    }

    // Asked before a thrown-away photo is acted on: if the snap is already
    // there, its photos are in use and must not be taken back.
    final repository = _repository();
    if (!await repository.ownSnapExists(snapId)) {
      if (albumDead) return _discardAlbum(group, row);
      _holdOffUntilSpacingPasses(snapId);
      // A discard while the server was asked must not publish the snap.
      group = await _group(userId, snapId);
      if (!_isLive(group, row.id, userId)) return CompletionOutcome.discarded;
      if (group.any((r) => r.status == 'cancelled')) {
        return _discardAlbum(group, row);
      }
      if (group.any((r) => r.status != 'uploaded')) {
        return CompletionOutcome.waitingForGroup;
      }
      final snap = _snapOf(group, userId);
      var created = true;
      try {
        await repository.addCookSnap(snap);
      } catch (e) {
        created = !await _alreadyThere(e, repository, snapId);
      }
      _lastCreate = clock.now();
      _refusedOnce.remove(snapId);
      _notBefore.remove(snapId);
      if (created) {
        final meta = _metaOf(group.first);
        _announce(
          snap,
          recipeAuthorId: (meta['recipeAuthorId'] as String?).orEmpty(),
          recipeName: (meta['recipeName'] as String?).orEmpty(),
          senderName: snap.userDisplayName,
        );
      }
    }

    // The snap is on the server: the rows and their files are done with. A
    // discard from here on has nothing left to throw away.
    for (final r in group) {
      await _db.uploadQueueDao.markCompleted(r.id);
      await _storage.deleteUploadFile(r.localPath);
    }
    return CompletionOutcome.done;
  }

  /// One photo thrown away takes the album with it: a snap with fewer photos
  /// than the user took is not what they sent. The queue takes this row's
  /// image back; the others are cancelled and taken back by the next pass.
  Future<CompletionOutcome> _discardAlbum(
    List<UploadQueueEntry> group,
    UploadQueueEntry row,
  ) async {
    for (final other in group) {
      if (other.id == row.id || other.status == 'cancelled') continue;
      await _db.uploadQueueDao.cancelUpload(other.id);
      await _storage.deleteUploadFile(other.localPath);
    }
    await _storage.deleteUploadFile(row.localPath);
    return CompletionOutcome.targetGone;
  }

  /// Throws [CompletionDeferred] while the guard between two snaps, or the
  /// wait after this snap's own first refusal, has not passed.
  void _holdOffUntilSpacingPasses(String snapId) {
    final now = clock.now();
    final afterLast = _lastCreate?.add(spacing);
    final afterRefusal = _notBefore[snapId];
    final until = [?afterLast, ?afterRefusal].fold<DateTime?>(
      null,
      (latest, t) => latest == null || t.isAfter(latest) ? t : latest,
    );
    if (until != null && now.isBefore(until)) {
      throw CompletionDeferred(until.difference(now));
    }
  }

  /// Whether a failed create left the snap on the server all the same (an
  /// earlier try got through). A refusal is final otherwise, except the first,
  /// which may be the five-second guard of a snap made just before. Throws
  /// when the snap is not there.
  Future<bool> _alreadyThere(
    Object error,
    CookSnapRepository repository,
    String snapId,
  ) async {
    if (permanentFailureReason(error) == null) throw error;
    if (await repository.ownSnapExists(snapId)) return true;
    if (_refusedOnce.add(snapId)) {
      _notBefore[snapId] = clock.now().add(spacing);
      throw CompletionDeferred(spacing);
    }
    _refusedOnce.remove(snapId);
    _notBefore.remove(snapId);
    throw error;
  }

  Future<List<UploadQueueEntry>> _group(String userId, String snapId) =>
      _db.uploadQueueDao.getGroup(userId, SyncQueueEntityType.cookSnap, snapId);

  bool _isLive(List<UploadQueueEntry> group, String rowId, String userId) {
    for (final r in group) {
      if (r.id == rowId) return uploadRowIsLive(r, userId);
    }
    return false;
  }

  Map<String, dynamic> _metaOf(UploadQueueEntry row) =>
      jsonDecode(row.metadata ?? '{}') as Map<String, dynamic>;

  /// The rows' own `order`, not the order they sit in the table: rows queued
  /// in the same second tie on time.
  CookSnap _snapOf(List<UploadQueueEntry> group, String userId) {
    int orderOf(UploadQueueEntry r) => _metaOf(r)['order'] as int? ?? 0;
    final photos = [...group]..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    final meta = _metaOf(photos.first);
    final author = _author(userId);
    return CookSnap.create(
      id: photos.first.entityId,
      recipeId: meta['recipeId'] as String,
      userId: userId,
      userDisplayName: author.displayName,
      userAvatarUrl: author.avatarUrl,
      photoUrls: [for (final r in photos) r.uploadedUrl!],
      thumbnailUrl: photos.first.uploadedThumbnailUrl,
      caption: meta['caption'] as String?,
      visibility: CookSnapVisibility.values.firstWhere(
        (v) => v.name == meta['visibility'],
        orElse: () => CookSnapVisibility.sameAsRecipe,
      ),
    );
  }
}
