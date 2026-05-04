/// Unified model for friend requests and group invitations stored in `social_requests`.
/// Replaces separate FriendRequest and GroupInvitation Firestore collections with a
/// single collection using a `type` discriminator field.

import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:uuid/uuid.dart';

enum SocialRequestType { friend, groupInvitation }

enum SocialRequestStatus { pending, accepted, rejected, cancelled, expired }

class SocialRequest {
  static const _expiryDuration = Duration(days: 7);

  final String id;
  final SocialRequestType type;
  final String fromUserId;
  final String toUserId;
  final SocialRequestStatus status;
  final DateTime sentAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final String? message;

  // Group invitation fields (null for friend requests)
  final String? groupId;
  final String? groupName;
  final String? groupEmoji;
  final String? fromUserName;

  SocialRequest({
    required this.id,
    required this.type,
    required this.fromUserId,
    required this.toUserId,
    this.status = SocialRequestStatus.pending,
    DateTime? sentAt,
    DateTime? expiresAt,
    this.respondedAt,
    this.message,
    this.groupId,
    this.groupName,
    this.groupEmoji,
    this.fromUserName,
  })  : sentAt = sentAt ?? clock.now().toUtc(),
        expiresAt =
            expiresAt ?? (sentAt ?? clock.now().toUtc()).add(_expiryDuration);

  /// Create a friend request
  factory SocialRequest.friendRequest({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) {
    final now = clock.now().toUtc();
    return SocialRequest(
      id: const Uuid().v4(),
      type: SocialRequestType.friend,
      fromUserId: fromUserId,
      toUserId: toUserId,
      message: message,
      sentAt: now,
      expiresAt: now.add(_expiryDuration),
    );
  }

  /// Create a group invitation
  factory SocialRequest.groupInvitation({
    required String fromUserId,
    required String toUserId,
    required String groupId,
    required String groupName,
    required String groupEmoji,
    required String fromUserName,
    String? message,
  }) {
    final now = clock.now().toUtc();
    return SocialRequest(
      id: const Uuid().v4(),
      type: SocialRequestType.groupInvitation,
      fromUserId: fromUserId,
      toUserId: toUserId,
      message: message,
      groupId: groupId,
      groupName: groupName,
      groupEmoji: groupEmoji,
      fromUserName: fromUserName,
      sentAt: now,
      expiresAt: now.add(_expiryDuration),
    );
  }

  factory SocialRequest.fromMap(String id, Map<String, dynamic> data) {
    final sentAt =
        SerializationUtils.safeDateTime(data, 'sentAt') ?? clock.now().toUtc();
    return SocialRequest(
      id: id,
      type: SerializationUtils.safeEnum(
        data,
        'type',
        SocialRequestType.values,
        SocialRequestType.friend,
        (e) => e.name,
      ),
      fromUserId: SerializationUtils.safeString(data, 'fromUserId'),
      toUserId: SerializationUtils.safeString(data, 'toUserId'),
      status: SerializationUtils.safeEnum(
        data,
        'status',
        SocialRequestStatus.values,
        SocialRequestStatus.pending,
        (e) => e.name,
      ),
      sentAt: sentAt,
      expiresAt: SerializationUtils.safeDateTime(data, 'expiresAt') ??
          sentAt.add(_expiryDuration),
      respondedAt: SerializationUtils.safeDateTime(data, 'respondedAt'),
      message: SerializationUtils.safeNullableString(data, 'message'),
      groupId: SerializationUtils.safeNullableString(data, 'groupId'),
      groupName: SerializationUtils.safeNullableString(data, 'groupName'),
      groupEmoji: SerializationUtils.safeNullableString(data, 'groupEmoji'),
      fromUserName: SerializationUtils.safeNullableString(data, 'fromUserName'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': AppTimestamp.fromDateTime(sentAt).toFirestore(),
      'expiresAt': AppTimestamp.fromDateTime(expiresAt).toFirestore(),
      'respondedAt': respondedAt != null
          ? AppTimestamp.fromDateTime(respondedAt!).toFirestore()
          : null,
      'message': message,
      if (groupId != null) 'groupId': groupId,
      if (groupName != null) 'groupName': groupName,
      if (groupEmoji != null) 'groupEmoji': groupEmoji,
      if (fromUserName != null) 'fromUserName': fromUserName,
    };
  }

  SocialRequest copyWith({
    SocialRequestStatus? status,
    DateTime? respondedAt,
  }) {
    return SocialRequest(
      id: id,
      type: type,
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: status ?? this.status,
      sentAt: sentAt,
      expiresAt: expiresAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message,
      groupId: groupId,
      groupName: groupName,
      groupEmoji: groupEmoji,
      fromUserName: fromUserName,
    );
  }

  bool get isPending => status == SocialRequestStatus.pending;
  bool get isExpired =>
      clock.now().isAfter(expiresAt) || status == SocialRequestStatus.expired;
  bool get isFriendRequest => type == SocialRequestType.friend;
  bool get isGroupInvitation => type == SocialRequestType.groupInvitation;

  /// Convert to legacy FriendRequest for backward compatibility with VMs/views
  FriendRequest toFriendRequest() {
    return FriendRequest(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: FriendRequestStatus.values.firstWhere(
        (s) => s.name == status.name,
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt: sentAt,
      expiresAt: expiresAt,
      respondedAt: respondedAt,
      message: message,
    );
  }

  /// Convert to legacy GroupInvitation for backward compatibility with VMs/views
  GroupInvitation toGroupInvitation() {
    return GroupInvitation(
      id: id,
      groupId: groupId ?? '',
      groupName: groupName ?? '',
      groupEmoji: groupEmoji ?? '👥',
      fromUserId: fromUserId,
      fromUserName: fromUserName ?? '',
      toUserId: toUserId,
      status: GroupInvitationStatus.values.firstWhere(
        (s) => s.name == status.name,
        orElse: () => GroupInvitationStatus.pending,
      ),
      sentAt: sentAt,
      expiresAt: expiresAt,
      respondedAt: respondedAt,
      personalMessage: message,
    );
  }

  @override
  String toString() {
    return 'SocialRequest(id: $id, type: $type, from: $fromUserId, to: $toUserId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
