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

/// Message mutation module for write operations (including complex sendMessage).
class MessageMutationModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final CollectionReference<Map<String, dynamic>> messagesRef;
  final Future<Conversation?> Function(String) readConversation;
  final TimestampProvider timestampProvider;

  MessageMutationModule({
    required this.firestore,
    required this.collectionName,
    required this.messagesRef,
    required this.readConversation,
    this.timestampProvider = const ServerTimestampProvider(),
  });

  CollectionReference<Map<String, dynamic>> pollVotesRef(String messageId) =>
      messagesRef.doc(messageId).collection(FirestoreCollections.pollVotes);

  /// Send message with atomic conversation update (complex 175-line operation).
  Future<void> sendMessage(Message message) async {
    try {
      AppLogger.info(
        '📤 [MessageMutation] sendMessage with atomic conversation update',
      );
      AppLogger.debug('📤 [MessageMutation] Message ID: ${message.id}');
      AppLogger.debug(
        '📤 [MessageMutation] Conversation ID: ${message.conversationId}',
      );
      AppLogger.debug('📤 [MessageMutation] Sender ID: ${message.senderId}');
      AppLogger.debug('📤 [MessageMutation] Content: "${message.content}"');

      // Read conversation (required for atomic update)
      AppLogger.debug('📤 [MessageMutation] Reading conversation...');
      Conversation? conversation;
      try {
        conversation = await readConversation(message.conversationId);
      } catch (e) {
        AppLogger.warning(
          '⚠️ [MessageMutation] Could not read conversation: $e',
        );
        // For deterministic IDs, conversation might not exist yet - that's OK
        if (!message.conversationId.startsWith('direct_')) {
          throw ResourceNotFoundException(
            'Conversation not found',
            resourceType: 'conversation',
            resourceId: message.conversationId,
          );
        }
      }

      // Validate participant if conversation exists
      if (conversation != null) {
        AppLogger.debug(
          '📤 [MessageMutation] Conversation found: ${conversation.id}',
        );

        if (!conversation.isParticipant(message.senderId)) {
          AppLogger.error(
            '❌ [MessageMutation] User ${message.senderId} is not a participant',
          );
          throw PermissionDeniedException(
            'User is not a participant in this conversation',
            resource: 'conversation:${message.conversationId}',
            userId: message.senderId,
          );
        }
        AppLogger.debug(
          '📤 [MessageMutation] User is participant - authorized',
        );
      }

      // Handle missing conversation with smart fallback using message sender data
      if (conversation == null) {
        AppLogger.warning(
          '⚠️ [MessageMutation] Conversation not found locally: ${message.conversationId}',
        );
        AppLogger.info(
          '📝 [MessageMutation] Creating fallback conversation with complete participant data',
        );

        // Parse deterministic conversation ID to extract other participant
        final conversationId = message.conversationId;
        String? otherUserId;

        if (conversationId.startsWith('direct_')) {
          final parts = conversationId.split('_');
          if (parts.length == 3) {
            final userId1 = parts[1];
            final userId2 = parts[2];
            otherUserId = (userId1 == message.senderId) ? userId2 : userId1;
          }
        }

        // Fetch other participant's profile from Firestore users collection
        String? otherUserDisplayName;
        String? otherUserAvatarUrl;

        if (otherUserId != null) {
          try {
            AppLogger.debug(
              '📝 [MessageMutation] Fetching profile for user: $otherUserId',
            );
            final userDoc = await firestore
                .collection(FirestoreCollections.users)
                .doc(otherUserId)
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              otherUserDisplayName = userData?['displayName'] as String?;
              otherUserAvatarUrl = userData?['avatarUrl'] as String?;
              AppLogger.success(
                '✅ [MessageMutation] Fetched other participant profile: $otherUserDisplayName',
              );
            } else {
              AppLogger.warning(
                '⚠️ [MessageMutation] User profile not found for: $otherUserId',
              );
            }
          } catch (e) {
            AppLogger.warning(
              '⚠️ [MessageMutation] Could not fetch user profile: $e',
            );
          }
        }

        // Create fallback conversation with BOTH participant names
        // DO NOT give this conversation a `metadata.creatorId`, however
        // obviously right that looks — but the REASON changed on 2026-08-13
        // (BUT-1838) and the old one is worth not repeating.
        //
        // It used to be a CEL accident: the create rule read
        // `'creatorId' in request.resource.data.metadata`, an `in` on a null is
        // an evaluation error, and that error was the only thing stopping a
        // non-creator from materialising a group's top-level document by
        // sending the first message — which would have permanently disarmed the
        // `onDocumentCreated` child-safety trigger.
        //
        // None of that is the situation any more. The create rule is a bare
        // `request.resource.data.metadata.creatorId == request.auth.uid`, which
        // denies an absent or null creator cleanly rather than by error; a
        // client cannot create a GROUP conversation at all (`directIdBinds`);
        // and the safety gate runs before the write, in the `chat_groups`
        // callables, with the trigger repointed at `chat_groups` as a backstop.
        //
        // What survives: this fallback must still send no creator, because the
        // caller is not one — and `ConversationDto.toFirestore` still emits the
        // key unconditionally, so a "don't write nulls" tidy would change a
        // write path the rules govern. Test C7B pins the deny; the DTO's own
        // emission is pinned in message_mutation_module_test.dart.
        conversation = Conversation(
          id: conversationId,
          participantIds: [
            message.senderId,
            ?otherUserId,
          ],
          participantDisplayNames: {
            message.senderId: message.senderDisplayName,
            if (otherUserId != null && otherUserDisplayName != null)
              otherUserId: otherUserDisplayName,
          },
          participantAvatarUrls: {
            message.senderId: message.senderAvatarUrl,
            if (otherUserId != null && otherUserAvatarUrl != null)
              otherUserId: otherUserAvatarUrl,
          },
          lastReadTimestamps: {},
          isGroup: false,
          // BUT-1831: this re-stamp is why the write is DENIED against any
          // conversation that already exists — the DTO emits createdAt
          // unconditionally, the write is a merge-set, and the update rule
          // pins that field. Establish how often this branch runs before
          // changing it; the fix differs completely between "a rare repair
          // path is broken" and "every DM send takes a denied write".
          createdAt: clock.now().toUtc(),
          updatedAt: clock.now().toUtc(),
        );

        AppLogger.success(
          '✅ [MessageMutation] Fallback conversation created with complete participant data',
        );
      }

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
        '📤 [MessageMutation] Added conversation update to batch: ${message.conversationId}',
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
        '✅ [MessageMutation] Message sent: ${message.id} in conversation ${message.conversationId}',
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
          resourceId: conversationId,
        );
      }

      if (!conversation.isParticipant(userId)) {
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
          resource: 'conversation:$conversationId',
          userId: userId,
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
        'Conversation marked as read: $conversationId by ${userId.maskedUserId}',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to mark conversation as read: $conversationId',
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

  /// Vote on (or toggle off) a poll option.
  ///
  /// Writes `messages/{messageId}/poll_votes/{voterId}` — one row per voter,
  /// doc id == voter uid — never the message document (BUT-1832). Casting a
  /// vote used to be an update of `metadata.poll.options[].voterIds` on the
  /// message, and `firestore.rules` lets only a message's SENDER update it, so
  /// every vote by anyone other than the poll's own author was denied. The
  /// permission is not something a wider message rule could grant: a rule
  /// cannot walk a list of maps, so "change only your own entry inside
  /// options[i].voterIds" is not expressible, while any rule loose enough to
  /// permit the write would also let a participant rewrite the question and
  /// everybody else's votes. With the voter in the PATH the rule is exact.
  ///
  /// The transaction is on the voter's own row, so two people voting at once no
  /// longer contend for one document the way the old whole-metadata rewrite did.
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required String voterId,
    required bool allowMultiple,
  }) async {
    final voteRef = pollVotesRef(messageId).doc(voterId);

    await firestore.runTransaction((transaction) async {
      final doc = await transaction.get(voteRef);
      final existing = doc.exists
          ? List<String>.from(
              (doc.data()?['optionIds'] as List<dynamic>? ?? const [])
                  .whereType<String>(),
            )
          : <String>[];

      // Behaviour preserved from the inline version, both branches:
      //   multi-choice — tapping an option toggles it, leaving the others alone;
      //   single-choice — the pick REPLACES the previous one, and re-tapping
      //   your current choice leaves it selected rather than clearing it. The
      //   old code reached that second one by stripping every option and then
      //   adding back, which nets to "stays voted"; stated directly here so it
      //   reads as the decision it is and not as a missing toggle.
      final List<String> next;
      if (allowMultiple) {
        next = List<String>.from(existing);
        if (next.contains(optionId)) {
          next.remove(optionId);
        } else {
          next.add(optionId);
        }
      } else {
        next = <String>[optionId];
      }

      if (next.isEmpty) {
        // No selection left. Delete rather than keep an empty row: an empty row
        // is still a uid on a document other participants read, and Art. 17
        // should not have to erase what carries no information.
        if (doc.exists) transaction.delete(voteRef);
        return;
      }

      transaction.set(voteRef, {
        // Duplicated from the doc id on purpose — the erasure sweep queries by
        // FIELD (`collectionGroup('poll_votes').where('voterId', ...)`), and a
        // document id is not a field any query or `hasOnly` can see.
        'voterId': voterId,
        'optionIds': next,
        'votedAt': timestampProvider.serverTimestamp(),
      });
    });

    AppLogger.debug('Poll vote recorded for message $messageId');
  }

  /// Close a poll (creator only).
  Future<void> closePoll({
    required String messageId,
    required String closerId,
  }) async {
    final messageRef = messagesRef.doc(messageId);
    final doc = await messageRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
    final pollMap = Map<String, dynamic>.from(metadata['poll'] ?? {});

    if (pollMap['creatorId'] != closerId) {
      AppLogger.warning('Non-creator attempted to close poll $messageId');
      return;
    }

    pollMap['isClosed'] = true;
    metadata['poll'] = pollMap;
    await messageRef.update({'metadata': metadata});

    AppLogger.debug('Poll closed: $messageId');
  }
}
