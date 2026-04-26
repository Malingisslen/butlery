import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/social/content_type.dart';

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
  final ContentType contentType;
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

  /// Best-effort parse. Returns null when the persisted contentType is
  /// unknown — e.g. a legacy report submitted under a since-retired type.
  /// Callers iterating reports must `.whereType<ContentReport>()` to filter
  /// these out. Follows Dart/Flutter convention where the unprefixed
  /// `fromX` is the safe/total variant; use [fromFirestoreOrThrow] when
  /// the caller controls the input and a malformed doc indicates a bug.
  static ContentReport? fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final wire = SerializationUtils.safeNullableString(data, 'contentType');
    final type = ContentType.fromWire(wire);
    if (type == null) {
      AppLogger.warning(
          '[ContentReport] Skipping report ${doc.id} with unknown contentType: $wire');
      return null;
    }
    return ContentReport(
      id: doc.id,
      reporterId: SerializationUtils.safeString(data, 'reporterId'),
      contentType: type,
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

  /// Strict parse — throws `FormatException` on unknown contentType. Use
  /// from contracts that require non-null (e.g. `BaseFirebaseRepository`).
  static ContentReport fromFirestoreOrThrow(DocumentSnapshot doc) {
    final report = fromFirestore(doc);
    if (report == null) {
      throw FormatException(
          'ContentReport ${doc.id} has unknown or missing contentType');
    }
    return report;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'contentType': contentType.wireName,
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
