// lib/models/messaging/chat_group.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// A group people chat in, stored at `chat_groups/{groupId}`.
///
/// **Read-only from the app.** Every membership change — creating the group,
/// adding someone, leaving, removing someone — goes through a Cloud Function,
/// and `firestore.rules` refuses any client write to `memberIds` or `adminIds`.
/// That is not defensiveness about data quality: it is what makes the
/// minor-membership check unbypassable. Rules cannot iterate a member list, so
/// the only place the check can be enforced is a server that owns the write
/// (BUT-1838).
///
/// Deliberately NOT [FriendCategory]. A friend category belongs to one person,
/// lives under `users/{ownerId}/`, and two people's "Familjen" are two unrelated
/// lists; a chat group is one shared object everybody sees the same way. Recipe
/// sharing keeps using friend categories and the two must not be merged.
///
/// The moment each member joined lives on the CONVERSATION, not here — see
/// `Conversation.memberSince`. `firestore.rules` reads it to decide which
/// history a member may see, and the rule that needs it already looks the
/// conversation up.
class ChatGroup {
  final String id;
  final String name;

  /// The source of truth for who is in the group.
  final List<String> memberIds;

  /// Who may rename the group and remove other members. Fixed at creation.
  final List<String> adminIds;

  final Map<String, String> memberDisplayNames;
  final Map<String, String?> memberAvatarUrls;

  /// The conversation this group talks in.
  final String conversationId;

  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatGroup({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.adminIds,
    required this.memberDisplayNames,
    required this.memberAvatarUrls,
    required this.conversationId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isMember(String userId) => memberIds.contains(userId);

  /// The only authority on what someone may do to this group. The roster row's
  /// `role` field is descriptive and must never be consulted for this.
  bool isAdmin(String userId) => adminIds.contains(userId);

  String displayNameOf(String userId) => memberDisplayNames[userId] ?? '?';

  String? avatarUrlOf(String userId) => memberAvatarUrls[userId];

  factory ChatGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final names = SerializationUtils.safeMap(data, 'memberDisplayNames');
    final avatars = SerializationUtils.safeMap(data, 'memberAvatarUrls');
    return ChatGroup(
      id: doc.id,
      name: SerializationUtils.safeString(data, 'name'),
      memberIds: SerializationUtils.safeStringList(data, 'memberIds'),
      adminIds: SerializationUtils.safeStringList(data, 'adminIds'),
      memberDisplayNames: names.map(
        (key, value) => MapEntry(key, value is String ? value : '?'),
      ),
      memberAvatarUrls: avatars.map(
        (key, value) => MapEntry(key, value is String ? value : null),
      ),
      conversationId: SerializationUtils.safeString(data, 'conversationId'),
      createdBy: SerializationUtils.safeString(data, 'createdBy'),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      updatedAt: SerializationUtils.safeRequiredDateTime(data, 'updatedAt'),
    );
  }

  // No toFirestore(). The client never writes this document, and a serializer
  // sitting here unused is an invitation to write one — which `firestore.rules`
  // would deny, silently, in the way a Dart-side test cannot see (BUT-1482).

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ChatGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ChatGroup(id: $id, members: ${memberIds.length})';
}
