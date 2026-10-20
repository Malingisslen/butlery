// lib/services/offline/grouped_upload_completion.dart
//
// BUT-2294: the second step of an upload whose photos belong together. Every
// photo is a row of one group named after the thing they belong to (a cook
// snap, a comment); the thing is created once all of them are in Storage.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/upload_completion.dart';

/// [T] is what the group is turned into before it is created.
abstract class GroupedUploadCompletion<T> implements UploadCompletion {
  /// [spacing] is the least time between two creates: the rules refuse a
  /// second one inside five seconds, and that refusal looks like any other.
  GroupedUploadCompletion({
    required AppDatabase database,
    required this.storage,
    required this.entityType,
    this.spacing = const Duration(seconds: 6),
  }) : db = database;

  final String entityType;
  final Duration spacing;
  final AppDatabase db;
  final OfflineUserStorage storage;

  DateTime? _lastCreate;

  /// The earliest time each target may be tried again after a refusal that
  /// may have been the guard. Kept per target, not per row: every photo of the
  /// group calls [complete], and one of them spending the single extra try
  /// must not leave the next one to meet the guard unprepared.
  final Map<String, DateTime> _notBefore = {};

  /// Targets whose create was refused once and given another try after the
  /// spacing; a second refusal is taken as the real answer.
  final Set<String> _refusedOnce = {};

  /// Whether the signed-in user's [targetId] is on the server.
  Future<bool> exists(String targetId);

  /// What the ready group becomes. Throws to have the try repeated later.
  T build(List<UploadQueueEntry> group, String userId);

  Future<void> create(T target);

  /// Called once, only when this call created the target.
  void created(T target, List<UploadQueueEntry> group) {}

  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async {
    final targetId = row.entityId!;
    var group = await _group(userId, targetId);
    if (!_isLive(group, row.id, userId)) return CompletionOutcome.discarded;
    final groupDead = group.any((r) => r.status == 'cancelled');
    if (!groupDead && _siblingNotReady(group)) {
      return CompletionOutcome.waitingForGroup;
    }

    // Asked before a thrown-away photo is acted on: if the target is already
    // there, its photos are in use and must not be taken back.
    if (!await exists(targetId)) {
      if (groupDead) return _discardGroup(group, row);
      _holdOffUntilSpacingPasses(targetId);
      // A discard while the server was asked must not publish the target.
      group = await _group(userId, targetId);
      if (!_isLive(group, row.id, userId)) return CompletionOutcome.discarded;
      if (group.any((r) => r.status == 'cancelled')) {
        return _discardGroup(group, row);
      }
      if (_siblingNotReady(group)) {
        return CompletionOutcome.waitingForGroup;
      }
      final target = build(group, userId);
      var wasCreated = true;
      try {
        await create(target);
      } catch (e) {
        wasCreated = !await _alreadyThere(e, targetId);
      }
      _lastCreate = clock.now();
      _refusedOnce.remove(targetId);
      _notBefore.remove(targetId);
      if (wasCreated) created(target, group);
    }

    // The target is on the server: the rows and their files are done with. A
    // discard from here on has nothing left to throw away.
    for (final r in group) {
      await db.uploadQueueDao.markCompleted(r.id);
      await storage.deleteUploadFile(r.localPath);
    }
    return CompletionOutcome.done;
  }

  /// A permanent failure leaves the row's status as it was, so `uploaded`
  /// alone does not mean the photo is ready: the target must not be created
  /// while any photo of the group waits for the user.
  bool _siblingNotReady(List<UploadQueueEntry> group) =>
      group.any((r) => r.status != 'uploaded' || r.permanentlyFailed);

  /// One photo thrown away takes the group with it: a target with fewer
  /// photos than the user took is not what they sent. The queue takes this
  /// row's image back; the others are cancelled and taken back by the next
  /// pass.
  Future<CompletionOutcome> _discardGroup(
    List<UploadQueueEntry> group,
    UploadQueueEntry row,
  ) async {
    for (final other in group) {
      if (other.id == row.id || other.status == 'cancelled') continue;
      await db.uploadQueueDao.cancelUpload(other.id);
      await storage.deleteUploadFile(other.localPath);
    }
    await storage.deleteUploadFile(row.localPath);
    return CompletionOutcome.targetGone;
  }

  /// Throws [CompletionDeferred] while the guard between two creates, or the
  /// wait after this target's own first refusal, has not passed.
  void _holdOffUntilSpacingPasses(String targetId) {
    final now = clock.now();
    final afterLast = _lastCreate?.add(spacing);
    final afterRefusal = _notBefore[targetId];
    final until = [?afterLast, ?afterRefusal].fold<DateTime?>(
      null,
      (latest, t) => latest == null || t.isAfter(latest) ? t : latest,
    );
    if (until != null && now.isBefore(until)) {
      throw CompletionDeferred(until.difference(now));
    }
  }

  /// Whether a failed create left the target on the server all the same (an
  /// earlier try got through). A refusal is final otherwise, except the first,
  /// which may be the five-second guard of a create made just before. Throws
  /// when the target is not there.
  Future<bool> _alreadyThere(Object error, String targetId) async {
    if (permanentFailureReason(error) == null) throw error;
    if (await exists(targetId)) return true;
    if (_refusedOnce.add(targetId)) {
      _notBefore[targetId] = clock.now().add(spacing);
      throw CompletionDeferred(spacing);
    }
    _refusedOnce.remove(targetId);
    _notBefore.remove(targetId);
    throw error;
  }

  Future<List<UploadQueueEntry>> _group(String userId, String targetId) =>
      db.uploadQueueDao.getGroup(userId, entityType, targetId);

  bool _isLive(List<UploadQueueEntry> group, String rowId, String userId) {
    for (final r in group) {
      if (r.id == rowId) return uploadRowIsLive(r, userId);
    }
    return false;
  }
}
