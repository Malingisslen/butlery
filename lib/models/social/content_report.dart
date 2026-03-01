import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Represents a user-submitted content report for moderation.
class ContentReport {
  final String id;
  final String reporterId;
  final String
      contentType; // 'recipe', 'comment', 'message', 'profile', 'shopping_list'
  final String contentId;
  final String? contentOwnerId;
  final String reason;
  final String? description;
  final String status; // 'pending', 'reviewed', 'resolved', 'dismissed'
  final DateTime createdAt;

  const ContentReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    this.contentOwnerId,
    required this.reason,
    this.description,
    this.status = 'pending',
    required this.createdAt,
  });

  factory ContentReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentReport(
      id: doc.id,
      reporterId: SerializationUtils.safeString(data, 'reporterId'),
      contentType: SerializationUtils.safeString(data, 'contentType'),
      contentId: SerializationUtils.safeString(data, 'contentId'),
      contentOwnerId:
          SerializationUtils.safeNullableString(data, 'contentOwnerId'),
      reason: SerializationUtils.safeString(data, 'reason'),
      description: SerializationUtils.safeNullableString(data, 'description'),
      status: SerializationUtils.safeString(data, 'status',
          defaultValue: 'pending'),
      createdAt:
          SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'contentType': contentType,
      'contentId': contentId,
      'contentOwnerId': contentOwnerId,
      'reason': reason,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
