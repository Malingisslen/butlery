// lib/services/offline/avatar_upload_completion.dart
//
// BUT-2294: the second step of a profile picture chosen without a connection.
// The picture is in Storage; this puts it on the profile unless the profile
// has been given a different picture since the user chose this one, in which
// case the newer picture stays.
library;

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/models/avatar_write_outcome.dart';
import 'package:butlery/services/offline/avatar_queue_metadata.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/upload_completion.dart';

/// How many failed second steps a waiting picture gets before it waits for the
/// user, in addition to the 24 h the queue gives every row.
const int kAvatarMaxAttempts = 8;

typedef SetQueuedAvatar =
    Future<AvatarWriteOutcome> Function({
      required String userId,
      required String? expected,
      required String url,
    });

class AvatarUploadCompletion implements UploadCompletion {
  AvatarUploadCompletion({
    required AppDatabase database,
    required OfflineUserStorage storage,
    required SetQueuedAvatar setAvatar,
  }) : _db = database,
       _storage = storage,
       _setAvatar = setAvatar;

  final AppDatabase _db;
  final OfflineUserStorage _storage;
  final SetQueuedAvatar _setAvatar;

  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async {
    final base = avatarBaseUrl(row.metadata);
    if (base == null) {
      await _storage.deleteUploadFile(row.localPath);
      return CompletionOutcome.targetGone;
    }
    if (row.retryCount >= kAvatarMaxAttempts) {
      throw const QueueAttemptsExhausted();
    }
    if (!await _isLive(row.id, userId)) return CompletionOutcome.discarded;

    final outcome = await _setAvatar(
      userId: userId,
      expected: base.url,
      url: row.uploadedUrl!,
    );
    switch (outcome) {
      case AvatarWriteOutcome.set:
      case AvatarWriteOutcome.alreadySet:
        await _db.uploadQueueDao.markCompleted(row.id);
        await _storage.deleteUploadFile(row.localPath);
        return CompletionOutcome.done;
      case AvatarWriteOutcome.superseded:
      case AvatarWriteOutcome.accountGone:
        // A newer picture stays, and an account that is gone has no profile to
        // put one on: this one is not in use, so the queue takes it back.
        await _storage.deleteUploadFile(row.localPath);
        return CompletionOutcome.targetGone;
    }
  }

  Future<bool> _isLive(String rowId, String userId) async =>
      uploadRowIsLive(await _db.uploadQueueDao.getUpload(rowId), userId);
}
