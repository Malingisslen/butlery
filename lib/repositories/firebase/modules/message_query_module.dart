// lib/repositories/firebase/modules/message_query_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/utils/logger.dart';

/// Message query module for read-only message operations.
class MessageQueryModule {
  final CollectionReference<Map<String, dynamic>> messagesRef;

  MessageQueryModule({
    required this.messagesRef,
  });

  /// Stream conversation messages with real-time updates.
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  }) {
    try {
      AppLogger.info(
          '🔍 [MessageQuery] Creating message stream for conversationId: $conversationId');
      return messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        AppLogger.debug(
            '📬 [MessageQuery] Stream update: ${snapshot.docs.length} messages for conversation $conversationId');
        final messages = snapshot.docs
            .map((doc) => MessageDto.fromFirestore(doc))
            .toList()
            .reversed // Reverse to show oldest first
            .toList();
        return messages;
      });
    } catch (e) {
      AppLogger.error(
          '❌ [MessageQuery] Failed to get messages for conversation $conversationId',
          e);
      return const Stream.empty();
    }
  }

  /// Get paginated messages for conversation.
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    int limit = 50,
    DateTime? startAfter,
  }) async {
    try {
      var query = messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true);

      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter)]);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => MessageDto.fromFirestore(doc))
          .toList()
          .reversed // Reverse to show oldest first
          .toList();
    } catch (e) {
      AppLogger.error(
          'Failed to get messages page for conversation $conversationId', e);
      return [];
    }
  }

  /// Get a single message by ID.
  Future<Message?> getMessage(String messageId) async {
    try {
      final doc = await messagesRef.doc(messageId).get();
      if (doc.exists) {
        return MessageDto.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get message: $messageId', e);
      return null;
    }
  }

  /// Search messages in conversation (simplified implementation).
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  }) async {
    try {
      // Firestore doesn't support full-text search natively
      // This is a simplified implementation that searches in content
      // In production, consider using Algolia or similar

      final messages = await messagesRef
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('sentAt', descending: true)
          .limit(limit * 3) // Get more to filter
          .get();

      final lowerQuery = query.toLowerCase();
      return messages.docs
          .map((doc) => MessageDto.fromFirestore(doc))
          .where(
              (message) => message.content.toLowerCase().contains(lowerQuery))
          .take(limit)
          .toList();
    } catch (e) {
      AppLogger.error(
          'Failed to search messages in conversation $conversationId', e);
      return [];
    }
  }
}
