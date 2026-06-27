// lib/viewmodels/chat_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/presence_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

class ChatViewModel extends ChangeNotifier
    with
        StreamManagementMixin,
        ErrorHandlingMixin,
        StateNotifierMixin,
        AsyncOperationMixin {
  final MessagingService _messagingService;
  final PresenceService? _presenceService;
  ContentFilterService? _contentFilter;
  UnifiedFriendsService? _friendsService;
  StreamSubscription? _friendsSubscription;

  final String conversationId;

  // State
  bool _isDisposed = false;
  bool _isFriendWithOther = true;
  Conversation? _conversation;
  List<Message> _messages = [];
  bool _isSending = false;
  String? _sendError;
  List<String> _typingUserIds = [];
  Message? _replyToMessage;

  // Typing users mapped from IDs to display names
  final Map<String, String> _userDisplayNames = {};

  List<String> get typingUserNames =>
      _typingUserIds.map((id) => _userDisplayNames[id] ?? '?').toList();

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<List<String>>? _typingSubscription;
  Timer? _typingDebounceTimer;

  ChatViewModel({
    required MessagingService messagingService,
    required this.conversationId,
    Conversation? initialConversation,
    PresenceService? presenceService,
  }) : _messagingService = messagingService,
       _presenceService = presenceService,
       _conversation = initialConversation {
    try {
      _contentFilter = ServiceLocator.get<ContentFilterService>();
    } catch (_) {
      // Filter not available — proceed without it
    }
    try {
      _friendsService = ServiceLocator.get<UnifiedFriendsService>();
    } catch (_) {
      // Friends service not available — allow sending by default
    }
    // Start in loading state until messages arrive from stream
    setLoading(true);
    _initializeChat();
  }

  // Getters
  Conversation? get conversation => _conversation;
  List<Message> get messages => _messages;
  // isLoading and error provided by StateNotifierMixin
  bool get isSending => _isSending;
  String? get sendError => _sendError;
  List<String> get currentTypingUsers => typingUserNames;
  bool get hasTypingUsers => typingUserNames.isNotEmpty;
  bool get hasMessages => _messages.isNotEmpty;
  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;
  Message? get replyToMessage => _replyToMessage;
  bool get hasReplyTarget => _replyToMessage != null;

  String get conversationTitle {
    if (_conversation == null) return AppLocale.current.commonLoading;
    if (currentUserId == null) {
      return _conversation!.title ?? AppLocale.current.labelChat;
    }
    return _conversation!.getDisplayTitle(currentUserId!);
  }

  String get conversationSubtitle {
    if (_conversation == null) return '';

    // For group conversations, show participant count
    if (_conversation!.isGroup) {
      final count = _conversation!.participantIds.length;
      return AppLocale.current.labelParticipantCount(count);
    }

    // For direct conversations, show last seen or online status
    final otherParticipantId = _conversation!.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherParticipantId.isEmpty) return '';

    // Could return online status or last seen time here
    // For now, just return empty string since we don't track online status
    return '';
  }

  bool get canSendMessages =>
      _conversation != null && !_isDisposed && _isFriendWithOther;

  /// True when messaging is blocked because users are no longer friends.
  bool get isFriendshipBlocked =>
      !_isFriendWithOther && !(_conversation?.isGroup ?? true);

  void _initializeChat() {
    if (_isDisposed) return;

    AppLogger.info(
      '🔍 [ChatViewModel] Initializing chat for conversationId: $conversationId',
    );
    _loadConversation();
    _loadMessages();
    _subscribeToTypingIndicators();
  }

  Future<void> _loadConversation() async {
    if (_isDisposed) return;

    if (_conversation == null) {
      try {
        _conversation = await _messagingService.getConversation(conversationId);
        if (_isDisposed) return;
        _safeNotifyListeners();
      } catch (e) {
        if (_isDisposed) return;
        AppLogger.error('Failed to load conversation', e);
        _setError(AppLocale.current.errorCouldNotLoadConversation);
      }
    }

    // Always check friendship status and subscribe to changes,
    // whether conversation was loaded or passed via initialConversation.
    // Without this, passing initialConversation skips the friendship
    // gate entirely and _isFriendWithOther stays true forever (BUG-040).
    if (_conversation != null) {
      _checkFriendshipStatus();
      _subscribeFriendshipChanges();
      _safeNotifyListeners();
    }
  }

  void _checkFriendshipStatus() {
    if (_conversation == null ||
        _conversation!.isGroup ||
        _friendsService == null) {
      _isFriendWithOther = true;
      return;
    }
    try {
      final myId = currentUserId;
      if (myId == null) {
        _isFriendWithOther = true;
        return;
      }
      final otherId = _conversation!.getOtherParticipantId(myId);
      if (otherId == null) {
        _isFriendWithOther = true;
        return;
      }
      _isFriendWithOther = _friendsService!.management.isFriend(otherId);
    } catch (_) {
      _isFriendWithOther = true;
    }
  }

  void _subscribeFriendshipChanges() {
    if (_friendsService == null || _conversation == null) return;
    if (_conversation!.isGroup) return;
    if (_friendsSubscription != null) return; // Already subscribed

    _friendsSubscription = _friendsService!.stateStream.listen((_) {
      final wasFriend = _isFriendWithOther;
      _checkFriendshipStatus();
      if (wasFriend != _isFriendWithOther) {
        _safeNotifyListeners();
      }
    });
  }

  void _loadMessages() {
    if (_isDisposed) return;

    try {
      AppLogger.info(
        '🔍 [ChatViewModel] Starting message stream for conversationId: $conversationId',
      );
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
      _setError(AppLocale.current.errorCouldNotLoadMessages);
    }
  }

  void _onMessagesUpdate(List<Message> messages) {
    if (_isDisposed) return;

    AppLogger.info('📬 [ChatViewModel] Message stream update received');
    AppLogger.debug('📬 [ChatViewModel] ConversationId: $conversationId');
    AppLogger.debug(
      '📬 [ChatViewModel] Number of messages: ${messages.length}',
    );
    if (messages.isNotEmpty) {
      AppLogger.debug(
        '📬 [ChatViewModel] First message: ${messages.first.content.substring(0, messages.first.content.length > 50 ? 50 : messages.first.content.length)}...',
      );
      AppLogger.debug(
        '📬 [ChatViewModel] Last message: ${messages.last.content.substring(0, messages.last.content.length > 50 ? 50 : messages.last.content.length)}...',
      );
    }

    _messages = messages;
    setSuccess();
    _safeNotifyListeners();

    // Auto-mark as read when messages arrive
    if (messages.isNotEmpty) {
      _markAsRead();
    }
  }

  void _onMessagesError(dynamic error) {
    if (_isDisposed) return;

    AppLogger.error('Messages stream error', error);
    _setError(AppLocale.current.errorCouldNotLoadMessages);
  }

  void _setError(String errorMessage) {
    setError(errorMessage);
  }

  // Message operations
  Future<bool> sendTextMessage(String content) async {
    if (_isDisposed) return false;
    if (!canSendMessages) return false;

    if (content.trim().isEmpty) {
      _sendError = AppLocale.current.errorMessageCannotBeEmpty;
      _safeNotifyListeners();
      return false;
    }

    // BUT-1393: profanity gate before send. DMs are a primary harassment
    // surface (firestore.rules flags them as a spam vector) and rules cannot
    // filter content, so this client-side gate is the only pre-publish defense.
    final filter = _contentFilter;
    if (filter != null) {
      final result = filter.ensureClean(content.trim(), fieldName: 'message');
      if (!result.isClean) {
        _sendError = result.reason;
        _safeNotifyListeners();
        return false;
      }
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

      await ServiceLocator.tryGet<AnalyticsService>()?.social.logMessageSent(
        conversationId: conversationId,
        messageType: 'text',
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
      _sendError = AppLocale.current.errorCouldNotSend('meddelande');
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
    if (!canSendMessages) return false;

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

      await ServiceLocator.tryGet<AnalyticsService>()?.social.logMessageSent(
        conversationId: conversationId,
        messageType: 'recipe_share',
      );

      _isSending = false;
      _safeNotifyListeners();

      AppLogger.debug('Recipe share sent successfully');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send recipe share', e);
      _sendError = AppLocale.current.errorCouldNotShare('recept');
      _isSending = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Vote on (or toggle off) a poll option. Resolves the poll's
  /// `allowMultipleChoices` flag from the message metadata before delegating
  /// to the service, so the caller (a poll widget) only needs the option id.
  Future<void> votePoll(String messageId, String optionId) async {
    if (_isDisposed) return;

    Message? target;
    for (final m in _messages) {
      if (m.id == messageId) {
        target = m;
        break;
      }
    }
    if (target == null) {
      AppLogger.warning('votePoll: message $messageId not in cache');
      return;
    }
    final pollData = target.metadata?['poll'] as Map<String, dynamic>?;
    if (pollData == null) {
      AppLogger.warning('votePoll: no poll metadata on message $messageId');
      return;
    }
    final allowMultiple = pollData['allowMultipleChoices'] == true;

    try {
      await _messagingService.votePoll(
        messageId: messageId,
        optionId: optionId,
        allowMultiple: allowMultiple,
      );
    } catch (e) {
      AppLogger.error('Failed to vote on poll', e);
    }
  }

  /// Close a poll (creator-only; gating enforced by the poll widget).
  Future<void> closePoll(String messageId) async {
    if (_isDisposed) return;

    try {
      await _messagingService.closePoll(messageId: messageId);
    } catch (e) {
      AppLogger.error('Failed to close poll', e);
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

  int _typingSubscribeRetries = 0;
  static const _maxTypingSubscribeRetries = 10;

  void _subscribeToTypingIndicators() {
    if (_isDisposed || _presenceService == null) return;

    // Wait for conversation to load first
    if (_conversation == null) {
      _typingSubscribeRetries++;
      if (_typingSubscribeRetries > _maxTypingSubscribeRetries) {
        AppLogger.warning(
          'Gave up waiting for conversation to subscribe to typing indicators',
        );
        return;
      }
      cancelNamedTimer('typing_retry');
      createTimer(
        const Duration(milliseconds: 500),
        () => _subscribeToTypingIndicators(),
        name: 'typing_retry',
      );
      return;
    }

    try {
      // Get participant IDs excluding current user
      final participantIds = _conversation!.participantIds
          .where((id) => id != currentUserId)
          .toList();

      if (participantIds.isEmpty) return;

      // Subscribe to typing indicators from PresenceService
      _typingSubscription = _presenceService
          .getTypingUsersStream(conversationId, participantIds)
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
        _userDisplayNames[userId] = '?';
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
    if (!canSendMessages) return false;

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
      _sendError = AppLocale.current.errorCouldNotSend('svar');
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
    if (message.isFromCurrentUser(currentUserId.orEmpty())) {
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

  @override
  void clearError() {
    if (_isDisposed) return;

    super.clearError();
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
    _friendsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingDebounceTimer?.cancel();
    clearTyping();
    cancelAllOperations();
    disposeStreamResources();
    super.dispose();
  }
}
