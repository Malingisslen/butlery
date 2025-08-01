/// Comprehensive chat ViewModel providing advanced real-time messaging and conversation interaction for Flutter applications.
///
/// This module implements sophisticated chat functionality following Single Responsibility Principle,
/// specializing in real-time message management, conversation interaction, typing indicators, and message
/// delivery coordination. It provides complete chat infrastructure while maintaining clean separation from
/// UI rendering, conversation list management, and complex messaging business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles individual chat presentation layer concerns:
/// - **Real-Time Message Management**: Advanced message stream coordination with automatic updates and synchronization
/// - **Message Sending Intelligence**: Sophisticated message composition including text messages and recipe sharing
/// - **Typing Indicator Coordination**: Real-time typing status management with user presence and activity tracking
/// - **Conversation Interaction Features**: Complete chat UI state management with message operations and status tracking
/// - **Swedish Localization Excellence**: Complete Swedish language support for chat operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Conversation list management (handled by ConversationsViewModel and conversation list components)
/// - UI rendering and widget creation (handled by chat views and presentation components)
/// - Complex messaging business logic (handled by MessagingService and underlying messaging infrastructure)
/// - Message storage and persistence (handled by messaging services and data layer systems)
///
/// **Chat ViewModel Features:**
/// - **Real-Time Message Streams**: Complete message stream management with automatic updates and message synchronization
/// - **Advanced Message Operations**: Comprehensive message sending including text messages, recipe sharing, and message deletion
/// - **Typing Indicator System**: Real-time typing status with user presence tracking and automatic cleanup
/// - **Conversation State Management**: Complete chat UI state coordination with loading states and error handling
/// - **Swedish Localization**: Complete Swedish language support for chat operations and error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize chat ViewModel with conversation ID and messaging service integration
/// final chatViewModel = ChatViewModel(
///   messagingService: ServiceLocator.get<MessagingService>(),
///   authRepository: ServiceLocator.get<AuthRepository>(),
///   conversationId: 'conversation_123',
///   initialConversation: conversation, // Optional pre-loaded conversation
/// );
/// 
/// // Real-time message monitoring and display
/// if (chatViewModel.hasMessages) {
///   final messages = chatViewModel.messages;
///   for (int i = 0; i < messages.length; i++) {
///     final message = messages[i];
///     final previousMessage = chatViewModel.getPreviousMessage(i);
///     final showAvatar = chatViewModel.shouldShowAvatar(message, previousMessage);
///   }
/// }
/// 
/// // Message sending operations
/// final textSent = await chatViewModel.sendTextMessage('Hej! Hur mår du?');
/// if (textSent) {
///   // Message sent successfully
/// } else if (chatViewModel.sendError != null) {
///   // Handle send error
/// }
/// 
/// // Recipe sharing functionality
/// final recipeSent = await chatViewModel.sendRecipeShare(
///   recipeId: 'recipe_456',
///   recipeTitle: 'Pannkakor med sylt',
///   message: 'Prova detta recept!',
/// );
/// 
/// // Typing indicator management
/// chatViewModel.setTyping(); // User started typing
/// // ... user typing
/// chatViewModel.clearTyping(); // User stopped typing
/// 
/// // Monitor other users typing
/// if (chatViewModel.hasTypingUsers) {
///   final typingUsers = chatViewModel.currentTypingUsers;
///   // Display "Anna and Erik are typing..." indicator
/// }
/// 
/// // Message management operations
/// final deleted = await chatViewModel.deleteMessage('message_789');
/// await chatViewModel.markAsRead(); // Mark conversation as read
/// 
/// // State monitoring and error handling
/// if (chatViewModel.isLoading) {
///   // Show loading indicator
/// } else if (chatViewModel.error != null) {
///   // Display error message
/// } else if (chatViewModel.isSending) {
///   // Show message sending indicator
/// }
/// 
/// // Error handling and recovery
/// if (chatViewModel.sendError != null) {
///   // Handle message sending error
///   chatViewModel.clearSendError();
/// }
/// 
/// // Conversation information and display
/// final title = chatViewModel.conversationTitle;
/// final canSend = chatViewModel.canSendMessages;
/// 
/// // Refresh functionality for pull-to-refresh
/// await chatViewModel.refresh();
/// ```

// lib/viewmodels/chat_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// Comprehensive chat ViewModel providing advanced real-time messaging through service integration.
///
/// Manages individual chat conversation state enabling real-time messaging interaction with message sending,
/// typing indicators, conversation operations, and message management while maintaining clean MVVM architecture
/// separation between chat business logic and UI presentation concerns.
///
/// **Core Responsibilities:**
/// - Real-time message stream management with automatic updates and message synchronization
/// - Advanced message sending operations including text messages and recipe sharing functionality
/// - Typing indicator coordination with user presence tracking and automatic cleanup
/// - Conversation interaction state management with loading states and comprehensive error handling
/// - Swedish localized error messages and user feedback coordination
class ChatViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final MessagingService _messagingService;
  final AuthRepository _authRepository;
  
  /// Unique conversation identifier for chat session management and message coordination.
  /// 
  /// Stores the conversation ID for MessagingService operations, message streaming,
  /// and conversation-specific functionality throughout the chat session.
  final String conversationId;

  // ===== LIFECYCLE MANAGEMENT =====

  /// Disposal safety flag preventing operations after ViewModel disposal.
  /// 
  /// Ensures safe disposal and prevents operations on disposed ViewModel
  /// avoiding memory leaks and state corruption during lifecycle transitions.
  bool _isDisposed = false;

  // ===== CONVERSATION STATE =====

  /// Current conversation data for display and interaction management.
  /// 
  /// Stores loaded conversation information enabling conversation title display,
  /// participant management, and conversation-specific functionality coordination.
  Conversation? _conversation;
  
  /// Real-time message collection for display and interaction coordination.
  /// 
  /// Stores current chat messages enabling message display, interaction,
  /// and real-time message management throughout chat sessions.
  List<Message> _messages = [];
  
  /// Message loading state for UI progress indication during data synchronization.
  /// 
  /// Indicates active message loading for loading indicators and interaction
  /// control during chat initialization and message synchronization.
  bool _isLoading = true;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout chat operations and messaging functionality.
  String? _error;

  // ===== MESSAGE SENDING STATE =====

  /// Message sending operation state for UI progress indication during send operations.
  /// 
  /// Indicates active message sending for loading indicators and interaction
  /// control during message composition and delivery processes.
  bool _isSending = false;
  
  /// Message sending error message for specific send error handling and user feedback.
  /// 
  /// Provides specialized error messages for message sending failures
  /// enabling targeted error display and send operation recovery.
  String? _sendError;

  // ===== TYPING INDICATOR STATE =====

  /// Active typing users with timestamp tracking for presence management.
  /// 
  /// Maps user display names to typing timestamps enabling real-time typing
  /// indicator coordination and automatic cleanup of expired typing status.
  final Map<String, DateTime> _typingUsers = {};
  
  /// Current active typing users with automatic expiration filtering.
  /// 
  /// Filters typing users map to show only currently active users (within 5 seconds)
  /// enabling dynamic typing indicator display and user presence coordination.
  List<String> get typingUserNames => _typingUsers.entries
      .where((entry) => DateTime.now().difference(entry.value).inSeconds < 5)
      .map((entry) => entry.key)
      .toList();

  // ===== STREAM MANAGEMENT =====

  /// Real-time messages stream subscription for automatic message updates and synchronization.
  /// 
  /// Manages MessagingService message stream subscription enabling real-time message updates,
  /// automatic synchronization, and live chat coordination throughout user sessions.
  StreamSubscription<List<Message>>? _messagesSubscription;
  
  /// Typing indicator cleanup timer for automatic expired status removal.
  /// 
  /// Manages periodic cleanup of expired typing indicators ensuring accurate
  /// user presence display and resource management throughout chat sessions.
  Timer? _typingCleanUpTimer;

  /// Initializes chat ViewModel with comprehensive messaging service integration and real-time preparation.
  /// 
  /// [messagingService] MessagingService instance for message operations and real-time messaging coordination
  /// [authRepository] AuthRepository instance for user authentication and message authorization
  /// [conversationId] Unique conversation identifier for chat session management
  /// [initialConversation] Optional pre-loaded conversation data for performance optimization
  /// 
  /// Establishes chat infrastructure with service integration, enabling comprehensive
  /// real-time messaging functionality with message management, typing indicators, and unified state coordination.
  /// 
  /// **Initialization Process:**
  /// - MessagingService integration for message operations and real-time updates
  /// - AuthRepository integration for user authentication and message authorization
  /// - Conversation ID assignment for targeted chat session management
  /// - Optional initial conversation assignment for performance optimization
  /// - Automatic chat initialization with message loading and typing indicator setup
  ChatViewModel({
    required MessagingService messagingService,
    required AuthRepository authRepository,
    required this.conversationId,
    Conversation? initialConversation,
  }) : _messagingService = messagingService,
       _authRepository = authRepository,
       _conversation = initialConversation {
    _initializeChat();
  }

  // ===== STATE ACCESSORS =====

  /// Current conversation data for display and interaction coordination.
  /// 
  /// Provides access to loaded conversation information enabling conversation title display,
  /// participant information access, and conversation-specific functionality coordination.
  Conversation? get conversation => _conversation;
  
  /// Real-time message collection for display and interaction management.
  /// 
  /// Provides access to current chat messages enabling message display,
  /// message interaction management, and chat functionality coordination.
  List<Message> get messages => _messages;
  
  /// Message loading state for UI progress indication and interaction control.
  /// 
  /// Indicates whether message data is being loaded for loading indicators
  /// and user interaction management during chat synchronization.
  bool get isLoading => _isLoading;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides access to current error state enabling error display
  /// and recovery coordination throughout chat operations.
  String? get error => _error;
  
  /// Message sending operation state for UI progress indication and interaction control.
  /// 
  /// Indicates whether message sending is in progress for loading indicators
  /// and user interaction management during message composition operations.
  bool get isSending => _isSending;
  
  /// Message sending error message for specialized error handling and user feedback.
  /// 
  /// Provides access to message sending specific errors enabling targeted
  /// error display and send operation recovery coordination.
  String? get sendError => _sendError;
  
  /// Current active typing users for typing indicator display and presence coordination.
  /// 
  /// Provides list of currently typing users for typing indicator display
  /// and user presence coordination throughout chat functionality.
  List<String> get currentTypingUsers => typingUserNames;
  
  /// Typing users availability indicator for conditional UI rendering and presence display.
  /// 
  /// Indicates whether users are currently typing for UI conditional
  /// rendering and typing indicator display coordination.
  bool get hasTypingUsers => typingUserNames.isNotEmpty;
  
  /// Messages availability indicator for conditional UI rendering and empty state management.
  /// 
  /// Indicates whether messages are available for UI conditional
  /// rendering and empty state display coordination.
  bool get hasMessages => _messages.isNotEmpty;
  
  /// Current authenticated user ID for message authorization and display coordination.
  /// 
  /// Provides access to current user ID enabling message authorization,
  /// message ownership determination, and user-specific chat management.
  String? get currentUserId => _authRepository.currentUserId;
  
  /// Conversation title with dynamic generation and loading state handling.
  /// 
  /// Provides conversation display title with current user context consideration
  /// and loading state fallback ensuring consistent UI display throughout chat sessions.
  String get conversationTitle {
    if (_conversation == null) return 'Laddar...';
    if (currentUserId == null) return _conversation!.title ?? 'Chatt';
    return _conversation!.getDisplayTitle(currentUserId!);
  }

  /// Message sending capability indicator for UI enabling and interaction control.
  /// 
  /// Indicates whether message sending is available based on conversation availability
  /// and ViewModel disposal state for UI interaction management and feature enabling.
  bool get canSendMessages => _conversation != null && !_isDisposed;

  // ===== INITIALIZATION OPERATIONS =====

  /// Initializes chat ViewModel with comprehensive setup and real-time coordination.
  /// 
  /// Performs chat initialization including conversation loading, message stream setup,
  /// and typing indicator management with disposal safety checks ensuring proper
  /// chat functionality throughout ViewModel lifecycle.
  /// 
  /// **Initialization Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Conversation data loading and validation
  /// - Message stream subscription setup for real-time updates
  /// - Typing indicator cleanup timer initialization
  /// - State management preparation for chat coordination
  void _initializeChat() {
    if (_isDisposed) return;
    
    _loadConversation();
    _loadMessages();
    _startTypingCleanUp();
  }

  /// Loads conversation data with comprehensive error handling and state management.
  /// 
  /// Performs conversation loading from MessagingService when initial conversation
  /// is not provided, with comprehensive error handling and state coordination
  /// ensuring proper conversation information availability throughout chat sessions.
  /// 
  /// **Conversation Loading Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Conversation existence check avoiding unnecessary loading operations
  /// - MessagingService conversation retrieval with conversation identification
  /// - State update with loaded conversation data and UI notification
  /// - Comprehensive error handling with Swedish localized error messages
  Future<void> _loadConversation() async {
    if (_isDisposed) return;
    
    if (_conversation == null) {
      try {
        _conversation = await _messagingService.getConversation(conversationId);
        _safeNotifyListeners();
      } catch (e) {
        AppLogger.error('Failed to load conversation', e);
        _setError('Kunde inte ladda konversation');
      }
    }
  }

  /// Loads messages with comprehensive stream setup and real-time coordination.
  /// 
  /// Performs message stream initialization including MessagingService subscription,
  /// real-time update coordination, and error handling with disposal safety checks
  /// ensuring proper message functionality throughout chat sessions.
  /// 
  /// **Message Loading Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService message stream subscription setup with conversation targeting
  /// - Stream event handlers configuration for message updates and error handling
  /// - Comprehensive error handling with Swedish localized error messages
  /// - State management preparation for message coordination
  void _loadMessages() {
    if (_isDisposed) return;
    
    try {
      _messagesSubscription = _messagingService
          .getConversationMessages(
            conversationId: conversationId,
            limit: 50,
          )
          .listen(
            _onMessagesUpdate,
            onError: _onMessagesError,
          );
    } catch (e) {
      AppLogger.error('Failed to initialize messages', e);
      _setError('Kunde inte ladda meddelanden');
    }
  }

  /// Handles real-time message updates with comprehensive state synchronization and read status coordination.
  /// 
  /// [messages] Updated message list from MessagingService stream for state synchronization
  /// 
  /// Processes incoming message updates from MessagingService stream with complete state
  /// synchronization, loading state management, automatic read marking, and UI notification
  /// coordination ensuring responsive real-time chat functionality.
  /// 
  /// **Message Update Processing:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Complete message list state update with new data
  /// - Loading state completion and error state clearing
  /// - Automatic conversation read marking for new messages
  /// - Safe UI notification with disposal protection
  void _onMessagesUpdate(List<Message> messages) {
    if (_isDisposed) return;
    
    _messages = messages;
    _isLoading = false;
    _error = null;
    _safeNotifyListeners();
    
    // Auto-mark as read when messages arrive
    if (messages.isNotEmpty) {
      _markAsRead();
    }
  }

  /// Handles message stream errors with comprehensive error management and user feedback.
  /// 
  /// [error] Stream error from MessagingService for error handling and recovery coordination
  /// 
  /// Processes message stream errors with comprehensive error logging, user feedback preparation,
  /// and state management ensuring graceful error handling throughout real-time chat operations.
  /// 
  /// **Error Handling Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Comprehensive error logging through AppLogger for debugging support
  /// - Swedish localized error message preparation for user feedback
  /// - Error state coordination and UI notification management
  void _onMessagesError(dynamic error) {
    if (_isDisposed) return;
    
    AppLogger.error('Messages stream error', error);
    _setError('Kunde inte ladda meddelanden');
  }

  /// Sets error state with comprehensive state management and UI notification coordination.
  /// 
  /// [error] Error message for user display and error state management
  /// 
  /// Updates chat error state with loading completion, error message coordination,
  /// and safe UI notification ensuring proper error display throughout chat operations.
  /// 
  /// **Error State Management:**
  /// - Error message state update with Swedish localization
  /// - Loading state completion for proper UI state coordination
  /// - Safe UI notification with disposal protection and state synchronization
  void _setError(String error) {
    _error = error;
    _isLoading = false;
    _safeNotifyListeners();
  }

  // ===== MESSAGE OPERATIONS =====

  /// Sends text message with comprehensive validation and delivery coordination.
  /// 
  /// [content] Message text content for validation and delivery
  /// 
  /// Returns true if message sending succeeds, false if validation fails or delivery errors occur.
  /// Performs text message sending with content validation, MessagingService integration,
  /// state management, and comprehensive error handling ensuring successful message delivery.
  /// 
  /// **Text Message Sending Process:**
  /// 1. Disposal safety validation preventing operations on disposed ViewModel
  /// 2. Content validation ensuring non-empty message text
  /// 3. Sending state activation for UI progress indication and interaction control
  /// 4. Send error clearing for fresh operation state management
  /// 5. MessagingService text message sending with content preparation
  /// 6. Success handling with sending state completion and logging coordination
  /// 7. Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final sent = await chatViewModel.sendTextMessage('Hej! Hur mår du?');
  /// if (sent) {
  ///   // Message sent successfully
  /// } else if (chatViewModel.sendError != null) {
  ///   // Handle send error
  /// }
  /// ```
  Future<bool> sendTextMessage(String content) async {
    if (_isDisposed) return false;
    
    if (content.trim().isEmpty) {
      _sendError = 'Meddelandet kan inte vara tomt';
      _safeNotifyListeners();
      return false;
    }

    _isSending = true;
    _sendError = null;
    _safeNotifyListeners();

    try {
      await _messagingService.sendTextMessage(
        conversationId: conversationId,
        content: content.trim(),
      );

      _isSending = false;
      _safeNotifyListeners();
      
      AppLogger.debug('Text message sent successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send text message', e);
      _sendError = 'Kunde inte skicka meddelandet: ${e.toString()}';
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Sends recipe share message with comprehensive recipe coordination and delivery management.
  /// 
  /// [recipeId] Unique recipe identifier for recipe sharing and reference coordination
  /// [recipeTitle] Recipe title for display and sharing context management
  /// [message] Optional accompanying message for enhanced sharing context
  /// 
  /// Returns true if recipe sharing succeeds, false if operation fails or delivery errors occur.
  /// Performs recipe share message sending with MessagingService integration, recipe coordination,
  /// state management, and comprehensive error handling ensuring successful recipe sharing.
  /// 
  /// **Recipe Share Sending Process:**
  /// 1. Disposal safety validation preventing operations on disposed ViewModel
  /// 2. Sending state activation for UI progress indication and interaction control
  /// 3. Send error clearing for fresh operation state management
  /// 4. MessagingService recipe share sending with recipe identification and context
  /// 5. Success handling with sending state completion and logging coordination
  /// 6. Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final sent = await chatViewModel.sendRecipeShare(
  ///   recipeId: 'recipe_456',
  ///   recipeTitle: 'Pannkakor med sylt',
  ///   message: 'Prova detta recept!',
  /// );
  /// ```
  Future<bool> sendRecipeShare({
    required String recipeId,
    required String recipeTitle,
    String? message,
  }) async {
    if (_isDisposed) return false;
    
    _isSending = true;
    _sendError = null;
    _safeNotifyListeners();

    try {
      await _messagingService.sendRecipeShare(
        conversationId: conversationId,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        message: message,
      );

      _isSending = false;
      _safeNotifyListeners();
      
      AppLogger.debug('Recipe share sent successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send recipe share', e);
      _sendError = 'Kunde inte dela receptet: ${e.toString()}';
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  // Note: Menu sharing can be added later when the MessagingService supports it

  /// Deletes message with comprehensive removal coordination and error handling.
  /// 
  /// [messageId] Unique message identifier for deletion and removal coordination
  /// 
  /// Returns true if message deletion succeeds, false if operation fails or authorization errors occur.
  /// Performs message deletion with MessagingService integration, authorization validation,
  /// and comprehensive error handling ensuring proper message removal coordination.
  /// 
  /// **Message Deletion Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService message deletion with message identification
  /// - Success logging and operation confirmation with boolean result return
  /// - Comprehensive error handling with operation failure indication
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final deleted = await chatViewModel.deleteMessage('message_789');
  /// if (deleted) {
  ///   // Message successfully deleted
  /// } else {
  ///   // Show error message about deletion failure
  /// }
  /// ```
  Future<bool> deleteMessage(String messageId) async {
    if (_isDisposed) return false;
    
    try {
      await _messagingService.deleteMessage(messageId);
      AppLogger.debug('Message deleted successfully: $messageId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete message', e);
      return false;
    }
  }

  // ===== TYPING INDICATOR OPERATIONS =====

  /// Sets typing indicator with comprehensive presence coordination and state management.
  /// 
  /// Activates typing indicator for current user through MessagingService with
  /// comprehensive error handling ensuring proper typing presence coordination
  /// throughout chat interaction without disrupting user experience for non-critical operations.
  /// 
  /// **Typing Indicator Activation Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService typing indicator activation with conversation identification
  /// - Silent error handling preventing user disruption for non-critical operations
  /// - Presence coordination for real-time typing status management
  /// 
  /// **Error Handling Strategy:**
  /// Typing indicator operations use silent error handling because operation failure
  /// should not disrupt user chat experience. Errors are logged for debugging
  /// but not displayed to users as this is a presence feature.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// chatViewModel.setTyping(); // User started typing
  /// // Typing indicator activated for other participants
  /// ```
  void setTyping() {
    if (_isDisposed) return;
    
    try {
      _messagingService.setTypingIndicator(conversationId);
    } catch (e) {
      AppLogger.error('Failed to set typing indicator', e);
    }
  }

  /// Clears typing indicator with comprehensive presence cleanup and state coordination.
  /// 
  /// Deactivates typing indicator for current user through MessagingService with
  /// comprehensive error handling ensuring proper typing presence cleanup
  /// throughout chat interaction without disrupting user experience for non-critical operations.
  /// 
  /// **Typing Indicator Deactivation Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService typing indicator deactivation with conversation identification
  /// - Silent error handling preventing user disruption for non-critical operations
  /// - Presence cleanup for accurate typing status management
  /// 
  /// **Usage Example:**
  /// ```dart
  /// chatViewModel.clearTyping(); // User stopped typing
  /// // Typing indicator removed for other participants
  /// ```
  void clearTyping() {
    if (_isDisposed) return;
    
    try {
      _messagingService.clearTypingIndicator(conversationId);
    } catch (e) {
      AppLogger.error('Failed to clear typing indicator', e);
    }
  }

  /// Updates typing user presence with comprehensive tracking and display coordination.
  /// 
  /// [userId] User identifier for typing status tracking and presence management
  /// [displayName] User display name for typing indicator display and user identification
  /// 
  /// Records external typing user presence with timestamp tracking enabling
  /// typing indicator display and automatic cleanup coordination throughout
  /// chat sessions with disposal safety and current user filtering.
  /// 
  /// **Typing User Update Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Current user filtering preventing self-typing indicator display
  /// - Typing user presence recording with timestamp for automatic cleanup
  /// - Safe UI notification with disposal protection and state synchronization
  /// 
  /// **Usage Example:**
  /// ```dart
  /// // Called from external typing indicator updates
  /// chatViewModel.updateTypingUser('user_123', 'Anna Andersson');
  /// // Anna's typing indicator now displayed
  /// ```
  void updateTypingUser(String userId, String displayName) {
    if (_isDisposed) return;
    
    if (userId != currentUserId) {
      _typingUsers[displayName] = DateTime.now();
      _safeNotifyListeners();
    }
  }

  /// Clears typing user presence with comprehensive cleanup and display coordination.
  /// 
  /// [userId] User identifier for typing status cleanup and presence management
  /// [displayName] User display name for typing indicator removal and cleanup coordination
  /// 
  /// Removes external typing user presence enabling accurate typing indicator
  /// display and presence management throughout chat sessions with disposal
  /// safety and UI notification coordination.
  /// 
  /// **Typing User Cleanup Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Typing user presence removal from tracking map
  /// - Safe UI notification with disposal protection and state synchronization
  /// - Typing indicator display update for accurate presence coordination
  /// 
  /// **Usage Example:**
  /// ```dart
  /// // Called when user stops typing
  /// chatViewModel.clearTypingUser('user_123', 'Anna Andersson');
  /// // Anna's typing indicator removed
  /// ```
  void clearTypingUser(String userId, String displayName) {
    if (_isDisposed) return;
    
    _typingUsers.remove(displayName);
    _safeNotifyListeners();
  }

  /// Starts typing indicator cleanup timer with comprehensive automatic management and resource coordination.
  /// 
  /// Initializes periodic cleanup timer for expired typing indicators ensuring accurate
  /// user presence display and resource management with automatic cleanup of users
  /// who have stopped typing but haven't explicitly cleared their typing status.
  /// 
  /// **Typing Cleanup Process:**
  /// - Periodic timer setup with 2-second cleanup intervals
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Expired typing status identification (older than 5 seconds)
  /// - Batch cleanup of expired typing users
  /// - UI notification coordination for accurate presence display
  /// - Automatic timer cancellation on ViewModel disposal
  void _startTypingCleanUp() {
    _typingCleanUpTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final expired = _typingUsers.entries
          .where((entry) => now.difference(entry.value).inSeconds > 5)
          .map((entry) => entry.key)
          .toList();
      
      if (expired.isNotEmpty) {
        for (final name in expired) {
          _typingUsers.remove(name);
        }
        _safeNotifyListeners();
      }
    });
  }

  // ===== CONVERSATION OPERATIONS =====

  /// Marks conversation as read with comprehensive status management and silent error handling.
  /// 
  /// Performs conversation read status update through MessagingService with silent error handling
  /// ensuring proper read status coordination without disrupting user experience for non-critical operations.
  /// 
  /// **Read Status Update Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService read status update with conversation identification
  /// - Silent error handling preventing user disruption for non-critical operations
  /// 
  /// **Private Method**: Used internally for automatic read marking when messages arrive.
  Future<void> _markAsRead() async {
    if (_isDisposed) return;
    
    try {
      await _messagingService.markConversationAsRead(conversationId);
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read', e);
    }
  }

  /// Marks conversation as read with comprehensive status management (public method).
  /// 
  /// Provides public interface for manual conversation read marking enabling
  /// explicit read status coordination and conversation management operations
  /// throughout chat functionality.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await chatViewModel.markAsRead();
  /// // Conversation marked as read, unread indicators cleared
  /// ```
  Future<void> markAsRead() async {
    await _markAsRead();
  }

  // ===== UI UTILITY OPERATIONS =====

  /// Determines avatar display necessity with comprehensive message context analysis and display optimization.
  /// 
  /// [message] Current message for avatar display determination and context analysis
  /// [previousMessage] Previous message for sender comparison and timing analysis
  /// 
  /// Returns true if avatar should be displayed, false if avatar display should be omitted.
  /// Performs intelligent avatar display logic based on message sender, timing, and conversation
  /// context ensuring optimal chat UI with appropriate avatar placement and visual hierarchy.
  /// 
  /// **Avatar Display Logic:**
  /// - **Current User Messages**: Never show avatar (messages aligned to right)
  /// - **First Message**: Always show avatar for conversation context
  /// - **Sender Change**: Show avatar when sender changes between messages
  /// - **Time Gap**: Show avatar if more than 5 minutes passed since previous message
  /// - **Same Sender Recent**: Hide avatar for recent messages from same sender
  /// 
  /// **Usage Example:**
  /// ```dart
  /// for (int i = 0; i < messages.length; i++) {
  ///   final message = messages[i];
  ///   final previousMessage = chatViewModel.getPreviousMessage(i);
  ///   final showAvatar = chatViewModel.shouldShowAvatar(message, previousMessage);
  ///   // Use showAvatar for UI rendering decisions
  /// }
  /// ```
  bool shouldShowAvatar(Message message, Message? previousMessage) {
    if (message.isFromCurrentUser(currentUserId ?? '')) {
      return false; // Never show avatar for own messages
    }
    
    if (previousMessage == null) {
      return true; // Always show for first message
    }
    
    // Show avatar if sender changed or if more than 5 minutes passed
    return previousMessage.senderId != message.senderId ||
           message.sentAt.difference(previousMessage.sentAt).inMinutes > 5;
  }

  /// Gets message at specific index with comprehensive bounds checking and safe access.
  /// 
  /// [index] Message index for retrieval and access coordination
  /// 
  /// Returns message at specified index if valid, null if index is out of bounds.
  /// Provides safe message access with bounds validation preventing index errors
  /// and enabling reliable message retrieval throughout chat functionality.
  /// 
  /// **Safe Access Process:**
  /// - Index bounds validation ensuring valid array access
  /// - Null return for out-of-bounds access preventing crashes
  /// - Direct message access for valid indices
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final message = chatViewModel.getMessageAt(5);
  /// if (message != null) {
  ///   // Process valid message
  /// }
  /// ```
  Message? getMessageAt(int index) {
    if (index < 0 || index >= _messages.length) return null;
    return _messages[index];
  }

  /// Gets previous message for given index with comprehensive context access and bounds checking.
  /// 
  /// [index] Current message index for previous message retrieval and context analysis
  /// 
  /// Returns previous message if available, null if no previous message exists.
  /// Provides convenient previous message access for UI context analysis including
  /// avatar display logic, message grouping, and conversation flow coordination.
  /// 
  /// **Previous Message Access Logic:**
  /// - Automatic index calculation for previous message position
  /// - Bounds checking through getMessageAt for safe access
  /// - Null return for first message or invalid indices
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final previousMessage = chatViewModel.getPreviousMessage(currentIndex);
  /// final showAvatar = chatViewModel.shouldShowAvatar(message, previousMessage);
  /// ```
  Message? getPreviousMessage(int index) {
    return getMessageAt(index - 1);
  }

  // ===== REFRESH OPERATIONS =====

  /// Refreshes messages with UI feedback coordination and stream-based architecture support.
  /// 
  /// Performs message refresh operation optimized for pull-to-refresh UI patterns
  /// with stream-based architecture consideration and user feedback timing coordination.
  /// 
  /// **Refresh Architecture:**
  /// This method provides UI feedback timing for pull-to-refresh functionality while
  /// leveraging the real-time stream architecture. Since messages are updated
  /// automatically through MessagingService streams, this method primarily handles
  /// UI coordination and user feedback timing rather than forcing data refresh.
  /// 
  /// **Refresh Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - UI feedback delay providing appropriate user experience timing
  /// - Stream architecture coordination with automatic updates
  /// - Pull-to-refresh pattern support with responsive user interaction
  /// 
  /// **Usage Example:**
  /// ```dart
  /// // In pull-to-refresh widget
  /// onRefresh: () async {
  ///   await chatViewModel.refresh();
  ///   // Messages automatically updated via stream
  /// }
  /// ```
  Future<void> refresh() async {
    if (_isDisposed) return;
    
    // Stream will automatically update, this is just for UI feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ===== ERROR MANAGEMENT OPERATIONS =====

  /// Clears all error states with comprehensive error recovery and state coordination.
  /// 
  /// Performs complete error state cleanup including general chat errors
  /// and message sending specific errors with UI notification ensuring
  /// proper error recovery throughout chat operations.
  /// 
  /// **Error Clearing Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - General chat error state clearing and reset
  /// - Message sending error state clearing and reset
  /// - Safe UI notification with disposal protection and state synchronization
  /// 
  /// **Error Recovery Coordination:**
  /// This method clears both general chat errors and message sending
  /// specific errors, providing comprehensive error recovery for all chat
  /// operations and enabling fresh operation attempts after error resolution.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (chatViewModel.error != null || chatViewModel.sendError != null) {
  ///   chatViewModel.clearError();
  ///   // All errors cleared, ready for retry
  /// }
  /// ```
  void clearError() {
    if (_isDisposed) return;
    
    _error = null;
    _sendError = null;
    _safeNotifyListeners();
  }

  /// Clears message sending error with comprehensive send error recovery and state coordination.
  /// 
  /// Performs message sending error state cleanup with UI notification enabling
  /// targeted send error recovery and fresh send operation attempts throughout
  /// chat functionality without affecting general error state.
  /// 
  /// **Send Error Clearing Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Message sending error state clearing and reset
  /// - Safe UI notification with disposal protection and state synchronization
  /// - Focused error recovery for send operations only
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (chatViewModel.sendError != null) {
  ///   chatViewModel.clearSendError();
  ///   // Send error cleared, ready for new message sending attempt
  /// }
  /// ```
  void clearSendError() {
    if (_isDisposed) return;
    
    _sendError = null;
    _safeNotifyListeners();
  }

  // ===== SAFE UI COORDINATION =====

  /// Performs safe UI notification with comprehensive disposal protection and state synchronization.
  /// 
  /// Executes UI notification with disposal safety checks preventing operations
  /// on disposed ViewModel and avoiding memory leaks or state corruption during
  /// ViewModel lifecycle transitions and cleanup operations.
  /// 
  /// **Safe Notification Process:**
  /// - Disposal state validation ensuring ViewModel is still active
  /// - UI notification execution only for active ViewModel instances
  /// - Memory leak prevention through lifecycle management
  /// - State corruption prevention during disposal transitions
  /// 
  /// **Disposal Safety Architecture:**
  /// This method is critical for preventing crashes and memory issues during
  /// ViewModel disposal, especially with asynchronous operations that might
  /// complete after disposal has been initiated.
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ===== LIFECYCLE MANAGEMENT =====

  /// Disposes chat ViewModel with comprehensive cleanup and resource management.
  /// 
  /// Performs complete resource cleanup including stream subscription cancellation,
  /// timer disposal, typing indicator cleanup, and memory management ensuring proper
  /// chat ViewModel lifecycle management and preventing memory leaks throughout application lifecycle.
  /// 
  /// **Disposal Process:**
  /// - Disposal flag activation preventing further operations and state changes
  /// - MessagingService message stream subscription cancellation and resource cleanup
  /// - Typing indicator cleanup timer cancellation and resource management
  /// - Final typing indicator clearing ensuring proper presence cleanup
  /// - Parent disposal coordination through super.dispose() call
  /// - Memory management and resource cleanup for proper lifecycle completion
  /// 
  /// **Resource Management:**
  /// Stream subscription and timer cancellation is critical for preventing memory leaks
  /// and ensuring proper cleanup of real-time messaging resources throughout
  /// ViewModel lifecycle management and application memory optimization.
  /// 
  /// **Override Implementation**: Extends ChangeNotifier disposal with chat-specific cleanup.
  @override
  void dispose() {
    _isDisposed = true;
    _messagesSubscription?.cancel();
    _typingCleanUpTimer?.cancel();
    clearTyping(); // Clear typing indicator when leaving chat
    super.dispose();
  }
}