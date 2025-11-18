/// Comprehensive conversation model providing advanced messaging infrastructure for multi-participant communication.
/// This model implements sophisticated conversation management following Single Responsibility Principle,
/// handling all aspects of messaging conversations including participant management, read status tracking,
/// group conversation features, and comprehensive UI integration. It provides complete conversation
/// infrastructure while maintaining clean separation from message content and UI presentation concerns.
/// **Single Responsibility Focus:**
/// This model exclusively handles conversation structure and participant coordination:
/// - **Participant Management**: Complete participant tracking with display names, avatars, and read status management
/// - **Conversation Types**: Unified support for both direct (1:1) and group conversations with appropriate feature sets
/// - **Read Status Tracking**: Advanced read receipt system with per-participant timestamp tracking and unread counting
/// - **Display Integration**: Rich UI helper methods for conversation titles, avatars, and activity summaries
/// **What This Model Does NOT Handle:**
/// - Individual message content and delivery (handled by Message model and messaging services)
/// - Message persistence and synchronization (handled by messaging repositories and real-time services)
/// - UI presentation and interaction handling (handled by ViewModels and UI components)
/// - Push notifications and messaging alerts (handled by notification services)
/// **Conversation Features:**
/// - **Dual-Mode Support**: Seamless handling of both direct conversations and group chats with appropriate feature adaptation
/// - **Participant Intelligence**: Complete participant management with cached display information for UI performance
/// - **Read Receipt System**: Advanced per-participant read tracking with unread message counting and status indicators
/// - **Swedish Localization**: Complete Swedish language support for conversation titles, status messages, and activity displays
/// - **Flexible Metadata**: Extensible metadata system for conversation-specific information and future feature extensions
/// **Usage Examples:**
/// ```dart
/// // Create a direct conversation between two users
/// final directConversation = Conversation.direct(
///   user1Id: currentUserId,
///   user1DisplayName: 'Anna Andersson',
///   user1AvatarUrl: currentUser.avatarUrl,
///   user2Id: friendUserId,
///   user2DisplayName: 'Erik Svensson',
///   user2AvatarUrl: friend.avatarUrl,
/// );
/// // Create a group conversation
/// final groupConversation = Conversation.group(
///   participantIds: [userId1, userId2, userId3],
///   participantDisplayNames: {
///     userId1: 'Anna', userId2: 'Erik', userId3: 'Maria'
///   },
///   participantAvatarUrls: avatarMap,
///   title: 'Veckans middagsplanering',
///   creatorId: currentUserId,
/// );
/// // Update conversation with new message and read status
/// final updatedConversation = conversation.copyWith(
///   lastMessage: newMessage,
///   updatedAt: DateTime.now(),
///   lastReadTimestamps: {...conversation.lastReadTimestamps, userId: DateTime.now()},
/// );
/// // Check conversation status and display information
/// final hasUnread = conversation.hasUnreadMessages(currentUserId);
/// final unreadCount = conversation.getUnreadCount(currentUserId, recentMessages);
/// final displayTitle = conversation.getDisplayTitle(currentUserId);
/// final avatarUrl = conversation.getDisplayAvatarUrl(currentUserId);
/// ```

// lib/models/messaging/conversation.dart

import 'package:butlery/models/messaging/message.dart';
import 'package:uuid/uuid.dart';

/// Comprehensive conversation model with participant management and read status tracking for messaging infrastructure.
/// Represents a complete messaging conversation with support for both direct and group communications,
/// comprehensive participant tracking, read receipt management, and rich UI integration capabilities.
/// This class serves as the foundation for all conversation-based messaging features.
class Conversation {
  /// Unique identifier for this conversation instance.
  /// Auto-generated UUID ensuring unique identification across all messaging systems
  /// and enabling reliable conversation tracking throughout the messaging infrastructure.
  final String id;

  /// List of user IDs participating in this conversation.
  /// Contains all participant user IDs for both direct (2 participants) and group conversations.
  /// Used for participant validation, message routing, and conversation access control.
  final List<String> participantIds;

  /// Cached display names of all conversation participants for UI performance optimization.
  /// Maps participant user IDs to their display names to avoid additional user profile lookups
  /// during conversation display, message attribution, and participant list presentations.
  final Map<String, String> participantDisplayNames;

  /// Cached avatar URLs of all conversation participants for UI performance optimization.
  /// Maps participant user IDs to their avatar URLs (nullable) to avoid additional profile lookups
  /// during conversation display and participant visual representation in messaging interfaces.
  final Map<String, String?> participantAvatarUrls;

  /// Most recent message in the conversation for preview and activity tracking.
  /// Cached reference to the latest message for conversation list displays, unread status
  /// determination, and activity timeline tracking without requiring full message history queries.
  final Message? lastMessage;

  /// Per-participant read receipt timestamps for unread message tracking.
  /// Maps participant user IDs to their last read timestamps enabling accurate unread message
  /// counting, read receipt indicators, and conversation activity status for each participant.
  final Map<String, DateTime> lastReadTimestamps;

  /// Timestamp when the conversation was originally created.
  /// Used for chronological conversation sorting, conversation lifecycle tracking,
  /// and historical conversation management and analytics operations.
  final DateTime createdAt;

  /// Timestamp when the conversation was last updated with activity.
  /// Tracks the most recent conversation activity for sorting conversation lists,
  /// determining conversation freshness, and managing conversation lifecycle states.
  final DateTime updatedAt;

  /// Optional custom title for group conversations enabling personalized identification.
  /// Used for group conversations to provide meaningful conversation names beyond
  /// participant lists. Null for direct conversations which use participant names.
  final String? title;

  /// Flag indicating whether this is a group conversation supporting multiple participants.
  /// Determines conversation type behavior with true for group conversations (>2 participants)
  /// and false for direct conversations (exactly 2 participants) enabling appropriate feature sets.
  final bool isGroup;

  /// Flexible metadata container for conversation-specific information and future extensions.
  /// Extensible storage for additional conversation data including creator information,
  /// conversation settings, feature flags, and conversation-specific configurations.
  final Map<String, dynamic>? metadata;

  /// Indicates if conversation is pinned to top of list
  final bool isPinned;

  /// Indicates if conversation is archived (hidden from main list)
  final bool isArchived;

  /// Indicates if notifications are muted for this conversation
  final bool isMuted;

  /// Timestamp when conversation was pinned (null if not pinned)
  final DateTime? pinnedAt;

  /// Timestamp when conversation was archived (null if not archived)
  final DateTime? archivedAt;

  /// Creates a new conversation with comprehensive participant and metadata configuration.
  /// This constructor provides complete conversation initialization with support for both
  /// direct and group conversations. All participant information is cached for UI performance,
  /// and read timestamps are initialized for all participants.
  /// [id] Required unique identifier for conversation tracking
  /// [participantIds] Required list of participant user IDs for access control
  /// [participantDisplayNames] Required participant display names map for UI performance
  /// [participantAvatarUrls] Required participant avatar URLs map for UI performance
  /// [lastMessage] Optional most recent message for conversation previews
  /// [lastReadTimestamps] Required read timestamps map for unread message tracking
  /// [createdAt] Required creation timestamp for chronological sorting
  /// [updatedAt] Required last update timestamp for activity tracking
  /// [title] Optional custom title for group conversations
  /// [isGroup] Required flag indicating conversation type (direct vs group)
  /// [metadata] Optional metadata container for additional conversation information
  const Conversation({
    required this.id,
    required this.participantIds,
    required this.participantDisplayNames,
    required this.participantAvatarUrls,
    this.lastMessage,
    required this.lastReadTimestamps,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    required this.isGroup,
    this.metadata,
    this.isPinned = false,
    this.isArchived = false,
    this.isMuted = false,
    this.pinnedAt,
    this.archivedAt,
  });

  /// Factory constructors for simplified conversation creation with specific configurations.

  /// Creates a new direct conversation between exactly two users with automatic setup.
  /// This factory provides streamlined creation for 1:1 conversations with automatic
  /// participant mapping, read timestamp initialization, and UUID generation. Sets up
  /// both participants with synchronized read status for immediate messaging capability.
  /// [user1Id] Required first participant user ID
  /// [user1DisplayName] Required first participant display name for UI
  /// [user1AvatarUrl] Optional first participant avatar URL for UI
  /// [user2Id] Required second participant user ID
  /// [user2DisplayName] Required second participant display name for UI
  /// [user2AvatarUrl] Optional second participant avatar URL for UI
  /// Returns a new [Conversation] configured for direct messaging with synchronized timestamps.
  factory Conversation.direct({
    required String user1Id,
    required String user1DisplayName,
    String? user1AvatarUrl,
    required String user2Id,
    required String user2DisplayName,
    String? user2AvatarUrl,
  }) {
    final now = DateTime.now();
    final conversationId = const Uuid().v4();
    
    return Conversation(
      id: conversationId,
      participantIds: [user1Id, user2Id],
      participantDisplayNames: {
        user1Id: user1DisplayName,
        user2Id: user2DisplayName,
      },
      participantAvatarUrls: {
        user1Id: user1AvatarUrl,
        user2Id: user2AvatarUrl,
      },
      lastReadTimestamps: {
        user1Id: now,
        user2Id: now,
      },
      createdAt: now,
      updatedAt: now,
      isGroup: false,
    );
  }

  /// Creates a new group conversation with multiple participants and comprehensive setup.
  /// This factory provides complete group conversation creation with participant management,
  /// custom title support, creator tracking, and synchronized read timestamp initialization
  /// for all participants. Includes creator metadata for administrative capabilities.
  /// [participantIds] Required list of all participant user IDs for the group
  /// [participantDisplayNames] Required map of participant IDs to display names for UI
  /// [participantAvatarUrls] Required map of participant IDs to avatar URLs for UI
  /// [title] Required custom title for group identification and display
  /// [creatorId] Required creator user ID for administrative tracking and permissions
  /// Returns a new [Conversation] configured for group messaging with creator metadata.
  factory Conversation.group({
    required List<String> participantIds,
    required Map<String, String> participantDisplayNames,
    required Map<String, String?> participantAvatarUrls,
    required String title,
    required String creatorId,
  }) {
    final now = DateTime.now();
    final conversationId = const Uuid().v4();
    
    // Initialize last read timestamps for all participants
    final lastReadTimestamps = <String, DateTime>{};
    for (final participantId in participantIds) {
      lastReadTimestamps[participantId] = now;
    }
    
    return Conversation(
      id: conversationId,
      participantIds: participantIds,
      participantDisplayNames: participantDisplayNames,
      participantAvatarUrls: participantAvatarUrls,
      lastReadTimestamps: lastReadTimestamps,
      createdAt: now,
      updatedAt: now,
      title: title,
      isGroup: true,
      metadata: {
        'creatorId': creatorId,
      },
    );
  }


  /// Utility methods for conversation manipulation and immutable updates.

  /// Creates a copy of this conversation with updated values while preserving immutability.
  /// Used for all conversation modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for conversation updates, message additions, and participant changes.
  Conversation copyWith({
    Message? lastMessage,
    Map<String, DateTime>? lastReadTimestamps,
    DateTime? updatedAt,
    String? title,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Map<String, String?>? participantAvatarUrls,
    Map<String, dynamic>? metadata,
    bool? isPinned,
    bool? isArchived,
    bool? isMuted,
    DateTime? pinnedAt,
    DateTime? archivedAt,
  }) {
    return Conversation(
      id: id,
      participantIds: participantIds ?? this.participantIds,
      participantDisplayNames: participantDisplayNames ?? this.participantDisplayNames,
      participantAvatarUrls: participantAvatarUrls ?? this.participantAvatarUrls,
      lastMessage: lastMessage ?? this.lastMessage,
      lastReadTimestamps: lastReadTimestamps ?? this.lastReadTimestamps,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
      isGroup: isGroup,
      metadata: metadata ?? this.metadata,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  /// Display utility methods for UI presentation and user experience optimization.

  /// Gets the appropriate display title for the conversation based on type and current user.
  /// For group conversations: returns custom title or default "Gruppchatt" with Swedish localization.
  /// For direct conversations: returns the other participant's display name with fallback handling.
  /// Used for conversation list displays, navigation headers, and conversation identification.
  String getDisplayTitle(String currentUserId) {
    if (isGroup) {
      return title ?? 'Gruppchatt';
    }
    
    // For direct conversations, show the other participant's name
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    
    return participantDisplayNames[otherParticipantId] ?? 'Okänd användare';
  }

  /// Gets the appropriate avatar URL for conversation display based on type and current user.
  /// For group conversations: returns null as groups don't have single representative avatars.
  /// For direct conversations: returns the other participant's avatar URL for visual identification.
  /// Used for conversation list displays and conversation header avatar presentation.
  String? getDisplayAvatarUrl(String currentUserId) {
    if (isGroup) {
      return null; // Group conversations don't have a single avatar
    }
    
    final otherParticipantId = participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    
    return participantAvatarUrls[otherParticipantId];
  }

  /// Gets the other participant ID for direct conversations enabling 1:1 messaging operations.
  /// For direct conversations: returns the participant ID that is not the current user.
  /// For group conversations: returns null as there is no single "other" participant.
  /// Used for direct message routing, typing indicators, and 1:1 conversation features.
  String? getOtherParticipantId(String currentUserId) {
    if (isGroup) return null;
    
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
  }

  /// Read status and participant management methods for conversation state tracking.

  /// Checks if the specified user has unread messages in this conversation.
  /// Compares the user's last read timestamp with the last message timestamp to determine
  /// unread status. Returns false if no messages exist or true if last message is newer
  /// than user's last read time. Used for conversation list unread indicators.
  bool hasUnreadMessages(String userId) {
    if (lastMessage == null) return false;
    
    final lastReadTime = lastReadTimestamps[userId];
    if (lastReadTime == null) return true;
    
    return lastMessage!.sentAt.isAfter(lastReadTime);
  }

  /// Gets the count of unread messages for the specified user in this conversation.
  /// Analyzes recent messages against the user's last read timestamp to count unread items.
  /// Excludes the user's own messages from the unread count for accurate notification counts.
  /// Used for conversation list unread badges and notification counters.
  int getUnreadCount(String userId, List<Message> recentMessages) {
    final lastReadTime = lastReadTimestamps[userId];
    if (lastReadTime == null) return recentMessages.length;
    
    return recentMessages.where((message) => 
      message.sentAt.isAfter(lastReadTime) && 
      message.senderId != userId // Don't count own messages
    ).length;
  }

  /// Checks if the specified user is a participant in this conversation.
  /// Validates user participation for access control, message routing, and conversation
  /// operations. Used for permission validation and conversation access management.
  bool isParticipant(String userId) {
    return participantIds.contains(userId);
  }

  /// Content display methods for conversation preview and activity summaries.

  /// Gets Swedish-localized preview text for the last message in the conversation.
  /// Provides formatted message preview for conversation lists with sender attribution
  /// for regular messages and direct content display for system messages. Uses Swedish
  /// fallback text when no messages exist. Used for conversation list previews.
  String get lastMessagePreview {
    if (lastMessage == null) {
      return 'Ingen meddelanden än';
    }
    
    final message = lastMessage!;
    if (message.isSystemMessage) {
      return message.content;
    }
    
    final senderName = message.senderDisplayName;
    return '$senderName: ${message.displayContent}';
  }

  /// Gets formatted last activity time using compact Swedish-localized time units.
  /// Provides human-readable time descriptions for conversation activity with compact
  /// formatting suitable for conversation list displays. Uses Swedish time units with
  /// abbreviated format (m, h, d, w) for space-efficient activity indicators.
  String get formattedLastActivity {
    final now = DateTime.now();
    final lastActivity = lastMessage?.sentAt ?? updatedAt;
    final difference = now.difference(lastActivity);
    
    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${(difference.inDays / 7).floor()}w';
    }
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the conversation for debugging and logging.
  /// Provides essential conversation information in a readable format for development
  /// and debugging purposes with conversation type, participant count, and last message preview.
  @override
  String toString() {
    return 'Conversation(id: $id, isGroup: $isGroup, participants: ${participantIds.length}, lastMessage: ${lastMessage?.content})';
  }

  /// Compares two conversations for equality based on unique identifier.
  /// Uses conversation ID for equality comparison ensuring consistent object identity
  /// across different instances of the same conversation data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  /// Generates hash code based on unique conversation identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and conversation identification.
  @override
  int get hashCode => id.hashCode;
}