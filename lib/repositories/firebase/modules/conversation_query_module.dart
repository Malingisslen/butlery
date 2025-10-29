// lib/repositories/firebase/modules/conversation_query_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Conversation query module for read-only operations.
class ConversationQueryModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final Conversation Function(DocumentSnapshot<Map<String, dynamic>>) fromFirestore;
  final void Function(String) startAutoHealer;

  ConversationQueryModule({
    required this.firestore,
    required this.collectionName,
    required this.fromFirestore,
    required this.startAutoHealer,
  });

  /// Stream all conversations for a user with real-time updates.
  /// Auto-starts healers for all conversations.
  Stream<List<Conversation>> getUserConversations(String userId) {
    try {
      return firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(50) // Limit to 50 most recent conversations
          .snapshots()
          .map((snapshot) {
            final conversations = snapshot.docs.map(fromFirestore).toList();

            // Auto-start healers for all conversations
            for (final conversation in conversations) {
              startAutoHealer(conversation.id);
            }

            return conversations;
          });
    } catch (e) {
      AppLogger.error('Failed to get user conversations for $userId', e);
      return const Stream.empty();
    }
  }

  /// Get a single conversation by ID.
  Future<Conversation?> getConversation(String conversationId,
      Future<Conversation?> Function(String) readFn) async {
    try {
      return await readFn(conversationId);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  /// Get list of participant IDs for a conversation.
  Future<List<String>> getConversationParticipants(String conversationId,
      Future<Conversation?> Function(String) readFn) async {
    try {
      final conversation = await readFn(conversationId);
      return conversation?.participantIds ?? [];
    } catch (e) {
      AppLogger.error('Failed to get conversation participants: $conversationId', e);
      return [];
    }
  }

  /// Get unread message count for user (simplified aggregation).
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final conversations = await firestore.collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .limit(100) // Limit to 100 most recent conversations
          .get();

      int totalUnread = 0;
      for (final doc in conversations.docs) {
        final conversation = fromFirestore(doc);
        if (conversation.hasUnreadMessages(userId)) {
          totalUnread += 1;
        }
      }

      return totalUnread;
    } catch (e) {
      AppLogger.error('Failed to get unread message count for $userId', e);
      return 0;
    }
  }

  /// Get count of conversations with unread messages.
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
}
