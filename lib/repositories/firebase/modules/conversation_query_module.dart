// lib/repositories/firebase/modules/conversation_query_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/repositories/firebase/modules/conversation_participant_module.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Conversation query module for read-only operations.
/// Supports both legacy arrayContains queries and new subcollection-based queries.
class ConversationQueryModule {
  final FirebaseFirestore firestore;
  final String collectionName;
  final Conversation Function(DocumentSnapshot<Map<String, dynamic>>)
  fromFirestore;
  final ConversationParticipantModule? participantModule;

  ConversationQueryModule({
    required this.firestore,
    required this.collectionName,
    required this.fromFirestore,
    this.participantModule,
  });

  /// Stream all conversations for a user with real-time updates.
  ///
  /// BUT-778: previously also fanned out per-conversation auto-healer
  /// listeners (~50 per active user). lastMessage sync now happens
  /// server-side via the `syncConversationLastMessage` CF trigger; this
  /// stream is a single arrayContains snapshot listener and nothing else.
  Stream<List<Conversation>> getUserConversations(String userId) {
    try {
      return firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(50) // Limit to 50 most recent conversations
          .snapshots()
          .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
    } catch (e) {
      AppLogger.error(
        'Failed to get user conversations for ${userId.maskedUserId}',
        e,
      );
      return const Stream.empty();
    }
  }

  /// Get a single conversation by ID.
  Future<Conversation?> getConversation(
    String conversationId,
    Future<Conversation?> Function(String) readFn,
  ) async {
    try {
      return await readFn(conversationId);
    } catch (e) {
      AppLogger.error('Failed to get conversation $conversationId', e);
      return null;
    }
  }

  /// Get list of participant IDs for a conversation.
  Future<List<String>> getConversationParticipants(
    String conversationId,
    Future<Conversation?> Function(String) readFn,
  ) async {
    try {
      final conversation = await readFn(conversationId);
      return conversation?.participantIds ?? [];
    } catch (e) {
      AppLogger.error(
        'Failed to get conversation participants: $conversationId',
        e,
      );
      return [];
    }
  }

  /// Get unread message count for user (simplified aggregation).
  ///
  /// Optimized (#040): Limited to 100 conversations to prevent unbounded fetches.
  /// Future optimization: Add `unreadByUser` map field to conversation documents
  /// for server-side filtering with `.count()` aggregation.
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final conversations = await firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true) // Most recent first
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
      AppLogger.error(
        'Failed to get unread message count for ${userId.maskedUserId}',
        e,
      );
      return 0;
    }
  }

  /// Get count of conversations with unread messages.
  ///
  /// Uses inverse index (conversationMemberships) when available for O(1) lookup.
  /// Falls back to legacy arrayContains query otherwise.
  Future<int> getUnreadConversationsCount(String userId) async {
    try {
      // Try inverse index first (much faster for users with many conversations)
      final memberships = await participantModule?.getUserMemberships(userId);
      if (memberships != null && memberships.isNotEmpty) {
        return memberships.where((m) => m.hasUnread).length;
      }

      // Fallback to legacy query
      final conversations = await firestore
          .collection(collectionName)
          .where('participantIds', arrayContains: userId)
          .orderBy('updatedAt', descending: true)
          .limit(500)
          .get();

      return conversations.docs
          .map(fromFirestore)
          .where((conversation) => conversation.hasUnreadMessages(userId))
          .length;
    } catch (e) {
      AppLogger.error(
        'Failed to get unread conversations count for ${userId.maskedUserId}',
        e,
      );
      return 0;
    }
  }

  /// Get conversation IDs for a user using inverse index.
  /// Returns empty list if subcollection participants not enabled.
  Future<List<String>> getConversationIdsViaInverseIndex(String userId) async {
    try {
      final memberships = await participantModule?.getUserMemberships(userId);
      if (memberships == null) return [];
      return memberships.map((m) => m.conversationId).toList();
    } catch (e) {
      AppLogger.error('Failed to get conversation IDs via inverse index', e);
      return [];
    }
  }
}
