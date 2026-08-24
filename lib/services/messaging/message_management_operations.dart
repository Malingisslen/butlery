// lib/services/messaging/message_management_operations.dart

import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Message and conversation management operations.
/// Handles:
/// - Message editing and deletion
/// - Conversation deletion
/// - Group management (add/remove participants, update title)
class MessageManagementOperations {
  final MessagingRepository messagingRepository;
  final auth_repo.AuthRepository authRepository;

  MessageManagementOperations({
    required this.messagingRepository,
    required this.authRepository,
  });

  /// Edit message content
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      if (newContent.trim().isEmpty) {
        throw ValidationException('Message content cannot be empty');
      }

      // Verify message ownership
      final message = await messagingRepository.getMessage(messageId);
      if (message == null) {
        throw ResourceNotFoundException(
          'Message not found',
          resourceType: 'message',
          resourceId: messageId,
        );
      }

      final currentUserId = authRepository.currentUserId;
      if (message.senderId != currentUserId) {
        throw PermissionDeniedException(
          'Can only edit own messages',
          resource: 'message:$messageId',
          userId: currentUserId.maskedUserId,
        );
      }

      await messagingRepository.updateMessageContent(
        messageId: messageId,
        newContent: newContent.trim(),
      );

      AppLogger.debug('Message edited: $messageId');
    } catch (e) {
      AppLogger.error('Failed to edit message $messageId', e);
      rethrow;
    }
  }

  /// Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      // Verify message ownership
      final message = await messagingRepository.getMessage(messageId);
      if (message == null) {
        throw ResourceNotFoundException(
          'Message not found',
          resourceType: 'message',
          resourceId: messageId,
        );
      }

      final currentUserId = authRepository.currentUserId;
      if (message.senderId != currentUserId) {
        throw PermissionDeniedException(
          'Can only delete own messages',
          resource: 'message:$messageId',
          userId: currentUserId.maskedUserId,
        );
      }

      await messagingRepository.deleteMessage(messageId);

      AppLogger.debug('Message deleted: $messageId');
    } catch (e) {
      AppLogger.error('Failed to delete message $messageId', e);
      rethrow;
    }
  }

  /// Delete all messages in a conversation (chat clear functionality)
  Future<void> deleteAllMessages(
    String conversationId, {
    DateTime? historyStart,
  }) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw PermissionDeniedException(
          'Must be logged in to delete messages',
          resource: 'conversation:${conversationId.maskedConversationId}',
          userId: null,
        );
      }

      // Get all messages in the conversation
      final messages = await messagingRepository.searchMessages(
        conversationId: conversationId,
        query: '', // Empty query to get all messages
        // BUT-1838: without this the query is refused wholesale for a member
        // who joined a group late, the refusal is caught, and "rensa chatt"
        // reports success having deleted nothing.
        historyStart: historyStart,
        limit: 1000, // High limit to get all messages
      );

      AppLogger.info(
        '🧹 Deleting ${messages.length} messages from conversation $conversationId',
      );

      // Delete messages in batches to avoid overwhelming the system
      const batchSize = 50;
      for (int i = 0; i < messages.length; i += batchSize) {
        final batch = messages.skip(i).take(batchSize);

        // Delete each message in the batch
        final deleteFutures = batch.map((message) async {
          try {
            // Only delete messages sent by current user (permission check)
            if (message.senderId == currentUserId) {
              await messagingRepository.deleteMessage(message.id);
            }
          } catch (e) {
            AppLogger.warning('Failed to delete message ${message.id}: $e');
          }
        });

        await Future.wait(deleteFutures);

        // Small delay between batches to prevent overwhelming the backend
        if (i + batchSize < messages.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      AppLogger.success(
        '✅ Successfully cleared conversation messages for user $currentUserId',
      );
    } catch (e) {
      AppLogger.error(
        '❌ Failed to delete all messages in conversation '
        '${conversationId.maskedConversationId}',
        e,
      );
      rethrow;
    }
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(
    String conversationId,
    Future<Conversation?> Function(String) getConversation,
  ) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw PermissionDeniedException(
          'Must be logged in to delete conversations',
          resource: 'conversation:${conversationId.maskedConversationId}',
          userId: null,
        );
      }

      // Get conversation to check permissions
      final conversation = await getConversation(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId.maskedConversationId,
        );
      }

      // Check if user has permission to delete (owner or participant)
      if (!conversation.participantIds.contains(currentUserId)) {
        throw PermissionDeniedException(
          'Cannot delete conversation - not a participant',
          resource: 'conversation:${conversationId.maskedConversationId}',
          userId: currentUserId.maskedUserId,
        );
      }

      AppLogger.info(
        '🗑️ Deleting conversation $conversationId for user $currentUserId',
      );

      // First delete all messages in the conversation
      await deleteAllMessages(
        conversationId,
        historyStart: conversation.historyQueryStartFor(currentUserId),
      );

      // Then delete the conversation itself
      await messagingRepository.deleteConversation(
        conversationId,
        historyStart: conversation.historyQueryStartFor(currentUserId),
      );

      AppLogger.success('✅ Successfully deleted conversation $conversationId');
    } catch (e) {
      AppLogger.error(
        '❌ Failed to delete conversation ${conversationId.maskedConversationId}',
        e,
      );
      rethrow;
    }
  }

  // BUT-1838: addParticipantsToGroup/removeParticipantFromGroup are removed
  // — see the note on MessagingService for why.

  /// Update group conversation title
  Future<void> updateGroupTitle({
    required String conversationId,
    required String newTitle,
  }) async {
    try {
      if (newTitle.trim().isEmpty) {
        throw ValidationException('Group title cannot be empty');
      }

      await messagingRepository.updateConversation(
        conversationId: conversationId,
        title: newTitle.trim(),
      );

      AppLogger.debug('Group title updated: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update group title', e);
      rethrow;
    }
  }
}
