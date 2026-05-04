/// Metadata model for engagement tracking (imports, joins, etc.).
/// Represents a user's engagement with a document (importing recipe, joining group, etc.).
/// Used by BaseEngagementRepository to track user interactions with content.
/// Stored in subcollections: {parent_collection}/{resource_id}/engagements/{user_id}
/// **Use Cases:**
/// - Shared recipes: Track when users import recipes to their personal collection
/// - Shared menus: Track when users import menus
/// - Groups: Track when users join groups
/// - Shopping lists: Track when users join collaborative lists

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

class EngagementMetadata {
  final String userId;
  final DateTime engagedAt;
  final String action; // 'import', 'join', 'copy', etc.
  final String? targetId; // ID of created entity (imported recipe ID, etc.)

  EngagementMetadata({
    required this.userId,
    required this.engagedAt,
    required this.action,
    this.targetId,
  });

  /// Create EngagementMetadata from Firestore document
  factory EngagementMetadata.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return EngagementMetadata(
      userId: SerializationUtils.safeString(data, 'userId'),
      engagedAt: SerializationUtils.safeRequiredDateTime(data, 'timestamp'),
      action: SerializationUtils.safeString(data, 'action'),
      targetId: SerializationUtils.safeNullableString(data, 'targetId'),
    );
  }

  /// Convert EngagementMetadata to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': clock.now(),
      'action': action,
      if (targetId != null) 'targetId': targetId,
    };
  }

  @override
  String toString() =>
      'EngagementMetadata(userId: $userId, action: $action, engagedAt: $engagedAt, targetId: $targetId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngagementMetadata &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          engagedAt == other.engagedAt &&
          action == other.action &&
          targetId == other.targetId;

  @override
  int get hashCode =>
      userId.hashCode ^
      engagedAt.hashCode ^
      action.hashCode ^
      targetId.hashCode;
}
