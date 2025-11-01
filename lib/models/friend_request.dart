/// Comprehensive friend request data model providing complete friend request lifecycle management.
///
/// This model implements sophisticated friend request management following Single Responsibility Principle,
/// handling all aspects of friend request operations including status tracking, lifecycle management,
/// expiration handling, and social interaction features. It provides comprehensive friend request
/// functionality while maintaining clean separation from friend management and user profile concerns.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles friend request data and operations:
/// - **Request Lifecycle**: Complete friend request workflow with pending, accepted, rejected, and cancelled states
/// - **Status Management**: Comprehensive status tracking with timestamps and automated expiration detection
/// - **Social Messaging**: Optional message support for personalized friend requests with custom communication
/// - **Time Tracking**: Complete temporal tracking with sent time, response time, and expiration calculations
///
/// **What This Model Does NOT Handle:**
/// - Friend relationship management (handled by friend operations and services)
/// - User profile and identity management (handled by user profile models)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Authentication and permission validation (handled by permission services)
///
/// **Friend Request Features:**
/// - **Complete Lifecycle Management**: Full request workflow from creation through resolution with status tracking
/// - **Automated Expiration**: Smart expiration detection with configurable timeout periods for request cleanup
/// - **Personalized Messaging**: Optional message support for custom friend request communication and context
/// - **Temporal Analytics**: Comprehensive time tracking with user-friendly time display and duration calculations
/// - **Status Operations**: Convenient status transition methods with automatic timestamp management
///
/// **Usage Examples:**
/// ```dart
/// // Create new friend request
/// final request = FriendRequest.create(
///   fromUserId: currentUserId,
///   toUserId: targetUserId,
///   message: 'Hej! Vi träffades på matlagningskursen igår.',
/// );
/// 
/// // Handle request responses
/// final acceptedRequest = request.accept();
/// final rejectedRequest = request.reject();
/// final cancelledRequest = request.cancel();
/// 
/// // Check request status and timing
/// final isPending = request.isPending;
/// final isExpired = request.isExpired;
/// final timeAgo = request.timeAgoText; // '2 dagar sedan'
/// final isCompleted = request.isCompleted;
/// ```

// lib/models/friend_request.dart

import 'package:butlery/core/types/app_timestamp.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;

/// Enumeration defining the different states of a friend request throughout its lifecycle.
///
/// Friend request statuses determine the current state and available actions:
/// - [pending] - Request sent but not yet responded to by recipient
/// - [accepted] - Request approved by recipient, friendship established
/// - [rejected] - Request declined by recipient
/// - [cancelled] - Request withdrawn by sender before response
/// - [expired] - Request automatically expired due to timeout
enum FriendRequestStatus { pending, accepted, rejected, cancelled, expired }

/// Comprehensive friend request data model with lifecycle management and social messaging capabilities.
///
/// Represents a complete friend request with all associated metadata including status tracking,
/// temporal information, and optional messaging features.
class FriendRequest with JsonSerializableMixin {
  final String id;
  final String fromUserId; // Who sent the request
  final String toUserId; // Who received the request
  final FriendRequestStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt; // When accepted/rejected
  final String? message; // Optional message with request

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.status = FriendRequestStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    this.message,
  }) : sentAt = sentAt ?? DateTime.now();

  /// Factory constructor with auto-generated ID
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

  /// Create copy with updated status
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

  /// Accept the friend request
  FriendRequest accept() {
    return copyWith(
      status: FriendRequestStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  /// Reject the friend request
  FriendRequest reject() {
    return copyWith(
      status: FriendRequestStatus.rejected,
      respondedAt: DateTime.now(),
    );
  }

  /// Cancel the friend request
  FriendRequest cancel() {
    return copyWith(
      status: FriendRequestStatus.cancelled,
      respondedAt: DateTime.now(),
    );
  }

  // Status checkers
  bool get isPending => status == FriendRequestStatus.pending;
  bool get isAccepted => status == FriendRequestStatus.accepted;
  bool get isRejected => status == FriendRequestStatus.rejected;
  bool get isCancelled => status == FriendRequestStatus.cancelled;
  bool get isCompleted => respondedAt != null;

  /// Check if request has expired (7 days)
  bool get isExpired {
    return DateTime.now().difference(sentAt).inDays > 7;
  }

  /// Get time ago text for UI
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

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': AppTimestamp.fromDateTime(sentAt).toFirestore(),
      'respondedAt':
          respondedAt != null ? AppTimestamp.fromDateTime(respondedAt!).toFirestore() : null,
      'message': message,
    };
  }

  /// Create from repository data
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
      sentAt: utils.SerializationUtils.safeDateTime(data, 'sentAt') ?? DateTime.now(),
      respondedAt: utils.SerializationUtils.safeDateTime(data, 'respondedAt'),
      message: utils.SerializationUtils.safeNullableString(data, 'message'),
    );
  }

  /// JSON serialization för caching
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
      sentAt: FriendRequest._deserializeDateTime(json['sentAt']) ?? DateTime.now(),
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
