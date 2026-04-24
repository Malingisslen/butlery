import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Moderation lifecycle state for a report. Forward-only transitions enforced
/// by Firestore rules: newReport -> inReview -> actioned -> closed.
///
/// `newReport` rather than `new` because `new` is a Dart reserved word.
enum ReportStatus {
  newReport('new'),
  inReview('in_review'),
  actioned('actioned'),
  closed('closed');

  final String wireName;
  const ReportStatus(this.wireName);

  static ReportStatus fromWire(String? value) {
    switch (value) {
      case 'in_review':
        return ReportStatus.inReview;
      case 'actioned':
        return ReportStatus.actioned;
      case 'closed':
        return ReportStatus.closed;
      case 'new':
      default:
        return ReportStatus.newReport;
    }
  }

  /// Ordered rank for forward-only state machine checks on the client. The
  /// rules layer enforces the same order authoritatively.
  int get rank => switch (this) {
        ReportStatus.newReport => 0,
        ReportStatus.inReview => 1,
        ReportStatus.actioned => 2,
        ReportStatus.closed => 3,
      };
}

/// Represents a user-submitted content report for moderation.
class ContentReport {
  final String id;
  final String reporterId;
  final String
      contentType; // 'recipe', 'comment', 'message', 'profile', 'shopping_list', 'cook_snap', 'rating', 'group'
  final String contentId;
  final String? contentOwnerId;
  final String reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;

  const ContentReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    this.contentOwnerId,
    required this.reason,
    this.description,
    this.status = ReportStatus.newReport,
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
      status: ReportStatus.fromWire(
        SerializationUtils.safeNullableString(data, 'status'),
      ),
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
      'status': status.wireName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ContentReport copyWith({
    ReportStatus? status,
  }) {
    return ContentReport(
      id: id,
      reporterId: reporterId,
      contentType: contentType,
      contentId: contentId,
      contentOwnerId: contentOwnerId,
      reason: reason,
      description: description,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
