// lib/views/messaging/chat_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:butlery/widgets/messaging/message_bubble.dart';
import 'package:butlery/widgets/messaging/chat_app_bar.dart';
import 'package:butlery/widgets/messaging/message_input_container.dart';
import 'package:butlery/widgets/messaging/message_input_field.dart';
import 'package:butlery/widgets/messaging/typing_indicator_container.dart';
import 'package:butlery/widgets/messaging/attachment_options_container.dart';
import 'package:butlery/widgets/messaging/styled_modal_bottom_sheet.dart';
import 'package:butlery/widgets/messaging/modal_content_container.dart';
import 'package:butlery/widgets/messaging/error_text.dart';
import 'package:butlery/widgets/messaging/error_list_tile.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

/// Chat view for displaying and sending messages in a conversation
/// 
/// Provides full chat functionality including:
/// - Real-time message list with auto-scroll
/// - Text input with send functionality
/// - Typing indicators display
/// - Message status indicators
/// - Pull-to-refresh for loading older messages
/// - Integration with existing share functionality
class ChatView extends StatefulWidget {
  final String conversationId;
  final Conversation? conversation;

  const ChatView({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  late final MessagingService _messagingService;
  late final AuthRepository _authRepository;
  
  String? _currentUserId;
  Conversation? _conversation;
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  final List<String> _typingUsers = [];

  @override
  void initState() {
    super.initState();
    _messagingService = sl<MessagingService>();
    _authRepository = sl<AuthRepository>();
    _currentUserId = _authRepository.currentUserId;
    _conversation = widget.conversation;
    
    _setupListeners();
    _loadConversation();
    _loadMessages();
  }

  void _setupListeners() {
    // Listen to typing changes
    _messageController.addListener(_onTypingChanged);
    
    // Listen to focus changes
    _messageFocusNode.addListener(_onFocusChanged);
  }

  void _onTypingChanged() {
    final text = _messageController.text;
    if (text.isNotEmpty) {
      _messagingService.setTypingIndicator(widget.conversationId);
    } else {
      _messagingService.clearTypingIndicator(widget.conversationId);
    }
  }

  void _onFocusChanged() {
    if (_messageFocusNode.hasFocus) {
      _scrollToBottom();
      // Mark conversation as read when user focuses on input
      _messagingService.markConversationAsRead(widget.conversationId);
    }
  }

  Future<void> _loadConversation() async {
    if (_conversation == null) {
      final conversation = await _messagingService.getConversation(widget.conversationId);
      if (conversation != null && mounted) {
        setState(() {
          _conversation = conversation;
        });
      }
    }
  }

  void _loadMessages() {
    _messagingService.getConversationMessages(
      conversationId: widget.conversationId,
      limit: 50,
    ).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _messagingService.sendTextMessage(
        conversationId: widget.conversationId,
        content: content,
      );
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kunde inte skicka meddelandet: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _getAppBarTitle() {
    if (_conversation == null) return 'Laddar...';
    
    if (_currentUserId == null) return _conversation!.title ?? 'Chatt';
    
    return _conversation!.getDisplayTitle(_currentUserId!);
  }

  Widget _buildAppBarActions() {
    if (_conversation == null || _currentUserId == null) return const SizedBox.shrink();
    
    return PopupMenuButton<String>(
      onSelected: _handleMenuAction,
      itemBuilder: (context) => [
        if (_conversation!.isGroup) ...[
          const PopupMenuItem<String>(
            value: 'group_info',
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Grupinformation'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem<String>(
            value: 'add_participants',
            child: ListTile(
              leading: Icon(Icons.person_add),
              title: Text('Lägg till medlemmar'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ] else ...[
          const PopupMenuItem<String>(
            value: 'user_profile',
            child: ListTile(
              leading: Icon(Icons.person),
              title: Text('Visa profil'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        const PopupMenuItem<String>(
          value: 'search',
          child: ListTile(
            leading: Icon(Icons.search),
            title: Text('Sök meddelanden'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'clear_chat',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Rensa chatt'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'group_info':
        // TODO: Navigate to group info
        break;
      case 'add_participants':
        // TODO: Show add participants dialog
        break;
      case 'user_profile':
        // TODO: Navigate to user profile
        break;
      case 'search':
        // TODO: Show search dialog
        break;
      case 'clear_chat':
        _showClearChatDialog();
        break;
    }
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rensa chatt'),
        content: const Text('Är du säker på att du vill radera alla meddelanden i denna chatt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement clear chat functionality
            },
            child: const ErrorText('Radera'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(
        title: _getAppBarTitle(),
        actions: [_buildAppBarActions()],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _buildMessagesList(),
          ),
          
          // Typing indicator
          TypingIndicatorContainer(typingUsers: _typingUsers),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoading) {
      return LoadingWidgets.loadingOverlay(
        isLoading: true,
        loadingMessage: 'Laddar meddelanden...',
      );
    }

    if (_messages.isEmpty) {
      return EmptyStates.buildEmptyState(
        context,
        variant: EmptyStateVariant.generic,
        icon: Icons.chat_bubble_outline,
        title: 'Inga meddelanden än',
        subtitle: 'Säg hej för att starta konversationen!',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: Load more messages
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final previousMessage = index > 0 ? _messages[index - 1] : null;
          final showAvatar = _shouldShowAvatar(message, previousMessage);
          
          return MessageBubble(
            key: ValueKey(message.id),
            message: message,
            currentUserId: _currentUserId ?? '',
            showAvatar: showAvatar,
            onTap: () => _onMessageTap(message),
            onLongPress: () => _onMessageLongPress(message),
          );
        },
      ),
    );
  }

  bool _shouldShowAvatar(Message message, Message? previousMessage) {
    if (message.isFromCurrentUser(_currentUserId ?? '')) {
      return false; // Never show avatar for own messages
    }
    
    if (previousMessage == null) {
      return true; // Always show for first message
    }
    
    // Show avatar if sender changed or if more than 5 minutes passed
    return previousMessage.senderId != message.senderId ||
           message.sentAt.difference(previousMessage.sentAt).inMinutes > 5;
  }


  Widget _buildMessageInput() {
    return MessageInputContainer(
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed: _showAttachmentOptions,
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.primaryBlue,
            ),
          ),
          
          // Text input
          Expanded(
            child: MessageInputField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              hintText: 'Skriv ett meddelande...',
              onSubmitted: _sendMessage,
            ),
          ),
          
          const SizedBox(width: AppDimensions.paddingS),
          
          // Send button
          _isSending
              ? const SizedBox(
                  width: AppDimensions.buttonHeight,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: null,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.cardWhite),
                      ),
                    ),
                  ),
                )
              : StyledButton.icon(
                  icon: const Icon(
                    Icons.send,
                    color: AppColors.cardWhite,
                  ),
                  onPressed: _sendMessage,
                ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    final options = [
      AttachmentOption(
        icon: Icons.restaurant_menu,
        label: 'Recept',
        onTap: () {
          Navigator.pop(context);
          _shareRecipe();
        },
      ),
      AttachmentOption(
        icon: Icons.list_alt,
        label: 'Meny',
        onTap: () {
          Navigator.pop(context);
          _shareMenu();
        },
      ),
      AttachmentOption(
        icon: Icons.shopping_cart,
        label: 'Inköpslista',
        onTap: () {
          Navigator.pop(context);
          _shareShoppingList();
        },
      ),
      AttachmentOption(
        icon: Icons.camera_alt,
        label: 'Kamera',
        onTap: () {
          Navigator.pop(context);
          _shareImage();
        },
      ),
    ];

    StyledModalBottomSheet.show(
      context: context,
      child: AttachmentOptionsContainer(options: options),
    );
  }


  void _shareRecipe() {
    // TODO: Integrate with existing recipe selection dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receptdelning kommer snart!')),
    );
  }

  void _shareMenu() {
    // TODO: Integrate with existing menu selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menydelning kommer snart!')),
    );
  }

  void _shareShoppingList() {
    // TODO: Integrate with existing shopping list selection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inköpslistedelning kommer snart!')),
    );
  }

  void _shareImage() {
    // TODO: Implement image sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bilddelning kommer snart!')),
    );
  }

  void _onMessageTap(Message message) {
    // Handle message tap (e.g., show full content, open shared content)
    if (message.type == MessageType.recipeShare) {
      // TODO: Navigate to recipe detail
    } else if (message.type == MessageType.menuShare) {
      // TODO: Navigate to menu preview
    }
  }

  void _onMessageLongPress(Message message) {
    // Show message actions (reply, edit, delete, etc.)
    _showMessageActions(message);
  }

  void _showMessageActions(Message message) {
    final canEdit = message.isFromCurrentUser(_currentUserId ?? '') && 
                   message.type == MessageType.text;
    final canDelete = message.isFromCurrentUser(_currentUserId ?? '');

    StyledModalBottomSheet.show(
      context: context,
      child: ModalContentContainer(
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Svara'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement reply functionality
            },
          ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Redigera'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement edit functionality
              },
            ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Kopiera'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Copy message to clipboard
            },
          ),
          if (canDelete)
            ErrorListTile(
              icon: Icons.delete,
              title: 'Radera',
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
        ],
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Radera meddelande'),
        content: const Text('Är du säker på att du vill radera detta meddelande?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _messagingService.deleteMessage(message.id);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Kunde inte radera meddelandet: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const ErrorText('Radera'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messagingService.clearTypingIndicator(widget.conversationId);
    super.dispose();
  }
}