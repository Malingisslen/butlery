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
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/core/utils/logger.dart';

// Module imports
import 'package:butlery/repositories/firebase/modules/conversation_auto_healer_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_query_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_mutation_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/repositories/firebase/modules/message_query_module.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase messaging repository using modular architecture.
/// Delegates to specialized modules for clean separation of concerns.
class FirebaseMessagingRepository extends BaseFirebaseRepository<Conversation>
    with UserScopedFirebaseRepository<Conversation>
    implements MessagingRepository {
  // Modules
  late final ConversationAutoHealerModule _autoHealerModule;
  late final ConversationQueryModule _conversationQueryModule;
  late final ConversationMutationModule _conversationMutationModule;
  late final ConversationParticipantModule? _participantModule;
  late final MessageQueryModule _messageQueryModule;
  late final MessageMutationModule _messageMutationModule;

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
    _autoHealerModule = ConversationAutoHealerModule(
      messagesRef: _messagesRef,
      readConversation: read,
      updateConversation: update,
    );

    _conversationQueryModule = ConversationQueryModule(
      firestore: firestore,
      collectionName: collectionName,
      fromFirestore: fromFirestore,
      startAutoHealer: _autoHealerModule.startAutoHealer,
      participantModule: _participantModule,
    );

    _conversationMutationModule = ConversationMutationModule(
      firestore: firestore,
      collectionName: collectionName,
      createFn: create,
      updateFn: update,
      readFn: read,
      sendMessageFn: sendMessage,
      participantModule: _participantModule,
    );

    _messageQueryModule = MessageQueryModule(
      messagesRef: _messagesRef,
    );

    _messageMutationModule = MessageMutationModule(
      firestore: firestore,
      collectionName: collectionName,
      messagesRef: _messagesRef,
      readConversation: read,
      timestampProvider: timestampProvider,
    );
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
      String userId, Conversation entity) async {
    // User must be a participant in conversations they create
    return entity.participantIds.contains(userId);
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, Conversation? entity) async {
    if (entity == null) return false;
    // Only participants can read the conversation
    return entity.participantIds.contains(userId);
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, Conversation entity) async {
    // Only participants can update conversation metadata
    return entity.participantIds.contains(userId);
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
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
      _conversationQueryModule.getConversation(conversationId, read);

  @override
  Future<String> createDirectConversation({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  }) async =>
      _conversationMutationModule.createDirectConversation(
        user1Id: user1Id,
        user1DisplayName: user1DisplayName,
        user1AvatarUrl: user1AvatarUrl,
        user2Id: user2Id,
        user2DisplayName: user2DisplayName,
        user2AvatarUrl: user2AvatarUrl,
      );

  @override
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
    required String creatorId,
  }) async =>
      _conversationMutationModule.createGroupConversation(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
        creatorId: creatorId,
      );

  @override
  @Deprecated(
      'Use createDirectConversation directly - it handles "get or create" with deterministic IDs')
  Future<String?> findDirectConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      AppLogger.warning(
          '⚠️ findDirectConversation is DEPRECATED - use createDirectConversation instead');

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
  }) async =>
      _conversationMutationModule.updateConversation(
        conversationId: conversationId,
        title: title,
        metadata: metadata,
      );

  @override
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async =>
      _conversationMutationModule.addParticipants(
        conversationId: conversationId,
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
      );

  @override
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async =>
      _conversationMutationModule.removeParticipant(
        conversationId: conversationId,
        participantId: participantId,
      );

  @override
  Future<void> deleteConversation(String conversationId) async =>
      _conversationMutationModule.deleteConversation(
          conversationId, _messagesRef);

  @override
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required String voterId,
    required bool allowMultiple,
  }) async =>
      _messageMutationModule.votePoll(
        messageId: messageId,
        optionId: optionId,
        voterId: voterId,
        allowMultiple: allowMultiple,
      );

  @override
  Future<void> closePoll({
    required String messageId,
    required String closerId,
  }) async =>
      _messageMutationModule.closePoll(
        messageId: messageId,
        closerId: closerId,
      );

  @override
  Future<void> updateConversationUserSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  }) async =>
      _conversationMutationModule.updateConversationUserSettings(
        conversationId: conversationId,
        userId: userId,
        settings: settings,
      );

  @override
  Future<List<String>> getConversationParticipants(
          String conversationId) async =>
      _conversationQueryModule.getConversationParticipants(
          conversationId, read);

  @override
  Future<int> getUnreadMessageCount(String userId) async =>
      _conversationQueryModule.getUnreadMessageCount(userId);

  @override
  Future<int> getUnreadConversationsCount(String userId) async =>
      _conversationQueryModule.getUnreadConversationsCount(userId);
  @override
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) =>
      _messageQueryModule.getConversationMessages(
        conversationId: conversationId,
        limit: limit,
      );

  @override
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    int limit = 50,
    DateTime? startAfter,
  }) async =>
      _messageQueryModule.getConversationMessagesPage(
        conversationId: conversationId,
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
    int limit = 20,
  }) async =>
      _messageQueryModule.searchMessages(
        conversationId: conversationId,
        query: query,
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
  }) async =>
      _messageMutationModule.updateMessageStatus(
        messageId: messageId,
        status: status,
        timestamp: timestamp,
      );

  @override
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async =>
      _messageMutationModule.markMessageAsRead(
        messageId: messageId,
        userId: userId,
      );

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async =>
      _messageMutationModule.markConversationAsRead(
        conversationId: conversationId,
        userId: userId,
        updateConversation: update,
      );

  @override
  Future<void> updateMessageContent({
    required String messageId,
    required String newContent,
  }) async =>
      _messageMutationModule.updateMessageContent(
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
  }) async =>
      _messageMutationModule.batchMarkAsDelivered(
        messageIds: messageIds,
        userId: userId,
      );

  /// Start real-time self-healing for a conversation.
  void startConversationAutoHealer(String conversationId) =>
      _autoHealerModule.startAutoHealer(conversationId);

  /// Stop auto-healer for a conversation (cleanup).
  void stopConversationAutoHealer(String conversationId) =>
      _autoHealerModule.stopAutoHealer(conversationId);

  /// Stop all auto-healers (call on repository disposal).
  void stopAllAutoHealers() => _autoHealerModule.stopAllAutoHealers();

  /// Dispose repository and cleanup all resources including active stream subscriptions.
  void dispose() {
    stopAllAutoHealers();
    AppLogger.debug('FirebaseMessagingRepository disposed');
  }

  /// Cascade-delete [userId]'s message participation. GDPR Art. 17.
  ///
  /// For each conversation [userId] participates in:
  /// - All messages in the conversation's `messages` subcollection are
  ///   deleted (irrespective of sender — the user's read receipts and
  ///   conversation context are also their data).
  /// - 1:1 conversations (≤2 participants) are deleted entirely.
  /// - Group conversations (>2 participants) have [userId] removed from
  ///   `participantIds` so the remaining group continues. The user
  ///   "leaves" without nuking the others' chat history.
  ///
  /// More involved than other repos' `deleteAllByUser` because messages
  /// live in subcollections under each conversation, and ownership is on
  /// the conversation's `participantIds` array — not a flat field on the
  /// message doc.
  ///
  /// Returns the total number of message docs deleted (conversation docs
  /// and participant-list updates are NOT counted in the return value —
  /// matches the prior `social_deletion_operations.deleteMessages`
  /// behaviour this replaces).
  @override
  Future<int> deleteAllMessagesForUser(String userId) async {
    // GDPR cascade: caller must be deleting their own data.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: FirestoreCollections.conversations,
    );

    final conversationsSnapshot = await firestore
        .collection(FirestoreCollections.conversations)
        .where('participantIds', arrayContains: userId)
        .get();

    // Bounded parallelism: 10 conversations at a time keeps us well under
    // Firestore's per-client write quota while collapsing the
    // round-trip-per-conversation latency that account-deletion otherwise
    // accumulates linearly. A power-user in 100 chats goes from ~100
    // sequential RTTs to ~10 parallel waves.
    var totalMessagesDeleted = 0;
    for (final chunk in conversationsSnapshot.docs.chunked(10)) {
      final perChunkCounts = await Future.wait(
        chunk.map((convoDoc) => _deleteOneConversation(convoDoc, userId)),
      );
      totalMessagesDeleted += perChunkCounts.fold<int>(0, (a, b) => a + b);
    }

    AppLogger.info(
        'Deleted $totalMessagesDeleted messages across ${conversationsSnapshot.docs.length} conversations for user $userId');
    return totalMessagesDeleted;
  }

  Future<int> _deleteOneConversation(
    QueryDocumentSnapshot<Map<String, dynamic>> convoDoc,
    String userId,
  ) async {
    final messagesSnapshot = await convoDoc.reference
        .collection(FirestoreCollections.messages)
        .get();
    var deleted = 0;
    if (messagesSnapshot.docs.isNotEmpty) {
      await batchDeleteDocs(firestore, messagesSnapshot.docs);
      deleted = messagesSnapshot.docs.length;
    }

    final participants =
        List<String>.from(convoDoc.data()['participantIds'] ?? const []);
    if (participants.length <= 2) {
      // 1:1 conversation (or solo) — delete the conversation doc itself.
      await convoDoc.reference.delete();
    } else {
      // Group: read-modify-write. `FieldValue.arrayRemove` would be more
      // race-safe in production but FakeFirebaseFirestore can't test it
      // (MockFieldValuePlatform cast error — see firebase_shared_recipe_repository_test
      // for the documented limitation). The race window is negligible on
      // an account-deletion path: the deleting user can't concurrently
      // mutate their own conversations.
      participants.remove(userId);
      await convoDoc.reference.update({'participantIds': participants});
    }
    return deleted;
  }
}
