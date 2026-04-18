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
    required auth_repo.AuthRepository authRepository,
    required MessageReactionsService reactionsService,
  })  : _messagingRepository = messagingRepository,
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
        user1DisplayName:
            currentUser.displayName ?? AppLocale.current.displayUnknownUser,
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
            currentUser.displayName ?? AppLocale.current.displayUnknownUser;
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

    AppLogger.debug(
        'Typing indicator cleared for ${userId.maskedUserId} in $conversationId');
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
        sentAt: DateTime.now(),
        metadata: {'poll': pollData},
      );

      await _messagingRepository.sendMessage(message);
      AppLogger.success('Poll message sent in conversation $conversationId');
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
  /// resolution appends that recipe to the creator's current-week plan
  /// (today-anchored next empty slot) and reshares the plan with the group
  /// that received the poll. Winner = most votes; ties broken by chronological
  /// order (first option in the options list wins).
  ///
  /// MVP scope: writes to the poll creator's own plan. Double-fire across
  /// concurrent callers is guarded by a pre-read of the poll message — if
  /// already closed, the plan write is skipped on this call. The underlying
  /// repo's `closePoll` also re-checks `!isClosed` inside its write path.
  Future<void> closePoll({required String messageId}) async {
    try {
      final currentUserId = _authRepository.currentUserId;
      if (currentUserId == null) {
        throw AuthenticationException('User must be authenticated');
      }

      // Pre-read the message to guard against double-resolution. If the poll
      // is already closed, another caller raced us — skip both the repo
      // close and the plan write so auto-resolution fires exactly once.
      final existing = await _messagingRepository.getMessage(messageId);
      final existingPoll = _extractPoll(existing);
      if (existingPoll?.isClosed == true) {
        AppLogger.debug('Poll $messageId already closed — skipping resolve');
        return;
      }

      await _messagingRepository.closePoll(
        messageId: messageId,
        closerId: currentUserId,
      );

      // Re-read the message so vote tallies reflect the final state.
      final finalMessage =
          await _messagingRepository.getMessage(messageId) ?? existing;
      final poll = _extractPoll(finalMessage);
      if (poll == null || finalMessage == null) return;

      if (poll.creatorId != currentUserId) {
        // Only creator-triggered closes resolve into the creator's plan.
        return;
      }

      final winner = _resolveWinner(poll);
      if (winner?.recipeId == null) return;

      // BUT-405: route by conversation type. Groups get a collaborative
      // `GroupWeeklyMenuPlan`; 1:1 conversations keep the creator-personal
      // plan path from BUT-340. The split is deliberately narrow — only
      // the target collection differs, everything else (winner resolution,
      // today-anchored slot search, double-fire guard) is shared.
      final conversation = await _messagingRepository
          .getConversation(finalMessage.conversationId);
      final isGroup = conversation?.isGroup ?? false;

      if (isGroup && conversation != null) {
        await _appendWinnerToGroupPlan(
          winnerRecipeId: winner!.recipeId!,
          conversation: conversation,
          creatorId: currentUserId,
        );
      } else {
        await _appendWinnerToWeeklyPlanAndShare(
          winnerRecipeId: winner!.recipeId!,
          conversationId: finalMessage.conversationId,
        );
      }
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

  /// Appends the winning recipe to the current-week plan at the next empty
  /// middag slot (today-anchored) and reshares with the group the poll was
  /// sent to. Creates an empty plan first if the creator has none.
  Future<void> _appendWinnerToWeeklyPlanAndShare({
    required String winnerRecipeId,
    required String conversationId,
  }) async {
    final planService = ServiceLocator.tryGet<WeeklyMenuPlanService>();
    final recipeService = ServiceLocator.tryGet<UnifiedRecipeService>();
    final socialMenuOps = ServiceLocator.tryGet<SocialMenuOperations>();
    if (planService == null || recipeService == null || socialMenuOps == null) {
      AppLogger.warning(
          'Auto-resolution skipped — required services not registered');
      return;
    }

    Recipe? winnerRecipe;
    for (final r in recipeService.recipes) {
      if (r.id == winnerRecipeId) {
        winnerRecipe = r;
        break;
      }
    }
    if (winnerRecipe == null) {
      AppLogger.warning(
          'Auto-resolution skipped — winner recipe $winnerRecipeId not found');
      return;
    }

    final now = DateTime.now();
    final plan = await planService.getWeek(now);

    // Today-anchored next empty middag slot. Walks today → Sunday.
    final anchorIndex = DayOfWeek.fromDateTime(now).index;
    DayOfWeek? targetDay;
    for (var i = anchorIndex; i <= DayOfWeek.sun.index; i++) {
      final candidate = DayOfWeek.values[i];
      if (!plan.isOccupied(candidate, MealSlot.middag)) {
        targetDay = candidate;
        break;
      }
    }
    // If the rest of this week is full, fall back to ovrigt (multi-slot).
    final usedSlot = targetDay == null ? MealSlot.ovrigt : MealSlot.middag;
    final usedDay = targetDay ?? DayOfWeek.values[anchorIndex];

    final updatedPlan = planService.addEntry(
      plan: plan,
      day: usedDay,
      slot: usedSlot,
      recipe: winnerRecipe,
    );
    await planService.save(updatedPlan);

    // Share with the group — for MVP we share the in-progress menu payload
    // with the other participants of the conversation that hosted the poll.
    try {
      final conversation =
          await _messagingRepository.getConversation(conversationId);
      final currentUserId = _authRepository.currentUserId;
      if (conversation != null && conversation.isGroup) {
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

  /// BUT-405: group-plan auto-resolution path. Appends the winning recipe
  /// to a shared `GroupWeeklyMenuPlan` (creates it with all conversation
  /// participants as editors if none exists for the ISO week).
  ///
  /// Double-fire race: the poll's `isClosed` check in [closePoll] already
  /// gates this — by the time we reach here, the caller holds logical
  /// ownership of the resolution. The group-plan upsert itself is
  /// idempotent by deterministic doc ID (`{groupId}_{YYYY}-W{WW}`), so a
  /// race with another branch of the same close would overwrite with
  /// identical content rather than append twice.
  Future<void> _appendWinnerToGroupPlan({
    required String winnerRecipeId,
    required Conversation conversation,
    required String creatorId,
  }) async {
    final groupService = ServiceLocator.tryGet<GroupWeeklyMenuPlanService>();
    final recipeService = ServiceLocator.tryGet<UnifiedRecipeService>();
    if (groupService == null || recipeService == null) {
      AppLogger.warning(
          'Auto-resolution (group) skipped — required services not registered');
      return;
    }

    Recipe? winnerRecipe;
    for (final r in recipeService.recipes) {
      if (r.id == winnerRecipeId) {
        winnerRecipe = r;
        break;
      }
    }
    if (winnerRecipe == null) {
      AppLogger.warning(
          'Auto-resolution (group) skipped — winner recipe $winnerRecipeId not found');
      return;
    }

    final now = DateTime.now();

    // Fetch-or-create the group plan. First-time creation seeds every
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
    final GroupWeeklyMenuPlan plan = await groupService.getOrCreateWeek(
      groupId: conversation.id,
      creatorId: creatorId,
      date: now,
      initialParticipants: initialParticipants,
    );

    // Today-anchored slot search — identical to the personal-plan branch.
    final anchorIndex = DayOfWeek.fromDateTime(now).index;
    DayOfWeek? targetDay;
    for (var i = anchorIndex; i <= DayOfWeek.sun.index; i++) {
      final candidate = DayOfWeek.values[i];
      if (!plan.isOccupied(candidate, MealSlot.middag)) {
        targetDay = candidate;
        break;
      }
    }
    final usedSlot = targetDay == null ? MealSlot.ovrigt : MealSlot.middag;
    final usedDay = targetDay ?? DayOfWeek.values[anchorIndex];

    final updatedPlan = groupService.addEntry(
      plan: plan,
      actorId: creatorId,
      day: usedDay,
      slot: usedSlot,
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
