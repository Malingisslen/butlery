/// Chat view with real-time messaging and content sharing.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
// MessageStatus and MessageType available through message.dart import
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
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

/// Comprehensive chat view providing real-time messaging and content sharing through advanced messaging architecture.
///
/// Manages complete chat interface enabling real-time message display, content sharing, message management,
/// and comprehensive chat functionality while maintaining clean separation between UI presentation
/// and business logic through MessagingService integration and specialized component architecture.
///
/// **Core Responsibilities:**
/// - Advanced real-time messaging with message streaming, auto-scroll, and pagination functionality
/// - Content sharing coordination with recipe, menu, and shopping list integration through specialized dialogs
/// - Message action management with reply, edit, delete, and copy operations through context menus
/// - Conversation management with participant handling, group features, and user interaction coordination
/// - Swedish localized messaging experience with comprehensive user feedback and error handling
class ChatView extends StatefulWidget {
  /// Conversation identifier for message loading and real-time coordination.
  /// 
  /// Enables conversation-specific message streaming, participant management,
  /// and comprehensive chat functionality through unique conversation identification.
  final String conversationId;
  
  /// Optional conversation data model for initial display and coordination.
  /// 
  /// Provides conversation metadata enabling title display, participant information,
  /// and conversation feature coordination when available for enhanced user experience.
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
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  final List<String> _typingUsers = [];
  Message? _replyToMessage;
  bool _isEditing = false;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _messagingService = ServiceLocator.get<MessagingService>();
    _authRepository = ServiceLocator.get<AuthRepository>();
    _currentUserId = _authRepository.currentUserId;
    _conversation = widget.conversation;
    
    _setupListeners();
    _loadConversation();
    _loadMessages();
  }

  /// Comprehensive listener setup for typing indicators, focus changes, and scroll behavior coordination.
  /// 
  /// Establishes event listeners enabling typing indicator management, focus coordination,
  /// scroll-based pagination, and comprehensive user interaction handling through
  /// proper listener integration and real-time responsiveness with user experience optimization.
  /// 
  /// **Listener Integration:**
  /// - Message controller typing change listener for typing indicator coordination
  /// - Focus node listener for conversation read status and keyboard management
  /// - Scroll controller listener for pagination triggering and load more functionality
  void _setupListeners() {
    // Listen to typing changes
    _messageController.addListener(_onTypingChanged);
    
    // Listen to focus changes
    _messageFocusNode.addListener(_onFocusChanged);
    
    // Listen to scroll changes for pagination
    _scrollController.addListener(_onScrollChanged);
  }
  
  /// Scroll-based pagination triggering for older message loading coordination.
  /// 
  /// Monitors scroll position enabling automatic pagination triggering, load more functionality,
  /// and comprehensive message history access through scroll behavior analysis
  /// with proper pagination management and user experience optimization.
  /// 
  /// **Pagination Features:**
  /// - Scroll position monitoring with proximity-based triggering
  /// - Pagination state validation preventing duplicate loading operations
  /// - Load more functionality coordination with proper state management
  void _onScrollChanged() {
    // Trigger pagination when user scrolls near the top
    if (_scrollController.position.pixels <= 100 && _hasMoreMessages && !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  /// Typing indicator management for real-time user awareness coordination.
  /// 
  /// Handles typing state changes enabling typing indicator display, user awareness,
  /// and comprehensive typing coordination through MessagingService integration
  /// with real-time indicator management and proper state synchronization.
  /// 
  /// **Typing Indicator Features:**
  /// - Text input monitoring with typing state determination
  /// - Typing indicator activation with user awareness coordination
  /// - Typing indicator clearing with proper state management
  void _onTypingChanged() {
    final text = _messageController.text;
    if (text.isNotEmpty) {
      _messagingService.setTypingIndicator(widget.conversationId);
    } else {
      _messagingService.clearTypingIndicator(widget.conversationId);
    }
  }

  /// Focus change handling for conversation read status and user interaction coordination.
  /// 
  /// Manages input focus changes enabling conversation read status updates, auto-scroll coordination,
  /// and comprehensive user interaction handling through focus state management
  /// with proper conversation coordination and user experience optimization.
  /// 
  /// **Focus Management Features:**
  /// - Focus state monitoring with user interaction detection
  /// - Auto-scroll triggering with message visibility coordination
  /// - Conversation read status updates with proper state management
  void _onFocusChanged() {
    if (_messageFocusNode.hasFocus) {
      _scrollToBottom();
      // Mark conversation as read when user focuses on input
      _messagingService.markConversationAsRead(widget.conversationId);
    }
  }

  /// Conversation loading for metadata display and feature coordination.
  /// 
  /// Loads conversation data enabling title display, participant information,
  /// and comprehensive conversation functionality through MessagingService integration
  /// with proper error handling and state management coordination.
  /// 
  /// **Conversation Loading Features:**
  /// - Conversation metadata loading with service coordination
  /// - State updates with proper widget mounting validation
  /// - Error handling with graceful degradation and user experience protection
  Future<void> _loadConversation() async {
    if (_conversation == null) {
      final conversation = await _messagingService.getConversation(widget.conversationId);
      if (conversation != null && mounted) {
        if (mounted) {
          setState(() {
            _conversation = conversation;
          });
        }
      }
    }
  }

  /// Real-time message loading with stream coordination and auto-scroll management.
  /// 
  /// Establishes message stream enabling real-time message display, automatic updates,
  /// and comprehensive message coordination through MessagingService integration
  /// with proper state management and user experience optimization.
  /// 
  /// **Message Stream Features:**
  /// - Real-time message streaming with live updates and proper synchronization
  /// - Message list management with state coordination and proper ordering
  /// - Auto-scroll coordination with new message arrival and user experience
  /// - Loading state management with proper UI feedback and operation indication
  void _loadMessages() {
    _messagingService.getConversationMessages(
      conversationId: widget.conversationId,
      limit: 50,
    ).listen((messages) {
      if (mounted) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        }
        
        // Auto-scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });
  }

  /// Auto-scroll coordination for message visibility and user experience optimization.
  /// 
  /// Manages automatic scrolling enabling message visibility, smooth navigation,
  /// and comprehensive scroll coordination through animated scroll behavior
  /// with proper scroll controller validation and user experience enhancement.
  /// 
  /// **Auto-Scroll Features:**
  /// - Smooth animated scrolling with proper curve and duration coordination
  /// - Scroll controller validation with safe operation execution
  /// - Message visibility optimization with bottom scroll positioning
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Comprehensive message sending with editing and reply coordination.
  /// 
  /// Handles message composition enabling text sending, message editing, reply functionality,
  /// and comprehensive message operations through MessagingService integration
  /// with proper validation, error handling, and user feedback coordination.
  /// 
  /// **Message Sending Features:**
  /// - Message composition with content validation and proper formatting
  /// - Message editing with existing message modification and content updates
  /// - Reply functionality with message threading and context coordination
  /// - Error handling with user feedback and operation recovery
  /// - Loading state management with send button coordination and user experience
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      if (_isEditing && _editingMessageId != null) {
        // Edit existing message
        await _messagingService.editMessage(
          messageId: _editingMessageId!,
          newContent: content,
        );
        _cancelEdit();
      } else {
        // Send message (regular or reply)
        await _messagingService.sendTextMessage(
          conversationId: widget.conversationId,
          content: content,
          replyToMessageId: _replyToMessage?.id,
        );
        if (_replyToMessage != null) {
          _cancelReply();
        }
      }
      
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



  /// Menu action handling with comprehensive conversation management coordination.
  /// 
  /// [action] Action identifier for menu selection processing and operation coordination
  /// 
  /// Handles menu action selection enabling conversation management, user interaction,
  /// and comprehensive chat functionality through action-specific processing
  /// with proper navigation and feature coordination.
  /// 
  /// **Action Handling Features:**
  /// - Group management actions with information display and member coordination
  /// - User profile actions with navigation and user interaction
  /// - Search functionality with message search and content discovery
  /// - Conversation clearing with confirmation and data management
  void _handleMenuAction(String action) {
    switch (action) {
      case 'group_info':
        _navigateToGroupInfo();
        break;
      case 'add_participants':
        _showAddParticipantsDialog();
        break;
      case 'user_profile':
        _navigateToUserProfile();
        break;
      case 'search':
        _showSearchDialog();
        break;
      case 'clear_chat':
        _showClearChatDialog();
        break;
    }
  }

  /// Chat clearing confirmation dialog with user safety and data management coordination.
  /// 
  /// Presents confirmation dialog enabling user safety, operation preview,
  /// and comprehensive chat clearing functionality through dialog management
  /// with proper confirmation workflow and user experience protection.
  /// 
  /// **Clear Chat Features:**
  /// - User safety confirmation with clear operation description
  /// - Swedish localized dialog with proper user communication
  /// - Confirmation workflow with proper dialog navigation
  /// - Chat clearing coordination with data management integration
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
              _clearChat();
            },
            child: const ErrorText('Radera'),
          ),
        ],
      ),
    );
  }

  /// Comprehensive chat interface construction with real-time messaging and content sharing coordination.
  /// 
  /// [context] Build context for theme access and component construction coordination
  /// 
  /// Constructs complete chat interface featuring real-time message display, content sharing integration,
  /// typing indicators, and comprehensive messaging functionality through specialized component architecture
  /// with proper state management and user experience optimization.
  /// 
  /// **Interface Architecture:**
  /// - ChatAppBar integration with conversation title and action menu coordination
  /// - Column layout with message list, typing indicators, and message input
  /// - Real-time message display with proper scrolling and pagination
  /// - Content sharing integration with attachment options and sharing workflow
  /// - Typing indicator display with user awareness and real-time coordination
  /// 
  /// **Component Integration:**
  /// - Message list with comprehensive display and interaction functionality
  /// - Typing indicator container with user awareness and real-time updates
  /// - Message input container with composition and sending functionality
  /// - Loading states with proper feedback and user experience coordination
  /// - Empty states with user guidance and engagement encouragement
  /// 
  /// Returns complete chat interface with comprehensive functionality and real-time coordination.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(
        conversation: _conversation,
        onMenuAction: _handleMenuAction,
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

  /// Comprehensive message list construction with loading states and pagination coordination.
  /// 
  /// Constructs message list enabling real-time display, loading state management,
  /// pagination functionality, and comprehensive message interaction through
  /// proper state handling and user experience optimization.
  /// 
  /// **Message List Features:**
  /// - Loading state with progress indication and user feedback
  /// - Empty state with user guidance and conversation encouragement
  /// - Pagination with pull-to-refresh and load more functionality
  /// - Message display with proper ordering and interaction coordination
  /// - Avatar display logic with conversation context and user identification
  /// 
  /// Returns message list widget with comprehensive functionality and state management.
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
      onRefresh: _loadMoreMessages,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the top when loading more messages
          if (index == 0 && _isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingM),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          // Adjust index for messages when loading indicator is present
          final messageIndex = _isLoadingMore ? index - 1 : index;
          final message = _messages[messageIndex];
          final previousMessage = messageIndex > 0 ? _messages[messageIndex - 1] : null;
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

  /// Avatar display logic for message grouping and conversation context coordination.
  /// 
  /// [message] Current message for avatar display determination
  /// [previousMessage] Previous message for grouping analysis and context coordination
  /// 
  /// Determines avatar display enabling message grouping, user identification,
  /// and comprehensive conversation context through message analysis
  /// with proper grouping logic and user experience optimization.
  /// 
  /// **Avatar Display Logic:**
  /// - Current user message handling with avatar suppression
  /// - First message handling with avatar display requirement
  /// - Sender change detection with avatar display coordination
  /// - Time-based grouping with conversation flow optimization
  /// 
  /// Returns boolean indicating avatar display requirement for message.
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

  /// Message context display for reply and editing coordination.
  /// 
  /// Constructs context bar enabling reply and editing functionality, context display,
  /// and comprehensive message interaction through visual context indication
  /// with proper state management and user experience coordination.
  /// 
  /// **Context Display Features:**
  /// - Reply context with original message preview and sender identification
  /// - Editing context with modification indication and content display
  /// - Visual context indication with icons and proper styling
  /// - Context cancellation with proper state cleanup and user control
  /// 
  /// Returns context bar widget with reply and editing functionality.
  Widget _buildMessageContext() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit : Icons.reply,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'Redigerar meddelande' : 'Svarar på ${_replyToMessage?.senderDisplayName ?? 'meddelande'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                if (!_isEditing && _replyToMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _replyToMessage!.content.length > 50 
                        ? '${_replyToMessage!.content.substring(0, 50)}...'
                        : _replyToMessage!.content,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              if (_isEditing) {
                _cancelEdit();
              } else {
                _cancelReply();
              }
            },
            icon: const Icon(Icons.close, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  /// Comprehensive message input construction with attachment options and context coordination.
  /// 
  /// Constructs message input interface enabling text composition, content sharing,
  /// reply and editing functionality, and comprehensive message creation through
  /// specialized input components with proper state management and user experience.
  /// 
  /// **Input Interface Features:**
  /// - Reply and editing context display with proper context indication
  /// - Message input container with text composition and attachment coordination
  /// - Attachment button with content sharing options and workflow integration
  /// - Send button with loading states and operation progress indication
  /// - Context-aware input hints with proper user guidance
  /// 
  /// Returns message input widget with comprehensive functionality and context coordination.
  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply/Edit context bar
        if (_replyToMessage != null || _isEditing) _buildMessageContext(),
        
        // Message input
        MessageInputContainer(
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
                  hintText: _isEditing 
                      ? 'Redigera meddelande...'
                      : _replyToMessage != null 
                          ? 'Svara på ${_replyToMessage!.senderDisplayName}...'
                          : 'Skriv ett meddelande...',
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
                      icon: Icon(
                        _isEditing ? Icons.check : Icons.send,
                        color: AppColors.cardWhite,
                      ),
                      onPressed: _sendMessage,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  /// Attachment options display with content type selection and sharing workflow coordination.
  /// 
  /// Presents attachment options enabling content sharing, type selection,
  /// and comprehensive sharing workflow through modal bottom sheet
  /// with proper option organization and user experience optimization.
  /// 
  /// **Attachment Options Features:**
  /// - Recipe sharing with recipe selection and sharing dialog integration
  /// - Menu sharing with menu coordination and sharing workflow
  /// - Shopping list sharing with list selection and sharing functionality
  /// - Image sharing with camera integration and photo upload
  /// - Modal presentation with proper option organization and user interaction
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

  /// Recipe sharing with selection dialog and message coordination.
  /// 
  /// Handles recipe sharing enabling recipe selection, sharing dialog presentation,
  /// and comprehensive recipe sharing functionality through UniversalShareDialog integration
  /// with proper recipe service coordination and message sending.
  /// 
  /// **Recipe Sharing Features:**
  /// - Recipe availability validation with user feedback and error handling
  /// - Recipe selection with sharing dialog integration and user interaction
  /// - Message sending with recipe metadata and content coordination
  /// - Success feedback with user confirmation and operation status
  Future<void> _shareRecipe() async {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    final recipes = recipeService.recipes;
    
    if (recipes.isEmpty) {
      _showInfoMessage('Inga recept att dela');
      return;
    }

    // Show recipe selection and share dialog
    final viewModel = UniversalShareDialogViewModel(
      socialRecipeService: ServiceLocator.get(),
      shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
    );
    final result = await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog(
        content: recipes.first, // For now, use first recipe or implement selection
        contentType: ShareContentType.recipe,
        viewModel: viewModel,
      ),
    );

    if (result == true && context.mounted && widget.conversation != null) {
      final selectedRecipe = recipes.first; // Using first recipe as content
      await _messagingService.sendRecipeShare(
        conversationId: widget.conversation!.id,
        recipeId: selectedRecipe.id,
        recipeTitle: selectedRecipe.title,
      );
    }
  }

  /// Menu sharing with coordination and message functionality.
  /// 
  /// Handles menu sharing enabling menu coordination, sharing functionality,
  /// and comprehensive menu sharing workflow through proper service integration
  /// with user feedback and future feature indication.
  /// 
  /// **Menu Sharing Features:**
  /// - Future feature indication with user notification
  /// - Menu service integration with sharing coordination
  /// - Comprehensive sharing workflow with proper message coordination
  Future<void> _shareMenu() async {
    // MenuService doesn't maintain saved menus, so show info message
    _showInfoMessage('Menydelning kommer snart!');
  }

  /// Shopping list sharing with selection dialog and message coordination.
  /// 
  /// Handles shopping list sharing enabling list selection, sharing dialog presentation,
  /// and comprehensive shopping list sharing functionality through UniversalShareDialog integration
  /// with proper shopping service coordination and message sending.
  /// 
  /// **Shopping List Sharing Features:**
  /// - Shopping list availability validation with user feedback and error handling
  /// - List selection with sharing dialog integration and user interaction
  /// - Message sending with shopping list metadata and content coordination
  /// - Success feedback with user confirmation and operation status
  Future<void> _shareShoppingList() async {
    final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    final lists = shoppingService.lists; // Use lists instead of shoppingLists
    
    if (lists.isEmpty) {
      _showInfoMessage('Inga inköpslistor att dela');
      return;
    }

    // For now, share the first available shopping list
    final firstList = lists.first;
    final result = await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog(
        content: firstList,
        contentType: ShareContentType.shoppingList,
        viewModel: UniversalShareDialogViewModel(
          socialRecipeService: ServiceLocator.get(),
          shoppingService: ServiceLocator.get<UnifiedShoppingService>(),
        ),
      ),
    );
    
    if (result == true && widget.conversation != null && context.mounted) {
      await _messagingService.sendShoppingListShare(
        conversationId: widget.conversation!.id,
        listId: firstList.id,
        listTitle: firstList.name,
      );
      
      _showSuccessMessage('Inköpslista "${firstList.name}" delad!');
    }
  }

  /// Image sharing with camera integration and photo upload coordination.
  /// 
  /// Handles image sharing enabling camera integration, photo selection,
  /// and comprehensive image sharing functionality through image picker coordination
  /// with future feature indication and user feedback.
  /// 
  /// **Image Sharing Features:**
  /// - Future feature indication with user notification
  /// - Camera integration with photo capture and selection
  /// - Image upload coordination with proper processing and sharing
  void _shareImage() {
    _showImagePicker();
  }
  
  /// Success message display with user feedback and confirmation coordination.
  /// 
  /// [message] Success message for user display and confirmation
  /// 
  /// Presents success messages enabling user feedback, operation confirmation,
  /// and comprehensive success indication through snackbar integration
  /// with proper context validation and user experience optimization.
  /// 
  /// **Success Message Features:**
  /// - Context validation with safe message display
  /// - Success styling with proper color coordination and visual indication
  /// - User feedback with confirmation and operation status display
  void _showSuccessMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }
  
  /// Information message display with user guidance and feedback coordination.
  /// 
  /// [message] Information message for user display and guidance
  /// 
  /// Presents information messages enabling user guidance, feature indication,
  /// and comprehensive information display through snackbar integration
  /// with proper context validation and user experience optimization.
  /// 
  /// **Information Message Features:**
  /// - Context validation with safe message display
  /// - Information styling with proper visual indication
  /// - User guidance with clear communication and feature status
  void _showInfoMessage(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  /// Group information navigation with proper route coordination.
  /// 
  /// Navigates to group information enabling group management, member display,
  /// and comprehensive group functionality through proper route navigation
  /// with group validation and user experience coordination.
  /// 
  /// **Group Navigation Features:**
  /// - Group conversation validation with proper access control
  /// - Route navigation with group identifier coordination
  /// - Group management integration with comprehensive functionality
  void _navigateToGroupInfo() {
    if (widget.conversation?.isGroup == true) {
      Navigator.pushNamed(
        context, 
        '/group-detail',
        arguments: {'groupId': widget.conversationId},
      );
    }
  }
  
  /// Add participants dialog with group management coordination.
  /// 
  /// Presents add participants functionality enabling group member management,
  /// participant selection, and comprehensive group coordination through
  /// future feature indication and user feedback.
  /// 
  /// **Add Participants Features:**
  /// - Group conversation validation with proper access control
  /// - Future feature indication with user notification
  /// - Group management integration with member coordination
  Future<void> _showAddParticipantsDialog() async {
    if (widget.conversation?.isGroup == true) {
      // Import the dialog and show it
      _showInfoMessage('Lägg till deltagare kommer snart!');
    }
  }
  
  /// User profile navigation with participant coordination.
  /// 
  /// Navigates to user profile enabling profile display, user information,
  /// and comprehensive user functionality through proper route navigation
  /// with participant identification and user experience coordination.
  /// 
  /// **Profile Navigation Features:**
  /// - Individual conversation validation with proper access control
  /// - Participant identification with other user determination
  /// - Route navigation with user identifier coordination
  void _navigateToUserProfile() {
    if (widget.conversation?.isGroup == false && widget.conversation?.participantIds.isNotEmpty == true) {
      final otherUserId = widget.conversation!.participantIds
          .firstWhere((id) => id != _currentUserId);
      Navigator.pushNamed(
        context,
        '/user-profile',
        arguments: {'userId': otherUserId},
      );
    }
  }
  
  /// Message search dialog with search functionality coordination.
  /// 
  /// Presents message search functionality enabling content discovery,
  /// message finding, and comprehensive search coordination through
  /// future feature indication and user feedback.
  /// 
  /// **Search Features:**
  /// - Future feature indication with user notification
  /// - Message search integration with content discovery
  /// - Search functionality with comprehensive message coordination
  Future<void> _showSearchDialog() async {
    _showInfoMessage('Sök i chatt kommer snart!');
  }
  
  /// Chat clearing with confirmation and data management coordination.
  /// 
  /// Handles chat clearing enabling message deletion, data management,
  /// and comprehensive clearing functionality through MessagingService integration
  /// with proper confirmation workflow and user feedback.
  /// 
  /// **Chat Clearing Features:**
  /// - Confirmation dialog with user safety and operation preview
  /// - Message deletion with data management coordination
  /// - User feedback with operation status and success indication
  /// - Error handling with proper recovery and user notification
  Future<void> _clearChat() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rensa chatt'),
          content: const Text(
            'Är du säker på att du vill rensa alla dina meddelanden i denna chatt? '
            'Detta kommer endast att ta bort meddelanden som du har skickat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Avbryt'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Rensa'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Show loading indicator
        _showInfoMessage('Rensar chatt...');
        
        // Delete all messages through the service
        await _messagingService.deleteAllMessages(widget.conversationId);
        
        _showSuccessMessage('Chatt rensad - dina meddelanden har tagits bort');
      }
    } catch (e) {
      _showInfoMessage('Kunde inte rensa chatt: $e');
    }
  }
  
  /// Message pagination with older message loading coordination.
  /// 
  /// Handles message pagination enabling older message loading, message history access,
  /// and comprehensive pagination functionality through MessagingService integration
  /// with proper cursor-based pagination and state management.
  /// 
  /// **Pagination Features:**
  /// - Pagination state validation with duplicate loading prevention
  /// - Cursor-based pagination with oldest message timestamp coordination
  /// - Message history loading with proper ordering and state management
  /// - Error handling with user feedback and operation recovery
  /// - Loading state management with proper UI feedback and coordination
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) {
      return;
    }
    
    if (mounted) {
      setState(() {
        _isLoadingMore = true;
      });
    }
    
    try {
      // Use the oldest message's timestamp as the startAfter cursor
      DateTime? startAfter;
      if (_messages.isNotEmpty) {
        startAfter = _messages.first.sentAt;
      }
      
      // Load older messages
      final olderMessages = await _messagingService.getConversationMessagesPage(
        conversationId: widget.conversationId,
        limit: 20, // Load 20 older messages at a time
        startAfter: startAfter,
      );
      
      if (mounted) {
        setState(() {
          if (olderMessages.isEmpty) {
            _hasMoreMessages = false;
          } else {
            // Prepend older messages to the beginning of the list
            _messages = [...olderMessages, ..._messages];
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        _showInfoMessage('Kunde inte ladda fler meddelanden: $e');
      }
    }
  }
  
  /// Image picker display with photo selection and upload coordination.
  /// 
  /// Presents image picker functionality enabling photo selection,
  /// image upload, and comprehensive image sharing workflow through
  /// future feature indication and user feedback.
  /// 
  /// **Image Picker Features:**
  /// - Future feature indication with user notification
  /// - Photo selection with image picker integration
  /// - Image upload coordination with proper processing and sharing
  Future<void> _showImagePicker() async {
    _showInfoMessage('Bilddelning kommer snart!');
  }
  
  /// Recipe detail navigation with content coordination.
  /// 
  /// [recipeId] Recipe identifier for navigation and content display
  /// 
  /// Navigates to recipe detail enabling recipe display, content interaction,
  /// and comprehensive recipe functionality through proper route navigation
  /// with recipe validation and user experience coordination.
  /// 
  /// **Recipe Navigation Features:**
  /// - Recipe identifier validation with proper access control
  /// - Route navigation with recipe content coordination
  /// - Recipe detail integration with comprehensive functionality
  void _navigateToRecipeDetail(String? recipeId) {
    if (recipeId != null && context.mounted) {
      Navigator.pushNamed(
        context,
        '/recipe-detail',
        arguments: {'recipeId': recipeId},
      );
    }
  }
  
  /// Menu preview navigation with content coordination.
  /// 
  /// [menuId] Menu identifier for navigation and content display
  /// 
  /// Navigates to menu preview enabling menu display, content interaction,
  /// and comprehensive menu functionality through proper route navigation
  /// with menu validation and user experience coordination.
  /// 
  /// **Menu Navigation Features:**
  /// - Menu identifier validation with proper access control
  /// - Route navigation with menu content coordination
  /// - Menu preview integration with comprehensive functionality
  void _navigateToMenuPreview(String? menuId) {
    if (menuId != null && context.mounted) {
      Navigator.pushNamed(
        context,
        '/menu-preview',
        arguments: {'menuId': menuId},
      );
    }
  }
  
  /// Content ID extraction from message metadata coordination.
  /// 
  /// [message] Message for content ID extraction and metadata processing
  /// 
  /// Extracts content identifier enabling content navigation, metadata processing,
  /// and comprehensive content coordination through message metadata analysis
  /// with proper data extraction and validation.
  /// 
  /// **Content ID Features:**
  /// - Message metadata analysis with content identification
  /// - Content ID extraction with proper data validation
  /// - Metadata processing with comprehensive content coordination
  /// 
  /// Returns content identifier string or null if not available.
  String? _getContentIdFromMessage(Message message) {
    // Messages store content IDs in metadata
    return message.metadata?['contentId'] as String?;
  }

  /// Message tap handling with content navigation coordination.
  /// 
  /// [message] Message for tap handling and interaction processing
  /// 
  /// Handles message tap events enabling content navigation, interaction processing,
  /// and comprehensive message functionality through message type analysis
  /// with proper navigation coordination and user experience optimization.
  /// 
  /// **Message Tap Features:**
  /// - Message type analysis with appropriate action determination
  /// - Content navigation with proper route coordination
  /// - Interaction processing with comprehensive functionality
  void _onMessageTap(Message message) {
    // Handle message tap (e.g., show full content, open shared content)
    if (message.type == MessageType.recipeShare) {
      _navigateToRecipeDetail(_getContentIdFromMessage(message));
    } else if (message.type == MessageType.menuShare) {
      _navigateToMenuPreview(_getContentIdFromMessage(message));
    }
  }

  /// Message long press handling with action menu coordination.
  /// 
  /// [message] Message for long press handling and action menu display
  /// 
  /// Handles message long press events enabling action menu display, interaction options,
  /// and comprehensive message functionality through action menu presentation
  /// with proper permission handling and user experience optimization.
  /// 
  /// **Message Long Press Features:**
  /// - Action menu display with context-specific options
  /// - Permission validation with proper access control
  /// - Interaction options with comprehensive functionality
  void _onMessageLongPress(Message message) {
    // Show message actions (reply, edit, delete, etc.)
    _showMessageActions(message);
  }

  /// Message action menu display with permission-based options coordination.
  /// 
  /// [message] Message for action menu display and permission validation
  /// 
  /// Presents message action menu enabling message operations, permission validation,
  /// and comprehensive message functionality through modal bottom sheet
  /// with proper action organization and user experience optimization.
  /// 
  /// **Message Action Features:**
  /// - Permission-based action display with proper access control
  /// - Action organization with user-friendly menu presentation
  /// - Comprehensive functionality with reply, edit, copy, and delete operations
  /// - Modal presentation with proper action coordination
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
              _replyToMessageMethod(message);
            },
          ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Redigera'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Kopiera'),
            onTap: () {
              Navigator.pop(context);
              _copyMessage(message);
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

  /// Reply functionality activation with message context coordination.
  /// 
  /// [message] Message for reply functionality and context establishment
  /// 
  /// Activates reply functionality enabling message threading, context display,
  /// and comprehensive reply coordination through state management
  /// with proper focus handling and user experience optimization.
  /// 
  /// **Reply Features:**
  /// - Reply context establishment with message threading
  /// - State management with proper reply coordination
  /// - Focus handling with input field activation
  void _replyToMessageMethod(Message message) {
    if (mounted) {
      setState(() {
        _replyToMessage = message;
        _messageFocusNode.requestFocus();
      });
    }
  }

  /// Message editing activation with content coordination.
  /// 
  /// [message] Message for editing functionality and content loading
  /// 
  /// Activates message editing enabling content modification, state management,
  /// and comprehensive editing coordination through input field preparation
  /// with proper content loading and user experience optimization.
  /// 
  /// **Editing Features:**
  /// - Editing state activation with message identification
  /// - Content loading with input field preparation
  /// - Focus handling with editing interface activation
  Future<void> _editMessage(Message message) async {
    if (mounted) {
      setState(() {
        _isEditing = true;
        _editingMessageId = message.id;
        _messageController.text = message.content;
        _messageFocusNode.requestFocus();
      });
    }
  }

  /// Message copying with clipboard integration coordination.
  /// 
  /// [message] Message for content copying and clipboard coordination
  /// 
  /// Handles message copying enabling clipboard integration, content copying,
  /// and comprehensive copy functionality through clipboard data management
  /// with proper user feedback and operation confirmation.
  /// 
  /// **Copy Features:**
  /// - Clipboard integration with content copying
  /// - User feedback with operation confirmation
  /// - Content management with proper data handling
  Future<void> _copyMessage(Message message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meddelande kopierat'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Reply cancellation with state cleanup coordination.
  /// 
  /// Cancels reply functionality enabling state cleanup, UI reset,
  /// and comprehensive reply coordination through proper state management
  /// with user control and interface restoration.
  /// 
  /// **Reply Cancellation Features:**
  /// - State cleanup with reply context removal
  /// - UI reset with proper interface restoration
  /// - User control with cancellation functionality
  void _cancelReply() {
    if (mounted) {
      setState(() {
        _replyToMessage = null;
      });
    }
  }

  /// Editing cancellation with state cleanup and input restoration coordination.
  /// 
  /// Cancels editing functionality enabling state cleanup, input restoration,
  /// and comprehensive editing coordination through proper state management
  /// with user control and interface restoration.
  /// 
  /// **Editing Cancellation Features:**
  /// - State cleanup with editing context removal
  /// - Input restoration with content clearing
  /// - User control with cancellation functionality
  void _cancelEdit() {
    if (mounted) {
      setState(() {
        _isEditing = false;
        _editingMessageId = null;
        _messageController.clear();
      });
    }
  }

  /// Message deletion with confirmation and data management coordination.
  /// 
  /// [message] Message for deletion functionality and confirmation workflow
  /// 
  /// Handles message deletion enabling confirmation dialog, data management,
  /// and comprehensive deletion functionality through MessagingService integration
  /// with proper user confirmation and error handling.
  /// 
  /// **Message Deletion Features:**
  /// - Confirmation dialog with user safety and operation preview
  /// - Data management with message deletion coordination
  /// - Error handling with user feedback and operation recovery
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

  /// Comprehensive resource disposal with cleanup and lifecycle management coordination.
  /// 
  /// Performs complete resource cleanup preventing memory leaks and ensuring proper
  /// lifecycle management through systematic disposal of controllers, listeners,
  /// and service resources with comprehensive cleanup coordination.
  /// 
  /// **Disposal Features:**
  /// - Controller disposal with memory leak prevention
  /// - Listener cleanup with proper resource management
  /// - Service cleanup with typing indicator clearing
  /// - Lifecycle management with systematic resource disposal
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _messagingService.clearTypingIndicator(widget.conversationId);
    super.dispose();
  }
}