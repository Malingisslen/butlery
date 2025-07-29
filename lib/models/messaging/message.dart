// lib/models/messaging/message.dart

import 'package:butlery/models/messaging/message_type.dart';
import 'package:uuid/uuid.dart';

/// Model representing a single message in a conversation
class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderDisplayName;
  final String? senderAvatarUrl;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata; // For content-specific data (recipe ID, etc.)
  final String? replyToMessageId; // For message replies
  final bool isEdited;
  final DateTime? editedAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderDisplayName,
    this.senderAvatarUrl,
    required this.content,
    required this.type,
    required this.status,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.metadata,
    this.replyToMessageId,
    this.isEdited = false,
    this.editedAt,
  });

  /// Create a new text message
  factory Message.text({
    required String conversationId,
    required String senderId,
    required String senderDisplayName,
    String? senderAvatarUrl,
    required String content,
    String? replyToMessageId,
  }) {
    return Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      senderAvatarUrl: senderAvatarUrl,
      content: content,
      type: MessageType.text,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
    );
  }

  /// Create a recipe share message
  factory Message.recipeShare({
    required String conversationId,
    required String senderId,
    required String senderDisplayName,
    String? senderAvatarUrl,
    required String recipeId,
    required String recipeTitle,
    String? message,
  }) {
    return Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      senderAvatarUrl: senderAvatarUrl,
      content: message ?? 'Delade ett recept: $recipeTitle',
      type: MessageType.recipeShare,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
      metadata: {
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
      },
    );
  }

  /// Create a system message
  factory Message.system({
    required String conversationId,
    required String content,
  }) {
    return Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: 'system',
      senderDisplayName: 'System',
      content: content,
      type: MessageType.system,
      status: MessageStatus.delivered,
      sentAt: DateTime.now(),
    );
  }


  /// Create a copy with updated fields
  Message copyWith({
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? content,
    bool? isEdited,
    DateTime? editedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      senderAvatarUrl: senderAvatarUrl,
      content: content ?? this.content,
      type: type,
      status: status ?? this.status,
      sentAt: sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
      replyToMessageId: replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  /// Get display content based on message type
  String get displayContent {
    switch (type) {
      case MessageType.text:
        return content;
      case MessageType.recipeShare:
        return '${type.icon} ${metadata?['recipeTitle'] ?? 'Recept'}';
      case MessageType.menuShare:
        return '${type.icon} ${metadata?['menuTitle'] ?? 'Meny'}';
      case MessageType.shoppingListShare:
        return '${type.icon} ${metadata?['listTitle'] ?? 'Inköpslista'}';
      case MessageType.system:
        return content;
      case MessageType.image:
        return '${type.icon} Bild';
      case MessageType.voice:
        return '${type.icon} Röstmeddelande';
    }
  }

  /// Check if message is from current user
  bool isFromCurrentUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Check if message has been read
  bool get isRead => readAt != null;

  /// Check if message has been delivered
  bool get isDelivered => deliveredAt != null || isRead;

  /// Check if message is a reply
  bool get isReply => replyToMessageId != null;

  /// Check if message is a system message
  bool get isSystemMessage => type == MessageType.system;

  @override
  String toString() {
    return 'Message(id: $id, type: $type, content: $content, status: $status, sentAt: $sentAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}