/// Firebase implementation for real-time messaging with conversation management.
///
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
import 'package:butlery/core/utils/logger.dart';

// Module imports
import 'package:butlery/repositories/firebase/modules/conversation_auto_healer_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_query_module.dart';
import 'package:butlery/repositories/firebase/modules/conversation_mutation_module.dart';
import 'package:butlery/repositories/firebase/modules/message_query_module.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';

/// Firebase messaging repository using modular architecture.
/// Delegates to specialized modules for clean separation of concerns.
class FirebaseMessagingRepository
    extends BaseFirebaseRepository<Conversation>
    with UserScopedFirebaseRepository<Conversation>
    implements MessagingRepository {

  // Modules
  late final ConversationAutoHealerModule _autoHealerModule;
  late final ConversationQueryModule _conversationQueryModule;
  late final ConversationMutationModule _conversationMutationModule;
  late final MessageQueryModule _messageQueryModule;
  late final MessageMutationModule _messageMutationModule;

  FirebaseMessagingRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        ) {
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
    );

    _conversationMutationModule = ConversationMutationModule(
      firestore: firestore,
      collectionName: collectionName,
      createFn: create,
      updateFn: update,
      readFn: read,
      sendMessageFn: sendMessage,
    );

    _messageQueryModule = MessageQueryModule(
      messagesRef: _messagesRef,
    );

    _messageMutationModule = MessageMutationModule(
      firestore: firestore,
      collectionName: collectionName,
      messagesRef: _messagesRef,
      readConversation: read,
    );
  }

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'conversations';

  @override
  Conversation fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ConversationDto.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Conversation entity) => ConversationDto.toFirestore(entity);

  @override
  String getId(Conversation entity) => entity.id;

  // ===== COLLECTION REFERENCES =====

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      firestore.collection('messages');

  // ===== CONVERSATION OPERATIONS (DELEGATED TO MODULES) =====

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
  }) async => _conversationMutationModule.createDirectConversation(
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
  }) async => _conversationMutationModule.createGroupConversation(
    participantIds: participantIds,
    participantDisplayNames: participantDisplayNames,
    participantAvatarUrls: participantAvatarUrls,
    title: title,
    creatorId: creatorId,
  );

  @override
  @Deprecated('Use createDirectConversation directly - it handles "get or create" with deterministic IDs')
  Future<String?> findDirectConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      AppLogger.warning('⚠️ findDirectConversation is DEPRECATED - use createDirectConversation instead');

      final query = await firestore.collection(collectionName)
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

  @override
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async => _conversationMutationModule.addParticipants(
    conversationId: conversationId,
    participantIds: participantIds,
    participantDisplayNames: participantDisplayNames,
    participantAvatarUrls: participantAvatarUrls,
  );

  @override
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async => _conversationMutationModule.removeParticipant(
    conversationId: conversationId,
    participantId: participantId,
  );

  @override
  Future<void> deleteConversation(String conversationId) async =>
      _conversationMutationModule.deleteConversation(conversationId, _messagesRef);

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
  Future<List<String>> getConversationParticipants(String conversationId) async =>
      _conversationQueryModule.getConversationParticipants(conversationId, read);

  @override
  Future<int> getUnreadMessageCount(String userId) async =>
      _conversationQueryModule.getUnreadMessageCount(userId);

  @override
  Future<int> getUnreadConversationsCount(String userId) async =>
      _conversationQueryModule.getUnreadConversationsCount(userId);

  // ===== MESSAGE OPERATIONS (DELEGATED TO MODULES) =====

  @override
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) => _messageQueryModule.getConversationMessages(
    conversationId: conversationId,
    limit: limit,
  );

  @override
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    int limit = 50,
    DateTime? startAfter,
  }) async => _messageQueryModule.getConversationMessagesPage(
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
  }) async => _messageQueryModule.searchMessages(
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
    updateConversation: update,
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

  // ===== AUTO-HEALER PUBLIC API =====

  /// Start real-time self-healing for a conversation.
  void startConversationAutoHealer(String conversationId) =>
      _autoHealerModule.startAutoHealer(conversationId);

  /// Stop auto-healer for a conversation (cleanup).
  void stopConversationAutoHealer(String conversationId) =>
      _autoHealerModule.stopAutoHealer(conversationId);

  /// Stop all auto-healers (call on repository disposal).
  void stopAllAutoHealers() =>
      _autoHealerModule.stopAllAutoHealers();

  // ===== CLEANUP =====

  /// Dispose repository and cleanup all resources including active stream subscriptions.
  void dispose() {
    stopAllAutoHealers();
    AppLogger.debug('FirebaseMessagingRepository disposed');
  }
}
