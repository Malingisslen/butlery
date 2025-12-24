/// Real-time messaging service for direct and group conversations.
/// Provides message sending/editing/deletion, typing indicators, read status tracking,
/// conversation management (pin/archive/mute), and notification integration.
/// Delegates to specialized operation classes following the facade pattern.

import 'dart:async';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/services/messaging/message_sending_operations.dart';
import 'package:butlery/services/messaging/conversation_action_operations.dart';
import 'package:butlery/services/messaging/message_management_operations.dart';

/// Messaging service implementing the facade pattern for real-time communication.
class MessagingService extends BaseService with StreamManagementMixin {
  final MessagingRepository _messagingRepository;
  final auth_repo.AuthRepository _authRepository;
  late final MessageSendingOperations _sendingOps;
  late final ConversationActionOperations _actionOps;
  late final MessageManagementOperations _managementOps;

  @override
  String get serviceName => 'MessagingService';

  // Typing indicators tracking
  final Map<String, Timer> _typingTimers = {};
  final Map<String, Set<String>> _typingUsers = {};

  MessagingService({
    required MessagingRepository messagingRepository,
    required auth_repo.AuthRepository authRepository,
  })  : _messagingRepository = messagingRepository,
        _authRepository = authRepository {
    _sendingOps = MessageSendingOperations(
      messagingRepository: _messagingRepository,
      authRepository: _authRepository,
    );
    _actionOps = ConversationActionOperations(
      messagingRepository: _messagingRepository,
      authRepository: _authRepository,
    );
    _managementOps = MessageManagementOperations(
      messagingRepository: _messagingRepository,
      authRepository: _authRepository,
    );
  }

  /// Get all conversations for current user
  Stream<List<Conversation>> getMyConversations() {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) {
      AppLogger.error('User must be authenticated to get conversations');
      return const Stream.empty();
    }

    return _messagingRepository.getUserConversations(currentUserId);
  }

  /// Start or get existing direct conversation with another user
  /// This method now uses a deterministic conversation ID approach instead of querying.
  /// The `createDirectConversation` method already implements "get or create" pattern,
  /// so we skip the potentially problematic query-based lookup that could return old UUID conversations.
  Future<String> startDirectConversation({
    required String otherUserId,
    required String otherUserDisplayName,
    String? otherUserAvatarUrl,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      AppLogger.info('🔍 [MessagingService] startDirectConversation called');
      AppLogger.debug(
          '🔍 [MessagingService] Current user: ${currentUser.uid} (${currentUser.displayName})');
      AppLogger.debug(
          '🔍 [MessagingService] Other user: $otherUserId ($otherUserDisplayName)');

      // FIXED: Skip findDirectConversation query lookup - go directly to createDirectConversation
      // which already handles "get or create" with deterministic IDs
      AppLogger.debug(
          '🔍 [MessagingService] Getting/creating conversation with deterministic ID...');
      final conversationId =
          await _messagingRepository.createDirectConversation(
        user1Id: currentUser.uid,
        user1DisplayName: currentUser.displayName ?? 'Okänd användare',
        user1AvatarUrl: currentUser.photoURL,
        user2Id: otherUserId,
        user2DisplayName: otherUserDisplayName,
        user2AvatarUrl: otherUserAvatarUrl,
      );

      AppLogger.success(
          '✅ [MessagingService] Conversation ready: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error(
          '❌ [MessagingService] Failed to start direct conversation with $otherUserId',
          e);
      rethrow;
    }
  }

  /// Create a new group conversation
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      // Add current user to participants if not already included
      final allParticipantIds = [...participantIds];
      if (!allParticipantIds.contains(currentUser.uid)) {
        allParticipantIds.add(currentUser.uid);
        participantDisplayNames[currentUser.uid] =
            currentUser.displayName ?? 'Okänd användare';
        participantAvatarUrls[currentUser.uid] = currentUser.photoURL;
      }

      final conversationId = await _messagingRepository.createGroupConversation(
        participantIds: allParticipantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
        creatorId: currentUser.uid,
      );

      AppLogger.success('✅ Group conversation created: $conversationId');
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      rethrow;
    }
  }

  /// Get conversation details
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      return await _messagingRepository.getConversation(conversationId);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  /// Get messages for a conversation
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) {
    return _messagingRepository.getConversationMessages(
      conversationId: conversationId,
      limit: limit,
    );
  }

  /// Get messages for a conversation with pagination support
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    int limit = 50,
    DateTime? startAfter,
  }) async {
    try {
      return await _messagingRepository.getConversationMessagesPage(
        conversationId: conversationId,
        limit: limit,
        startAfter: startAfter,
      );
    } catch (e) {
      AppLogger.error(
          'Failed to get conversation messages page for $conversationId', e);
      return [];
    }
  }

  /// Send a text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String content,
    String? replyToMessageId,
  }) async {
    return _sendingOps.sendTextMessage(
      conversationId: conversationId,
      content: content,
      replyToMessageId: replyToMessageId,
      clearTypingIndicator: _clearTypingIndicator,
    );
  }

  /// Send an image message
  Future<void> sendImageMessage({
    required String conversationId,
    required String imageUrl,
    String? caption,
    String? replyToMessageId,
  }) async {
    return _sendingOps.sendImageMessage(
      conversationId: conversationId,
      imageUrl: imageUrl,
      caption: caption,
      replyToMessageId: replyToMessageId,
      clearTypingIndicator: _clearTypingIndicator,
    );
  }

  /// Send a recipe share message
  Future<void> sendRecipeShare({
    required String conversationId,
    required String recipeId,
    required String recipeTitle,
    String? message,
  }) async {
    return _sendingOps.sendRecipeShare(
      conversationId: conversationId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      message: message,
    );
  }

  /// Send a menu share message
  Future<void> sendMenuShare({
    required String conversationId,
    required String menuId,
    required String menuTitle,
    String? message,
  }) async {
    return _sendingOps.sendMenuShare(
      conversationId: conversationId,
      menuId: menuId,
      menuTitle: menuTitle,
      message: message,
    );
  }

  /// Send a shopping list share message
  Future<void> sendShoppingListShare({
    required String conversationId,
    required String listId,
    required String listTitle,
    String? message,
  }) async {
    return _sendingOps.sendShoppingListShare(
      conversationId: conversationId,
      listId: listId,
      listTitle: listTitle,
      message: message,
    );
  }

  /// Mark conversation as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await _messagingRepository.markConversationAsRead(
        conversationId: conversationId,
        userId: currentUserId,
      );

      AppLogger.debug('Conversation marked as read: $conversationId');
    } catch (e) {
      AppLogger.error(
          'Failed to mark conversation as read: $conversationId', e);
    }
  }

  /// Edit message content
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async =>
      _managementOps.editMessage(messageId: messageId, newContent: newContent);

  /// Delete message
  Future<void> deleteMessage(String messageId) async =>
      _managementOps.deleteMessage(messageId);

  /// Delete all messages in a conversation (chat clear functionality)
  Future<void> deleteAllMessages(String conversationId) async =>
      _managementOps.deleteAllMessages(conversationId);

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String conversationId) async =>
      _managementOps.deleteConversation(conversationId, getConversation);

  /// Set typing indicator for current user in conversation
  Future<void> setTypingIndicator(String conversationId) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) return;

      // Add user to typing set
      _typingUsers.putIfAbsent(conversationId, () => <String>{});
      _typingUsers[conversationId]!.add(currentUserId);

      // Cancel existing timer
      _typingTimers[conversationId]?.cancel();

      // Set timer to clear typing indicator after 3 seconds of inactivity
      _typingTimers[conversationId] = Timer(const Duration(seconds: 3), () {
        _clearTypingIndicator(conversationId, currentUserId);
      });

      AppLogger.debug(
          'Typing indicator set for $currentUserId in $conversationId');
    } catch (e) {
      AppLogger.error('Failed to set typing indicator', e);
    }
  }

  /// Clear typing indicator for current user
  Future<void> clearTypingIndicator(String conversationId) async {
    final currentUserId = _authRepository.currentUserId;
    if (currentUserId == null) return;

    await _clearTypingIndicator(conversationId, currentUserId);
  }

  Future<void> _clearTypingIndicator(
      String conversationId, String userId) async {
    _typingUsers[conversationId]?.remove(userId);
    if (_typingUsers[conversationId]?.isEmpty == true) {
      _typingUsers.remove(conversationId);
    }
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);

    AppLogger.debug('Typing indicator cleared for $userId in $conversationId');
  }

  /// Get users currently typing in conversation
  List<String> getTypingUsers(String conversationId) {
    final currentUserId = _authRepository.currentUserId;
    return _typingUsers[conversationId]
            ?.where((userId) => userId != currentUserId)
            .toList() ??
        [];
  }

  /// Pin a conversation to the top of the list
  Future<void> pinConversation(String conversationId) async =>
      _actionOps.pinConversation(conversationId, getConversation);

  /// Unpin a conversation
  Future<void> unpinConversation(String conversationId) async =>
      _actionOps.unpinConversation(conversationId);

  /// Archive a conversation (hide from main list)
  Future<void> archiveConversation(String conversationId) async =>
      _actionOps.archiveConversation(conversationId);

  /// Unarchive a conversation
  Future<void> unarchiveConversation(String conversationId) async =>
      _actionOps.unarchiveConversation(conversationId);

  /// Mute notifications for a conversation
  Future<void> muteConversation(String conversationId) async =>
      _actionOps.muteConversation(conversationId);

  /// Unmute notifications for a conversation
  Future<void> unmuteConversation(String conversationId) async =>
      _actionOps.unmuteConversation(conversationId);

  /// Mark all conversations as read for current user
  Future<void> markAllConversationsAsRead() async => _actionOps
      .markAllConversationsAsRead(getMyConversations, markConversationAsRead);

  /// Search messages in conversation
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) return [];

      return await _messagingRepository.searchMessages(
        conversationId: conversationId,
        query: query.trim(),
        limit: limit,
      );
    } catch (e) {
      AppLogger.error('Failed to search messages in $conversationId', e);
      return [];
    }
  }

  /// Get unread message count for current user
  Future<int> getUnreadMessageCount() async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) return 0;

      return await _messagingRepository.getUnreadMessageCount(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get unread message count', e);
      return 0;
    }
  }

  /// Get unread conversations count for current user
  Future<int> getUnreadConversationsCount() async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) return 0;

      return await _messagingRepository
          .getUnreadConversationsCount(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get unread conversations count', e);
      return 0;
    }
  }

  /// Add participants to group conversation
  Future<void> addParticipantsToGroup({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async =>
      _managementOps.addParticipantsToGroup(
        conversationId: conversationId,
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
      );

  /// Remove participant from group conversation
  Future<void> removeParticipantFromGroup({
    required String conversationId,
    required String participantId,
  }) async =>
      _managementOps.removeParticipantFromGroup(
        conversationId: conversationId,
        participantId: participantId,
      );

  /// Update group conversation title
  Future<void> updateGroupTitle({
    required String conversationId,
    required String newTitle,
  }) async =>
      _managementOps.updateGroupTitle(
        conversationId: conversationId,
        newTitle: newTitle,
      );

  @override
  Future<void> dispose() async {
    // Cancel all typing timers
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _typingUsers.clear();

    await super.dispose();
  }
}
