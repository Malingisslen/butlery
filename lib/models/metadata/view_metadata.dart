/// Metadata model for view/read status tracking.
/// Represents a user's view of a document (recipe, menu, notification, message, etc.).
/// Used by BaseViewRepository to track which users have viewed specific content.
/// Stored in subcollections: {parent_collection}/{resource_id}/views/{user_id}
/// **Use Cases:**
/// - Shared recipes: Track who has viewed each shared recipe
/// - Notifications: Track read status for notifications
/// - Messages: Track read receipts for messages
/// - Shared menus: Track who has viewed each shared menu

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

class ViewMetadata {
  final String userId;
  final DateTime viewedAt;

  ViewMetadata({
    required this.userId,
    required this.viewedAt,
  });

  /// Create ViewMetadata from Firestore document
  factory ViewMetadata.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return ViewMetadata(
      userId: SerializationUtils.safeString(data, 'userId'),
      viewedAt: SerializationUtils.safeRequiredDateTime(data, 'timestamp'),
    );
  }

  /// Convert ViewMetadata to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'timestamp': DateTime.now(),
    };
  }

  @override
  String toString() => 'ViewMetadata(userId: $userId, viewedAt: $viewedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewMetadata &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          viewedAt == other.viewedAt;

  @override
  int get hashCode => userId.hashCode ^ viewedAt.hashCode;
}
