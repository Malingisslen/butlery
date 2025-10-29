/// Group invitation model with lifecycle (pending/accepted/rejected/expired), 7-day expiration, Swedish.
/// ```dart
/// final inv = GroupInvitation.create(groupId: id, groupName: 'Mat', fromUserId: u1, toUserId: u2);

// lib/models/group_invitation.dart

import 'package:butlery/core/types/app_timestamp.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';

/// Invitation status: pending, accepted, rejected, expired, cancelled.
enum GroupInvitationStatus {
  pending, // Väntande inbjudan
  accepted, // Accepterad
  rejected, // Avvisad
  expired, // Utgången
  cancelled // Avbruten av avsändare
}

/// Group invitation with lifecycle management and cached metadata (group name/emoji, sender name).
class GroupInvitation with JsonSerializableMixin {
  final String id;
  final String groupId;
  final String groupName;
  final String groupEmoji;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final GroupInvitationStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final String? personalMessage;
  final DateTime expiresAt;
  GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.groupEmoji,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    this.status = GroupInvitationStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    this.personalMessage,
    DateTime? expiresAt,
  })  : sentAt = sentAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  /// Factory constructor for creating new group invitations with auto-generated ID.
  ///
  /// Creates a new group invitation with automatic ID generation and default timing.
  /// The invitation will be set to pending status with a 7-day expiration period.
  ///
  /// [groupId] Target group identifier
  /// [groupName] Group name for caching and UI performance
  /// [groupEmoji] Group emoji for visual identification
  /// [fromUserId] Sender's user identifier
  /// [fromUserName] Sender's name for caching and UI performance
  /// [toUserId] Recipient's user identifier
  /// [personalMessage] Optional custom message for personalized communication
  ///
  /// Returns a new [GroupInvitation] instance with pending status and current timestamp.
  factory GroupInvitation.create({
    required String groupId,
    required String groupName,
    required String groupEmoji,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    String? personalMessage,
  }) {
    return GroupInvitation(
      id: const Uuid().v4(),
      groupId: groupId,
      groupName: groupName,
      groupEmoji: groupEmoji,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      personalMessage: personalMessage,
    );
  }

  /// Creates a copy of this invitation with updated status and response time.
  ///
  /// Used for immutable status transitions while preserving all other invitation data.
  /// Maintains immutability pattern for safe state management and tracking.
  ///
  /// [status] New invitation status, if updating
  /// [respondedAt] Response timestamp, if updating
  ///
  /// Returns a new [GroupInvitation] instance with updated values.
  GroupInvitation copyWith({
    GroupInvitationStatus? status,
    DateTime? respondedAt,
  }) {
    return GroupInvitation(
      id: id,
      groupId: groupId,
      groupName: groupName,
      groupEmoji: groupEmoji,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: toUserId,
      status: status ?? this.status,
      sentAt: sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      personalMessage: personalMessage,
      expiresAt: expiresAt,
    );
  }

  /// Accepts the group invitation and establishes group membership.
  ///
  /// Transitions the invitation status to accepted and sets the response timestamp.
  /// This method should be called by the invitation recipient to join the group.
  ///
  /// Returns a new [GroupInvitation] instance with accepted status and current timestamp.
  GroupInvitation accept() {
    return copyWith(
      status: GroupInvitationStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  /// Rejects the group invitation and declines group membership.
  ///
  /// Transitions the invitation status to rejected and sets the response timestamp.
  /// This method should be called by the invitation recipient to decline joining.
  ///
  /// Returns a new [GroupInvitation] instance with rejected status and current timestamp.
  GroupInvitation reject() {
    return copyWith(
      status: GroupInvitationStatus.rejected,
      respondedAt: DateTime.now(),
    );
  }

  /// Cancels the group invitation before recipient response.
  ///
  /// Transitions the invitation status to cancelled and sets the response timestamp.
  /// This method should only be called by the invitation sender to withdraw the invitation.
  ///
  /// Returns a new [GroupInvitation] instance with cancelled status and current timestamp.
  GroupInvitation cancel() {
    return copyWith(
      status: GroupInvitationStatus.cancelled,
      respondedAt: DateTime.now(),
    );
  }

  /// Status checker methods for invitation state validation and UI logic.

  /// Checks if the invitation is currently pending and not expired.
  ///
  /// Returns true only when the invitation is in pending status AND has not expired.
  /// Used for determining if the invitation can still be responded to.
  bool get isPending => status == GroupInvitationStatus.pending && !isExpired;
  
  /// Checks if the invitation has been accepted by the recipient.
  ///
  /// Returns true when the invitation status is accepted, indicating successful group membership.
  bool get isAccepted => status == GroupInvitationStatus.accepted;
  
  /// Checks if the invitation has been rejected by the recipient.
  ///
  /// Returns true when the invitation status is rejected, indicating declined membership.
  bool get isRejected => status == GroupInvitationStatus.rejected;
  
  /// Checks if the invitation has been cancelled by the sender.
  ///
  /// Returns true when the invitation status is cancelled, indicating sender withdrawal.
  bool get isCancelled => status == GroupInvitationStatus.cancelled;
  
  /// Checks if the invitation has been responded to with any action.
  ///
  /// Returns true when respondedAt is not null, regardless of the response type.
  /// Used for determining if the invitation lifecycle is complete.
  bool get isCompleted => respondedAt != null;
  
  /// Checks if the invitation has expired beyond its validity period.
  ///
  /// Returns true if the current time is past the expiration time OR if the status
  /// is explicitly set to expired. Used for automatic cleanup and UI state management.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) ||
      status == GroupInvitationStatus.expired;

  /// UI helper methods for Swedish-localized display and user experience optimization.

  /// Gets user-friendly Swedish text for how long ago the invitation was sent.
  ///
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context.
  ///
  /// Returns Swedish time format: 'Nu', '5 min sedan', '2 tim sedan', '3 dagar sedan', '2 veckor sedan'.
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

  /// Gets user-friendly Swedish text for remaining time until expiration.
  ///
  /// Provides localized expiration display with countdown formatting for Swedish users.
  /// Shows remaining time until invitation becomes invalid and requires renewal.
  ///
  /// Returns Swedish countdown format: 'Utgången', '3 dagar kvar', '5 timmar kvar', 'Går ut snart'.
  String get expiresInText {
    if (isExpired) return 'Utgången';

    final now = DateTime.now();
    final difference = expiresAt.difference(now);

    if (difference.inDays > 1) {
      return '${difference.inDays} dagar kvar';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} timmar kvar';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minuter kvar';
    } else {
      return 'Går ut snart';
    }
  }

  /// Gets formatted Swedish notification text for group invitation alerts.
  ///
  /// Provides complete notification message including sender name, group information,
  /// and optional personal message for rich notification display and context.
  ///
  /// Returns formatted Swedish notification with optional message inclusion.
  String get notificationText {
    if (personalMessage?.isNotEmpty == true) {
      return '$fromUserName bjöd in dig till gruppen $groupEmoji $groupName: "$personalMessage"';
    } else {
      return '$fromUserName bjöd in dig till gruppen $groupEmoji $groupName';
    }
  }

  /// Gets concise Swedish notification text for notification lists and summaries.
  ///
  /// Provides abbreviated notification display optimized for list views and compact
  /// notification interfaces with essential information only.
  ///
  /// Returns compact Swedish format: 'Sender → 👥 GroupName'.
  String get shortNotificationText {
    return '$fromUserName → $groupEmoji $groupName';
  }

  /// Gets UI color name for status-based styling and visual feedback.
  ///
  /// Provides semantic color names for consistent UI styling based on invitation status.
  /// Used for theming, badges, and visual status indicators throughout the interface.
  ///
  /// Returns color name: 'primary', 'success', 'error', or 'warning'.
  String get statusColorName {
    switch (status) {
      case GroupInvitationStatus.pending:
        return isExpired ? 'warning' : 'primary';
      case GroupInvitationStatus.accepted:
        return 'success';
      case GroupInvitationStatus.rejected:
      case GroupInvitationStatus.cancelled:
        return 'error';
      case GroupInvitationStatus.expired:
        return 'warning';
    }
  }

  /// Gets localized Swedish status text for UI display and user communication.
  ///
  /// Provides human-readable Swedish status descriptions for user interface display,
  /// status badges, and user communication with natural language formatting.
  ///
  /// Returns Swedish status text: 'Väntande', 'Accepterad', 'Avvisad', 'Avbruten', 'Utgången'.
  String get statusText {
    switch (status) {
      case GroupInvitationStatus.pending:
        return isExpired ? 'Utgången' : 'Väntande';
      case GroupInvitationStatus.accepted:
        return 'Accepterad';
      case GroupInvitationStatus.rejected:
        return 'Avvisad';
      case GroupInvitationStatus.cancelled:
        return 'Avbruten';
      case GroupInvitationStatus.expired:
        return 'Utgången';
    }
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the group invitation to Firestore-compatible format for persistence.
  ///
  /// Transforms all invitation data into a format suitable for Firestore storage
  /// with proper timestamp handling and null value management for database efficiency.
  ///
  /// Returns a map containing all invitation data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupEmoji': groupEmoji,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': AppTimestamp.fromDateTime(sentAt).toFirestore(),
      'respondedAt':
          respondedAt != null ? AppTimestamp.fromDateTime(respondedAt!).toFirestore() : null,
      'personalMessage': personalMessage,
      'expiresAt': AppTimestamp.fromDateTime(expiresAt).toFirestore(),
    };
  }

  /// Creates a group invitation instance from Firestore repository data.
  ///
  /// Transforms Firestore document data into a complete [GroupInvitation] instance
  /// with proper type conversion, timestamp parsing, and default value handling for robust data recovery.
  ///
  /// [id] Document identifier from Firestore
  /// [data] Raw document data from Firestore with all invitation fields
  ///
  /// Returns a new [GroupInvitation] instance with all data properly parsed and validated.
  factory GroupInvitation.fromMap(String id, Map<String, dynamic> data) {
    return GroupInvitation(
      id: id,
      groupId: data['groupId'] as String,
      groupName: data['groupName'] as String,
      groupEmoji: data['groupEmoji'] as String? ?? '👥',
      fromUserId: data['fromUserId'] as String,
      fromUserName: data['fromUserName'] as String,
      toUserId: data['toUserId'] as String,
      status: GroupInvitationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupInvitationStatus.pending,
      ),
      sentAt: _parseTimestamp(data['sentAt']) ?? DateTime.now(),
      respondedAt: _parseTimestamp(data['respondedAt']),
      personalMessage: data['personalMessage'] as String?,
      expiresAt: _parseTimestamp(data['expiresAt']) ?? DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Converts the group invitation to JSON format for local caching and serialization.
  ///
  /// Transforms all invitation data into JSON-compatible format with proper DateTime
  /// serialization for local storage, caching, and data transfer operations.
  ///
  /// Returns a JSON-compatible map with all invitation data properly serialized.
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'groupEmoji': groupEmoji,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'status': status.name,
      'sentAt': serializeDateTime(sentAt),
      'respondedAt': serializeDateTime(respondedAt),
      'personalMessage': personalMessage,
      'expiresAt': serializeDateTime(expiresAt),
    };
  }

  /// Creates a group invitation instance from JSON data for caching and deserialization.
  ///
  /// Transforms JSON data into a complete [GroupInvitation] instance with proper
  /// type conversion and DateTime deserialization for cache recovery and data transfer.
  ///
  /// [json] JSON map containing all invitation data with proper field names
  ///
  /// Returns a new [GroupInvitation] instance with all data properly deserialized.
  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String,
      groupEmoji: json['groupEmoji'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      toUserId: json['toUserId'] as String,
      status: GroupInvitationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => GroupInvitationStatus.pending,
      ),
      sentAt: GroupInvitation._deserializeDateTime(json['sentAt']) ?? DateTime.now(),
      respondedAt: GroupInvitation._deserializeDateTime(json['respondedAt']),
      personalMessage: json['personalMessage'] as String?,
      expiresAt: GroupInvitation._deserializeDateTime(json['expiresAt']) ?? DateTime.now(),
    );
  }

  /// Utility and helper methods for timestamp parsing and object operations.

  /// Helper method for deserializing DateTime from JSON data with format flexibility.
  ///
  /// Handles multiple DateTime formats including ISO strings, DateTime objects,
  /// and Firestore timestamp maps for robust data recovery from various sources.
  ///
  /// [value] Dynamic value that may contain DateTime data in various formats
  ///
  /// Returns parsed DateTime or null if parsing fails.
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

  /// Helper method for parsing timestamps from repository data with comprehensive format support.
  ///
  /// Provides robust timestamp parsing for Firestore data including DateTime objects,
  /// timestamp maps, epoch milliseconds, and ISO strings with fallback handling for data reliability.
  ///
  /// [timestamp] Dynamic timestamp value from repository in various possible formats
  ///
  /// Returns parsed DateTime or null if timestamp is null, with current time as fallback for errors.
  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is Map) {
        // Handle raw timestamp data from Firestore
        final seconds = timestamp['seconds'] as int?;
        final nanoseconds = timestamp['nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + nanoseconds ~/ 1000000);
        }
      } else if (timestamp is int) {
        // Handle milliseconds since epoch
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        // Handle ISO string format
        return DateTime.parse(timestamp);
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the group invitation for debugging and logging.
  ///
  /// Provides essential invitation information in a readable format for development
  /// and debugging purposes with key identifiers and status information.
  @override
  String toString() {
    return 'GroupInvitation(id: $id, group: $groupName, from: $fromUserName, to: $toUserId, status: $status)';
  }

  /// Compares two group invitations for equality based on unique identifier.
  ///
  /// Uses invitation ID for equality comparison ensuring consistent object
  /// identity across different instances of the same invitation data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupInvitation && other.id == id;
  }

  /// Generates hash code based on unique invitation identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and identity management.
  @override
  int get hashCode => id.hashCode;
}
