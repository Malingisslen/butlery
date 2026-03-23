/// Group invitation model with lifecycle (pending/accepted/rejected/expired), 7-day expiration, Swedish.
/// ```dart
/// final inv = GroupInvitation.create(groupId: id, groupName: 'Mat', fromUserId: u1, toUserId: u2);

// lib/models/group_invitation.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/mixins/json_serializable_mixin.dart';
import 'package:butlery/core/utils/serialization_utils.dart' as utils;

/// Invitation status: pending, accepted, rejected, expired, cancelled.
enum GroupInvitationStatus {
  pending, // Pending invitation
  accepted, // Accepterad
  rejected, // Avvisad
  expired, // Expired
  cancelled // Cancelled by sender
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
  })  : sentAt = sentAt ?? DateTime.now().toUtc(),
        expiresAt =
            expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 7));

  /// Factory constructor for creating new group invitations with auto-generated ID.
  /// Creates a new group invitation with automatic ID generation and default timing.
  /// The invitation will be set to pending status with a 7-day expiration period.
  /// [groupId] Target group identifier
  /// [groupName] Group name for caching and UI performance
  /// [groupEmoji] Group emoji for visual identification
  /// [fromUserId] Sender's user identifier
  /// [fromUserName] Sender's name for caching and UI performance
  /// [toUserId] Recipient's user identifier
  /// [personalMessage] Optional custom message for personalized communication
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
  /// Used for immutable status transitions while preserving all other invitation data.
  /// Maintains immutability pattern for safe state management and tracking.
  /// [status] New invitation status, if updating
  /// [respondedAt] Response timestamp, if updating
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
  /// Transitions the invitation status to accepted and sets the response timestamp.
  /// This method should be called by the invitation recipient to join the group.
  /// Returns a new [GroupInvitation] instance with accepted status and current timestamp.
  GroupInvitation accept() {
    return copyWith(
      status: GroupInvitationStatus.accepted,
      respondedAt: DateTime.now().toUtc(),
    );
  }

  /// Rejects the group invitation and declines group membership.
  /// Transitions the invitation status to rejected and sets the response timestamp.
  /// This method should be called by the invitation recipient to decline joining.
  /// Returns a new [GroupInvitation] instance with rejected status and current timestamp.
  GroupInvitation reject() {
    return copyWith(
      status: GroupInvitationStatus.rejected,
      respondedAt: DateTime.now().toUtc(),
    );
  }

  /// Cancels the group invitation before recipient response.
  /// Transitions the invitation status to cancelled and sets the response timestamp.
  /// This method should only be called by the invitation sender to withdraw the invitation.
  /// Returns a new [GroupInvitation] instance with cancelled status and current timestamp.
  GroupInvitation cancel() {
    return copyWith(
      status: GroupInvitationStatus.cancelled,
      respondedAt: DateTime.now().toUtc(),
    );
  }

  /// Status checker methods for invitation state validation and UI logic.

  /// Checks if the invitation is currently pending and not expired.
  /// Returns true only when the invitation is in pending status AND has not expired.
  /// Used for determining if the invitation can still be responded to.
  bool get isPending => status == GroupInvitationStatus.pending && !isExpired;

  /// Checks if the invitation has been accepted by the recipient.
  /// Returns true when the invitation status is accepted, indicating successful group membership.
  bool get isAccepted => status == GroupInvitationStatus.accepted;

  /// Checks if the invitation has been rejected by the recipient.
  /// Returns true when the invitation status is rejected, indicating declined membership.
  bool get isRejected => status == GroupInvitationStatus.rejected;

  /// Checks if the invitation has been cancelled by the sender.
  /// Returns true when the invitation status is cancelled, indicating sender withdrawal.
  bool get isCancelled => status == GroupInvitationStatus.cancelled;

  /// Checks if the invitation has been responded to with any action.
  /// Returns true when respondedAt is not null, regardless of the response type.
  /// Used for determining if the invitation lifecycle is complete.
  bool get isCompleted => respondedAt != null;

  /// Checks if the invitation has expired beyond its validity period.
  /// Returns true if the current time is past the expiration time OR if the status
  /// is explicitly set to expired. Used for automatic cleanup and UI state management.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt) ||
      status == GroupInvitationStatus.expired;

  /// UI helper methods for Swedish-localized display and user experience optimization.

  /// Gets user-friendly Swedish text for how long ago the invitation was sent.
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context.
  /// Returns Swedish time format: 'Nu', '5 min sedan', '2 tim sedan', '3 dagar sedan', '2 veckor sedan'.
  String get timeAgoText {
    return TimeAgoFormatter.standard(sentAt);
  }

  /// Gets user-friendly Swedish text for remaining time until expiration.
  /// Provides localized expiration display with countdown formatting for Swedish users.
  /// Shows remaining time until invitation becomes invalid and requires renewal.
  /// Returns Swedish countdown format: 'Utgången', '3 dagar kvar', '5 timmar kvar', 'Går ut snart'.
  String get expiresInText {
    if (isExpired) return AppLocale.current.expiresExpired;
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    final l = AppLocale.current;
    if (difference.inDays > 1) {
      return l.expiresDaysRemaining(difference.inDays);
    } else if (difference.inHours > 1) {
      return l.expiresHoursRemaining(difference.inHours);
    } else if (difference.inMinutes > 1) {
      return l.expiresMinutesRemaining(difference.inMinutes);
    } else {
      return l.expiresSoon;
    }
  }

  /// Gets formatted Swedish notification text for group invitation alerts.
  /// Provides complete notification message including sender name, group information,
  /// and optional personal message for rich notification display and context.
  /// Returns formatted Swedish notification with optional message inclusion.
  String get notificationText {
    final l = AppLocale.current;
    if (personalMessage?.isNotEmpty == true) {
      return l.groupInvitationNotificationWithMessage(
          fromUserName, groupEmoji, groupName, personalMessage!);
    } else {
      return l.groupInvitationNotificationSimple(
          fromUserName, groupEmoji, groupName);
    }
  }

  /// Gets concise Swedish notification text for notification lists and summaries.
  /// Provides abbreviated notification display optimized for list views and compact
  /// notification interfaces with essential information only.
  /// Returns compact Swedish format: 'Sender → 👥 GroupName'.
  String get shortNotificationText {
    return '$fromUserName → $groupEmoji $groupName';
  }

  /// Gets UI color name for status-based styling and visual feedback.
  /// Provides semantic color names for consistent UI styling based on invitation status.
  /// Used for theming, badges, and visual status indicators throughout the interface.
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
  /// Provides human-readable Swedish status descriptions for user interface display,
  /// status badges, and user communication with natural language formatting.
  /// Returns Swedish status text: 'Väntande', 'Accepterad', 'Avvisad', 'Avbruten', 'Utgången'.
  String get statusText {
    final l = AppLocale.current;
    switch (status) {
      case GroupInvitationStatus.pending:
        return isExpired
            ? l.invitationStatusExpired
            : l.invitationStatusPending;
      case GroupInvitationStatus.accepted:
        return l.invitationStatusAccepted;
      case GroupInvitationStatus.rejected:
        return l.invitationStatusRejected;
      case GroupInvitationStatus.cancelled:
        return l.invitationStatusCancelled;
      case GroupInvitationStatus.expired:
        return l.invitationStatusExpired;
    }
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the group invitation to Firestore-compatible format for persistence.
  /// Transforms all invitation data into a format suitable for Firestore storage
  /// with proper timestamp handling and null value management for database efficiency.
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
      'respondedAt': respondedAt != null
          ? AppTimestamp.fromDateTime(respondedAt!).toFirestore()
          : null,
      'personalMessage': personalMessage,
      'expiresAt': AppTimestamp.fromDateTime(expiresAt).toFirestore(),
    };
  }

  /// Creates a group invitation instance from Firestore repository data.
  /// Transforms Firestore document data into a complete [GroupInvitation] instance
  /// with proper type conversion, timestamp parsing, and default value handling for robust data recovery.
  /// [id] Document identifier from Firestore
  /// [data] Raw document data from Firestore with all invitation fields
  /// Returns a new [GroupInvitation] instance with all data properly parsed and validated.
  factory GroupInvitation.fromMap(String id, Map<String, dynamic> data) {
    return GroupInvitation(
      id: id,
      groupId: utils.SerializationUtils.safeString(data, 'groupId'),
      groupName: utils.SerializationUtils.safeString(data, 'groupName'),
      groupEmoji: utils.SerializationUtils.safeString(data, 'groupEmoji',
          defaultValue: '👥'),
      fromUserId: utils.SerializationUtils.safeString(data, 'fromUserId'),
      fromUserName: utils.SerializationUtils.safeString(data, 'fromUserName'),
      toUserId: utils.SerializationUtils.safeString(data, 'toUserId'),
      status: utils.SerializationUtils.safeEnum(
        data,
        'status',
        GroupInvitationStatus.values,
        GroupInvitationStatus.pending,
        (e) => e.name,
      ),
      sentAt: utils.SerializationUtils.safeDateTime(data, 'sentAt') ??
          DateTime.now().toUtc(),
      respondedAt: utils.SerializationUtils.safeDateTime(data, 'respondedAt'),
      personalMessage:
          utils.SerializationUtils.safeNullableString(data, 'personalMessage'),
      expiresAt: utils.SerializationUtils.safeDateTime(data, 'expiresAt') ??
          DateTime.now().toUtc().add(const Duration(days: 7)),
    );
  }

  /// Converts the group invitation to JSON format for local caching and serialization.
  /// Transforms all invitation data into JSON-compatible format with proper DateTime
  /// serialization for local storage, caching, and data transfer operations.
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
  /// Transforms JSON data into a complete [GroupInvitation] instance with proper
  /// type conversion and DateTime deserialization for cache recovery and data transfer.
  /// [json] JSON map containing all invitation data with proper field names
  /// Returns a new [GroupInvitation] instance with all data properly deserialized.
  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: utils.SerializationUtils.safeString(json, 'id'),
      groupId: utils.SerializationUtils.safeString(json, 'groupId'),
      groupName: utils.SerializationUtils.safeString(json, 'groupName'),
      groupEmoji: utils.SerializationUtils.safeString(json, 'groupEmoji'),
      fromUserId: utils.SerializationUtils.safeString(json, 'fromUserId'),
      fromUserName: utils.SerializationUtils.safeString(json, 'fromUserName'),
      toUserId: utils.SerializationUtils.safeString(json, 'toUserId'),
      status: utils.SerializationUtils.safeEnum(
        json,
        'status',
        GroupInvitationStatus.values,
        GroupInvitationStatus.pending,
        (e) => e.name,
      ),
      sentAt: utils.SerializationUtils.safeDateTime(json, 'sentAt') ??
          DateTime.now().toUtc(),
      respondedAt: utils.SerializationUtils.safeDateTime(json, 'respondedAt'),
      personalMessage:
          utils.SerializationUtils.safeNullableString(json, 'personalMessage'),
      expiresAt: utils.SerializationUtils.safeDateTime(json, 'expiresAt') ??
          DateTime.now().toUtc(),
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the group invitation for debugging and logging.
  /// Provides essential invitation information in a readable format for development
  /// and debugging purposes with key identifiers and status information.
  @override
  String toString() {
    return 'GroupInvitation(id: $id, group: $groupName, from: $fromUserName, to: $toUserId, status: $status)';
  }

  /// Compares two group invitations for equality based on unique identifier.
  /// Uses invitation ID for equality comparison ensuring consistent object
  /// identity across different instances of the same invitation data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupInvitation && other.id == id;
  }

  /// Generates hash code based on unique invitation identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and identity management.
  @override
  int get hashCode => id.hashCode;
}
