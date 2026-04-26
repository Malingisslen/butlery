/// Nuclear Action Handler Component - Chat Actions Logic
/// Focused component handling ALL chat action logic that was previously
/// scattered throughout the massive ChatView. Implements clean separation
/// of concerns with proper error handling and user feedback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/messaging_media_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart';
import 'package:butlery/views/messaging/group_detail_view.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:image_picker/image_picker.dart';

/// Centralized chat action handler with clean interfaces
class ChatActionHandler {
  final String conversationId;
  final BuildContext context;
  final MessagingService _messagingService;
  final MessagingMediaService _mediaService;
  final Function(Message)? onReplyToMessage;

  ChatActionHandler({
    required this.conversationId,
    required this.context,
    this.onReplyToMessage,
  })  : _messagingService = ServiceLocator.get<MessagingService>(),
        _mediaService = MessagingMediaService(
          messagingService: ServiceLocator.get(),
          authRepository: ServiceLocator.get(),
        );

  /// Handle menu actions from chat app bar
  Future<void> handleMenuAction(String action) async {
    switch (action) {
      case 'info':
        await _showConversationInfo();
        break;
      case 'mute':
        await _toggleMute();
        break;
      case 'leave':
        await _leaveConversation();
        break;
      default:
        AppLogger.warning('Unknown menu action: $action');
    }
  }

  /// Handle message-specific actions (reply, edit, delete, copy)
  Future<void> handleMessageAction(Message message, String action) async {
    switch (action) {
      case 'reply':
        await _replyToMessage(message);
        break;
      case 'edit':
        await _editMessage(message);
        break;
      case 'delete':
        await _deleteMessage(message);
        break;
      case 'copy':
        await _copyMessage(message);
        break;
      case 'report':
        ReportContentDialog.show(
          context: context,
          contentType: ContentType.message,
          contentId: message.id,
          contentOwnerId: message.senderId,
        );
        break;
      default:
        AppLogger.warning('Unknown message action: $action');
    }
  }

  /// Handle sending new messages
  Future<void> handleSendMessage(String content,
      {MessageType type = MessageType.text}) async {
    try {
      if (content.trim().isEmpty) {
        AppLogger.warning(
            '📤 [ChatActionHandler] Empty content, aborting send');
        return;
      }

      AppLogger.info('📤 [ChatActionHandler] Received send request');
      AppLogger.debug('📤 [ChatActionHandler] Content: "$content"');
      AppLogger.debug('📤 [ChatActionHandler] Type: $type');
      AppLogger.debug(
          '📤 [ChatActionHandler] Conversation ID: $conversationId');

      // Send based on message type
      if (type == MessageType.text) {
        AppLogger.debug(
            '📤 [ChatActionHandler] Calling MessagingService.sendTextMessage...');
        await _messagingService.sendTextMessage(
          conversationId: conversationId,
          content: content,
        );
        AppLogger.success(
            '✅ [ChatActionHandler] MessagingService.sendTextMessage completed');
      } else if (type == MessageType.image) {
        AppLogger.debug('📤 [ChatActionHandler] Sending image message...');
        // For images, content would be the path - in production this would upload first
        await _messagingService.sendTextMessage(
          conversationId: conversationId,
          content: '[Image: $content]',
        );
        AppLogger.success('✅ [ChatActionHandler] Image message sent');
      } else {
        AppLogger.debug('📤 [ChatActionHandler] Sending other message type...');
        // For other types, send as text with type prefix
        await _messagingService.sendTextMessage(
          conversationId: conversationId,
          content: content,
        );
        AppLogger.success('✅ [ChatActionHandler] Other type message sent');
      }
      AppLogger.success(
          '✅ [ChatActionHandler] Message send operation completed successfully');
    } catch (e, stackTrace) {
      AppLogger.error('❌ [ChatActionHandler] Failed to send message', e);
      AppLogger.error('❌ [ChatActionHandler] Stack trace: $stackTrace');
      if (!context.mounted) rethrow;
      _showErrorSnackBar(context.l10n.chatErrorOccurred);
      rethrow;
    }
  }

  /// Handle swipe-to-reply action directly on a message
  void handleSwipeToReply(Message message) {
    AppLogger.debug('Swipe-to-reply triggered for message: ${message.id}');
    onReplyToMessage?.call(message);
  }

  /// Handle attachment actions
  Future<void> handleAttachment(String attachmentType) async {
    // Check if it's a photo attachment with source
    if (attachmentType.startsWith('photo:')) {
      final sourceName = attachmentType.split(':')[1];
      final source =
          sourceName == 'camera' ? ImageSource.camera : ImageSource.gallery;
      await _sharePhoto(source: source);
      return;
    }

    switch (attachmentType) {
      case 'recipe':
        await _shareRecipe();
        break;
      case 'menu':
        await _shareMenu();
        break;
      case 'shopping_list':
        await _shareShoppingList();
        break;
      case 'photo':
        await _sharePhoto();
        break;
      default:
        AppLogger.warning('Unknown attachment type: $attachmentType');
    }
  }

  // Private action implementations
  Future<void> _showConversationInfo() async {
    AppLogger.info('Showing conversation info');

    try {
      if (!context.mounted) return;

      // Get conversation to check if it's a group
      final conversation =
          await _messagingService.getConversation(conversationId);

      if (!context.mounted) return;

      // For group conversations, navigate to GroupDetailView
      if (conversation != null && conversation.isGroup) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ConversationGroupDetailView(
              conversationId: conversationId,
            ),
          ),
        );
      } else {
        // For direct conversations, show simple info dialog
        final l10n = context.l10n;
        await showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.chatConversationInfo),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.chatTypeDirectMessage),
                if (conversation != null) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(l10n.chatCreatedAt(conversation.createdAt
                      .toLocal()
                      .toString()
                      .split('.')[0])),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonClose),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to show conversation info', e);
    }
  }

  Future<void> _toggleMute() async {
    AppLogger.info('Toggling conversation mute');

    try {
      // In production, this would toggle mute status through the messaging repository
      // For now, just show a message that notifications are toggled
      _showInfoSnackBar(context.l10n.chatNotificationSettingsUpdated);
    } catch (e) {
      AppLogger.error('Failed to toggle mute', e);
      _showErrorSnackBar(context.l10n.chatCouldNotChangeNotifications);
    }
  }

  Future<void> _leaveConversation() async {
    AppLogger.info('Leaving conversation');

    try {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.chatLeaveConversation),
              content: Text(l10n.chatLeaveConversationConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.messagingLeave),
                ),
              ],
            ),
          ) ??
          false;

      if (confirmed) {
        // In production, this would remove the user from the conversation
        // For now, just navigate back
        AppLogger.info('Leaving conversation: $conversationId');
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      AppLogger.error('Failed to leave conversation', e);
      if (!context.mounted) return;
      _showErrorSnackBar(context.l10n.chatCouldNotLeaveConversation);
    }
  }

  Future<void> _replyToMessage(Message message) async {
    AppLogger.info('Replying to message: ${message.id}');
    // Notify viewmodel about reply action
    onReplyToMessage?.call(message);
  }

  Future<void> _editMessage(Message message) async {
    AppLogger.info('Editing message: ${message.id}');

    // Show edit dialog
    final l10n = context.l10n;
    final controller = TextEditingController(text: message.content);
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatEditMessage),
        content: TextField(
          controller: controller,
          maxLines: null,
          maxLength: 5000,
          decoration: InputDecoration(
            hintText: l10n.chatWriteYourMessage,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );

    if (edited != null &&
        edited.trim().isNotEmpty &&
        edited != message.content) {
      try {
        await _messagingService.editMessage(
          messageId: message.id,
          newContent: edited,
        );
        AppLogger.success('Message edited');
      } catch (e) {
        AppLogger.error('Failed to edit message', e);
        _showErrorSnackBar(l10n.chatCouldNotEditMessage);
      }
    }
    controller.dispose();
  }

  Future<void> _deleteMessage(Message message) async {
    try {
      final confirmed = await _showDeleteConfirmation();
      if (confirmed) {
        AppLogger.debug('Deleting message: ${message.id}');
        await _messagingService.deleteMessage(message.id);
        AppLogger.success('Message deleted');
      }
    } catch (e) {
      AppLogger.error('Failed to delete message', e);
      if (!context.mounted) return;
      _showErrorSnackBar(context.l10n.chatCouldNotDeleteMessage);
    }
  }

  Future<void> _copyMessage(Message message) async {
    AppLogger.info('Copying message: ${message.content}');

    try {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (!context.mounted) return;
      _showSuccessSnackBar(context.l10n.chatMessageCopied);
    } catch (e) {
      AppLogger.error('Failed to copy message', e);
      if (!context.mounted) return;
      _showErrorSnackBar(context.l10n.chatCouldNotCopyMessage);
    }
  }

  Future<void> _shareRecipe() async {
    AppLogger.info('Sharing recipe');

    try {
      final l10n = context.l10n;
      final selectedRecipes = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => MenuRecipeSelectionDialog(
          categoryName: l10n.chatYourRecipes,
        ),
      );

      if (selectedRecipes != null && selectedRecipes.isNotEmpty) {
        // Send recipe share using the messaging service
        await _messagingService.sendRecipeShare(
          conversationId: conversationId,
          recipeId: selectedRecipes.first,
          recipeTitle:
              l10n.chatSharedRecipe, // In production, fetch the actual title
          message: l10n.chatCheckOutRecipe,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to share recipe', e);
      if (!context.mounted) return;
      _showErrorSnackBar(context.l10n.chatCouldNotShareRecipe);
    }
  }

  Future<void> _shareMenu() async {
    AppLogger.info('Sharing menu');

    try {
      // For menus, we'll send a special message type
      // The menu selection would be handled by a dedicated dialog
      _showInfoSnackBar(context.l10n.chatMenuSharingComingSoon);
    } catch (e) {
      AppLogger.error('Failed to share menu', e);
      _showErrorSnackBar(context.l10n.chatCouldNotShareMenu);
    }
  }

  Future<void> _shareShoppingList() async {
    AppLogger.info('Sharing shopping list');

    try {
      // Shopping list sharing would involve selecting from user's lists
      _showInfoSnackBar(context.l10n.chatShoppingListSharingComingSoon);
    } catch (e) {
      AppLogger.error('Failed to share shopping list', e);
      _showErrorSnackBar(context.l10n.chatCouldNotShareShoppingList);
    }
  }

  Future<void> _sharePhoto({ImageSource source = ImageSource.gallery}) async {
    AppLogger.info(
        'Sharing photo from ${source == ImageSource.camera ? "camera" : "gallery"}');

    try {
      final l10n = context.l10n;
      // Show loading indicator
      _showInfoSnackBar(l10n.chatLoadingImage);

      // Use MediaService to pick and send image
      final success = await _mediaService.pickAndSendImage(
        conversationId: conversationId,
        source: source,
        onProgress: (progress) {
          // Could update UI with progress here
          AppLogger.debug(
              'Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      if (success) {
        _showSuccessSnackBar(l10n.chatImageSent);
      } else {
        _showErrorSnackBar(l10n.chatNoImageSelected);
      }
    } catch (e) {
      AppLogger.error('Failed to share photo', e);
      if (!context.mounted) return;
      _showErrorSnackBar(context.l10n.chatCouldNotSharePhoto);
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    final l10n = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.chatDeleteMessage),
            content: Text(l10n.chatDeleteMessageConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.butleryColors.success,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void dispose() {
    // Clean up any resources
  }
}
