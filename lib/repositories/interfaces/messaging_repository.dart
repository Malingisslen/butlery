// lib/repositories/interfaces/messaging_repository.dart

import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
// MessageStatus and MessageType available through message.dart import

/// Repository interface for real-time messaging and conversation management.
/// This interface provides comprehensive messaging functionality including direct
/// messaging, group conversations, real-time message streaming, and conversation
/// management. It enables users to communicate privately and collaborate effectively
/// within the Butlery social platform.
/// **Core Messaging Features:**
/// - **Direct Conversations**: One-on-one private messaging between users
/// - **Group Conversations**: Multi-participant group messaging and collaboration
/// - **Real-time Messaging**: Live message streaming and instant delivery
/// - **Message Management**: Send, edit, delete, and status tracking for messages
/// - **Conversation Management**: Create, update, and manage conversation metadata
/// - **Participant Management**: Add/remove participants in group conversations
/// **Real-time Capabilities:**
/// - Instant message delivery and receipt confirmation
/// - Live typing indicators and presence information
/// - Real-time conversation and message streams
/// - Message status tracking (sent, delivered, read)
/// - Automatic message synchronization across devices
/// **Conversation Types:**
/// - **Direct**: Private conversations between two users
/// - **Group**: Multi-participant conversations with shared context
/// - **Recipe Collaboration**: Messaging integrated with recipe sharing
/// - **Shopping Coordination**: Messaging for collaborative shopping lists
/// **Privacy and Security:**
/// - Participant-only access to conversation content
/// - Secure message transmission and storage
/// - Conversation metadata protection
/// - User blocking and privacy controls integration
/// **Usage Examples:**
/// ```dart
/// final messagingRepo = ServiceLocator.get<MessagingRepository>();
/// // Create direct conversation
/// final conversationId = await messagingRepo.createDirectConversation(
///   user1Id: currentUserId,
///   user1DisplayName: currentUser.displayName,
///   user2Id: friendId,
///   user2DisplayName: friend.displayName,
/// );
/// // Send message
/// final message = Message(
///   conversationId: conversationId,
///   senderId: currentUserId,
///   content: 'Hey! Want to try this recipe together?',
///   type: MessageType.text,
/// );
/// await messagingRepo.sendMessage(message);
/// // Listen to messages
/// messagingRepo.getConversationMessages(conversationId: conversationId)
///   .listen((messages) {
///     updateMessageList(messages);
///   });
/// ```
abstract class MessagingRepository {
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

  /// Get messages for a conversation
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    int limit = 50,
  });

  /// Get messages for a conversation with pagination support
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    int limit = 50,
    DateTime? startAfter,
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

  /// Delete conversation and all its messages
  Future<void> deleteConversation(String conversationId);

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

  /// Vote on a poll option in a message
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required String voterId,
    required bool allowMultiple,
  });

  /// Close a poll (creator only)
  Future<void> closePoll({
    required String messageId,
    required String closerId,
  });

  /// Update per-user conversation settings (pin, archive, mute)
  Future<void> updateConversationUserSettings({
    required String conversationId,
    required String userId,
    required Map<String, dynamic> settings,
  });
}
