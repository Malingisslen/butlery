// lib/services/messaging/message_sending_operations.dart

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/pending_image_status.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/services/notifications/notification_service.dart'
    as notifications;
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/attribution_source.dart';

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
  final AttributionSource _attribution;
  final notifications.NotificationService Function() _getNotificationService;

  MessageSendingOperations({
    required this.messagingRepository,
    required this.authRepository,
    required notifications.NotificationService Function()
    getNotificationService,
    AttributionSource? attribution,
  }) : _getNotificationService = getNotificationService,
       _attribution = attribution ?? AttributionSource();

  /// Send a text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String content,
    String? replyToMessageId,
    required Future<void> Function(String, String) clearTypingIndicator,
  }) async {
    try {
      AppLogger.info('📤 [MessagingService] sendTextMessage called');
      AppLogger.debug(
        '📤 [MessagingService] Conversation ID: ${conversationId.maskedConversationId}',
      );
      AppLogger.debug('📤 [MessagingService] Content: "$content"');
      AppLogger.debug('📤 [MessagingService] Reply to: $replyToMessageId');

      final currentUser = authRepository.currentUser;
      if (currentUser == null) {
        AppLogger.error('❌ [MessagingService] User not authenticated');
        throw AuthenticationException('User must be authenticated');
      }
      AppLogger.debug(
        '📤 [MessagingService] Current user: ${currentUser.uid.maskedUserId}',
      );

      if (content.trim().isEmpty) {
        AppLogger.error('❌ [MessagingService] Empty content');
        throw ValidationException('Message content cannot be empty');
      }

      AppLogger.debug('📤 [MessagingService] Creating Message object...');
      final message = Message.text(
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: _attribution.displayName,
        senderAvatarUrl: _attribution.avatarUrl,
        content: content.trim(),
        replyToMessageId: replyToMessageId,
      );
      AppLogger.debug(
        '📤 [MessagingService] Message created with ID: ${message.id}',
      );

      AppLogger.debug(
        '📤 [MessagingService] Calling repository.sendMessage...',
      );
      await messagingRepository.sendMessage(message);
      AppLogger.success(
        '✅ [MessagingService] Repository.sendMessage completed',
      );

      // Clear typing indicator for this user
      AppLogger.debug('📤 [MessagingService] Clearing typing indicator...');
      await clearTypingIndicator(conversationId, currentUser.uid);

      // Send notification to other participants
      AppLogger.debug('📤 [MessagingService] Sending notification...');
      await sendMessageNotification(message, conversationId);

      AppLogger.success(
        '✅ [MessagingService] Text message sent successfully: ${message.id}',
      );
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
        senderDisplayName: _attribution.displayName,
        senderAvatarUrl: _attribution.avatarUrl,
        content: caption.orEmpty(),
        type: MessageType.image,
        status: MessageStatus.sent,
        sentAt: clock.now(),
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

  /// BUT-2294: the message of a chat image that is waiting for a connection.
  /// It is created now, through Firestore's own queue, so it keeps its place
  /// among the messages sent after it; the picture is set on it later.
  Future<void> sendPendingImageMessage({
    required String conversationId,
    required String messageId,
    required Future<void> Function(String, String) clearTypingIndicator,
  }) async {
    final currentUser = authRepository.currentUser;
    if (currentUser == null) {
      throw AuthenticationException('User must be authenticated');
    }
    await messagingRepository.sendMessage(
      Message(
        id: messageId,
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName: _attribution.displayName,
        senderAvatarUrl: _attribution.avatarUrl,
        content: '',
        type: MessageType.image,
        status: MessageStatus.sent,
        sentAt: clock.now(),
        metadata: const {pendingImageMetadataKey: true},
      ),
    );
    await clearTypingIndicator(conversationId, currentUser.uid);
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
        senderDisplayName: _attribution.displayName,
        senderAvatarUrl: _attribution.avatarUrl,
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
        senderDisplayName: _attribution.displayName,
        senderAvatarUrl: _attribution.avatarUrl,
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
        senderDisplayName: _attribution.displayName,
        senderAvatarUrl: _attribution.avatarUrl,
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
    Message message,
    String conversationId,
  ) async {
    try {
      // Don't send notifications to ourselves
      if (message.isFromCurrentUser(authRepository.currentUserId.orEmpty())) {
        return;
      }

      // Get conversation to determine recipients
      final conversation = await messagingRepository.getConversation(
        conversationId,
      );
      if (conversation == null) {
        AppLogger.warning(
          'Cannot send notification - conversation not found: ${conversationId.maskedConversationId}',
        );
        return;
      }

      // Get notification service
      final notificationService = _getNotificationService();

      // Determine notification title and body based on conversation type
      String title;
      String body;

      // The sender may have no profile name; the push text is built in the
      // sender's language, as everywhere else.
      final senderName = storedNameOr(
        message.senderDisplayName,
        AppLocale.current.displayUnknownUser,
      );

      if (conversation.isGroup) {
        title = conversation.title ?? AppLocale.current.conversationGroupChat;
        body = '$senderName: ${message.displayContent}';
      } else {
        title = senderName;
        body = message.displayContent;
      }

      // Get target user IDs (all participants except sender)
      final targetUserIds = conversation.participantIds
          .where((id) => id != message.senderId)
          .toList();

      if (targetUserIds.isNotEmpty) {
        await notificationService.sendImmediateNotification(
          targetUserIds: targetUserIds,
          strategy: NotificationStrategy.chatMessage,
          variables: {
            'title': title,
            'body': body,
            'sender_name': senderName,
          },
          additionalData: {
            'type': 'new_message',
            'conversationId': conversationId,
            'messageId': message.id,
            'senderId': message.senderId,
            'senderName': senderName,
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
