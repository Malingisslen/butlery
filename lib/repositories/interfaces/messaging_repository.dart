// lib/repositories/interfaces/messaging_repository.dart

import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message_type.dart';

/// Repository interface for messaging operations
abstract class MessagingRepository {
  // ===== CONVERSATION OPERATIONS =====
  
  /// Get all conversations for a user
  Stream<List<Conversation>> getUserConversations(String userId);
  
  /// Get a specific conversation by ID
  Future<Conversation?> getConversation(String conversationId);
  
  /// Create a new direct conversation between two users
  Future<String> createDirectConversation({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  });
  
  /// Create a new group conversation
  Future<String> createGroupConversation({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
    required String creatorId,
  });
  
  /// Find existing direct conversation between two users
  Future<String?> findDirectConversation({
    required String user1Id,
    required String user2Id,
  });
  
  /// Update conversation metadata
  Future<void> updateConversation({
    required String conversationId,
    String? title,
    Map<String, dynamic>? metadata,
  });
  
  /// Add participants to group conversation
  Future<void> addParticipants({
    required String conversationId,
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
  });
  
  /// Remove participant from group conversation
  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  });
  
  // ===== MESSAGE OPERATIONS =====
  
  /// Get messages for a conversation
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  });
  
  /// Send a new message
  Future<void> sendMessage(Message message);
  
  /// Update message status (delivered, read, etc.)
  Future<void> updateMessageStatus({
    required String messageId,
    required MessageStatus status,
    DateTime? timestamp,
  });
  
  /// Mark message as read
  Future<void> markMessageAsRead({
    required String messageId,
    required String userId,
  });
  
  /// Mark all messages in conversation as read
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  });
  
  /// Update message content (for editing)
  Future<void> updateMessageContent({
    required String messageId,
    required String newContent,
  });
  
  /// Delete message
  Future<void> deleteMessage(String messageId);
  
  // ===== UTILITY OPERATIONS =====
  
  /// Get conversation participants
  Future<List<String>> getConversationParticipants(String conversationId);
  
  /// Get unread message count for user
  Future<int> getUnreadMessageCount(String userId);
  
  /// Get unread conversations count for user
  Future<int> getUnreadConversationsCount(String userId);
  
  /// Search messages in conversation
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 20,
  });
  
  /// Get message by ID
  Future<Message?> getMessage(String messageId);
  
  /// Batch mark messages as delivered
  Future<void> batchMarkAsDelivered({
    required List<String> messageIds,
    required String userId,
  });
}