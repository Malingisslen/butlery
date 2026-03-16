/// Friend request model with lifecycle management and optional messaging.
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;

enum FriendRequestStatus { pending, accepted, rejected, cancelled, expired }

/// Friend request with status tracking and optional message.
class FriendRequest with JsonSerializableMixin {
  static const _expiryDuration = Duration(days: 7);

  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final String? message;

  /// TTL field for Firestore TTL policy — auto-deletes expired requests.
  final DateTime expiresAt;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.status = FriendRequestStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    this.message,
    DateTime? expiresAt,
  })  : sentAt = sentAt ?? DateTime.now(),
        expiresAt =
            expiresAt ?? (sentAt ?? DateTime.now()).add(_expiryDuration);

  factory FriendRequest.create({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) {
    final now = DateTime.now();
    return FriendRequest(
      id: const Uuid().v4(),
      fromUserId: fromUserId,
      toUserId: toUserId,
      message: message,
      sentAt: now,
      expiresAt: now.add(_expiryDuration),
    );
  }

  FriendRequest copyWith({FriendRequestStatus? status, DateTime? respondedAt}) {
    return FriendRequest(
      id: id,
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: status ?? this.status,
      sentAt: sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message,
      expiresAt: expiresAt,
    );
  }

  FriendRequest accept() {
    return copyWith(
      status: FriendRequestStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  FriendRequest reject() {
    return copyWith(
      status: FriendRequestStatus.rejected,
      respondedAt: DateTime.now(),
    );
  }

  FriendRequest cancel() {
    return copyWith(
      status: FriendRequestStatus.cancelled,
      respondedAt: DateTime.now(),
    );
  }

  bool get isPending => status == FriendRequestStatus.pending;
  bool get isAccepted => status == FriendRequestStatus.accepted;
  bool get isRejected => status == FriendRequestStatus.rejected;
  bool get isCancelled => status == FriendRequestStatus.cancelled;
  bool get isCompleted => respondedAt != null;
  bool get isExpired => isPending && DateTime.now().isAfter(expiresAt);

  String get timeAgoText {
    return TimeAgoFormatter.standard(sentAt);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': AppTimestamp.fromDateTime(sentAt).toFirestore(),
      'expiresAt': AppTimestamp.fromDateTime(expiresAt).toFirestore(),
      'respondedAt': respondedAt != null
          ? AppTimestamp.fromDateTime(respondedAt!).toFirestore()
          : null,
      'message': message,
    };
  }

  factory FriendRequest.fromMap(String id, Map<String, dynamic> data) {
    final sentAt =
        utils.SerializationUtils.safeDateTime(data, 'sentAt') ?? DateTime.now();
    return FriendRequest(
      id: id,
      fromUserId: utils.SerializationUtils.safeString(data, 'fromUserId'),
      toUserId: utils.SerializationUtils.safeString(data, 'toUserId'),
      status: utils.SerializationUtils.safeEnum(
        data,
        'status',
        FriendRequestStatus.values,
        FriendRequestStatus.pending,
        (e) => e.name,
      ),
      sentAt: sentAt,
      expiresAt: utils.SerializationUtils.safeDateTime(data, 'expiresAt') ??
          sentAt.add(_expiryDuration),
      respondedAt: utils.SerializationUtils.safeDateTime(data, 'respondedAt'),
      message: utils.SerializationUtils.safeNullableString(data, 'message'),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': serializeDateTime(sentAt),
      'expiresAt': serializeDateTime(expiresAt),
      'respondedAt': serializeDateTime(respondedAt),
      'message': message,
    };
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final sentAt =
        utils.SerializationUtils.parseRequiredDateTimeValue(json['sentAt']);
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt: sentAt,
      expiresAt:
          utils.SerializationUtils.parseDateTimeValue(json['expiresAt']) ??
              sentAt.add(_expiryDuration),
      respondedAt:
          utils.SerializationUtils.parseDateTimeValue(json['respondedAt']),
      message: json['message'] as String?,
    );
  }

  @override
  String toString() {
    return 'FriendRequest(id: $id, from: $fromUserId, to: $toUserId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
