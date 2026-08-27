/// Real-time messaging service for direct and group conversations.
/// Provides message sending/editing/deletion, typing indicators, read status tracking,
/// conversation management (pin/archive/mute), and notification integration.
/// Delegates to specialized operation classes following the facade pattern.

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart'
    show GroupMenuParticipant, GroupWeeklyMenuPlan;
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/menu/group_weekly_menu_plan_service.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/services/messaging/message_sending_operations.dart';
import 'package:butlery/services/messaging/conversation_action_operations.dart';
import 'package:butlery/services/messaging/message_management_operations.dart';
import 'package:butlery/services/messaging/message_reactions_service.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:uuid/uuid.dart';

/// Messaging service implementing the facade pattern for real-time communication.
///
/// ## Usage
/// ```dart
/// final service = ServiceLocator.get<MessagingService>();
///
/// // Send a message
/// await service.sendMessage(conversationId, 'Hello!');
///
/// // Watch for new messages
/// service.watchMessages(conversationId).listen((messages) => ...);
/// ```
class MessagingService extends BaseService with StreamManagementMixin {
  final MessagingRepository _messagingRepository;
  final ChatGroupRepository _chatGroupRepository;
  final auth_repo.AuthRepository _authRepository;
  late final MessageSendingOperations _sendingOps;
  late final ConversationActionOperations _actionOps;
  late final MessageManagementOperations _managementOps;
  final MessageReactionsService _reactionsService;

  @override
  String get serviceName => 'MessagingService';

  // Typing indicators tracking
  final Map<String, Timer> _typingTimers = {};
  final Map<String, Set<String>> _typingUsers = {};

  MessagingService({
    required MessagingRepository messagingRepository,
    required ChatGroupRepository chatGroupRepository,
    required auth_repo.AuthRepository authRepository,
    required MessageReactionsService reactionsService,
  }) : _messagingRepository = messagingRepository,
       _chatGroupRepository = chatGroupRepository,
       _authRepository = authRepository,
       _reactionsService = reactionsService {
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
        '🔍 [MessagingService] Current user: ${currentUser.uid} (${currentUser.displayName})',
      );
      AppLogger.debug(
        '🔍 [MessagingService] Other user: $otherUserId ($otherUserDisplayName)',
      );

      // FIXED: Skip findDirectConversation query lookup - go directly to createDirectConversation
      // which already handles "get or create" with deterministic IDs
      AppLogger.debug(
        '🔍 [MessagingService] Getting/creating conversation with deterministic ID...',
      );
      final conversationId = await _messagingRepository
          .createDirectConversation(
            user1Id: currentUser.uid,
            user1DisplayName:
                currentUser.displayName ?? AppLocale.current.displayUnknownUser,
            user1AvatarUrl: currentUser.photoURL,
            user2Id: otherUserId,
            user2DisplayName: otherUserDisplayName,
            user2AvatarUrl: otherUserAvatarUrl,
          );

      AppLogger.success(
        '✅ [MessagingService] Conversation ready: ${conversationId.maskedConversationId}',
      );
      return conversationId;
    } catch (e) {
      AppLogger.error(
        '❌ [MessagingService] Failed to start direct conversation with $otherUserId',
        e,
      );
      rethrow;
    }
  }

  /// Create a new group conversation.
  ///
  /// BUT-1838: delegates to `ChatGroupRepository.createGroup` — the
  /// `createChatGroup` callable — which is what lets the minor-membership
  /// gate run BEFORE anyone is seated, not once after the conversation
  /// already exists. [participantDisplayNames] and [participantAvatarUrls]
  /// are accepted for call-site compatibility but no longer sent anywhere:
  /// the callable resolves names/avatars server-side from `public_profiles`,
  /// so the person creating a group can no longer choose what everyone
  /// else's name looks like in it. The callable also adds the caller
  /// automatically, so [participantIds] is filtered down to the other
  /// members before the call.
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

      final memberIds = participantIds
          .where((id) => id != currentUser.uid)
          .toList();

      final conversationId = await _chatGroupRepository.createGroup(
        name: title,
        memberIds: memberIds,
      );

      AppLogger.success(
        '✅ Group conversation created: ${conversationId.maskedConversationId}',
      );
      return conversationId;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      rethrow;
    }
  }

  /// The ONE chat backing a social group, created on first use and reused
  /// afterwards (BUT-1856). Returns its conversation id.
  ///
  /// Unlike [createGroupConversation] this takes no member list: the roster is
  /// resolved server-side from the social group itself, which also fixes a
  /// long-standing gap — the client built it from `friendUserIds` profiles it
  /// managed to load, so a profile that failed to read quietly shrank the chat.
  ///
  /// The callable refuses in several distinguishable ways — a group with nobody
  /// else in it, a minor who may not be seated, the rate limiter — and
  /// `ChatGroupErrorMapper` turns each into its own Swedish sentence by reading
  /// the raw `FirebaseFunctionsException`.
  Future<String> ensureCategoryChat({
    required String ownerId,
    required String categoryId,
  }) async {
    return _chatGroupRepository.ensureCategoryChat(
      ownerId: ownerId,
      categoryId: categoryId,
    );
  }

  /// Get conversation details
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      return await _messagingRepository.getConversation(conversationId);
    } catch (e) {
      AppLogger.error(
        'Failed to get conversation ${conversationId.maskedConversationId}',
        e,
      );
      return null;
    }
  }

  /// Get messages for a conversation
  ///
  /// BUT-544: messages authored by users the viewer has blocked are
  /// retroactively filtered out before reaching the UI.
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    DateTime? historyStart,
    int limit = 50,
  }) {
    return _messagingRepository
        .getConversationMessages(
          conversationId: conversationId,
          historyStart: historyStart,
          limit: limit,
        )
        .asyncMap(_filterBlocked);
  }

  /// Get messages for a conversation with pagination support
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    DateTime? historyStart,
    int limit = 50,
    DateTime? startAfter,
  }) async {
    try {
      final messages = await _messagingRepository.getConversationMessagesPage(
        conversationId: conversationId,
        historyStart: historyStart,
        limit: limit,
        startAfter: startAfter,
      );
      return _filterBlocked(messages);
    } catch (e) {
      AppLogger.error(
        'Failed to get conversation messages page for '
        '${conversationId.maskedConversationId}',
        e,
      );
      return [];
    }
  }

  /// Trims a message list down to what this viewer may see.
  ///
  /// TWO jobs, deliberately in this order.
  ///
  /// BUT-1904 first: someone else's duplicate-blocked row is dropped. This runs
  /// BEFORE and OUTSIDE everything below, and that placement is the point —
  /// the block filter's FAILURE exits all return a less filtered list (an
  /// unregistered filter, a failed block-list fetch, a failed ballot strip),
  /// and this must not inherit that contract. It cannot: it is a pure test over
  /// data already in hand, with nothing to fetch and nothing to throw. Do not
  /// move it below the early returns.
  ///
  /// BUT-544 second: messages authored by users the viewer has blocked.
  /// `tryGet` keeps test contexts that don't register the filter unaffected.
  /// Fail-open: a transient blocked-list fetch error must not blank out
  /// the conversation; the next snapshot will retry the lookup.
  Future<List<Message>> _filterBlocked(List<Message> incoming) async {
    // A local rather than a reassigned parameter: every exit below returns
    // `messages` or a list derived from it, so the sender-only rule holds on
    // the failure exits too — which is the whole point of doing this first.
    final messages = _withoutOthersBlockedRows(incoming);
    if (messages.isEmpty) return messages;
    final filter = ServiceLocator.tryGet<BlockedUserFilter>();
    if (filter == null) return messages;

    final Set<String> blocked;
    final List<Message> visible;
    try {
      blocked = await filter.currentBlockedIds();
      visible = BlockedUserFilter.filter<Message>(
        messages,
        authorOf: (m) => m.senderId,
        blockedIds: blocked,
      );
    } catch (e) {
      // Fail-open, for DISPLAY only. `closePoll` deliberately does NOT
      // inherit this: see its own guard.
      AppLogger.warning(
        'MessagingService: block filter failed; serving unfiltered: $e',
      );
      return messages;
    }

    // BUT-1909. Hiding what a blocked person SAYS is not the same as removing
    // what their vote DOES: a poll winner is written into the household's week,
    // so a blocked ballot steering it survives the message filter entirely.
    // Applied here and in `closePoll` from the SAME helper, because filtering
    // the count on screen but not the winner (or the reverse) makes the number
    // and the outcome contradict each other.
    //
    // BUT-1926: its own catch, because falling back to `messages` here would
    // un-hide every blocked AUTHOR the step above already removed — the ballot
    // strip is a refinement of that list, so its failure costs the refinement,
    // never the filtering that succeeded.
    try {
      return _withoutBlockedBallots(visible, blocked);
    } catch (e) {
      AppLogger.warning(
        'MessagingService: ballot strip failed; '
        'serving author-filtered messages with unfiltered tallies: $e',
      );
      return visible;
    }
  }

  /// Drop duplicate-blocked rows that belong to somebody else (BUT-1904).
  ///
  /// The guard empties a blocked message rather than deleting it, so the row
  /// reaches every participant's client. Only its own sender is shown it — the
  /// row says "you already sent this", which is true for exactly one person and
  /// is nobody else's business.
  ///
  /// This hides a row; it does not protect content — and do not read it as
  /// resting on the row being empty. No `firestore.rules` limb bounds what
  /// `type` is written TO on a create or a sender update, so a client can stamp
  /// its own full message and it arrives here with its text (B16/B17 in
  /// `cook-snaps-and-message-mod-rules.test.ts`, both ALLOW). Hiding it is what
  /// stops "Du har redan skickat det här" being drawn over somebody else's
  /// sentence — a claim that is false for every viewer but its author.
  ///
  /// It was NOT gone before the document became readable. An earlier version
  /// of this comment claimed it was. `guardDuplicateMessage` is
  /// `onDocumentCreated`: the client commits the full text first and the
  /// trigger runs after, so a participant with the thread open sees the
  /// duplicate until the mark propagates — no measured duration, and a cold
  /// start makes it longer. Harmless, since it is by construction the same text
  /// they received moments earlier, but not the guarantee that was claimed.
  ///
  /// A signed-out reader owns nothing, so every blocked row goes — the safe
  /// direction, and unreachable in practice since the conversation itself needs
  /// a signed-in participant.
  List<Message> _withoutOthersBlockedRows(List<Message> messages) {
    final currentUserId = _authRepository.currentUserId;
    return messages
        .where(
          (m) =>
              m.type != MessageType.duplicateBlocked ||
              (currentUserId != null && m.senderId == currentUserId),
        )
        .toList();
  }

  /// Remove blocked voters from every poll option's `voterIds`, in memory.
  ///
  /// Viewer-scoped by design: the tally each person sees is filtered by THEIR
  /// own block list, exactly as the message list already is. Two members can
  /// therefore see different counts on one poll — inherent to per-viewer
  /// blocking, and the alternative (the screen and the written winner
  /// disagreeing for the person closing it) is the BUT-1908 harm.
  List<Message> _withoutBlockedBallots(
    List<Message> messages,
    Set<String> blockedIds,
  ) {
    if (blockedIds.isEmpty) return messages;
    return messages.map((m) => _stripBlockedBallots(m, blockedIds)).toList();
  }

  /// The single-message half of [_withoutBlockedBallots]. Fails OPEN toward the
  /// stored message on any unexpected shape, matching the hydration merge it
  /// mirrors: an unreadable poll is returned untouched, never blanked.
  Message _stripBlockedBallots(Message message, Set<String> blockedIds) {
    final metadata = message.metadata;
    if (metadata == null) return message;
    final poll = metadata['poll'];
    if (poll is! Map) return message;
    final options = poll['options'];
    if (options is! List) return message;

    var changed = false;
    final rebuiltOptions = options.map((option) {
      if (option is! Map) return option;
      final voterIds = option['voterIds'];
      if (voterIds is! List) return option;
      final kept = voterIds
          .whereType<String>()
          .where((uid) => !blockedIds.contains(uid))
          .toList(growable: false);
      if (kept.length == voterIds.length) return option;
      changed = true;
      return Map<String, dynamic>.from(option)..['voterIds'] = kept;
    }).toList();

    if (!changed) return message;
    final rebuiltPoll = Map<String, dynamic>.from(poll)
      ..['options'] = rebuiltOptions;
    return message.copyWith(
      metadata: Map<String, dynamic>.from(metadata)..['poll'] = rebuiltPoll,
    );
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

      AppLogger.debug(
        'Conversation marked as read: ${conversationId.maskedConversationId}',
      );
    } catch (e) {
      AppLogger.error(
        'Failed to mark conversation as read: '
        '${conversationId.maskedConversationId}',
        e,
      );
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
      _managementOps.deleteAllMessages(
        conversationId,
        historyStart: await _historyStartFor(conversationId),
      );

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
        'Typing indicator set for $currentUserId in ${conversationId.maskedConversationId}',
      );
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
    String conversationId,
    String userId,
  ) async {
    _typingUsers[conversationId]?.remove(userId);
    if (_typingUsers[conversationId]?.isEmpty == true) {
      _typingUsers.remove(conversationId);
    }
    _typingTimers[conversationId]?.cancel();
    _typingTimers.remove(conversationId);

    AppLogger.debug(
      'Typing indicator cleared for ${userId.maskedUserId} in ${conversationId.maskedConversationId}',
    );
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

  /// The caller's history cut-off for a conversation, or null when there is
  /// none (a direct chat, or a founding member).
  ///
  /// `firestore.rules` refuses messages sent before a member joined a GROUP,
  /// and a query returning one refused document fails entirely — so every
  /// message query in this service must carry this, and the ones that read the
  /// whole thread (search, clear-chat, delete-conversation) must carry it most,
  /// because their failure mode is a silent empty result.
  Future<DateTime?> _historyStartFor(String conversationId) async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return null;
    final conversation = await getConversation(conversationId);
    return conversation?.historyQueryStartFor(userId);
  }

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
        // Resolved here rather than asked of the caller: this is the layer
        // that can, and a caller who forgets it gets an empty result rather
        // than an error (BUT-1838).
        historyStart: await _historyStartFor(conversationId),
        limit: limit,
      );
    } catch (e) {
      AppLogger.error(
        'Failed to search messages in ${conversationId.maskedConversationId}',
        e,
      );
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

      return await _messagingRepository.getUnreadConversationsCount(
        currentUserId,
      );
    } catch (e) {
      AppLogger.error('Failed to get unread conversations count', e);
      return 0;
    }
  }

  // BUT-1838: addParticipantsToGroup/removeParticipantFromGroup are removed
  // — group membership changes go through ChatGroupRepository.addMembers/
  // removeMember directly, called from GroupDetailViewModel and
  // ConversationsViewModel. Neither of those old client write paths ever
  // succeeded against firestore.rules.

  /// Update group conversation title
  Future<void> updateGroupTitle({
    required String conversationId,
    required String newTitle,
  }) async => _managementOps.updateGroupTitle(
    conversationId: conversationId,
    newTitle: newTitle,
  );

  /// Toggle an emoji reaction on a message
  Future<void> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await _reactionsService.toggleReaction(
        messageId: messageId,
        conversationId: conversationId,
        userId: currentUserId,
        emoji: emoji,
      );
    } catch (e) {
      AppLogger.error('Failed to toggle reaction on message $messageId', e);
      rethrow;
    }
  }

  /// Send a poll message to a conversation
  Future<void> sendPollMessage({
    required String conversationId,
    required Map<String, dynamic> pollData,
  }) async {
    try {
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw AuthenticationException('User must be authenticated');
      }

      final message = Message(
        id: const Uuid().v4(),
        conversationId: conversationId,
        senderId: currentUser.uid,
        senderDisplayName:
            currentUser.displayName ?? AppLocale.current.displayUnknownUser,
        senderAvatarUrl: currentUser.photoURL,
        content:
            pollData['question'] as String? ?? AppLocale.current.messagingPoll,
        type: MessageType.poll,
        status: MessageStatus.sending,
        sentAt: clock.now(),
        metadata: {'poll': pollData},
      );

      await _messagingRepository.sendMessage(message);
      AppLogger.success(
        'Poll message sent in conversation ${conversationId.maskedConversationId}',
      );
    } catch (e) {
      AppLogger.error('Failed to send poll message', e);
      rethrow;
    }
  }

  /// Vote on a poll option in a message
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required bool allowMultiple,
  }) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      await _messagingRepository.votePoll(
        messageId: messageId,
        optionId: optionId,
        voterId: currentUserId,
        allowMultiple: allowMultiple,
      );

      AppLogger.debug('Poll vote recorded for message $messageId');
    } catch (e) {
      AppLogger.error('Failed to vote on poll $messageId', e);
      rethrow;
    }
  }

  /// Close a poll (creator only).
  ///
  /// When the closed poll has a winning option with a `recipeId`, auto-
  /// resolution appends that recipe to a current-week plan (today-anchored
  /// next empty slot) — which plan depends on the branch below. Winner = most
  /// votes; ties broken by chronological order (first option in the options
  /// list wins).
  ///
  /// Double-fire across concurrent callers is guarded by a pre-read of the
  /// poll message — if already closed, the plan write is skipped on this call.
  /// That pre-read is the ONLY such guard and it is not atomic: the
  /// repository's re-read checks `creatorId`, never `isClosed`, so a retry
  /// after a half-failed close can plant the same recipe in a second slot
  /// (BUT-1925).
  Future<void> closePoll({required String messageId}) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      // Pre-read the message to guard against double-resolution. If the poll
      // is already closed, another caller raced us — skip both the repo
      // close and the plan write.
      final existing = await _messagingRepository.getMessage(messageId);
      final existingPoll = _extractPoll(existing);
      if (existingPoll == null || existing == null) {
        // Message/poll gone — nothing to do.
        return;
      }
      if (existingPoll.isClosed) {
        AppLogger.debug('Poll $messageId already closed — skipping resolve');
        return;
      }

      // BUT-1908. Closing is a ONE-WAY door — nothing in the repository resets
      // `isClosed` — and a creator close writes a recipe into the household's
      // week. So it must never run on a tally that was not actually read.
      // Refusing leaves the poll OPEN and writes no plan, so a retry is safe.
      //
      // Reachable here only as `failed`: this method reads through
      // `getMessage`, whose list holds ONE message, so the cap is a no-op on
      // that path and a capped poll arrives marked `ok`. The capped case is
      // caught by `ChatViewModel.closePoll` and by the widget's own gate, which
      // are the two layers still holding the copy the user was shown. This
      // check is the backstop for a tally that errored.
      final hydration = PollVoteHydration.fromMetadata(existing.metadata);
      if (hydration.isUnread) {
        AppLogger.warning(
          'Refusing to close poll $messageId: votes were ${hydration.name}',
        );
        throw const PollCloseRefusedException(PollCloseRefusal.votesUnread);
      }

      // BUT-1909, and deliberately NOT the fail-open contract `_filterBlocked`
      // uses. There, an unknown block list serves an over-counted poll on
      // screen, which is recoverable. Here it would let a blocked person's
      // ballot decide the recipe that lands in other members' plan — so an
      // unresolvable block list refuses instead. Trust & Safety's condition.
      //
      // BUT-1926: an ABSENT filter refuses too. `tryGet` returning null is not
      // "nobody is blocked", it is "this build cannot tell" — the same state
      // the catch below refuses on — and skipping the branch on it made the
      // whole guard conditional on a service registration.
      final blockFilter = ServiceLocator.tryGet<BlockedUserFilter>();
      if (blockFilter == null) {
        AppLogger.warning(
          'Refusing to close poll $messageId: no block filter registered',
        );
        throw const PollCloseRefusedException(
          PollCloseRefusal.blockListUnknown,
        );
      }
      final Set<String> blocked;
      try {
        // `requireBlockedIds`, NOT `currentBlockedIds`: the latter swallows a
        // failed lookup and returns an empty set, which would make this whole
        // branch dead code and fail OPEN on exactly the decision that cannot
        // be taken back. Raised as critical by the firebase-backend-security
        // gate, which also showed the test here was measuring its own mock.
        blocked = await blockFilter.requireBlockedIds();
      } catch (e) {
        AppLogger.warning(
          'Refusing to close poll $messageId: block list unreadable ($e)',
        );
        throw const PollCloseRefusedException(
          PollCloseRefusal.blockListUnknown,
        );
      }
      // Through the SAME helper the display path uses.
      final filtered = _stripBlockedBallots(existing, blocked);
      final resolvablePoll = _extractPoll(filtered) ?? existingPoll;

      // Resolve + persist the plan write BEFORE marking the poll closed.
      // If the plan save fails, the poll stays open so the creator can
      // retry — the pre-read `isClosed` guard above is the idempotency
      // anchor, and it must still be false for a retry to reach here.
      //
      // Only creator-triggered closes resolve into a plan. A non-creator's
      // close writes NOTHING: the repository returns early when
      // `pollMap['creatorId'] != closerId`.
      if (resolvablePoll.creatorId == currentUserId) {
        final winner = _resolveWinner(resolvablePoll);
        if (winner?.recipeId != null) {
          final conversation = await _messagingRepository.getConversation(
            existing.conversationId,
          );
          final isGroup = conversation?.isGroup ?? false;

          if (isGroup && conversation != null) {
            await _appendWinnerToGroupPlan(
              winnerRecipeId: winner!.recipeId!,
              conversation: conversation,
              creatorId: currentUserId,
            );
          } else if (conversation != null) {
            await _appendWinnerToWeeklyPlanAndShare(
              winnerRecipeId: winner!.recipeId!,
              conversation: conversation,
            );
          }
        }
      }

      // Plan write succeeded (or there was nothing to write). Now close
      // the poll — if THIS fails, the plan already has the winner, which
      // is the preferred failure mode vs. a closed poll with no plan.
      await _messagingRepository.closePoll(
        messageId: messageId,
        closerId: currentUserId,
      );
    } on PollCloseRefusedException {
      // BUT-1926: already logged, at the warning level the refusal deserves.
      // Re-logging it as an error made every deliberate guard look like a
      // crash in the log, twice over.
      rethrow;
    } catch (e) {
      AppLogger.error('Failed to close poll $messageId', e);
      rethrow;
    }
  }

  /// Extract a `Poll` from a `Message.metadata.poll` map, or null if absent.
  Poll? _extractPoll(Message? message) {
    final metadata = message?.metadata;
    if (metadata == null) return null;
    final pollMap = metadata['poll'];
    if (pollMap is! Map) return null;
    try {
      return Poll.fromMap(Map<String, dynamic>.from(pollMap));
    } catch (e) {
      AppLogger.warning('Failed to parse poll from metadata: $e');
      return null;
    }
  }

  /// Winner = option with the most votes. Ties broken by chronological order
  /// (first option in `options` wins) — keeps resolution deterministic.
  PollOption? _resolveWinner(Poll poll) {
    if (poll.options.isEmpty) return null;
    PollOption? best;
    for (final option in poll.options) {
      if (best == null || option.voteCount > best.voteCount) {
        best = option;
      }
    }
    if (best == null || best.voteCount == 0) return null;
    return best;
  }

  /// Find the winner recipe in the local recipe cache. Returns null if
  /// the recipe is not loaded (stale cache, deleted, etc.); callers treat
  /// that as a skip-auto-resolution signal.
  Recipe? _findWinnerRecipe(
    UnifiedRecipeService recipeService,
    String winnerRecipeId,
  ) {
    for (final r in recipeService.recipes) {
      if (r.id == winnerRecipeId) return r;
    }
    return null;
  }

  /// Today-anchored next empty middag slot. Walks today → Sunday; if the
  /// rest of the week is full, falls back to `(today, ovrigt)` (multi-slot).
  ({DayOfWeek day, MealSlot slot}) _nextAvailableMiddagSlot(
    DateTime anchor,
    bool Function(DayOfWeek day, MealSlot slot) isOccupied,
  ) {
    final anchorIndex = DayOfWeek.fromDateTime(anchor).index;
    for (var i = anchorIndex; i <= DayOfWeek.sun.index; i++) {
      final candidate = DayOfWeek.values[i];
      if (!isOccupied(candidate, MealSlot.middag)) {
        return (day: candidate, slot: MealSlot.middag);
      }
    }
    return (day: DayOfWeek.values[anchorIndex], slot: MealSlot.ovrigt);
  }

  /// Appends the winning recipe to the creator's current-week personal plan
  /// at the next empty middag slot (today-anchored). Creates an empty plan
  /// first if the creator has none.
  Future<void> _appendWinnerToWeeklyPlanAndShare({
    required String winnerRecipeId,
    required Conversation conversation,
  }) async {
    final planService = ServiceLocator.tryGet<WeeklyMenuPlanService>();
    final recipeService = ServiceLocator.tryGet<UnifiedRecipeService>();
    final socialMenuOps = ServiceLocator.tryGet<SocialMenuOperations>();
    if (planService == null || recipeService == null || socialMenuOps == null) {
      AppLogger.warning(
        'Auto-resolution skipped — required services not registered',
      );
      return;
    }

    final winnerRecipe = _findWinnerRecipe(recipeService, winnerRecipeId);
    if (winnerRecipe == null) {
      AppLogger.warning(
        'Auto-resolution skipped — winner recipe $winnerRecipeId not found',
      );
      return;
    }

    final now = clock.now();
    // BUT-1928. `getWeek` answers a failed read with an EMPTY plan, so the
    // save below would write a one-entry week built from nothing. On a week
    // that already exists the server refuses it (the empty plan's fresh
    // `createdAt`; W2 in `weekly-menu-plans-rules.test.ts`). Throwing
    // leaves the poll open (the close happens after this returns), which is the
    // recoverable failure; a silent skip would burn a one-way close instead.
    final read = await planService.readWeek(now);
    if (read.readFailed) {
      throw StateError(
        'Refusing to write the poll winner: the current week could not be read',
      );
    }
    final plan = read.plan;
    final target = _nextAvailableMiddagSlot(now, plan.isOccupied);

    final updatedPlan = planService.addEntry(
      plan: plan,
      day: target.day,
      slot: target.slot,
      recipe: winnerRecipe,
    );
    await planService.save(updatedPlan);

    // Share with the group — for MVP we share the in-progress menu payload
    // with the other participants of the conversation that hosted the poll.
    try {
      final currentUserId = _authRepository.currentUserId;
      if (conversation.isGroup) {
        final menuPayload = <String, List<Recipe>>{
          'middag': [winnerRecipe],
        };
        final participantIds = conversation.participantIds
            .where((id) => id != currentUserId)
            .toList();
        if (participantIds.isNotEmpty) {
          await socialMenuOps.shareMenuWithFriends(
            menu: menuPayload,
            friendUserIds: participantIds,
          );
        }
      }
    } catch (e) {
      // Share failure shouldn't unwind the plan append — log and continue.
      AppLogger.warning('Auto-share after poll close failed: $e');
    }
  }

  /// Group-plan auto-resolution path. Appends the winning recipe to a
  /// shared `GroupWeeklyMenuPlan` (creates it with all conversation
  /// participants as editors if none exists for the ISO week).
  ///
  /// The group plan lives at a deterministic doc ID
  /// (`{groupId}_{YYYY}-W{WW}`), so two closes race on ONE document; that makes
  /// the upsert idempotent, not the append (BUT-1925).
  Future<void> _appendWinnerToGroupPlan({
    required String winnerRecipeId,
    required Conversation conversation,
    required String creatorId,
  }) async {
    final groupService = ServiceLocator.tryGet<GroupWeeklyMenuPlanService>();
    final recipeService = ServiceLocator.tryGet<UnifiedRecipeService>();
    if (groupService == null || recipeService == null) {
      AppLogger.warning(
        'Auto-resolution (group) skipped — required services not registered',
      );
      return;
    }

    final winnerRecipe = _findWinnerRecipe(recipeService, winnerRecipeId);
    if (winnerRecipe == null) {
      AppLogger.warning(
        'Auto-resolution (group) skipped — winner recipe $winnerRecipeId not found',
      );
      return;
    }

    final now = clock.now();

    // Fetch-or-build the group plan. First-time creation seeds every
    // conversation participant as an editor; the closer (creator) is
    // admin. Existing plans keep their membership intact.
    final initialParticipants = <GroupMenuParticipant>[
      for (final pid in conversation.participantIds)
        GroupMenuParticipant(
          userId: pid,
          permission: pid == creatorId
              ? SharedListPermission.admin
              : SharedListPermission.edit,
          addedAt: now,
        ),
    ];
    // Build-only (no persist). The single `save()` below persists the
    // plan WITH the winner entry already appended — saves one Firestore
    // write per new-group-week vs. create-then-save.
    //
    // BUT-1928, and the reason this is `readOrBuildWeek`: building on a FAILED
    // read produces a fresh empty plan whose id is the same deterministic
    // `{groupId}_{ISO week}`. Throwing leaves the poll open for a retry.
    final read = await groupService.readOrBuildWeek(
      groupId: conversation.id,
      creatorId: creatorId,
      date: now,
      initialParticipants: initialParticipants,
    );
    final GroupWeeklyMenuPlan? plan = read.plan;
    if (read.readFailed || plan == null) {
      throw StateError(
        'Refusing to write the poll winner: the group week could not be read',
      );
    }

    final target = _nextAvailableMiddagSlot(now, plan.isOccupied);

    final updatedPlan = groupService.addEntry(
      plan: plan,
      actorId: creatorId,
      day: target.day,
      slot: target.slot,
      recipe: winnerRecipe,
    );
    await groupService.save(plan: updatedPlan, actorId: creatorId);
  }

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
