// lib/services/offline/chat_image_upload_completion.dart
//
// BUT-2294: the second step of a chat image sent without a connection. The
// message already exists as a placeholder, created through Firestore's own
// queue so it keeps its place among the texts sent after it; this step fills
// in the picture once the image is in Storage.
library;

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/messaging/pending_image_status.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/offline/chat_image_queue_metadata.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queue_retry_policy.dart';
import 'package:butlery/services/offline/upload_completion.dart';

class ChatImageUploadCompletion implements UploadCompletion {
  ChatImageUploadCompletion({
    required AppDatabase database,
    required OfflineUserStorage storage,
    required MessagingRepository Function() repository,
    this.placeholderWait = const Duration(seconds: 30),
  }) : _db = database,
       _storage = storage,
       _repository = repository;

  final AppDatabase _db;
  final OfflineUserStorage _storage;
  final MessagingRepository Function() _repository;

  /// How long to leave an image whose placeholder has not reached the server
  /// yet. Not a failed attempt: the placeholder is on its way.
  final Duration placeholderWait;

  @override
  Future<CompletionOutcome> complete(
    UploadQueueEntry row,
    String userId,
  ) async {
    final messageId = row.entityId!;
    final repository = _repository();
    final conversationId = chatImageConversationId(row.metadata);
    if (conversationId == null) {
      await _storage.deleteUploadFile(row.localPath);
      return CompletionOutcome.targetGone;
    }
    if (!await _isLive(row.id, userId)) return CompletionOutcome.discarded;

    final PendingImageStatus status;
    try {
      status = await repository.pendingImageStatus(
        messageId: messageId,
        userId: userId,
        conversationId: conversationId,
      );
    } catch (e) {
      if (permanentFailureReason(e) != null) {
        await _withdrawPlaceholder(repository, messageId);
      }
      rethrow;
    }
    switch (status.state) {
      case PendingImageState.writePending:
        throw CompletionDeferred(placeholderWait);
      case PendingImageState.absent:
      case PendingImageState.notMine:
        // The placeholder was refused when it reached the server, deleted, or
        // belongs to an erased account: there is no message to put it in.
        await _storage.deleteUploadFile(row.localPath);
        return CompletionOutcome.targetGone;
      case PendingImageState.filled:
        if (status.imageUrl != row.uploadedUrl) {
          await _storage.deleteUploadFile(row.localPath);
          return CompletionOutcome.targetGone;
        }
      case PendingImageState.waiting:
        // A discard while the server was asked must not publish the picture.
        if (!await _isLive(row.id, userId)) return CompletionOutcome.discarded;
        try {
          await repository.attachPendingImage(
            messageId: messageId,
            imageUrl: row.uploadedUrl!,
          );
        } catch (e) {
          if (permanentFailureReason(e) != null) {
            await _withdrawPlaceholder(repository, messageId);
          }
          rethrow;
        }
    }

    await _db.uploadQueueDao.markCompleted(row.id);
    await _storage.deleteUploadFile(row.localPath);
    return CompletionOutcome.done;
  }

  Future<bool> _isLive(String rowId, String userId) async =>
      uploadRowIsLive(await _db.uploadQueueDao.getUpload(rowId), userId);

  /// The rules refused the picture (a block, the age gate), so the
  /// placeholder is taken down rather than left as an empty bubble for the
  /// others. The sender may always delete their own message.
  Future<void> _withdrawPlaceholder(
    MessagingRepository repository,
    String messageId,
  ) async {
    try {
      await repository.deleteMessage(messageId);
    } catch (_) {
      AppLogger.warning('Could not take down a refused chat image placeholder');
    }
  }
}
