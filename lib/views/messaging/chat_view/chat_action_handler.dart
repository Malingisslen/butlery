/// Nuclear Action Handler Component - Chat Actions Logic
/// 
/// Focused component handling ALL chat action logic that was previously
/// scattered throughout the massive ChatView. Implements clean separation
/// of concerns with proper error handling and user feedback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart';
import 'package:image_picker/image_picker.dart';

/// Centralized chat action handler with clean interfaces
class ChatActionHandler {
  final String conversationId;
  final BuildContext context;
  final MessagingService _messagingService;
  final ImagePicker _imagePicker = ImagePicker();

  ChatActionHandler({
    required this.conversationId,
    required this.context,
  }) : _messagingService = ServiceLocator.get<MessagingService>();

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
      default:
        AppLogger.warning('Unknown message action: $action');
    }
  }

  /// Handle sending new messages
  Future<void> handleSendMessage(String content, {MessageType type = MessageType.text}) async {
    try {
      if (content.trim().isEmpty) return;
      
      AppLogger.debug('Sending message: $content');
      // Send based on message type
      if (type == MessageType.text) {
        await _messagingService.sendTextMessage(
          conversationId: conversationId,
          content: content,
        );
      } else if (type == MessageType.image) {
        // For images, content would be the path - in production this would upload first
        await _messagingService.sendTextMessage(
          conversationId: conversationId,
          content: '[Image: $content]',
        );
      } else {
        // For other types, send as text with type prefix
        await _messagingService.sendTextMessage(
          conversationId: conversationId,
          content: content,
        );
      }
      AppLogger.success('Message sent successfully');
    } catch (e) {
      AppLogger.error('Failed to send message', e);
      _showErrorSnackBar('Ett fel uppstod');
    }
  }

  /// Handle attachment actions
  Future<void> handleAttachment(String attachmentType) async {
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
      // In production, this would fetch the conversation details
      // For now, show a simple info dialog
      final currentUserId = ServiceLocator.get<PermissionService>().currentUserId;
      if (currentUserId == null) return;
      
      if (!context.mounted) return;
      
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Konversationsinformation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Konversations-ID: $conversationId'),
              const Text('Typ: Direktmeddelande'),
              const Text('Status: Aktiv'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Stäng'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to show conversation info', e);
    }
  }

  Future<void> _toggleMute() async {
    AppLogger.info('Toggling conversation mute');
    
    try {
      // In production, this would toggle mute status through the messaging repository
      // For now, just show a message that notifications are toggled
      _showErrorSnackBar('Notifikationsinställningar uppdaterade');
    } catch (e) {
      AppLogger.error('Failed to toggle mute', e);
      _showErrorSnackBar('Kunde inte ändra notifikationsinställningar');
    }
  }

  Future<void> _leaveConversation() async {
    AppLogger.info('Leaving conversation');
    
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lämna konversation'),
          content: const Text('Är du säker på att du vill lämna konversationen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lämna'),
            ),
          ],
        ),
      ) ?? false;
      
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
      _showErrorSnackBar('Kunde inte lämna konversationen');
    }
  }

  Future<void> _replyToMessage(Message message) async {
    AppLogger.info('Replying to message: ${message.id}');
    // Reply context would be set in the parent widget
    // This handler just notifies the parent about the reply action
    Navigator.of(context).pop({
      'action': 'reply',
      'message': message,
    });
  }

  Future<void> _editMessage(Message message) async {
    AppLogger.info('Editing message: ${message.id}');
    
    // Show edit dialog
    final controller = TextEditingController(text: message.content);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redigera meddelande'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Skriv ditt meddelande...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Spara'),
          ),
        ],
      ),
    );
    
    if (edited != null && edited.trim().isNotEmpty && edited != message.content) {
      try {
        await _messagingService.editMessage(
          messageId: message.id,
          newContent: edited,
        );
        AppLogger.success('Message edited');
      } catch (e) {
        AppLogger.error('Failed to edit message', e);
        _showErrorSnackBar('Kunde inte redigera meddelandet');
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
      _showErrorSnackBar('Kunde inte ta bort meddelandet');
    }
  }

  Future<void> _copyMessage(Message message) async {
    AppLogger.info('Copying message: ${message.content}');
    
    try {
      await Clipboard.setData(ClipboardData(text: message.content));
      _showErrorSnackBar('Meddelande kopierat');
    } catch (e) {
      AppLogger.error('Failed to copy message', e);
      _showErrorSnackBar('Kunde inte kopiera meddelandet');
    }
  }

  Future<void> _shareRecipe() async {
    AppLogger.info('Sharing recipe');
    
    try {
      final selectedRecipes = await showDialog<List<String>>(
        context: context,
        builder: (context) => const MenuRecipeSelectionDialog(
          categoryName: 'Dina recept',
        ),
      );
      
      if (selectedRecipes != null && selectedRecipes.isNotEmpty) {
        // Send recipe share using the messaging service
        await _messagingService.sendRecipeShare(
          conversationId: conversationId,
          recipeId: selectedRecipes.first,
          recipeTitle: 'Delat recept', // In production, fetch the actual title
          message: 'Kolla in detta recept!',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to share recipe', e);
      _showErrorSnackBar('Kunde inte dela recept');
    }
  }

  Future<void> _shareMenu() async {
    AppLogger.info('Sharing menu');
    
    try {
      // For menus, we'll send a special message type
      // The menu selection would be handled by a dedicated dialog
      _showErrorSnackBar('Menydelning kommer snart');
    } catch (e) {
      AppLogger.error('Failed to share menu', e);
      _showErrorSnackBar('Kunde inte dela meny');
    }
  }

  Future<void> _shareShoppingList() async {
    AppLogger.info('Sharing shopping list');
    
    try {
      // Shopping list sharing would involve selecting from user's lists
      _showErrorSnackBar('Inköpslistedelning kommer snart');
    } catch (e) {
      AppLogger.error('Failed to share shopping list', e);
      _showErrorSnackBar('Kunde inte dela inköpslista');
    }
  }

  Future<void> _sharePhoto() async {
    AppLogger.info('Sharing photo');
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Upload image and send as message
        await handleSendMessage(
          image.path,
          type: MessageType.image,
        );
      }
    } catch (e) {
      AppLogger.error('Failed to share photo', e);
      _showErrorSnackBar('Kunde inte dela foto');
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ta bort'),
        content: const Text('Är du säker på att du vill ta bort meddelandet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void dispose() {
    // Clean up any resources
  }
}