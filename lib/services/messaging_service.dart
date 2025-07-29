// lib/services/messaging_service.dart

import 'dart:async';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/services/notifications/notification_service.dart' as notifications;
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/injection.dart';

/// Service for managing messaging functionality
/// 
/// Provides business logic layer for messaging operations including:
/// - Conversation management
/// - Message sending and receiving
/// - Read status tracking
/// - User presence and typing indicators
/// - Message search and filtering
class MessagingService extends BaseService {
  final MessagingRepository _messagingRepository;
  final auth_repo.AuthRepository _authRepository;

  @override
  String get serviceName => 'MessagingService';

  // Typing indicators tracking
  final Map<String, Timer> _typingTimers = {};
  final Map<String, Set<String>> _typingUsers = {};

  MessagingService({
    required MessagingRepository messagingRepository,
    required auth_repo.AuthRepository authRepository,
  }) : _messagingRepository = messagingRepository,
       _authRepository = authRepository;

  // ===== CONVERSATION OPERATIONS =====

  /// Get all conversations for current user
  Stream<List<Conversation>> getMyConversations() {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) {
      AppLogger.error('User must be authenticated to get conversations');
      return const Stream.empty();
    }

    return _messagingRepository.getUserConversations(currentUserId);
  }

  /// Start or get existing direct conversation with another user
  Future<String> startDirectConversation({
    required String otherUserId,
    required String otherUserDisplayName,
    String? otherUserAvatarUrl,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      // Check if conversation already exists
      final existingConversationId = await _messagingRepository.findDirectConversation(
        user1Id: currentUser.uid,
        user2Id: otherUserId,
      );

      if (existingConversationId != null) {
        AppLogger.debug('Found existing conversation: $existingConversationId');
        return existingConversationId;
      }

      // Create new conversation
      final conversationId = await _messagingRepository.createDirectConversation(
        user1Id: currentUser.uid,
        user1DisplayName: currentUser.displayName ?? 'Okänd användare',
        user1AvatarUrl: currentUser.photoURL,
        user2Id: otherUserId,
        user2DisplayName: otherUserDisplayName,
        user2AvatarUrl: otherUserAvatarUrl,
      );

      AppLogger.success('✅ Direct conversation started: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to start direct conversation with $otherUserId', e);
      rethrow;
    }
  }

  /// Create a new group conversation
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      // Add current user to participants if not already included
      final allParticipantIds = [...participantIds];
      if (!allParticipantIds.contains(currentUser.uid)) {
        allParticipantIds.add(currentUser.uid);
        participantDisplayNames[currentUser.uid] = currentUser.displayName ?? 'Okänd användare';
        participantAvatarUrls[currentUser.uid] = currentUser.photoURL;
      }

      final conversationId = await _messagingRepository.createGroupConversation(
        participantIds: allParticipantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
        creatorId: currentUser.uid,
      );

      AppLogger.success('✅ Group conversation created: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      rethrow;
    }
  }

  /// Get conversation details
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      return await _messagingRepository.getConversation(conversationId);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  // ===== MESSAGE OPERATIONS =====

  /// Get messages for a conversation
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) {
    return _messagingRepository.getConversationMessages(
      conversationId: conversationId,
      limit: limit,
    );
  }

  /// Send a text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String content,
    String? replyToMessageId,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      if (content.trim().isEmpty) {
        throw ValidationException('Message content cannot be empty');
      }

      final message = Message.text(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? 'Okänd användare',
        senderAvatarUrl: currentUser.photoURL,
        content: content.trim(),
        replyToMessageId: replyToMessageId,
      );

      await _messagingRepository.sendMessage(message);
      
      // Clear typing indicator for this user
      await _clearTypingIndicator(conversationId, currentUser.uid);
      
      // Send notification to other participants
      await _sendMessageNotification(message, conversationId);
      
      AppLogger.debug('Text message sent: ${message.id}');
    } catch (e) {
      AppLogger.error('Failed to send text message', e);
      rethrow;
    }
  }

  /// Send a recipe share message
  Future<void> sendRecipeShare({
    required String conversationId,
    required String recipeId,
    required String recipeTitle,
    String? message,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final shareMessage = Message.recipeShare(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? 'Okänd användare',
        senderAvatarUrl: currentUser.photoURL,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        message: message,
      );

      await _messagingRepository.sendMessage(shareMessage);
      
      AppLogger.debug('Recipe share sent: ${shareMessage.id}');
    } catch (e) {
      AppLogger.error('Failed to send recipe share', e);
      rethrow;
    }
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await _messagingRepository.markConversationAsRead(
        conversationId: conversationId,
        userId: currentUserId,
      );
      
      AppLogger.debug('Conversation marked as read: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read: $conversationId', e);
    }
  }

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
      final message = await _messagingRepository.getMessage(messageId);
      if (message == null) {
        throw ResourceNotFoundException(
          'Message not found',
          resourceType: 'message',
          resourceId: messageId,
        );
      }

      final currentUserId = _authRepository.currentUserId;
      if (message.senderId != currentUserId) {
        throw PermissionDeniedException(
          'Can only edit own messages',
          resource: 'message:$messageId',
          userId: currentUserId,
        );
      }

      await _messagingRepository.updateMessageContent(
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
      final message = await _messagingRepository.getMessage(messageId);
      if (message == null) {
        throw ResourceNotFoundException(
          'Message not found',
          resourceType: 'message',
          resourceId: messageId,
        );
      }

      final currentUserId = _authRepository.currentUserId;
      if (message.senderId != currentUserId) {
        throw PermissionDeniedException(
          'Can only delete own messages',
          resource: 'message:$messageId',
          userId: currentUserId,
        );
      }

      await _messagingRepository.deleteMessage(messageId);
      
      AppLogger.debug('Message deleted: $messageId');
    } catch (e) {
      AppLogger.error('Failed to delete message $messageId', e);
      rethrow;
    }
  }

  // ===== TYPING INDICATORS =====

  /// Set typing indicator for current user in conversation
  Future<void> setTypingIndicator(String conversationId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) return;

      // Add user to typing set
      _typingUsers.putIfAbsent(conversationId, () => <String>{});
      _typingUsers[conversationId]!.add(currentUserId);

      // Cancel existing timer
      _typingTimers[conversationId]?.cancel();

      // Set timer to clear typing indicator after 3 seconds of inactivity
      _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
        _clearTypingIndicator(conversationId, currentUserId);
      });

      AppLogger.debug('Typing indicator set for $currentUserId in $conversationId');
    } catch (e) {
      AppLogger.error('Failed to set typing indicator', e);
    }
  }

  /// Clear typing indicator for current user
  Future<void> clearTypingIndicator(String conversationId) async {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) return;

    await _clearTypingIndicator(conversationId, currentUserId);
  }

  Future<void> _clearTypingIndicator(String conversationId, String userId) async {
    _typingUsers[conversationId]?.remove(userId);
    if (_typingUsers[conversationId]?.isEmpty == true) {
      _typingUsers.remove(conversationId);
    }
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);

    AppLogger.debug('Typing indicator cleared for $userId in $conversationId');
  }

  /// Get users currently typing in conversation
  List<String> getTypingUsers(String conversationId) {
    final currentUserId = _authRepository.currentUserId;
    return _typingUsers[conversationId]
        ?.where((userId) => userId != currentUserId)
        .toList() ?? [];
  }

  // ===== UTILITY OPERATIONS =====

  /// Search messages in conversation
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      return await _messagingRepository.searchMessages(
        conversationId: conversationId,
        query: query.trim(),
        limit: limit,
      );
    } catch (e) {
      AppLogger.error('Failed to search messages in $conversationId', e);
      return [];
    }
  }

  /// Get unread message count for current user
  Future<int> getUnreadMessageCount() async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) return 0;

      return await _messagingRepository.getUnreadMessageCount(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get unread message count', e);
      return 0;
    }
  }

  /// Get unread conversations count for current user
  Future<int> getUnreadConversationsCount() async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) return 0;

      return await _messagingRepository.getUnreadConversationsCount(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get unread conversations count', e);
      return 0;
    }
  }

  /// Add participants to group conversation
  Future<void> addParticipantsToGroup({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async {
    try {
      await _messagingRepository.addParticipants(
        conversationId: conversationId,
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
      );
      
      AppLogger.success('✅ Added participants to group conversation: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to add participants to group', e);
      rethrow;
    }
  }

  /// Remove participant from group conversation
  Future<void> removeParticipantFromGroup({
    required String conversationId,
    required String participantId,
  }) async {
    try {
      await _messagingRepository.removeParticipant(
        conversationId: conversationId,
        participantId: participantId,
      );
      
      AppLogger.success('✅ Removed participant from group conversation: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to remove participant from group', e);
      rethrow;
    }
  }

  /// Update group conversation title
  Future<void> updateGroupTitle({
    required String conversationId,
    required String newTitle,
  }) async {
    try {
      if (newTitle.trim().isEmpty) {
        throw ValidationException('Group title cannot be empty');
      }

      await _messagingRepository.updateConversation(
        conversationId: conversationId,
        title: newTitle.trim(),
      );
      
      AppLogger.debug('Group title updated: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update group title', e);
      rethrow;
    }
  }

  // ===== NOTIFICATION METHODS =====

  /// Send push notification for new message
  Future<void> _sendMessageNotification(Message message, String conversationId) async {
    try {
      // Don't send notifications to ourselves
      if (message.isFromCurrentUser(_authRepository.currentUserId ?? '')) {
        return;
      }

      // Get conversation to determine recipients
      final conversation = await getConversation(conversationId);
      if (conversation == null) {
        AppLogger.warning('Cannot send notification - conversation not found: $conversationId');
        return;
      }

      // Get notification service
      final notificationService = sl<notifications.NotificationService>();

      // Determine notification title and body based on conversation type
      String title;
      String body;
      
      if (conversation.isGroup) {
        title = conversation.title ?? 'Gruppchatt';
        body = '${message.senderDisplayName}: ${message.displayContent}';
      } else {
        title = message.senderDisplayName;
        body = message.displayContent;
      }

      // Get target user IDs (all participants except sender)
      final targetUserIds = conversation.participantIds
          .where((id) => id != message.senderId)
          .toList();

      if (targetUserIds.isNotEmpty) {
        // Create notification strategy for messaging
        const strategy = NotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.messaging,
        );

        // Send notification
        await notificationService.sendImmediateNotification(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: {
            'title': title,
            'body': body,
            'sender_name': message.senderDisplayName,
          },
          additionalData: {
            'type': 'new_message',
            'conversationId': conversationId,
            'messageId': message.id,
            'senderId': message.senderId,
            'senderName': message.senderDisplayName,
          },
        );
      }

      AppLogger.debug('Message notifications sent for message: ${message.id}');
    } catch (e) {
      AppLogger.error('Failed to send message notification', e);
      // Don't rethrow - notification failure shouldn't break message sending
    }
  }

  // ===== SERVICE LIFECYCLE =====

  @override
  Future<void> dispose() async {
    // Cancel all typing timers
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _typingUsers.clear();
    
    await super.dispose();
  }
}