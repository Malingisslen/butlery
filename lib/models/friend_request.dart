/// Friend request model with lifecycle management and optional messaging.
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;

enum FriendRequestStatus { pending, accepted, rejected, cancelled, expired }

/// Friend request with status tracking and optional message.
class FriendRequest with JsonSerializableMixin {
  final String id;
  final String fromUserId;
  final String toUserId;
  final FriendRequestStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final String? message;

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.status = FriendRequestStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    this.message,
  }) : sentAt = sentAt ?? DateTime.now();

  factory FriendRequest.create({
    required String fromUserId,
    required String toUserId,
    String? message,
  }) {
    return FriendRequest(
      id: const Uuid().v4(),
      fromUserId: fromUserId,
      toUserId: toUserId,
      message: message,
      sentAt: DateTime.now(),
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
  bool get isExpired => DateTime.now().difference(sentAt).inDays > 7;

  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(sentAt);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': AppTimestamp.fromDateTime(sentAt).toFirestore(),
      'respondedAt': respondedAt != null
          ? AppTimestamp.fromDateTime(respondedAt!).toFirestore()
          : null,
      'message': message,
    };
  }

  factory FriendRequest.fromMap(String id, Map<String, dynamic> data) {
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
      sentAt: utils.SerializationUtils.safeDateTime(data, 'sentAt') ??
          DateTime.now(),
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
      'respondedAt': serializeDateTime(respondedAt),
      'message': message,
    };
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      status: FriendRequestStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      sentAt:
          FriendRequest._deserializeDateTime(json['sentAt']) ?? DateTime.now(),
      respondedAt: FriendRequest._deserializeDateTime(json['respondedAt']),
      message: json['message'] as String?,
    );
  }

  /// Helper method for deserializing DateTime from JSON
  static DateTime? _deserializeDateTime(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is DateTime) return value;
    if (value is Map) {
      // Handle raw timestamp data from Firestore
      final seconds = value['seconds'] as int?;
      final nanoseconds = value['nanoseconds'] as int? ?? 0;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + nanoseconds ~/ 1000000);
      }
    }
    return null;
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
