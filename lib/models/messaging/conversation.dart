// lib/models/messaging/conversation.dart

import 'package:butlery/models/messaging/message.dart';
import 'package:uuid/uuid.dart';

/// Model representing a conversation between users
class Conversation {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantDisplayNames;
  final Map<String, String?> participantAvatarUrls;
  final Message? lastMessage;
  final Map<String, DateTime> lastReadTimestamps;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? title; // Optional custom title for group conversations
  final bool isGroup; // True for group conversations (>2 participants)
  final Map<String, dynamic>? metadata; // For additional conversation data

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
  });

  /// Create a new direct conversation between two users
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

  /// Create a new group conversation
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


  /// Create a copy with updated fields
  Conversation copyWith({
    Message? lastMessage,
    Map<String, DateTime>? lastReadTimestamps,
    DateTime? updatedAt,
    String? title,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Map<String, String?>? participantAvatarUrls,
    Map<String, dynamic>? metadata,
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
    );
  }

  /// Get display title for the conversation
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

  /// Get avatar URL for display (for direct conversations, show other participant's avatar)
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

  /// Get other participant ID (for direct conversations only)
  String? getOtherParticipantId(String currentUserId) {
    if (isGroup) return null;
    
    return participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
  }

  /// Check if user has unread messages
  bool hasUnreadMessages(String userId) {
    if (lastMessage == null) return false;
    
    final lastReadTime = lastReadTimestamps[userId];
    if (lastReadTime == null) return true;
    
    return lastMessage!.sentAt.isAfter(lastReadTime);
  }

  /// Get unread message count for user
  int getUnreadCount(String userId, List<Message> recentMessages) {
    final lastReadTime = lastReadTimestamps[userId];
    if (lastReadTime == null) return recentMessages.length;
    
    return recentMessages.where((message) => 
      message.sentAt.isAfter(lastReadTime) && 
      message.senderId != userId // Don't count own messages
    ).length;
  }

  /// Check if user is participant
  bool isParticipant(String userId) {
    return participantIds.contains(userId);
  }

  /// Get last message preview text
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

  /// Get formatted last activity time
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

  @override
  String toString() {
    return 'Conversation(id: $id, isGroup: $isGroup, participants: ${participantIds.length}, lastMessage: ${lastMessage?.content})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}