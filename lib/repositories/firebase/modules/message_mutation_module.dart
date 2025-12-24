// lib/repositories/firebase/modules/message_mutation_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Message mutation module for write operations (including complex sendMessage).
class MessageMutationModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final CollectionReference<Map<String, dynamic>> messagesRef;
  final Future<Conversation?> Function(String) readConversation;

  MessageMutationModule({
    required this.firestore,
    required this.collectionName,
    required this.messagesRef,
    required this.readConversation,
  });

  /// Send message with atomic conversation update (complex 175-line operation).
  Future<void> sendMessage(Message message) async {
    try {
      AppLogger.info(
          '📤 [MessageMutation] sendMessage with atomic conversation update');
      AppLogger.debug('📤 [MessageMutation] Message ID: ${message.id}');
      AppLogger.debug(
          '📤 [MessageMutation] Conversation ID: ${message.conversationId}');
      AppLogger.debug('📤 [MessageMutation] Sender ID: ${message.senderId}');
      AppLogger.debug('📤 [MessageMutation] Content: "${message.content}"');

      // Read conversation (required for atomic update)
      AppLogger.debug('📤 [MessageMutation] Reading conversation...');
      Conversation? conversation;
      try {
        conversation = await readConversation(message.conversationId);
      } catch (e) {
        AppLogger.warning(
            '⚠️ [MessageMutation] Could not read conversation: $e');
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
            '📤 [MessageMutation] Conversation found: ${conversation.id}');

        if (!conversation.isParticipant(message.senderId)) {
          AppLogger.error(
              '❌ [MessageMutation] User ${message.senderId} is not a participant');
          throw PermissionDeniedException(
            'User is not a participant in this conversation',
            resource: 'conversation:${message.conversationId}',
            userId: message.senderId,
          );
        }
        AppLogger.debug(
            '📤 [MessageMutation] User is participant - authorized');
      }

      // Handle missing conversation with smart fallback using message sender data
      if (conversation == null) {
        AppLogger.warning(
            '⚠️ [MessageMutation] Conversation not found locally: ${message.conversationId}');
        AppLogger.info(
            '📝 [MessageMutation] Creating fallback conversation with complete participant data');

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
                '📝 [MessageMutation] Fetching profile for user: $otherUserId');
            final userDoc =
                await firestore.collection('users').doc(otherUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              otherUserDisplayName = userData?['displayName'] as String?;
              otherUserAvatarUrl = userData?['avatarUrl'] as String?;
              AppLogger.success(
                  '✅ [MessageMutation] Fetched other participant profile: $otherUserDisplayName');
            } else {
              AppLogger.warning(
                  '⚠️ [MessageMutation] User profile not found for: $otherUserId');
            }
          } catch (e) {
            AppLogger.warning(
                '⚠️ [MessageMutation] Could not fetch user profile: $e');
          }
        }

        // Create fallback conversation with BOTH participant names
        conversation = Conversation(
          id: conversationId,
          participantIds: [
            message.senderId,
            if (otherUserId != null) otherUserId,
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        AppLogger.success(
            '✅ [MessageMutation] Fallback conversation created with complete participant data');
      }

      // ATOMIC OPERATION: Write message + update conversation in single batch
      AppLogger.debug(
          '📤 [MessageMutation] Creating atomic batch operation...');
      AppLogger.debug(
          '📤 [MessageMutation] Message initial status: ${message.status}');
      final batch = firestore.batch();

      // 1. Write message to messages collection with ORIGINAL status (sending)
      final messageData = MessageDto.toFirestore(message);
      batch.set(messagesRef.doc(message.id), messageData);
      AppLogger.debug(
          '📤 [MessageMutation] Added message to batch with status: ${message.status}');

      // 2. Update conversation with lastMessage (keeping original status)
      final updatedConversation = conversation.copyWith(
        lastMessage: message,
        updatedAt: DateTime.now(),
      );
      final conversationData = ConversationDto.toFirestore(updatedConversation);
      batch.set(
        firestore.collection(collectionName).doc(message.conversationId),
        conversationData,
        SetOptions(merge: true),
      );
      AppLogger.debug(
          '📤 [MessageMutation] Added conversation update to batch: ${message.conversationId}');

      // Commit batch - either BOTH succeed or BOTH fail (atomicity guaranteed)
      AppLogger.debug('📤 [MessageMutation] Committing atomic batch...');
      try {
        await batch.commit();
        AppLogger.success(
            '✅ [MessageMutation] Atomic batch committed - message in Firestore with status: sending');

        // STEP 2: Update message status to "sent" AFTER batch commits successfully
        AppLogger.debug(
            '📤 [MessageMutation] Scheduling status update to sent...');
        Future.delayed(const Duration(milliseconds: 100), () async {
          try {
            await messagesRef.doc(message.id).update({
              'status': MessageStatus.sent.name,
            });
            AppLogger.success(
                '✅ [MessageMutation] Message status updated to: sent');

            // Also update conversation's lastMessage status
            await firestore
                .collection(collectionName)
                .doc(message.conversationId)
                .update({
              'lastMessage.status': MessageStatus.sent.name,
            });
            AppLogger.success(
                '✅ [MessageMutation] Conversation lastMessage status updated to: sent');
          } catch (e) {
            AppLogger.warning(
                '⚠️ [MessageMutation] Could not update message status: $e');
          }
        });
      } catch (batchError) {
        AppLogger.error('❌ [MessageMutation] Batch commit failed', batchError);
        // Check if it's network related
        if (batchError.toString().contains('UNAVAILABLE') ||
            batchError.toString().contains('network')) {
          AppLogger.warning(
              '📡 [MessageMutation] Network unavailable - batch queued for offline sync');
        } else {
          rethrow;
        }
      }

      AppLogger.success(
          '✅ [MessageMutation] Message sent: ${message.id} in conversation ${message.conversationId}');
    } catch (e, stackTrace) {
      AppLogger.error(
          '❌ [MessageMutation] Failed to send message ${message.id}', e);
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
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (status) {
        case MessageStatus.delivered:
          updateData['deliveredAt'] = timestamp != null
              ? Timestamp.fromDate(timestamp)
              : FieldValue.serverTimestamp();
          break;
        case MessageStatus.read:
          updateData['readAt'] = timestamp != null
              ? Timestamp.fromDate(timestamp)
              : FieldValue.serverTimestamp();
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
        timestamp: DateTime.now(),
      );

      AppLogger.debug('Message marked as read: $messageId by $userId');
    } catch (e) {
      AppLogger.error('Failed to mark message as read: $messageId', e);
      rethrow;
    }
  }

  /// Mark entire conversation as read.
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
    required Future<void> Function(Conversation) updateConversation,
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

      final now = DateTime.now();
      final updatedLastReadTimestamps =
          Map<String, DateTime>.from(conversation.lastReadTimestamps);
      updatedLastReadTimestamps[userId] = now;

      final updatedConversation = conversation.copyWith(
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: now,
      );

      await updateConversation(updatedConversation);

      AppLogger.debug(
          'Conversation marked as read: $conversationId by $userId');
    } catch (e) {
      AppLogger.error(
          'Failed to mark conversation as read: $conversationId', e);
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
        'editedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
      final timestamp = FieldValue.serverTimestamp();

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
          'Batch marked ${messageIds.length} messages as delivered for $userId');
    } catch (e) {
      AppLogger.error('Failed to batch mark messages as delivered', e);
      rethrow;
    }
  }
}
