// lib/repositories/firebase/firebase_messaging_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase implementation of MessagingRepository
class FirebaseMessagingRepository 
    extends BaseFirebaseRepository<Conversation>
    with UserScopedFirebaseRepository<Conversation>
    implements MessagingRepository {

  FirebaseMessagingRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

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

  // ===== CONVERSATION OPERATIONS =====

  @override
  Stream<List<Conversation>> getUserConversations(String userId) {
    try {
      return firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
    } catch (e) {
      AppLogger.error('Failed to get user conversations for $userId', e);
      return const Stream.empty();
    }
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    try {
      return await read(conversationId);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  @override
  Future<String> createDirectConversation({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  }) async {
    try {
      // Check if conversation already exists
      final existingId = await findDirectConversation(
        user1Id: user1Id,
        user2Id: user2Id,
      );
      
      if (existingId != null) {
        return existingId;
      }

      // Create new conversation
      final conversation = Conversation.direct(
        user1Id: user1Id,
        user1DisplayName: user1DisplayName,
        user1AvatarUrl: user1AvatarUrl,
        user2Id: user2Id,
        user2DisplayName: user2DisplayName,
        user2AvatarUrl: user2AvatarUrl,
      );

      final createdConversation = await create(conversation);
      
      AppLogger.success('✅ Direct conversation created: ${createdConversation.id}');
      return createdConversation.id;
    } catch (e) {
      AppLogger.error('Failed to create direct conversation', e);
      rethrow;
    }
  }

  @override
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
    required String creatorId,
  }) async {
    try {
      final conversation = Conversation.group(
        participantIds: participantIds,
        participantDisplayNames: participantDisplayNames,
        participantAvatarUrls: participantAvatarUrls,
        title: title,
        creatorId: creatorId,
      );

      final createdConversation = await create(conversation);
      
      // Send system message about group creation
      final systemMessage = Message.system(
        conversationId: createdConversation.id,
        content: '${participantDisplayNames[creatorId]} skapade gruppen "$title"',
      );
      
      await sendMessage(systemMessage);
      
      AppLogger.success('✅ Group conversation created: ${createdConversation.id}');
      return createdConversation.id;
    } catch (e) {
      AppLogger.error('Failed to create group conversation', e);
      rethrow;
    }
  }

  @override
  Future<String?> findDirectConversation({
    required String user1Id,
    required String user2Id,
  }) async {
    try {
      final query = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: user1Id)
          .where('isGroup', isEqualTo: false)
          .get();

      for (final doc in query.docs) {
        final conversation = fromFirestore(doc);
        if (conversation.participantIds.contains(user2Id)) {
          return conversation.id;
        }
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to find direct conversation', e);
      return null;
    }
  }

  @override
  Future<void> updateConversation({
    required String conversationId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      final updatedConversation = conversation.copyWith(
        title: title,
        metadata: metadata,
        updatedAt: DateTime.now(),
      );

      await update(updatedConversation);
      
      AppLogger.debug('Conversation updated: $conversationId');
    } catch (e) {
      AppLogger.error('Failed to update conversation $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isGroup) {
        throw ValidationException('Cannot add participants to direct conversation');
      }

      final updatedParticipantIds = [...conversation.participantIds, ...participantIds];
      final updatedDisplayNames = {...conversation.participantDisplayNames, ...participantDisplayNames};
      final updatedAvatarUrls = {...conversation.participantAvatarUrls, ...participantAvatarUrls};
      final updatedLastReadTimestamps = {...conversation.lastReadTimestamps};
      
      // Initialize last read timestamps for new participants
      final now = DateTime.now();
      for (final participantId in participantIds) {
        updatedLastReadTimestamps[participantId] = now;
      }

      final updatedConversation = conversation.copyWith(
        participantIds: updatedParticipantIds,
        participantDisplayNames: updatedDisplayNames,
        participantAvatarUrls: updatedAvatarUrls,
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: now,
      );

      await update(updatedConversation);
      
      // Send system message about participant addition
      for (final participantId in participantIds) {
        final displayName = participantDisplayNames[participantId] ?? 'Okänd användare';
        final systemMessage = Message.system(
          conversationId: conversationId,
          content: '$displayName har lagts till i gruppen',
        );
        await sendMessage(systemMessage);
      }
      
      AppLogger.success('✅ Added ${participantIds.length} participants to conversation $conversationId');
    } catch (e) {
      AppLogger.error('Failed to add participants to conversation $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isGroup) {
        throw ValidationException('Cannot remove participants from direct conversation');
      }

      final updatedParticipantIds = conversation.participantIds.where((id) => id != participantId).toList();
      final updatedDisplayNames = Map<String, String>.from(conversation.participantDisplayNames)..remove(participantId);
      final updatedAvatarUrls = Map<String, String?>.from(conversation.participantAvatarUrls)..remove(participantId);
      final updatedLastReadTimestamps = Map<String, DateTime>.from(conversation.lastReadTimestamps)..remove(participantId);

      final updatedConversation = conversation.copyWith(
        participantIds: updatedParticipantIds,
        participantDisplayNames: updatedDisplayNames,
        participantAvatarUrls: updatedAvatarUrls,
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: DateTime.now(),
      );

      await update(updatedConversation);
      
      // Send system message about participant removal
      final displayName = conversation.participantDisplayNames[participantId] ?? 'Okänd användare';
      final systemMessage = Message.system(
        conversationId: conversationId,
        content: '$displayName har lämnat gruppen',
      );
      await sendMessage(systemMessage);
      
      AppLogger.success('✅ Removed participant $participantId from conversation $conversationId');
    } catch (e) {
      AppLogger.error('Failed to remove participant from conversation $conversationId', e);
      rethrow;
    }
  }

  // ===== MESSAGE OPERATIONS =====

  @override
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) {
    try {
      return _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => MessageDto.fromFirestore(doc))
              .toList()
              .reversed // Reverse to show oldest first
              .toList());
    } catch (e) {
      AppLogger.error('Failed to get messages for conversation $conversationId', e);
      return const Stream.empty();
    }
  }

  @override
  Future<void> sendMessage(Message message) async {
    try {
      // Validate conversation exists and user has access
      final conversation = await read(message.conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: message.conversationId,
        );
      }

      if (!conversation.isParticipant(message.senderId)) {
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
          resource: 'conversation:${message.conversationId}',
          userId: message.senderId,
        );
      }

      // Send message with server timestamp
      final messageData = MessageDto.toFirestore(message);
      await _messagesRef.doc(message.id).set(messageData);

      // Update conversation with last message
      final updatedConversation = conversation.copyWith(
        lastMessage: message.copyWith(status: MessageStatus.sent),
        updatedAt: DateTime.now(),
      );
      await update(updatedConversation);

      AppLogger.debug('Message sent: ${message.id} in conversation ${message.conversationId}');
    } catch (e) {
      AppLogger.error('Failed to send message ${message.id}', e);
      rethrow;
    }
  }

  @override
  Future<void> updateMessageStatus({
    required String messageId,
    required MessageStatus status,
    DateTime? timestamp,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (status) {
        case MessageStatus.delivered:
          updateData['deliveredAt'] = timestamp != null 
              ? Timestamp.fromDate(timestamp) 
              : FieldValue.serverTimestamp();
          break;
        case MessageStatus.read:
          updateData['readAt'] = timestamp != null 
              ? Timestamp.fromDate(timestamp) 
              : FieldValue.serverTimestamp();
          break;
        default:
          break;
      }

      await _messagesRef.doc(messageId).update(updateData);
      
      AppLogger.debug('Message status updated: $messageId -> $status');
    } catch (e) {
      AppLogger.error('Failed to update message status for $messageId', e);
      rethrow;
    }
  }

  @override
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  }) async {
    try {
      await updateMessageStatus(
        messageId: messageId,
        status: MessageStatus.read,
        timestamp: DateTime.now(),
      );
      
      AppLogger.debug('Message marked as read: $messageId by $userId');
    } catch (e) {
      AppLogger.error('Failed to mark message as read: $messageId', e);
      rethrow;
    }
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final conversation = await read(conversationId);
      if (conversation == null) {
        throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        );
      }

      if (!conversation.isParticipant(userId)) {
        throw PermissionDeniedException(
          'User is not a participant in this conversation',
          resource: 'conversation:$conversationId',
          userId: userId,
        );
      }

      final now = DateTime.now();
      final updatedLastReadTimestamps = Map<String, DateTime>.from(conversation.lastReadTimestamps);
      updatedLastReadTimestamps[userId] = now;

      final updatedConversation = conversation.copyWith(
        lastReadTimestamps: updatedLastReadTimestamps,
        updatedAt: now,
      );

      await update(updatedConversation);
      
      AppLogger.debug('Conversation marked as read: $conversationId by $userId');
    } catch (e) {
      AppLogger.error('Failed to mark conversation as read: $conversationId', e);
      rethrow;
    }
  }

  @override
  Future<void> updateMessageContent({
    required String messageId,
    required String newContent,
  }) async {
    try {
      await _messagesRef.doc(messageId).update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      AppLogger.debug('Message content updated: $messageId');
    } catch (e) {
      AppLogger.error('Failed to update message content: $messageId', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messagesRef.doc(messageId).delete();
      
      AppLogger.debug('Message deleted: $messageId');
    } catch (e) {
      AppLogger.error('Failed to delete message: $messageId', e);
      rethrow;
    }
  }

  // ===== UTILITY OPERATIONS =====

  @override
  Future<List<String>> getConversationParticipants(String conversationId) async {
    try {
      final conversation = await read(conversationId);
      return conversation?.participantIds ?? [];
    } catch (e) {
      AppLogger.error('Failed to get conversation participants: $conversationId', e);
      return [];
    }
  }

  @override
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // This is a simplified implementation - in production you might want
      // to use a more efficient aggregation or counter approach
      final conversations = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .get();

      int totalUnread = 0;
      for (final doc in conversations.docs) {
        final conversation = fromFirestore(doc);
        if (conversation.hasUnreadMessages(userId)) {
          // For accurate count, you'd need to query messages
          // This is a simplified version
          totalUnread += 1;
        }
      }

      return totalUnread;
    } catch (e) {
      AppLogger.error('Failed to get unread message count for $userId', e);
      return 0;
    }
  }

  @override
  Future<int> getUnreadConversationsCount(String userId) async {
    try {
      final conversations = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .get();

      return conversations.docs
          .map(fromFirestore)
          .where((conversation) => conversation.hasUnreadMessages(userId))
          .length;
    } catch (e) {
      AppLogger.error('Failed to get unread conversations count for $userId', e);
      return 0;
    }
  }

  @override
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  }) async {
    try {
      // Firestore doesn't support full-text search natively
      // This is a simplified implementation that searches in content
      // In production, you might want to use Algolia or similar
      
      final messages = await _messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit * 3) // Get more to filter
          .get();

      final lowerQuery = query.toLowerCase();
      return messages.docs
          .map((doc) => MessageDto.fromFirestore(doc))
          .where((message) => message.content.toLowerCase().contains(lowerQuery))
          .take(limit)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to search messages in conversation $conversationId', e);
      return [];
    }
  }

  @override
  Future<Message?> getMessage(String messageId) async {
    try {
      final doc = await _messagesRef.doc(messageId).get();
      if (doc.exists) {
        return MessageDto.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get message: $messageId', e);
      return null;
    }
  }

  @override
  Future<void> batchMarkAsDelivered({
    required List<String> messageIds,
    required String userId,
  }) async {
    try {
      final batch = firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (final messageId in messageIds) {
        final messageRef = _messagesRef.doc(messageId);
        batch.update(messageRef, {
          'status': MessageStatus.delivered.name,
          'deliveredAt': timestamp,
          'updatedAt': timestamp,
        });
      }

      await batch.commit();
      
      AppLogger.debug('Batch marked ${messageIds.length} messages as delivered for $userId');
    } catch (e) {
      AppLogger.error('Failed to batch mark messages as delivered', e);
      rethrow;
    }
  }
}