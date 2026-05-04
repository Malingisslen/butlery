// lib/models/messaging/conversation_membership.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Inverse index for efficient conversation lookups per user.
/// Stored at `users/{userId}/conversationMemberships/{conversationId}`.
///
/// This pattern replaces `arrayContains` queries with direct subcollection
/// queries, which scale better for:
/// - Users with many conversations
/// - Efficient sorting by lastActivityAt
/// - Quick membership checks
class ConversationMembership {
  final String conversationId;
  final String conversationTitle;
  final bool isGroup;
  final DateTime lastActivityAt;
  final DateTime joinedAt;
  final bool hasUnread;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;

  const ConversationMembership({
    required this.conversationId,
    required this.conversationTitle,
    required this.isGroup,
    required this.lastActivityAt,
    required this.joinedAt,
    this.hasUnread = false,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
  });

  factory ConversationMembership.create({
    required String conversationId,
    required String conversationTitle,
    required bool isGroup,
  }) {
    final now = clock.now();
    return ConversationMembership(
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      isGroup: isGroup,
      lastActivityAt: now,
      joinedAt: now,
    );
  }

  ConversationMembership copyWith({
    String? conversationTitle,
    DateTime? lastActivityAt,
    bool? hasUnread,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
  }) {
    return ConversationMembership(
      conversationId: conversationId,
      conversationTitle: conversationTitle ?? this.conversationTitle,
      isGroup: isGroup,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      joinedAt: joinedAt,
      hasUnread: hasUnread ?? this.hasUnread,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'conversationTitle': conversationTitle,
      'isGroup': isGroup,
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'hasUnread': hasUnread,
      'isMuted': isMuted,
      'isPinned': isPinned,
      'isArchived': isArchived,
    };
  }

  factory ConversationMembership.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ConversationMembership(
      conversationId: doc.id,
      conversationTitle:
          SerializationUtils.safeString(data, 'conversationTitle'),
      isGroup: SerializationUtils.safeBool(data, 'isGroup'),
      lastActivityAt: SerializationUtils.safeDateTime(data, 'lastActivityAt') ??
          clock.now(),
      joinedAt:
          SerializationUtils.safeDateTime(data, 'joinedAt') ?? clock.now(),
      hasUnread: SerializationUtils.safeBool(data, 'hasUnread'),
      isMuted: SerializationUtils.safeBool(data, 'isMuted'),
      isPinned: SerializationUtils.safeBool(data, 'isPinned'),
      isArchived: SerializationUtils.safeBool(data, 'isArchived'),
    );
  }

  @override
  String toString() =>
      'ConversationMembership(conversationId: $conversationId, title: $conversationTitle)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationMembership && other.conversationId == conversationId;

  @override
  int get hashCode => conversationId.hashCode;
}
