/// Message model with multi-type content support and delivery status tracking.
/// **Features:** Text, recipe/menu/shopping list sharing, images, voice, system messages.
/// **Delivery:** Sent, delivered, read confirmation with timestamps. Reply threading and edit history.
/// ```dart
/// final msg = Message.text(conversationId: id, senderId: uid,
///   senderDisplayName: 'Anna', content: 'Hej!');
/// final shared = Message.recipeShare(conversationId: id, senderId: uid,
///   senderDisplayName: 'Anna', recipeId: recipe.id, recipeTitle: 'Köttbullar');
/// final delivered = msg.copyWith(status: MessageStatus.delivered, deliveredAt: DateTime.now());
/// ```

// lib/models/messaging/message.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:uuid/uuid.dart';

// Re-export enums for convenience
export 'package:butlery/models/messaging/message_type.dart'
    show MessageType, MessageStatus;

/// Comprehensive message model with multi-type content support and delivery status tracking for messaging infrastructure.
/// Represents a complete messaging unit with support for various content types, delivery tracking,
/// reply functionality, and comprehensive metadata management. This class serves as the foundation
/// for all message-based communication features in the messaging system.
class Message {
  /// Unique identifier for this message instance.
  /// Auto-generated UUID ensuring unique identification across all messaging systems
  /// and enabling reliable message tracking throughout the messaging infrastructure.
  final String id;

  /// Identifier of the conversation this message belongs to.
  /// References the parent conversation for message routing, context management,
  /// and conversation-level operations like read status and participant management.
  final String conversationId;

  /// User identifier of the message sender for attribution and permissions.
  /// References the user who created and sent the message, used for sender attribution,
  /// permission validation, and message ownership operations throughout the UI.
  final String senderId;

  /// Cached display name of the message sender for UI performance optimization.
  /// Stored locally to avoid additional user profile lookups during message display,
  /// sender attribution, and conversation participant identification in messaging interfaces.
  final String senderDisplayName;

  /// Cached avatar URL of the message sender for UI performance optimization.
  /// Stored locally to avoid additional profile lookups during message display and
  /// sender visual representation in messaging interfaces. Nullable for users without avatars.
  final String? senderAvatarUrl;

  /// Primary content of the message for display and communication.
  /// Contains the main message text, description, or content depending on message type.
  /// For text messages: the actual text. For sharing messages: descriptive text or title.
  final String content;

  /// Type classification of the message determining content handling and display.
  /// Defines how the message should be processed, displayed, and interacted with based
  /// on content type (text, recipe share, system message, etc.).
  final MessageType type;

  /// Current delivery status of the message for tracking and UI state management.
  /// Tracks message progression through delivery lifecycle from sending through
  /// final read confirmation, enabling appropriate UI indicators and retry logic.
  final MessageStatus status;

  /// Timestamp when the message was originally sent by the sender.
  /// Used for chronological message ordering, message timeline displays,
  /// and message aging calculations for UI presentation and analytics.
  final DateTime sentAt;

  /// Optional timestamp when the message was delivered to recipient's device.
  /// Set when message delivery confirmation is received, enabling delivery status
  /// indicators and message delivery analytics for conversation quality tracking.
  final DateTime? deliveredAt;

  /// Optional timestamp when the message was read by the recipient.
  /// Set when read receipt is received, enabling read status indicators and
  /// conversation engagement analytics for user interaction insights.
  final DateTime? readAt;

  /// Flexible metadata container for message-specific information and content references.
  /// Stores additional message data including content IDs (recipe, menu, shopping list),
  /// media information, reply context, and message-specific configurations for rich content support.
  final Map<String, dynamic>?
      metadata; // For content-specific data (recipe ID, etc.)

  /// Optional reference to parent message for reply threading functionality.
  /// Contains the ID of the message being replied to, enabling threaded conversation
  /// display and reply context tracking for enhanced conversation navigation.
  final String? replyToMessageId; // For message replies

  /// Flag indicating whether this message has been edited after original sending.
  /// Tracks message edit status for UI indicators, edit history tracking,
  /// and conversation integrity management in messaging displays.
  final bool isEdited;

  /// Optional timestamp when the message was last edited by the sender.
  /// Set when message content is modified, enabling edit history tracking
  /// and edit timeline displays for message management and conversation context.
  final DateTime? editedAt;

  /// Emoji reactions on this message. Maps emoji string to list of user IDs who reacted.
  final Map<String, List<String>> reactions;

  /// Creates a new message with comprehensive configuration and delivery tracking.
  /// This constructor provides complete message initialization with support for all message
  /// types, delivery status tracking, reply functionality, and metadata management. Used
  /// for creating messages with full control over all properties and states.
  /// [id] Required unique identifier for message tracking
  /// [conversationId] Required conversation ID for message routing
  /// [senderId] Required sender user ID for attribution and permissions
  /// [senderDisplayName] Required sender display name for UI performance
  /// [senderAvatarUrl] Optional sender avatar URL for UI performance
  /// [content] Required message content for display and communication
  /// [type] Required message type for content handling and display
  /// [status] Required delivery status for tracking and UI state
  /// [sentAt] Required send timestamp for chronological ordering
  /// [deliveredAt] Optional delivery timestamp for delivery tracking
  /// [readAt] Optional read timestamp for read receipt functionality
  /// [metadata] Optional metadata container for content-specific information
  /// [replyToMessageId] Optional parent message ID for reply threading
  /// [isEdited] Flag indicating edit status, defaults to false for new messages
  /// [editedAt] Optional edit timestamp for edit history tracking
  /// [reactions] Map of emoji to list of user IDs who reacted with that emoji
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
    this.reactions = const {},
  });

  /// Factory constructors for simplified message creation with specific content types.

  /// Creates a new text message with automatic configuration and timestamp generation.
  /// This factory provides streamlined creation for standard text messages with automatic
  /// ID generation, timestamp setting, and initial status configuration. Supports reply
  /// functionality for threaded conversations and includes sender caching for UI performance.
  /// [conversationId] Required conversation ID for message routing
  /// [senderId] Required sender user ID for attribution and permissions
  /// [senderDisplayName] Required sender display name for UI performance
  /// [senderAvatarUrl] Optional sender avatar URL for UI performance
  /// [content] Required text content for message communication
  /// [replyToMessageId] Optional parent message ID for reply threading
  /// Returns a new [Message] configured for text communication with sending status.
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

  /// Creates a recipe sharing message with content reference and automatic formatting.
  /// This factory provides streamlined creation for recipe sharing messages with automatic
  /// content formatting, metadata management, and recipe reference tracking. Includes
  /// optional custom message text and automatic fallback formatting with Swedish localization.
  /// [conversationId] Required conversation ID for message routing
  /// [senderId] Required sender user ID for attribution and permissions
  /// [senderDisplayName] Required sender display name for UI performance
  /// [senderAvatarUrl] Optional sender avatar URL for UI performance
  /// [recipeId] Required recipe ID for content reference and navigation
  /// [recipeTitle] Required recipe title for display and content identification
  /// [message] Optional custom message text, defaults to Swedish-localized sharing text
  /// Returns a new [Message] configured for recipe sharing with metadata and sending status.
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
      content: message ?? AppLocale.current.messageSharedRecipe(recipeTitle),
      type: MessageType.recipeShare,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
      metadata: {
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
      },
    );
  }

  /// Creates a menu sharing message with embedded menu information and Swedish localization.
  /// This factory provides streamlined creation for menu sharing messages with automatic
  /// content formatting, metadata management, and menu reference tracking. Includes
  /// optional custom message text and automatic fallback formatting with Swedish localization.
  factory Message.menuShare({
    required String conversationId,
    required String senderId,
    required String senderDisplayName,
    String? senderAvatarUrl,
    required String menuId,
    required String menuTitle,
    String? message,
  }) {
    return Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      senderAvatarUrl: senderAvatarUrl,
      content: message ?? AppLocale.current.messageSharedMenu(menuTitle),
      type: MessageType.menuShare,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
      metadata: {
        'menuId': menuId,
        'menuTitle': menuTitle,
      },
    );
  }

  /// Creates a shopping list sharing message with embedded list information and Swedish localization.
  /// This factory provides streamlined creation for shopping list sharing messages with automatic
  /// content formatting, metadata management, and list reference tracking. Includes
  /// optional custom message text and automatic fallback formatting with Swedish localization.
  factory Message.shoppingListShare({
    required String conversationId,
    required String senderId,
    required String senderDisplayName,
    String? senderAvatarUrl,
    required String listId,
    required String listTitle,
    String? message,
  }) {
    return Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      senderId: senderId,
      senderDisplayName: senderDisplayName,
      senderAvatarUrl: senderAvatarUrl,
      content:
          message ?? AppLocale.current.messageSharedShoppingList(listTitle),
      type: MessageType.shoppingListShare,
      status: MessageStatus.sending,
      sentAt: DateTime.now(),
      metadata: {
        'listId': listId,
        'listTitle': listTitle,
      },
    );
  }

  /// Creates a system message for conversation events and administrative notifications.
  /// This factory provides streamlined creation for system-generated messages including
  /// conversation events, administrative notifications, and automated announcements.
  /// System messages are automatically marked as delivered and use consistent system attribution.
  /// [conversationId] Required conversation ID for message routing
  /// [content] Required system message content for event description or notification text
  /// Returns a new [Message] configured for system messaging with delivered status and system attribution.
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

  /// Utility methods for message manipulation and immutable updates.

  /// Creates a copy of this message with updated values while preserving immutability.
  /// Used for all message modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for delivery status updates, content edits, and metadata changes.
  /// Commonly used for updating delivery status, read receipts, and edit history.
  Message copyWith({
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? content,
    bool? isEdited,
    DateTime? editedAt,
    Map<String, dynamic>? metadata,
    Map<String, List<String>>? reactions,
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
      reactions: reactions ?? this.reactions,
    );
  }

  /// Content display methods for UI presentation and message formatting.

  /// Gets formatted display content based on message type with appropriate icons and Swedish localization.
  /// Provides type-specific content formatting for message display including icons for rich content,
  /// metadata extraction for shared content titles, and Swedish-localized fallback text for
  /// optimal user experience across all message types and content sharing scenarios.
  /// Returns formatted display content with icons and titles appropriate for the message type.
  String get displayContent {
    final l = AppLocale.current;
    switch (type) {
      case MessageType.text:
        return content;
      case MessageType.recipeShare:
        return '${type.icon} ${metadata?['recipeTitle'] ?? l.messageContentRecipe}';
      case MessageType.menuShare:
        return '${type.icon} ${metadata?['menuTitle'] ?? l.messageContentMenu}';
      case MessageType.shoppingListShare:
        return '${type.icon} ${metadata?['listTitle'] ?? l.messageContentShoppingList}';
      case MessageType.system:
        return content;
      case MessageType.image:
        return '${type.icon} ${l.messageContentImage}';
      case MessageType.voice:
        return '${type.icon} ${l.messageContentVoice}';
      case MessageType.poll:
        final pollData = metadata?['poll'] as Map<String, dynamic>?;
        return '${type.icon} ${pollData?['question'] ?? content}';
    }
  }

  /// Message state validation methods for UI control and conversation management.

  /// Checks if the message was sent by the specified current user for UI positioning and control.
  /// Compares the message sender ID with the current user ID to determine message ownership
  /// for appropriate UI positioning (left/right), action availability, and message attribution
  /// in conversation displays and interaction handling.
  bool isFromCurrentUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Checks if the message has been read by recipients based on read receipt timestamp.
  /// Returns true when read receipt timestamp is set, indicating the message has been
  /// viewed by recipients. Used for read status indicators and conversation engagement tracking.
  bool get isRead => readAt != null;

  /// Checks if the message has been delivered to recipient devices based on delivery status.
  /// Returns true when delivery timestamp is set or message has been read (read implies delivery).
  /// Used for delivery status indicators and message transmission tracking in conversation UI.
  bool get isDelivered => deliveredAt != null || isRead;

  /// Checks if the message is a reply to another message for threading and context display.
  /// Returns true when reply-to message ID is set, indicating this message is part of a thread.
  /// Used for reply UI indicators, conversation threading, and context navigation features.
  bool get isReply => replyToMessageId != null;

  /// Checks if the message is a system-generated message for special handling and display.
  /// Returns true for system messages that represent conversation events or administrative
  /// notifications. Used for different UI styling and interaction behavior for system content.
  bool get isSystemMessage => type == MessageType.system;

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the message for debugging and logging.
  /// Provides essential message information in a readable format for development
  /// and debugging purposes with message type, content preview, status, and timestamp.
  @override
  String toString() {
    return 'Message(id: $id, type: $type, content: $content, status: $status, sentAt: $sentAt)';
  }

  /// Compares two messages for equality based on unique identifier.
  /// Uses message ID for equality comparison ensuring consistent object identity
  /// across different instances of the same message data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  /// Generates hash code based on unique message identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and message identification.
  @override
  int get hashCode => id.hashCode;
}
