/// Firebase implementation for real-time messaging with conversation management.
/// Supports direct/group conversations, real-time delivery, read receipts, and participant management.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/utils/logger.dart';

// Module imports
import 'package:butlery/repositories/firebase/modules/conversation_query_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_mutation_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/repositories/firebase/modules/message_query_module.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';
import 'package:butlery/repositories/firebase/modules/message_deletion_module.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase messaging repository using modular architecture.
/// Delegates to specialized modules for clean separation of concerns.
class FirebaseMessagingRepository extends BaseFirebaseRepository<Conversation>
    with UserScopedFirebaseRepository<Conversation>
    implements MessagingRepository {
  // Modules. BUT-778: ConversationAutoHealerModule deleted; lastMessage
  // sync now happens server-side via the `syncConversationLastMessage`
  // Cloud Function trigger.
  late final ConversationQueryModule _conversationQueryModule;
  late final ConversationMutationModule _conversationMutationModule;
  late final ConversationParticipantModule? _participantModule;
  late final MessageQueryModule _messageQueryModule;
  late final MessageMutationModule _messageMutationModule;
  late final MessageDeletionModule _messageDeletionModule;

  FirebaseMessagingRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
    super.timestampProvider,
    FeatureFlagService? featureFlagService,
  }) : super(
         authRepository: authRepository ?? FirebaseAuthRepository(),
       ) {
    // Initialize participant module if feature flag service is provided
    _participantModule = featureFlagService != null
        ? ConversationParticipantModule(
            firestore: firestore,
            featureFlags: featureFlagService,
          )
        : null;

    // Initialize modules
    _conversationQueryModule = ConversationQueryModule(
      firestore: firestore,
      collectionName: collectionName,
      fromFirestore: fromFirestore,
      participantModule: _participantModule,
    );

    _conversationMutationModule = ConversationMutationModule(
      firestore: firestore,
      collectionName: collectionName,
      participantModule: _participantModule,
    );

    _messageQueryModule = MessageQueryModule(
      messagesRef: _messagesRef,
    );

    _messageMutationModule = MessageMutationModule(
      firestore: firestore,
      collectionName: collectionName,
      messagesRef: _messagesRef,
      // BUT-1838: the TOP-LEVEL read, not `read` — this class mixes in
      // `UserScopedFirebaseRepository`, which rewrites every path to
      // `users/{uid}/conversations/{id}`. A chat group's conversation is
      // written only at the top level by `createChatGroup`, so `read` returned
      // null for every group, for everyone. `sendMessage` would then take its
      // fabricate-a-conversation fallback on EVERY send, and the batch that
      // carries it is refused by the conversations update rule — so the
      // message died with it.
      readConversation: _readTopLevelConversation,
      timestampProvider: timestampProvider,
    );

    _messageDeletionModule = MessageDeletionModule(firestore: firestore);
  }
  @override
  String get collectionName => FirestoreCollections.conversations;

  @override
  Conversation fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ConversationDto.fromFirestore(doc, currentUserId: currentUserId);

  @override
  Map<String, dynamic> toFirestore(Conversation entity) =>
      ConversationDto.toFirestore(entity);

  @override
  String getId(Conversation entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
    String userId,
    Conversation entity,
  ) async {
    // User must be a participant in conversations they create
    return entity.participantIds.contains(userId);
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    Conversation? entity,
  ) async {
    if (entity == null) return false;
    // Only participants can read the conversation
    return entity.participantIds.contains(userId);
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    Conversation entity,
  ) async {
    // Only participants can update conversation metadata
    return entity.participantIds.contains(userId);
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Only participants can delete conversations
    try {
      final conversation = await read(resourceId);
      if (conversation == null) return false;
      return conversation.participantIds.contains(userId);
    } catch (e) {
      AppLogger.error('Failed to validate delete permission: $e');
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      firestore.collection(FirestoreCollections.messages);
  @override
  Stream<List<Conversation>> getUserConversations(String userId) =>
      _conversationQueryModule.getUserConversations(userId);

  @override
  Future<Conversation?> getConversation(String conversationId) async =>
      _conversationQueryModule.getConversation(conversationId);

  @override
  Future<String> createDirectConversation({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  }) async => _conversationMutationModule.createDirectConversation(
    user1Id: user1Id,
    user1DisplayName: user1DisplayName,
    user1AvatarUrl: user1AvatarUrl,
    user2Id: user2Id,
    user2DisplayName: user2DisplayName,
    user2AvatarUrl: user2AvatarUrl,
  );

  @override
  @Deprecated(
    'Use createDirectConversation directly - it handles "get or create" with deterministic IDs',
  )
  Future<String?> findDirectConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      AppLogger.warning(
        '⚠️ findDirectConversation is DEPRECATED - use createDirectConversation instead',
      );

      final query = await firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: user1Id)
          .where('isGroup', isEqualTo: false)
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();

      for (final doc in query.docs) {
        final conversation = fromFirestore(doc);
        if (conversation.participantIds.contains(user2Id)) {
          return conversation.id;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed in findDirectConversation', e);
      return null;
    }
  }

  @override
  Future<void> updateConversation({
    required String conversationId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async => _conversationMutationModule.updateConversation(
    conversationId: conversationId,
    title: title,
    metadata: metadata,
  );

  /// The top-level conversation document, bypassing the user-scoped rewrite.
  ///
  /// Deliberately not `read`: see the note where this is wired in. Mirrors
  /// `ConversationQueryModule.getConversation`, which had the same bug.
  Future<Conversation?> _readTopLevelConversation(String conversationId) async {
    try {
      final doc = await firestore
          .collection(collectionName)
          .doc(conversationId)
          .get();
      if (!doc.exists) return null;
      return fromFirestore(doc);
    } catch (e) {
      AppLogger.error('Failed to read conversation $conversationId', e);
      return null;
    }
  }

  @override
  Future<void> deleteConversation(
    String conversationId, {
    DateTime? historyStart,
  }) async => _conversationMutationModule.deleteConversation(
    conversationId,
    _messagesRef,
    historyStart: historyStart,
  );

  @override
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required String voterId,
    required bool allowMultiple,
  }) async => _messageMutationModule.votePoll(
    messageId: messageId,
    optionId: optionId,
    voterId: voterId,
    allowMultiple: allowMultiple,
  );

  @override
  Future<void> closePoll({
    required String messageId,
    required String closerId,
  }) async => _messageMutationModule.closePoll(
    messageId: messageId,
    closerId: closerId,
  );

  @override
  Future<void> updateConversationUserSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  }) async => _conversationMutationModule.updateConversationUserSettings(
    conversationId: conversationId,
    userId: userId,
    settings: settings,
  );

  @override
  Future<List<String>> getConversationParticipants(
    String conversationId,
  ) async =>
      _conversationQueryModule.getConversationParticipants(conversationId);

  @override
  Future<int> getUnreadMessageCount(String userId) async =>
      _conversationQueryModule.getUnreadMessageCount(userId);

  @override
  Future<int> getUnreadConversationsCount(String userId) async =>
      _conversationQueryModule.getUnreadConversationsCount(userId);
  @override
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    DateTime? historyStart,
    int limit = 50,
  }) => _messageQueryModule.getConversationMessages(
    conversationId: conversationId,
    historyStart: historyStart,
    limit: limit,
  );

  @override
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    DateTime? historyStart,
    int limit = 50,
    DateTime? startAfter,
  }) async => _messageQueryModule.getConversationMessagesPage(
    conversationId: conversationId,
    historyStart: historyStart,
    limit: limit,
    startAfter: startAfter,
  );

  @override
  Future<Message?> getMessage(String messageId) async =>
      _messageQueryModule.getMessage(messageId);

  @override
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    DateTime? historyStart,
    int limit = 20,
  }) async => _messageQueryModule.searchMessages(
    conversationId: conversationId,
    query: query,
    historyStart: historyStart,
    limit: limit,
  );

  @override
  Future<void> sendMessage(Message message) async =>
      _messageMutationModule.sendMessage(message);

  @override
  Future<void> updateMessageStatus({
    required String messageId,
    required MessageStatus status,
    DateTime? timestamp,
  }) async => _messageMutationModule.updateMessageStatus(
    messageId: messageId,
    status: status,
    timestamp: timestamp,
  );

  @override
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async => _messageMutationModule.markMessageAsRead(
    messageId: messageId,
    userId: userId,
  );

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async => _messageMutationModule.markConversationAsRead(
    conversationId: conversationId,
    userId: userId,
  );

  @override
  Future<void> updateMessageContent({
    required String messageId,
    required String newContent,
  }) async => _messageMutationModule.updateMessageContent(
    messageId: messageId,
    newContent: newContent,
  );

  @override
  Future<void> deleteMessage(String messageId) async =>
      _messageMutationModule.deleteMessage(messageId);

  @override
  Future<void> batchMarkAsDelivered({
    required List<String> messageIds,
    required String userId,
  }) async => _messageMutationModule.batchMarkAsDelivered(
    messageIds: messageIds,
    userId: userId,
  );

  /// Called by the DI module's dispose hook (`messaging_module.dart`).
  /// BUT-778: lastMessage sync moved to the `syncConversationLastMessage`
  /// CF trigger; no client-side subscriptions to tear down here.
  void dispose() {
    AppLogger.debug('FirebaseMessagingRepository disposed');
  }

  /// Cascade-delete [userId]'s own messages and conversation membership
  /// (GDPR Art. 17). Delegates to [MessageDeletionModule]; the ownership guard
  /// stays here because this class owns the auth context.
  @override
  Future<int> deleteAllMessagesForUser(String userId) async {
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: FirestoreCollections.conversations,
    );
    return _messageDeletionModule.deleteAllMessagesForUser(userId);
  }
}
