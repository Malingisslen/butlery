// lib/viewmodels/chat_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

class ChatViewModel extends ChangeNotifier with StreamManagementMixin, ErrorHandlingMixin {
  final MessagingService _messagingService;
  final AuthRepository _authRepository;
  
  final String conversationId;

  // State
  bool _isDisposed = false;
  Conversation? _conversation;
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  String? _sendError;
  final Map<String, DateTime> _typingUsers = {};
  
  List<String> get typingUserNames => _typingUsers.entries
      .where((entry) => DateTime.now().difference(entry.value).inSeconds < 5)
      .map((entry) => entry.key)
      .toList();

  StreamSubscription<List<Message>>? _messagesSubscription;
  Timer? _typingCleanUpTimer;

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
  String? get currentUserId => _authRepository.currentUserId;
  
  String get conversationTitle {
    if (_conversation == null) return 'Laddar...';
    if (currentUserId == null) return _conversation!.title ?? 'Chatt';
    return _conversation!.getDisplayTitle(currentUserId!);
  }

  bool get canSendMessages => _conversation != null && !_isDisposed;

  void _initializeChat() {
    if (_isDisposed) return;
    
    _loadConversation();
    _loadMessages();
    _startTypingCleanUp();
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
    if (_isDisposed) return;
    
    try {
      _messagingService.setTypingIndicator(conversationId);
    } catch (e) {
      AppLogger.error('Failed to set typing indicator', e);
    }
  }

  void clearTyping() {
    if (_isDisposed) return;
    
    try {
      _messagingService.clearTypingIndicator(conversationId);
    } catch (e) {
      AppLogger.error('Failed to clear typing indicator', e);
    }
  }

  void updateTypingUser(String userId, String displayName) {
    if (_isDisposed) return;
    
    if (userId != currentUserId) {
      _typingUsers[displayName] = DateTime.now();
      _safeNotifyListeners();
    }
  }

  void clearTypingUser(String userId, String displayName) {
    if (_isDisposed) return;
    
    _typingUsers.remove(displayName);
    _safeNotifyListeners();
  }

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
    _typingCleanUpTimer?.cancel();
    clearTyping(); // Clear typing indicator when leaving chat
    super.dispose();
  }
}