// lib/models/messaging/conversation_participant.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Participant data for conversation subcollection.
/// Stored at `conversations/{conversationId}/participants/{userId}`.
///
/// This subcollection approach scales better than inline arrays for:
/// - Large group conversations (100+ participants)
/// - Efficient participant queries without arrayContains limitations
/// - Independent participant metadata updates
class ConversationParticipant {
  final String conversationId;
  final String participantId;
  final String displayName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final ParticipantRole role;
  final bool isMuted;

  const ConversationParticipant({
    required this.conversationId,
    required this.participantId,
    required this.displayName,
    this.avatarUrl,
    required this.joinedAt,
    required this.lastReadAt,
    this.role = ParticipantRole.member,
    this.isMuted = false,
  });

  factory ConversationParticipant.create({
    required String conversationId,
    required String participantId,
    required String displayName,
    String? avatarUrl,
    ParticipantRole role = ParticipantRole.member,
  }) {
    final now = DateTime.now();
    return ConversationParticipant(
      conversationId: conversationId,
      participantId: participantId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      joinedAt: now,
      lastReadAt: now,
      role: role,
    );
  }

  ConversationParticipant copyWith({
    String? displayName,
    String? avatarUrl,
    DateTime? lastReadAt,
    ParticipantRole? role,
    bool? isMuted,
  }) {
    return ConversationParticipant(
      conversationId: conversationId,
      participantId: participantId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'conversationId': conversationId,
      'participantId': participantId,
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastReadAt': Timestamp.fromDate(lastReadAt),
      'role': role.name,
      'isMuted': isMuted,
    };
  }

  factory ConversationParticipant.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ConversationParticipant(
      conversationId: data['conversationId'] as String,
      participantId: doc.id,
      displayName: data['displayName'] as String? ?? 'Unknown',
      avatarUrl: data['avatarUrl'] as String?,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReadAt:
          (data['lastReadAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      role: ParticipantRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => ParticipantRole.member,
      ),
      isMuted: data['isMuted'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'ConversationParticipant(conversationId: $conversationId, participantId: $participantId, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationParticipant &&
          other.conversationId == conversationId &&
          other.participantId == participantId;

  @override
  int get hashCode => Object.hash(conversationId, participantId);
}

/// Role of a participant in a conversation.
enum ParticipantRole {
  /// Regular member
  member,

  /// Administrator with elevated permissions
  admin,

  /// Creator/owner of the conversation
  owner,
}
