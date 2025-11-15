// lib/viewmodels/chat_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

class ChatViewModel extends ChangeNotifier with StreamManagementMixin, ErrorHandlingMixin {
  final MessagingService _messagingService;
  final PresenceService? _presenceService;

  final String conversationId;

  // State
  bool _isDisposed = false;
  Conversation? _conversation;
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  String? _sendError;
  List<String> _typingUserIds = [];
  Message? _replyToMessage;

  // Typing users mapped from IDs to display names
  final Map<String, String> _userDisplayNames = {};

  List<String> get typingUserNames => _typingUserIds
      .map((id) => _userDisplayNames[id] ?? 'Okänd')
      .toList();

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<List<String>>? _typingSubscription;
  Timer? _typingDebounceTimer;

  ChatViewModel({
    required MessagingService messagingService,
    required this.conversationId,
    Conversation? initialConversation,
    PresenceService? presenceService,
  })  : _messagingService = messagingService,
        _presenceService = presenceService,
        _conversation = initialConversation {
    _initializeChat();
  }

  // Getters
  Conversation? get conversation => _conversation;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSending => _isSending;
  String? get sendError => _sendError;
  List<String> get currentTypingUsers => typingUserNames;
  bool get hasTypingUsers => typingUserNames.isNotEmpty;
  bool get hasMessages => _messages.isNotEmpty;
  String? get currentUserId => ServiceLocator.get<PermissionService>().currentUserId;
  Message? get replyToMessage => _replyToMessage;
  bool get hasReplyTarget => _replyToMessage != null;
  
  String get conversationTitle {
    if (_conversation == null) return 'Laddar...';
    if (currentUserId == null) return _conversation!.title ?? 'Chatt';
    return _conversation!.getDisplayTitle(currentUserId!);
  }

  String get conversationSubtitle {
    if (_conversation == null) return '';
    
    // For group conversations, show participant count
    if (_conversation!.isGroup) {
      final count = _conversation!.participantIds.length;
      return '$count deltagare';
    }
    
    // For direct conversations, show last seen or online status
    final otherParticipantId = _conversation!.participantIds
        .firstWhere((id) => id != currentUserId, orElse: () => '');
    
    if (otherParticipantId.isEmpty) return '';
    
    // Could return online status or last seen time here
    // For now, just return empty string since we don't track online status
    return '';
  }

  bool get canSendMessages => _conversation != null && !_isDisposed;

  void _initializeChat() {
    if (_isDisposed) return;

    AppLogger.info('🔍 [ChatViewModel] Initializing chat for conversationId: $conversationId');
    _loadConversation();
    _loadMessages();
    _subscribeToTypingIndicators();
  }

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

  void _loadMessages() {
    if (_isDisposed) return;

    try {
      AppLogger.info('🔍 [ChatViewModel] Starting message stream for conversationId: $conversationId');
      _messagesSubscription = _messagingService
          .getConversationMessages(
            conversationId: conversationId,
            limit: 50,
          )
          .listen(
            _onMessagesUpdate,
            onError: _onMessagesError,
          );
      AppLogger.debug('🔍 [ChatViewModel] Message stream subscription created');
    } catch (e) {
      AppLogger.error('❌ [ChatViewModel] Failed to initialize messages', e);
      _setError('Kunde inte ladda meddelanden');
    }
  }

  void _onMessagesUpdate(List<Message> messages) {
    if (_isDisposed) return;

    AppLogger.info('📬 [ChatViewModel] Message stream update received');
    AppLogger.debug('📬 [ChatViewModel] ConversationId: $conversationId');
    AppLogger.debug('📬 [ChatViewModel] Number of messages: ${messages.length}');
    if (messages.isNotEmpty) {
      AppLogger.debug('📬 [ChatViewModel] First message: ${messages.first.content.substring(0, messages.first.content.length > 50 ? 50 : messages.first.content.length)}...');
      AppLogger.debug('📬 [ChatViewModel] Last message: ${messages.last.content.substring(0, messages.last.content.length > 50 ? 50 : messages.last.content.length)}...');
    }

    _messages = messages;
    _isLoading = false;
    _error = null;
    _safeNotifyListeners();

    // Auto-mark as read when messages arrive
    if (messages.isNotEmpty) {
      _markAsRead();
    }
  }

  void _onMessagesError(dynamic error) {
    if (_isDisposed) return;
    
    AppLogger.error('Messages stream error', error);
    _setError('Kunde inte ladda meddelanden');
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    _safeNotifyListeners();
  }

  // Message operations
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
        replyToMessageId: _replyToMessage?.id,
      );

      // Clear reply if we had one
      if (_replyToMessage != null) {
        _replyToMessage = null;
      }
      
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

  // Typing indicator operations
  void setTyping() {
    if (_isDisposed || _presenceService == null) return;

    // Cancel any existing debounce timer
    _typingDebounceTimer?.cancel();

    try {
      _presenceService.startTyping(conversationId);

      // Set up auto-clear after 3 seconds of no typing
      _typingDebounceTimer = Timer(const Duration(seconds: 3), () {
        clearTyping();
      });
    } catch (e) {
      AppLogger.error('Failed to set typing indicator', e);
    }
  }

  void clearTyping() {
    if (_isDisposed || _presenceService == null) return;

    _typingDebounceTimer?.cancel();

    try {
      _presenceService.stopTyping(conversationId);
    } catch (e) {
      AppLogger.error('Failed to clear typing indicator', e);
    }
  }

  void _subscribeToTypingIndicators() {
    if (_isDisposed || _presenceService == null) return;

    // Wait for conversation to load first
    if (_conversation == null) {
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _subscribeToTypingIndicators();
      });
      return;
    }

    try {
      // Get participant IDs excluding current user
      final participantIds = _conversation!.participantIds
          .where((id) => id != currentUserId)
          .toList();

      if (participantIds.isEmpty) return;

      // Subscribe to typing indicators from PresenceService
      _typingSubscription = _presenceService.getTypingUsersStream(conversationId, participantIds)
          .listen(
            (typingUserIds) {
              if (_isDisposed) return;
              _typingUserIds = typingUserIds;
              _loadUserDisplayNames(typingUserIds);
              _safeNotifyListeners();
            },
            onError: (error) {
              AppLogger.error('Typing subscription error', error);
            },
          );
    } catch (e) {
      AppLogger.error('Failed to subscribe to typing indicators', e);
    }
  }

  Future<void> _loadUserDisplayNames(List<String> userIds) async {
    for (final userId in userIds) {
      if (!_userDisplayNames.containsKey(userId)) {
        // For now, use a placeholder
        // In production, you'd fetch the display name from FirebaseUsersRepository or conversation metadata
        _userDisplayNames[userId] = 'Användare';
      }
    }
  }

  // Reply functionality
  void setReplyToMessage(Message message) {
    if (_isDisposed) return;
    
    _replyToMessage = message;
    _safeNotifyListeners();
  }

  void clearReplyToMessage() {
    if (_isDisposed) return;
    
    _replyToMessage = null;
    _safeNotifyListeners();
  }

  Future<bool> sendReply({
    required String content,
  }) async {
    if (_isDisposed || _replyToMessage == null) return false;
    
    _isSending = true;
    _sendError = null;
    _safeNotifyListeners();

    try {
      await _messagingService.sendTextMessage(
        conversationId: conversationId,
        content: content.trim(),
        replyToMessageId: _replyToMessage!.id,
      );

      _replyToMessage = null; // Clear reply after sending
      _isSending = false;
      _safeNotifyListeners();
      
      AppLogger.debug('Reply sent successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send reply', e);
      _sendError = 'Kunde inte skicka svaret: ${e.toString()}';
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  // Conversation operations
  Future<void> _markAsRead() async {
    if (_isDisposed) return;
    
    try {
      await _messagingService.markConversationAsRead(conversationId);
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read', e);
    }
  }

  Future<void> markAsRead() async {
    await _markAsRead();
  }

  // UI utility operations
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

  Message? getMessageAt(int index) {
    if (index < 0 || index >= _messages.length) return null;
    return _messages[index];
  }

  Message? getPreviousMessage(int index) {
    return getMessageAt(index - 1);
  }

  Future<void> refresh() async {
    if (_isDisposed) return;
    
    // Stream will automatically update, this is just for UI feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void clearError() {
    if (_isDisposed) return;
    
    _error = null;
    _sendError = null;
    _safeNotifyListeners();
  }

  void clearSendError() {
    if (_isDisposed) return;
    
    _sendError = null;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingDebounceTimer?.cancel();
    clearTyping(); // Clear typing indicator when leaving chat
    super.dispose();
  }
}