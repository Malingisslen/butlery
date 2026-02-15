// lib/services/messaging/message_sending_operations.dart

import 'package:uuid/uuid.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notifications;
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Message sending operations for the messaging service.
/// Handles all message sending functionality including:
/// - Text messages with optional replies
/// - Image messages with captions
/// - Recipe, menu, and shopping list sharing
/// - Typing indicator clearing
/// - Notification sending to recipients
class MessageSendingOperations {
  final MessagingRepository messagingRepository;
  final auth_repo.AuthRepository authRepository;

  MessageSendingOperations({
    required this.messagingRepository,
    required this.authRepository,
  });

  /// Send a text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String content,
    String? replyToMessageId,
    required Future<void> Function(String, String) clearTypingIndicator,
  }) async {
    try {
      AppLogger.info('📤 [MessagingService] sendTextMessage called');
      AppLogger.debug('📤 [MessagingService] Conversation ID: $conversationId');
      AppLogger.debug('📤 [MessagingService] Content: "$content"');
      AppLogger.debug('📤 [MessagingService] Reply to: $replyToMessageId');

      final currentUser = authRepository.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ [MessagingService] User not authenticated');
        throw AuthenticationException('User must be authenticated');
      }
      AppLogger.debug(
          '📤 [MessagingService] Current user: ${currentUser.uid} (${currentUser.displayName})');

      if (content.trim().isEmpty) {
        AppLogger.error('❌ [MessagingService] Empty content');
        throw ValidationException('Message content cannot be empty');
      }

      AppLogger.debug('📤 [MessagingService] Creating Message object...');
      final message = Message.text(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? '?',
        senderAvatarUrl: currentUser.photoURL,
        content: content.trim(),
        replyToMessageId: replyToMessageId,
      );
      AppLogger.debug(
          '📤 [MessagingService] Message created with ID: ${message.id}');

      AppLogger.debug(
          '📤 [MessagingService] Calling repository.sendMessage...');
      await messagingRepository.sendMessage(message);
      AppLogger.success(
          '✅ [MessagingService] Repository.sendMessage completed');

      // Clear typing indicator for this user
      AppLogger.debug('📤 [MessagingService] Clearing typing indicator...');
      await clearTypingIndicator(conversationId, currentUser.uid);

      // Send notification to other participants
      AppLogger.debug('📤 [MessagingService] Sending notification...');
      await sendMessageNotification(message, conversationId);

      AppLogger.success(
          '✅ [MessagingService] Text message sent successfully: ${message.id}');
    } catch (e, stackTrace) {
      AppLogger.error('❌ [MessagingService] Failed to send text message', e);
      AppLogger.error('❌ [MessagingService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Send an image message
  Future<void> sendImageMessage({
    required String conversationId,
    required String imageUrl,
    String? caption,
    String? replyToMessageId,
    required Future<void> Function(String, String) clearTypingIndicator,
  }) async {
    try {
      final currentUser = authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      if (imageUrl.trim().isEmpty) {
        throw ValidationException('Image URL cannot be empty');
      }

      // Create image message using base constructor with metadata
      const uuid = Uuid();
      final message = Message(
        id: uuid.v4(),
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? '?',
        senderAvatarUrl: currentUser.photoURL,
        content: caption ?? '',
        type: MessageType.image,
        status: MessageStatus.sent,
        sentAt: DateTime.now(),
        metadata: {
          'imageUrl': imageUrl,
          if (caption != null && caption.isNotEmpty) 'caption': caption,
        },
        replyToMessageId: replyToMessageId,
      );

      await messagingRepository.sendMessage(message);

      // Clear typing indicator for this user
      await clearTypingIndicator(conversationId, currentUser.uid);

      // Send notification to other participants
      await sendMessageNotification(message, conversationId);

      AppLogger.debug('Image message sent: ${message.id}');
    } catch (e) {
      AppLogger.error('Failed to send image message', e);
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
      final currentUser = authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final shareMessage = Message.recipeShare(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? '?',
        senderAvatarUrl: currentUser.photoURL,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        message: message,
      );

      await messagingRepository.sendMessage(shareMessage);

      AppLogger.debug('Recipe share sent: ${shareMessage.id}');
    } catch (e) {
      AppLogger.error('Failed to send recipe share', e);
      rethrow;
    }
  }

  /// Send a menu share message
  Future<void> sendMenuShare({
    required String conversationId,
    required String menuId,
    required String menuTitle,
    String? message,
  }) async {
    try {
      final currentUser = authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final shareMessage = Message.menuShare(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? '?',
        senderAvatarUrl: currentUser.photoURL,
        menuId: menuId,
        menuTitle: menuTitle,
        message: message,
      );

      await messagingRepository.sendMessage(shareMessage);

      AppLogger.debug('Menu share sent: ${shareMessage.id}');
    } catch (e) {
      AppLogger.error('Failed to send menu share', e);
      rethrow;
    }
  }

  /// Send a shopping list share message
  Future<void> sendShoppingListShare({
    required String conversationId,
    required String listId,
    required String listTitle,
    String? message,
  }) async {
    try {
      final currentUser = authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final shareMessage = Message.shoppingListShare(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: currentUser.displayName ?? '?',
        senderAvatarUrl: currentUser.photoURL,
        listId: listId,
        listTitle: listTitle,
        message: message,
      );

      await messagingRepository.sendMessage(shareMessage);

      AppLogger.debug('Shopping list share sent: ${shareMessage.id}');
    } catch (e) {
      AppLogger.error('Failed to send shopping list share', e);
      rethrow;
    }
  }

  /// Send notification to other participants in conversation
  Future<void> sendMessageNotification(
      Message message, String conversationId) async {
    try {
      // Don't send notifications to ourselves
      if (message.isFromCurrentUser(authRepository.currentUserId ?? '')) {
        return;
      }

      // Get conversation to determine recipients
      final conversation =
          await messagingRepository.getConversation(conversationId);
      if (conversation == null) {
        AppLogger.warning(
            'Cannot send notification - conversation not found: $conversationId');
        return;
      }

      // Get notification service
      final notificationService =
          ServiceLocator.get<notifications.NotificationService>();

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
}
