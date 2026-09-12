// lib/repositories/firebase/modules/message_mutation_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/modules/message_poll_mutation_module.dart';

/// Message mutation module for write operations (including complex sendMessage).
class MessageMutationModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final CollectionReference<Map<String, dynamic>> messagesRef;
  final Future<Conversation?> Function(String) readConversation;
  final TimestampProvider timestampProvider;

  /// Poll writes live in their own module (BUT-1925); this class keeps the
  /// delegating members so `FirebaseMessagingRepository` did not have to move
  /// with them. `pollVotesRef` is delegated for symmetry — nothing outside
  /// these two files calls it.
  late final MessagePollMutationModule _polls = MessagePollMutationModule(
    firestore: firestore,
    messagesRef: messagesRef,
    timestampProvider: timestampProvider,
  );

  MessageMutationModule({
    required this.firestore,
    required this.collectionName,
    required this.messagesRef,
    required this.readConversation,
    this.timestampProvider = const ServerTimestampProvider(),
  });

  CollectionReference<Map<String, dynamic>> pollVotesRef(String messageId) =>
      _polls.pollVotesRef(messageId);

  /// Send message with atomic conversation update.
  Future<void> sendMessage(Message message) async {
    try {
      AppLogger.info(
        '📤 [MessageMutation] sendMessage with atomic conversation update',
      );
      AppLogger.debug('📤 [MessageMutation] Message ID: ${message.id}');
      AppLogger.debug(
        '📤 [MessageMutation] Conversation ID: ${message.conversationId.maskedConversationId}',
      );
      AppLogger.debug('📤 [MessageMutation] Sender ID: ${message.senderId}');
      AppLogger.debug('📤 [MessageMutation] Content: "${message.content}"');

      // Read conversation (required for atomic update).
      //
      // BUT-1831: a read that FAILS propagates untouched. It used to be
      // swallowed — HERE for a `direct_` id, and in the wired callback for
      // every id, which made this catch unreachable — turning a momentary read
      // failure into "this conversation does not exist" and sending the send
      // down the repair path the absence check below replaces. Nothing may
      // wrap it either: `MessageSendErrorMapper.classify` needs the raw
      // `FirebaseException` to tell a clock-skew denial from anything else.
      // That file's own docstring carries the unwrap chain; do not restate it
      // here, where nothing keeps the copy honest.
      AppLogger.debug('📤 [MessageMutation] Reading conversation...');
      final conversation = await readConversation(message.conversationId);

      // A conversation that is genuinely ABSENT is an error, not something to
      // paper over.
      //
      // BUT-1831: this replaces a branch that fabricated a `Conversation` from
      // the message's own sender data and merge-set it beside the message. That
      // write is refused by `firestore.rules` on BOTH horns:
      //
      //   update (document exists) - the rebuilt DTO re-stamps `createdAt`,
      //     and the conversations update rule deny-lists it. When the RECIPIENT
      //     sends, the rebuilt `participantIds` also comes out in the opposite
      //     order to the stored array, which the same deny-list refuses.
      //   create (document absent)  - the create rule requires
      //     `metadata.creatorId == request.auth.uid`, and the fallback has no
      //     creator to name because its caller is not one.
      //
      // Because the batch is atomic, the refusal took the MESSAGE document with
      // it. Nothing is lost by removing the branch; a send that reaches here
      // with no conversation had no working outcome available to it.
      //
      // This branch IS reachable, and an earlier version of this comment said
      // otherwise — the sentence a future author would have acted on.
      // `deleteConversation` removes the shared top-level document and no chat
      // screen watches it, so the other party deleting the thread while this
      // one is open lands here on the next send. The repair, if that case is
      // ever given one, is to CALL `createDirectConversation` (which writes its
      // own `metadata.creatorId`), never to rebuild a payload rules refuse.
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          // This exception's toString() reaches Crashlytics through
          // recordError, which sanitises nothing, and a `direct_` id is two
          // raw uids.
          resourceId: message.conversationId.maskedConversationId,
        );
      }

      AppLogger.debug(
        '📤 [MessageMutation] Conversation found: ${conversation.id.maskedConversationId}',
      );

      if (!conversation.isParticipant(message.senderId)) {
        AppLogger.error(
          '❌ [MessageMutation] User ${message.senderId.maskedUserId} is '
          'not a participant',
        );
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
          resource:
              'conversation:${message.conversationId.maskedConversationId}',
          userId: message.senderId.maskedUserId,
        );
      }
      AppLogger.debug('📤 [MessageMutation] User is participant - authorized');

      // ATOMIC OPERATION: Write message + update conversation in single batch
      AppLogger.debug(
        '📤 [MessageMutation] Creating atomic batch operation...',
      );
      AppLogger.debug(
        '📤 [MessageMutation] Message initial status: ${message.status}',
      );
      final batch = firestore.batch();

      // 1. Write message to messages collection with ORIGINAL status (sending)
      final messageData = MessageDto.toFirestore(
        message,
        timestampProvider: timestampProvider,
      );
      batch.set(messagesRef.doc(message.id), messageData);
      AppLogger.debug(
        '📤 [MessageMutation] Added message to batch with status: ${message.status}',
      );

      // 2. Update conversation with lastMessage (keeping original status)
      final updatedConversation = conversation.copyWith(
        lastMessage: message,
        updatedAt: clock.now().toUtc(),
      );
      final conversationData = ConversationDto.toFirestore(updatedConversation);
      batch.set(
        firestore.collection(collectionName).doc(message.conversationId),
        conversationData,
        SetOptions(merge: true),
      );
      AppLogger.debug(
        '📤 [MessageMutation] Added conversation update to batch: ${message.conversationId.maskedConversationId}',
      );

      // 3. Update rate limit doc for server-side enforcement
      batch.set(
        firestore
            .collection(FirestoreCollections.users)
            .doc(message.senderId)
            .collection(FirestoreCollections.userRateLimits)
            .doc('messages'),
        {
          'lastWrite': timestampProvider.serverTimestamp(),
          'expireAt': Timestamp.fromDate(
            clock.now().add(const Duration(days: 90)),
          ),
        },
        SetOptions(merge: true),
      );

      // Commit batch - all writes succeed or all fail (atomicity guaranteed)
      AppLogger.debug('📤 [MessageMutation] Committing atomic batch...');
      try {
        await batch.commit();
        AppLogger.success(
          '✅ [MessageMutation] Atomic batch committed - message in Firestore with status: sending',
        );

        // STEP 2: Update message status to "sent" AFTER batch commits successfully
        AppLogger.debug(
          '📤 [MessageMutation] Scheduling status update to sent...',
        );
        Future.delayed(const Duration(milliseconds: 100), () async {
          try {
            await messagesRef.doc(message.id).update({
              'status': MessageStatus.sent.name,
            });
            AppLogger.success(
              '✅ [MessageMutation] Message status updated to: sent',
            );

            // Also update conversation's lastMessage status
            await firestore
                .collection(collectionName)
                .doc(message.conversationId)
                .update({
                  'lastMessage.status': MessageStatus.sent.name,
                });
            AppLogger.success(
              '✅ [MessageMutation] Conversation lastMessage status updated to: sent',
            );
          } catch (e) {
            AppLogger.warning(
              '⚠️ [MessageMutation] Could not update message status: $e',
            );
          }
        });
      } catch (batchError) {
        AppLogger.error('❌ [MessageMutation] Batch commit failed', batchError);
        // Check if it's network related
        if (batchError.toString().contains('UNAVAILABLE') ||
            batchError.toString().contains('network')) {
          AppLogger.warning(
            '📡 [MessageMutation] Network unavailable - batch queued for offline sync',
          );
        } else {
          rethrow;
        }
      }

      AppLogger.success(
        '✅ [MessageMutation] Message sent: ${message.id} in conversation ${message.conversationId.maskedConversationId}',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ [MessageMutation] Failed to send message ${message.id}',
        e,
      );
      AppLogger.error('❌ [MessageMutation] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update message status (delivered, read, etc.).
  Future<void> updateMessageStatus({
    required String messageId,
    required MessageStatus status,
    DateTime? timestamp,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updatedAt': timestampProvider.serverTimestamp(),
      };

      switch (status) {
        case MessageStatus.delivered:
          updateData['deliveredAt'] = timestamp != null
              ? Timestamp.fromDate(timestamp)
              : timestampProvider.serverTimestamp();
          break;
        case MessageStatus.read:
          updateData['readAt'] = timestamp != null
              ? Timestamp.fromDate(timestamp)
              : timestampProvider.serverTimestamp();
          break;
        default:
          break;
      }

      await messagesRef.doc(messageId).update(updateData);

      AppLogger.debug('Message status updated: $messageId -> $status');
    } catch (e) {
      AppLogger.error('Failed to update message status for $messageId', e);
      rethrow;
    }
  }

  /// Mark message as read.
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      await updateMessageStatus(
        messageId: messageId,
        status: MessageStatus.read,
        timestamp: clock.now().toUtc(),
      );

      AppLogger.debug(
        'Message marked as read: $messageId by ${userId.maskedUserId}',
      );
    } catch (e) {
      AppLogger.error('Failed to mark message as read: $messageId', e);
      rethrow;
    }
  }

  /// Mark entire conversation as read.
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final conversation = await readConversation(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId.maskedConversationId,
        );
      }

      if (!conversation.isParticipant(userId)) {
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
          resource: 'conversation:${conversationId.maskedConversationId}',
          userId: userId.maskedUserId,
        );
      }

      // BUT-1838: a FIELD-PATH write to the top level, not a whole-document
      // update through `updateConversation`. Two reasons, either sufficient.
      //
      // The path: `updateConversation` is `BaseFirebaseRepository.update`,
      // which this repository's user-scoped mixin rewrites to
      // `users/{uid}/conversations/{id}` — a document that exists for no chat
      // group, so `.update()` would throw on a read receipt (and the service
      // swallows it, so nobody would ever be told).
      //
      // The payload: sending the whole document back re-sends `participantIds`
      // and `createdAt`, which the conversations update rule denies on any
      // diff. It survives only while those values round-trip byte-identically
      // (BUT-1831). One dotted key cannot trip it.
      final now = clock.now().toUtc();
      await firestore.collection(collectionName).doc(conversationId).update({
        'lastReadTimestamps.$userId': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      AppLogger.debug(
        'Conversation marked as read: ${conversationId.maskedConversationId} by ${userId.maskedUserId}',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to mark conversation as read: '
        '${conversationId.maskedConversationId}',
        e,
      );
      rethrow;
    }
  }

  /// Update message content (edit message).
  Future<void> updateMessageContent({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await messagesRef.doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': timestampProvider.serverTimestamp(),
        'updatedAt': timestampProvider.serverTimestamp(),
      });

      AppLogger.debug('Message content updated: $messageId');
    } catch (e) {
      AppLogger.error('Failed to update message content: $messageId', e);
      rethrow;
    }
  }

  /// Delete message.
  Future<void> deleteMessage(String messageId) async {
    try {
      await messagesRef.doc(messageId).delete();

      AppLogger.debug('Message deleted: $messageId');
    } catch (e) {
      AppLogger.error('Failed to delete message: $messageId', e);
      rethrow;
    }
  }

  /// Batch mark messages as delivered.
  Future<void> batchMarkAsDelivered({
    required List<String> messageIds,
    required String userId,
  }) async {
    try {
      final batch = firestore.batch();
      final timestamp = timestampProvider.serverTimestamp();

      for (final messageId in messageIds) {
        final messageRef = messagesRef.doc(messageId);
        batch.update(messageRef, {
          'status': MessageStatus.delivered.name,
          'deliveredAt': timestamp,
          'updatedAt': timestamp,
        });
      }

      await batch.commit();

      AppLogger.debug(
        'Batch marked ${messageIds.length} messages as delivered for ${userId.maskedUserId}',
      );
    } catch (e) {
      AppLogger.error('Failed to batch mark messages as delivered', e);
      rethrow;
    }
  }

  /// Vote on (or toggle off) a poll option. Delegates to
  /// [MessagePollMutationModule.votePoll].
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required String voterId,
    required bool allowMultiple,
  }) => _polls.votePoll(
    messageId: messageId,
    optionId: optionId,
    voterId: voterId,
    allowMultiple: allowMultiple,
  );

  /// Close a poll (creator only). Returns true when THIS call closed it.
  /// Delegates to [MessagePollMutationModule.closePoll], which carries the
  /// transaction and the already-closed refusal.
  Future<bool> closePoll({
    required String messageId,
    required String closerId,
  }) => _polls.closePoll(messageId: messageId, closerId: closerId);
}
