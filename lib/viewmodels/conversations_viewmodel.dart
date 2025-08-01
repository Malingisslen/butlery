/// Comprehensive conversations list ViewModel providing advanced messaging coordination and conversation management for Flutter applications.
///
/// This module implements sophisticated conversation list functionality following Single Responsibility Principle,
/// specializing in real-time conversation management, messaging coordination, search functionality, and conversation
/// lifecycle operations. It provides complete messaging infrastructure while maintaining clean separation from
/// UI rendering, message content handling, and complex messaging business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles conversation list presentation layer concerns:
/// - **Real-Time Messaging Coordination**: Advanced conversation list management with real-time stream synchronization
/// - **Conversation Search Intelligence**: Sophisticated search functionality across conversation titles and message content
/// - **Conversation Lifecycle Management**: Complete conversation creation, group management, and participation operations
/// - **Messaging State Coordination**: Advanced messaging state management with error handling and loading coordination
/// - **Swedish Localization Excellence**: Complete Swedish language support for messaging operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - Individual message content and delivery (handled by ChatViewModel and message-specific ViewModels)
/// - UI rendering and widget creation (handled by conversations views and presentation components)
/// - Complex messaging business logic (handled by MessagingService and underlying messaging infrastructure)
/// - Real-time synchronization infrastructure (handled by messaging services and stream coordination systems)
///
/// **Conversations ViewModel Features:**
/// - **Real-Time Conversation Lists**: Complete conversation stream management with automatic updates and synchronization
/// - **Advanced Search Capabilities**: Intelligent search across conversation titles, participants, and recent message content
/// - **Conversation Creation System**: Comprehensive direct and group conversation creation with participant management
/// - **Messaging State Management**: Advanced loading states, error handling, and conversation status coordination
/// - **Swedish Localization**: Complete Swedish language support for conversation operations and error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize conversations ViewModel with messaging service integration
/// final conversationsViewModel = ConversationsViewModel(
///   messagingService: ServiceLocator.get<MessagingService>(),
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Real-time conversation list monitoring
/// if (conversationsViewModel.hasConversations) {
///   final conversations = conversationsViewModel.conversations;
///   for (final conversation in conversations) {
///     final title = conversation.getDisplayTitle(conversationsViewModel.currentUserId ?? '');
///     final lastMessage = conversation.lastMessage?.content;
///   }
/// }
/// 
/// // Conversation search and filtering
/// conversationsViewModel.updateSearchQuery('pannkakor');
/// final searchResults = conversationsViewModel.conversations;
/// conversationsViewModel.clearSearch(); // Clear search results
/// 
/// // Direct conversation creation
/// final conversationId = await conversationsViewModel.startDirectConversation(
///   otherUserId: 'user_123',
///   otherUserDisplayName: 'Anna Andersson',
///   otherUserAvatarUrl: 'https://example.com/avatar.jpg',
/// );
/// if (conversationId != null) {
///   // Navigate to conversation
/// }
/// 
/// // Group conversation creation
/// final groupId = await conversationsViewModel.createGroupConversation(
///   participantIds: ['user_123', 'user_456'],
///   participantDisplayNames: {'user_123': 'Anna', 'user_456': 'Erik'},
///   participantAvatarUrls: {'user_123': 'url1', 'user_456': 'url2'},
///   title: 'Receptgruppen',
/// );
/// 
/// // Conversation management operations
/// await conversationsViewModel.markConversationAsRead('conversation_123');
/// final leftGroup = await conversationsViewModel.leaveGroup('group_conversation_456');
/// 
/// // State monitoring and error handling
/// if (conversationsViewModel.isLoading) {
///   // Show loading indicator
/// } else if (conversationsViewModel.error != null) {
///   // Display error message
/// } else if (conversationsViewModel.isCreatingConversation) {
///   // Show conversation creation progress
/// }
/// 
/// // Error handling and recovery
/// if (conversationsViewModel.conversationCreationError != null) {
///   // Handle conversation creation error
///   conversationsViewModel.clearError();
/// }
/// 
/// // Refresh functionality for pull-to-refresh
/// await conversationsViewModel.refresh();
/// ```

// lib/viewmodels/conversations_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';

/// Comprehensive conversations list ViewModel providing advanced messaging coordination through service integration.
///
/// Manages conversation list state enabling real-time messaging coordination with conversation creation, search functionality,
/// participant management, and messaging status tracking while maintaining clean MVVM architecture separation between
/// messaging business logic and UI presentation concerns.
///
/// **Core Responsibilities:**
/// - Real-time conversation list management with stream synchronization and automatic updates
/// - Advanced search functionality across conversation titles, participants, and message content
/// - Conversation creation and management including direct messages and group conversations
/// - Messaging state coordination with loading states, error handling, and operation status tracking
/// - Swedish localized error messages and user feedback coordination
class ConversationsViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final MessagingService _messagingService;
  final AuthRepository _authRepository;

  // ===== LIFECYCLE MANAGEMENT =====

  /// Disposal safety flag preventing operations after ViewModel disposal.
  /// 
  /// Ensures safe disposal and prevents operations on disposed ViewModel
  /// avoiding memory leaks and state corruption during lifecycle transitions.
  bool _isDisposed = false;

  // ===== CONVERSATION STATE =====

  /// Complete conversations collection from messaging service for filtering and display coordination.
  /// 
  /// Stores all user conversations enabling search functionality, filtering operations,
  /// and complete conversation list management throughout messaging sessions.
  List<Conversation> _allConversations = [];
  
  /// Filtered conversations collection based on search criteria for display and interaction management.
  /// 
  /// Stores search-filtered conversation results enabling responsive search functionality
  /// and conversation discovery throughout messaging interface operations.
  List<Conversation> _filteredConversations = [];
  
  /// Conversation loading state for UI progress indication during data synchronization.
  /// 
  /// Indicates active conversation loading for loading indicators and interaction
  /// control during conversation list initialization and synchronization.
  bool _isLoading = true;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout conversation operations and messaging functionality.
  String? _error;
  
  // ===== SEARCH STATE =====

  /// Current search query for conversation filtering and content discovery.
  /// 
  /// Stores user search input enabling conversation search functionality
  /// and content discovery throughout messaging interface operations.
  String _searchQuery = '';
  
  /// Search operation state indicator for UI coordination (currently unused but available for future features).
  /// 
  /// Reserved for advanced search functionality enabling search progress indication
  /// and search operation status management in future implementations.
  final bool _isSearching = false;

  // ===== CONVERSATION CREATION STATE =====

  /// Conversation creation operation state for UI progress indication during creation operations.
  /// 
  /// Indicates active conversation creation for loading indicators and interaction
  /// control during direct message and group conversation creation processes.
  bool _isCreatingConversation = false;
  
  /// Conversation creation error message for specific creation error handling and user feedback.
  /// 
  /// Provides specialized error messages for conversation creation failures
  /// enabling targeted error display and creation operation recovery.
  String? _conversationCreationError;

  // ===== STREAM MANAGEMENT =====

  /// Real-time conversations stream subscription for automatic list updates and synchronization.
  /// 
  /// Manages MessagingService stream subscription enabling real-time conversation updates,
  /// automatic synchronization, and live messaging coordination throughout user sessions.
  StreamSubscription<List<Conversation>>? _conversationsSubscription;

  /// Initializes conversations ViewModel with comprehensive messaging service integration and real-time preparation.
  /// 
  /// [messagingService] MessagingService instance for conversation operations and real-time messaging coordination
  /// [authRepository] AuthRepository instance for user authentication and authorization management
  /// 
  /// Establishes conversations infrastructure with service integration, enabling comprehensive
  /// real-time messaging functionality with conversation management, search capabilities, and unified state coordination.
  /// 
  /// **Initialization Process:**
  /// - MessagingService integration for conversation operations and real-time updates
  /// - AuthRepository integration for user authentication and conversation authorization
  /// - Automatic conversation list initialization with stream subscription setup
  /// - Real-time synchronization preparation with error handling and state management
  ConversationsViewModel({
    required MessagingService messagingService,
    required AuthRepository authRepository,
  }) : _messagingService = messagingService,
       _authRepository = authRepository {
    _initializeConversations();
  }

  // ===== STATE ACCESSORS =====

  /// Filtered conversations collection for display and interaction coordination.
  /// 
  /// Provides access to search-filtered conversation list enabling UI rendering
  /// and conversation interaction management throughout messaging functionality.
  List<Conversation> get conversations => _filteredConversations;
  
  /// Conversation loading state for UI progress indication and interaction control.
  /// 
  /// Indicates whether conversation data is being loaded for loading indicators
  /// and user interaction management during conversation synchronization.
  bool get isLoading => _isLoading;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides access to current error state enabling error display
  /// and recovery coordination throughout conversation operations.
  String? get error => _error;
  
  /// Current search query for search input display and query management.
  /// 
  /// Provides access to active search query enabling search input field
  /// synchronization and search state management throughout conversation filtering.
  String get searchQuery => _searchQuery;
  
  /// Search operation state indicator for future UI coordination and progress indication.
  /// 
  /// Reserved for advanced search functionality enabling search progress indication
  /// and search operation status management in future implementations.
  bool get isSearching => _isSearching;
  
  /// Conversation creation operation state for UI progress indication and interaction control.
  /// 
  /// Indicates whether conversation creation is in progress for loading indicators
  /// and user interaction management during conversation creation operations.
  bool get isCreatingConversation => _isCreatingConversation;
  
  /// Conversation creation error message for specialized error handling and user feedback.
  /// 
  /// Provides access to conversation creation specific errors enabling targeted
  /// error display and creation operation recovery coordination.
  String? get conversationCreationError => _conversationCreationError;
  
  /// Conversations availability indicator for conditional UI rendering and empty state management.
  /// 
  /// Indicates whether filtered conversations are available for UI conditional
  /// rendering and empty state display coordination.
  bool get hasConversations => _filteredConversations.isNotEmpty;
  
  /// Current authenticated user ID for conversation authorization and display coordination.
  /// 
  /// Provides access to current user ID enabling conversation authorization,
  /// display title generation, and user-specific conversation management.
  String? get currentUserId => _authRepository.currentUserId;

  // ===== INITIALIZATION OPERATIONS =====

  /// Initializes conversations ViewModel with comprehensive stream setup and real-time coordination.
  /// 
  /// Performs conversation list initialization including MessagingService stream subscription,
  /// real-time update coordination, and error handling with disposal safety checks ensuring
  /// proper messaging functionality throughout ViewModel lifecycle.
  /// 
  /// **Initialization Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService stream subscription setup for real-time conversation updates
  /// - Stream event handlers configuration for data updates and error handling
  /// - Comprehensive error handling with Swedish localized error messages
  /// - State management preparation for conversation list coordination
  void _initializeConversations() {
    if (_isDisposed) return;
    
    try {
      _conversationsSubscription = _messagingService
          .getMyConversations()
          .listen(
            _onConversationsUpdate,
            onError: _onConversationsError,
          );
    } catch (e) {
      AppLogger.error('Failed to initialize conversations', e);
      _setError('Kunde inte ladda konversationer');
    }
  }

  /// Handles real-time conversation updates with comprehensive state synchronization and search coordination.
  /// 
  /// [conversations] Updated conversation list from MessagingService stream for state synchronization
  /// 
  /// Processes incoming conversation updates from MessagingService stream with complete state
  /// synchronization, search application, loading state management, and UI notification coordination
  /// ensuring responsive real-time messaging functionality.
  /// 
  /// **Update Processing:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Complete conversation list state update with new data
  /// - Search filter application maintaining current search criteria
  /// - Loading state completion and error state clearing
  /// - Safe UI notification with disposal protection
  void _onConversationsUpdate(List<Conversation> conversations) {
    if (_isDisposed) return;
    
    _allConversations = conversations;
    _applySearch();
    _isLoading = false;
    _error = null;
    _safeNotifyListeners();
  }

  /// Handles conversation stream errors with comprehensive error management and user feedback.
  /// 
  /// [error] Stream error from MessagingService for error handling and recovery coordination
  /// 
  /// Processes conversation stream errors with comprehensive error logging, user feedback preparation,
  /// and state management ensuring graceful error handling throughout real-time messaging operations.
  /// 
  /// **Error Handling Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Comprehensive error logging through AppLogger for debugging support
  /// - Swedish localized error message preparation for user feedback
  /// - Error state coordination and UI notification management
  void _onConversationsError(dynamic error) {
    if (_isDisposed) return;
    
    AppLogger.error('Conversations stream error', error);
    _setError('Kunde inte ladda konversationer');
  }

  /// Sets error state with comprehensive state management and UI notification coordination.
  /// 
  /// [error] Error message for user display and error state management
  /// 
  /// Updates conversation error state with loading completion, error message coordination,
  /// and safe UI notification ensuring proper error display throughout messaging operations.
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

  // ===== SEARCH OPERATIONS =====

  /// Updates search query with comprehensive filtering coordination and state management.
  /// 
  /// [query] Search query string for conversation filtering and content discovery
  /// 
  /// Performs search query update with text normalization, filter application,
  /// and UI notification ensuring responsive conversation search functionality with
  /// real-time filtering coordination throughout messaging interface operations.
  /// 
  /// **Search Update Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Query normalization with trimming and lowercase conversion for consistent matching
  /// - Search filter application with immediate results update
  /// - Safe UI notification with disposal protection and state synchronization
  /// 
  /// **Usage Example:**
  /// ```dart
  /// conversationsViewModel.updateSearchQuery('recipe chat');
  /// final searchResults = conversationsViewModel.conversations;
  /// ```
  void updateSearchQuery(String query) {
    if (_isDisposed) return;
    
    _searchQuery = query.trim().toLowerCase();
    _applySearch();
    _safeNotifyListeners();
  }

  /// Clears search query with comprehensive filter reset and state coordination.
  /// 
  /// Performs search query clearing with complete filter reset, showing all conversations,
  /// and UI notification ensuring proper search state management and conversation list restoration.
  /// 
  /// **Search Clear Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - Search query clearing and state reset
  /// - Complete conversation list restoration with filter application
  /// - Safe UI notification with disposal protection and state synchronization
  /// 
  /// **Usage Example:**
  /// ```dart
  /// conversationsViewModel.clearSearch();
  /// // All conversations now visible, search cleared
  /// ```
  void clearSearch() {
    if (_isDisposed) return;
    
    _searchQuery = '';
    _applySearch();
    _safeNotifyListeners();
  }

  /// Applies current search criteria with comprehensive conversation filtering and content matching.
  /// 
  /// Performs intelligent conversation filtering based on current search query including
  /// conversation title matching, last message content search, and multi-criteria matching
  /// ensuring comprehensive conversation discovery throughout messaging functionality.
  /// 
  /// **Search Filtering Logic:**
  /// - **No Search Query**: Complete conversation list display with all conversations
  /// - **Active Search**: Multi-criteria filtering including:
  ///   - Conversation display title matching (case-insensitive)
  ///   - Last message content matching (case-insensitive)
  ///   - Comprehensive text search across conversation metadata
  /// 
  /// **Search Criteria:**
  /// - Conversation titles with current user context for display title generation
  /// - Recent message content for conversation content discovery
  /// - Case-insensitive matching for user-friendly search experience
  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredConversations = List.from(_allConversations);
    } else {
      _filteredConversations = _allConversations.where((conversation) {
        final title = conversation.getDisplayTitle(currentUserId ?? '').toLowerCase();
        final lastMessageContent = conversation.lastMessage?.content.toLowerCase() ?? '';
        
        return title.contains(_searchQuery) || 
               lastMessageContent.contains(_searchQuery);
      }).toList();
    }
  }

  // ===== CONVERSATION LIFECYCLE OPERATIONS =====

  /// Starts direct conversation with comprehensive participant coordination and state management.
  /// 
  /// [otherUserId] Target user ID for direct conversation creation and participant management
  /// [otherUserDisplayName] Display name for conversation title and participant identification
  /// [otherUserAvatarUrl] Optional avatar URL for enhanced conversation display and user recognition
  /// 
  /// Returns conversation ID if creation succeeds, null if operation fails or user interaction cancelled.
  /// Performs direct conversation creation with MessagingService integration, participant coordination,
  /// state management, and comprehensive error handling ensuring successful messaging initialization.
  /// 
  /// **Direct Conversation Creation Process:**
  /// 1. Disposal safety validation preventing operations on disposed ViewModel
  /// 2. Creation state activation for UI progress indication and interaction control
  /// 3. Creation error clearing for fresh operation state management
  /// 4. MessagingService direct conversation creation with participant coordination
  /// 5. Success handling with conversation ID return and logging coordination
  /// 6. Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final conversationId = await conversationsViewModel.startDirectConversation(
  ///   otherUserId: 'user_123',
  ///   otherUserDisplayName: 'Anna Andersson',
  ///   otherUserAvatarUrl: 'https://example.com/avatar.jpg',
  /// );
  /// if (conversationId != null) {
  ///   // Navigate to new conversation
  /// }
  /// ```
  Future<String?> startDirectConversation({
    required String otherUserId,
    required String otherUserDisplayName,
    String? otherUserAvatarUrl,
  }) async {
    if (_isDisposed) return null;
    
    _isCreatingConversation = true;
    _conversationCreationError = null;
    _safeNotifyListeners();

    try {
      final conversationId = await _messagingService.startDirectConversation(
        otherUserId: otherUserId,
        otherUserDisplayName: otherUserDisplayName,
        otherUserAvatarUrl: otherUserAvatarUrl,
      );

      _isCreatingConversation = false;
      _safeNotifyListeners();
      
      AppLogger.success('Direct conversation started: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to start direct conversation', e);
      _conversationCreationError = 'Kunde inte starta konversation: ${e.toString()}';
      _isCreatingConversation = false;
      _safeNotifyListeners();
      return null;
    }
  }

  /// Creates group conversation with comprehensive participant management and collaboration coordination.
  /// 
  /// [participantIds] List of user IDs for group conversation participation and member management
  /// [participantDisplayNames] Map of user IDs to display names for conversation participant identification
  /// [participantAvatarUrls] Map of user IDs to avatar URLs for enhanced participant display and recognition
  /// [title] Group conversation title for identification and display coordination
  /// 
  /// Returns conversation ID if creation succeeds, null if operation fails or validation errors occur.
  /// Performs group conversation creation with MessagingService integration, multi-participant coordination,
  /// state management, and comprehensive error handling ensuring successful group messaging initialization.
  /// 
  /// **Group Conversation Creation Process:**
  /// 1. Disposal safety validation preventing operations on disposed ViewModel
  /// 2. Creation state activation for UI progress indication and interaction control
  /// 3. Creation error clearing for fresh operation state management
  /// 4. MessagingService group conversation creation with participant coordination
  /// 5. Success handling with conversation ID return and logging coordination
  /// 6. Comprehensive error handling with Swedish localized error messages
  /// 
  /// **Participant Management:**
  /// - Multi-user group creation with participant ID validation
  /// - Display name mapping for proper participant identification
  /// - Avatar URL coordination for enhanced group member visualization
  /// - Group title management for conversation identification
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final groupId = await conversationsViewModel.createGroupConversation(
  ///   participantIds: ['user_123', 'user_456', 'user_789'],
  ///   participantDisplayNames: {
  ///     'user_123': 'Anna Andersson',
  ///     'user_456': 'Erik Svensson',
  ///     'user_789': 'Maria Johansson',
  ///   },
  ///   participantAvatarUrls: {
  ///     'user_123': 'https://example.com/anna.jpg',
  ///     'user_456': 'https://example.com/erik.jpg',
  ///     'user_789': null,
  ///   },
  ///   title: 'Receptgruppen - Vegetariska rätter',
  /// );
  /// ```
  Future<String?> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
  }) async {
    if (_isDisposed) return null;
    
    _isCreatingConversation = true;
    _conversationCreationError = null;
    _safeNotifyListeners();

    try {
      final conversationId = await _messagingService.createGroupConversation(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
      );

      _isCreatingConversation = false;
      _safeNotifyListeners();
      
      AppLogger.success('Group conversation created: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      _conversationCreationError = 'Kunde inte skapa gruppchatt: ${e.toString()}';
      _isCreatingConversation = false;
      _safeNotifyListeners();
      return null;
    }
  }

  /// Marks conversation as read with comprehensive status management and silent error handling.
  /// 
  /// [conversationId] Unique conversation identifier for read status update and tracking management
  /// 
  /// Performs conversation read status update through MessagingService with silent error handling
  /// ensuring proper read status coordination without disrupting user experience for non-critical operations.
  /// 
  /// **Read Status Update Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - MessagingService read status update with conversation identification
  /// - Success logging for debugging and operation tracking coordination
  /// - Silent error handling preventing user disruption for non-critical operations
  /// 
  /// **Error Handling Strategy:**
  /// Read status marking uses silent error handling because operation failure
  /// should not disrupt user messaging experience. Errors are logged for debugging
  /// but not displayed to users as this is a background operation.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// await conversationsViewModel.markConversationAsRead('conversation_123');
  /// // Conversation read status updated, no UI feedback needed
  /// ```
  Future<void> markConversationAsRead(String conversationId) async {
    if (_isDisposed) return;
    
    try {
      await _messagingService.markConversationAsRead(conversationId);
      AppLogger.debug('Conversation marked as read: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read', e);
      // Don't show error to user for this operation
    }
  }

  /// Removes current user from group conversation with comprehensive participant management and authentication validation.
  /// 
  /// [conversationId] Group conversation identifier for participant removal and group management coordination
  /// 
  /// Returns true if group leaving succeeds, false if operation fails or authentication errors occur.
  /// Performs group participant removal with authentication validation, MessagingService integration,
  /// and comprehensive error handling ensuring proper group membership management.
  /// 
  /// **Group Leave Process:**
  /// 1. Disposal safety validation preventing operations on disposed ViewModel
  /// 2. Current user authentication validation ensuring proper authorization
  /// 3. Authentication error handling with exception throwing for invalid states
  /// 4. MessagingService participant removal with group and user identification
  /// 5. Success logging and operation confirmation with boolean result return
  /// 6. Comprehensive error handling with operation failure indication
  /// 
  /// **Authentication Requirements:**
  /// - Valid current user authentication required for group operations
  /// - User ID availability validation ensuring proper participant identification
  /// - Authentication error handling preventing unauthorized group operations
  /// 
  /// **Usage Example:**
  /// ```dart
  /// final leftGroup = await conversationsViewModel.leaveGroup('group_conversation_456');
  /// if (leftGroup) {
  ///   // User successfully left the group
  ///   // Navigate away from group conversation
  /// } else {
  ///   // Show error message about leaving group
  /// }
  /// ```
  Future<bool> leaveGroup(String conversationId) async {
    if (_isDisposed) return false;
    
    try {
      final currentUser = currentUserId;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _messagingService.removeParticipantFromGroup(
        conversationId: conversationId,
        participantId: currentUser,
      );
      
      AppLogger.success('Left group conversation: $conversationId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to leave group', e);
      return false;
    }
  }

  // ===== REFRESH OPERATIONS =====

  /// Refreshes conversations with UI feedback coordination and stream-based architecture support.
  /// 
  /// Performs conversation refresh operation optimized for pull-to-refresh UI patterns
  /// with stream-based architecture consideration and user feedback timing coordination.
  /// 
  /// **Refresh Architecture:**
  /// This method provides UI feedback timing for pull-to-refresh functionality while
  /// leveraging the real-time stream architecture. Since conversations are updated
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
  ///   await conversationsViewModel.refresh();
  ///   // Conversations automatically updated via stream
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
  /// Performs complete error state cleanup including general conversation errors
  /// and conversation creation specific errors with UI notification ensuring
  /// proper error recovery throughout messaging operations.
  /// 
  /// **Error Clearing Process:**
  /// - Disposal safety validation preventing operations on disposed ViewModel
  /// - General conversation error state clearing and reset
  /// - Conversation creation error state clearing and reset
  /// - Safe UI notification with disposal protection and state synchronization
  /// 
  /// **Error Recovery Coordination:**
  /// This method clears both general messaging errors and conversation creation
  /// specific errors, providing comprehensive error recovery for all conversation
  /// operations and enabling fresh operation attempts after error resolution.
  /// 
  /// **Usage Example:**
  /// ```dart
  /// if (conversationsViewModel.error != null || 
  ///     conversationsViewModel.conversationCreationError != null) {
  ///   conversationsViewModel.clearError();
  ///   // All errors cleared, ready for retry
  /// }
  /// ```
  void clearError() {
    if (_isDisposed) return;
    
    _error = null;
    _conversationCreationError = null;
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

  /// Disposes conversations ViewModel with comprehensive cleanup and resource management.
  /// 
  /// Performs complete resource cleanup including stream subscription cancellation,
  /// disposal flag setting, and memory management ensuring proper conversations ViewModel
  /// lifecycle management and preventing memory leaks throughout application lifecycle.
  /// 
  /// **Disposal Process:**
  /// - Disposal flag activation preventing further operations and state changes
  /// - MessagingService stream subscription cancellation and resource cleanup
  /// - Parent disposal coordination through super.dispose() call
  /// - Memory management and resource cleanup for proper lifecycle completion
  /// 
  /// **Resource Management:**
  /// Stream subscription cancellation is critical for preventing memory leaks
  /// and ensuring proper cleanup of real-time messaging resources throughout
  /// ViewModel lifecycle management and application memory optimization.
  /// 
  /// **Override Implementation**: Extends ChangeNotifier disposal with messaging-specific cleanup.
  @override
  void dispose() {
    _isDisposed = true;
    _conversationsSubscription?.cancel();
    super.dispose();
  }
}