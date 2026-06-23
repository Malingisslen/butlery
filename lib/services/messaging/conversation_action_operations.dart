// lib/services/messaging/conversation_action_operations.dart

import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:clock/clock.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Conversation action operations for the messaging service.
/// Handles conversation management actions including:
/// - Pin/unpin conversations for quick access
/// - Archive/unarchive conversations to organize inbox
/// - Mute/unmute conversation notifications
/// - Bulk operations like marking all as read
class ConversationActionOperations {
  final MessagingRepository messagingRepository;
  final auth_repo.AuthRepository authRepository;

  ConversationActionOperations({
    required this.messagingRepository,
    required this.authRepository,
  });

  /// Pin a conversation for quick access
  Future<void> pinConversation(
    String conversationId,
    Future<Conversation?> Function(String) getConversation,
  ) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final conversation = await getConversation(conversationId);
      if (conversation == null) {
        throw ValidationException('Conversation not found');
      }

      if (!conversation.participantIds.contains(currentUserId)) {
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
        );
      }

      // Store pin setting in user's conversation metadata
      await messagingRepository.updateConversationUserSettings(
        conversationId: conversationId,
        userId: currentUserId,
        settings: {
          'isPinned': true,
          'pinnedAt': clock.now().toIso8601String(),
        },
      );

      AppLogger.info('Conversation $conversationId pinned');
    } catch (e) {
      AppLogger.error('Failed to pin conversation', e);
      rethrow;
    }
  }

  /// Unpin a conversation
  Future<void> unpinConversation(String conversationId) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await messagingRepository.updateConversationUserSettings(
        conversationId: conversationId,
        userId: currentUserId,
        settings: {
          'isPinned': false,
          'pinnedAt': null,
        },
      );

      AppLogger.info('Conversation $conversationId unpinned');
    } catch (e) {
      AppLogger.error('Failed to unpin conversation', e);
      rethrow;
    }
  }

  /// Archive a conversation (hide from main list)
  Future<void> archiveConversation(String conversationId) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await messagingRepository.updateConversationUserSettings(
        conversationId: conversationId,
        userId: currentUserId,
        settings: {
          'isArchived': true,
          'archivedAt': clock.now().toIso8601String(),
        },
      );

      AppLogger.info('Conversation $conversationId archived');
    } catch (e) {
      AppLogger.error('Failed to archive conversation', e);
      rethrow;
    }
  }

  /// Unarchive a conversation
  Future<void> unarchiveConversation(String conversationId) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await messagingRepository.updateConversationUserSettings(
        conversationId: conversationId,
        userId: currentUserId,
        settings: {
          'isArchived': false,
          'archivedAt': null,
        },
      );

      AppLogger.info('Conversation $conversationId unarchived');
    } catch (e) {
      AppLogger.error('Failed to unarchive conversation', e);
      rethrow;
    }
  }

  /// Mute notifications for a conversation
  Future<void> muteConversation(String conversationId) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await messagingRepository.updateConversationUserSettings(
        conversationId: conversationId,
        userId: currentUserId,
        settings: {
          'isMuted': true,
        },
      );

      AppLogger.info('Conversation $conversationId muted');
    } catch (e) {
      AppLogger.error('Failed to mute conversation', e);
      rethrow;
    }
  }

  /// Unmute notifications for a conversation
  Future<void> unmuteConversation(String conversationId) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await messagingRepository.updateConversationUserSettings(
        conversationId: conversationId,
        userId: currentUserId,
        settings: {
          'isMuted': false,
        },
      );

      AppLogger.info('Conversation $conversationId unmuted');
    } catch (e) {
      AppLogger.error('Failed to unmute conversation', e);
      rethrow;
    }
  }

  /// Mark all conversations as read for current user
  Future<void> markAllConversationsAsRead(
    Stream<List<Conversation>> Function() getMyConversations,
    Future<void> Function(String) markConversationAsRead,
  ) async {
    try {
      final currentUserId = authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final conversations = await getMyConversations().first;

      for (final conversation in conversations) {
        await markConversationAsRead(conversation.id);
      }

      AppLogger.info('All conversations marked as read');
    } catch (e) {
      AppLogger.error('Failed to mark all conversations as read', e);
      rethrow;
    }
  }
}
