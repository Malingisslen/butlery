/// Metadata model for dismissal/archived status tracking.
/// Represents a user's dismissal of content (hiding shared recipes, archiving notifications, etc.).
/// Used by BaseDismissalRepository to track which users have dismissed specific content.
/// Stored in subcollections: {parent_collection}/{resource_id}/dismissals/{user_id}
/// **Use Cases:**
/// - Shared recipes: Allow users to hide shared recipes from their feed
/// - Shared menus: Allow users to dismiss menu recommendations
/// - Notifications: Track archived/dismissed notifications
/// - Discovery content: Allow users to dismiss discovery recommendations

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

class DismissalMetadata {
  final String userId;
  final DateTime dismissedAt;
  final String?
  reason; // Optional reason for dismissal ('not_interested', 'already_have', etc.)

  DismissalMetadata({
    required this.userId,
    required this.dismissedAt,
    this.reason,
  });

  /// Create DismissalMetadata from Firestore document
  factory DismissalMetadata.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DismissalMetadata(
      userId: SerializationUtils.safeString(data, 'userId'),
      dismissedAt: SerializationUtils.safeRequiredDateTime(data, 'timestamp'),
      reason: SerializationUtils.safeNullableString(data, 'reason'),
    );
  }

  /// Convert DismissalMetadata to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': clock.now(),
      if (reason != null) 'reason': reason,
    };
  }

  @override
  String toString() =>
      'DismissalMetadata(userId: $userId, dismissedAt: $dismissedAt, reason: $reason)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DismissalMetadata &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          dismissedAt == other.dismissedAt &&
          reason == other.reason;

  @override
  int get hashCode => userId.hashCode ^ dismissedAt.hashCode ^ reason.hashCode;
}
