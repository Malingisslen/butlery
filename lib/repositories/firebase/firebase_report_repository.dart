import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Repository for content reports, extending BaseFirebaseRepository for
/// CRUD + audit logging + permission validation.
class FirebaseReportRepository extends BaseFirebaseRepository<ContentReport> {
  FirebaseReportRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.reports;

  @override
  ContentReport fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ContentReport.fromFirestoreOrThrow(doc);
  }

  @override
  Map<String, dynamic> toFirestore(ContentReport entity) {
    return entity.toFirestore();
  }

  @override
  String getId(ContentReport entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(
    String userId,
    ContentReport entity,
  ) async => userId == entity.reporterId;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    ContentReport? entity,
  ) async => entity == null || userId == entity.reporterId;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    ContentReport entity,
  ) async => false; // Reports cannot be updated

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => true; // Own reports can be deleted via account deletion

  /// Submit a new report. Returns the document ID.
  ///
  /// BUT-781: writes the report and the per-(reporter, contentOwner) throttle
  /// sentinel in one batch. The Firestore rules for `/reports` consult the
  /// throttle on the next create attempt to enforce the 24h rate limit; without
  /// this batched write the rule's exists()/get() check finds no doc and the
  /// limit silently never engages. The report's `contentOwnerId` is now
  /// required by the rule, so a missing value is rejected before this code
  /// path runs.
  Future<String?> submitReport(ContentReport report) async {
    if (report.contentOwnerId == null || report.contentOwnerId!.isEmpty) {
      AppLogger.error(
        '[ReportRepository] contentOwnerId is required; rejecting submitReport',
      );
      return null;
    }
    if (report.contentOwnerId == report.reporterId) {
      AppLogger.error(
        '[ReportRepository] self-reports blocked at rules layer; rejecting client-side',
      );
      return null;
    }

    try {
      final reportRef = firestore.collection(collectionName).doc();
      final throttleRef = firestore
          .collection(FirestoreCollections.users)
          .doc(report.reporterId)
          .collection(FirestoreCollections.userReportThrottle)
          .doc(report.contentOwnerId);

      final batch = firestore.batch();
      batch.set(reportRef, report.toFirestore());
      batch.set(throttleRef, {
        'lastReportAt': timestampProvider.serverTimestamp(),
      });
      await batch.commit();

      AppLogger.info(
        '[ReportRepository] Report submitted: ${reportRef.id} for ${report.contentType}',
      );
      return reportRef.id;
    } catch (e) {
      AppLogger.error('[ReportRepository] Failed to submit report', e);
      return null;
    }
  }

  /// Get reports submitted by a specific user.
  Future<List<ContentReport>> getUserReports(String userId) async {
    try {
      final snapshot = await firestore
          .collection(collectionName)
          .where('reporterId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Tolerant parse — legacy reports submitted under since-retired
      // contentTypes are skipped rather than crashing the user's whole list.
      return snapshot.docs
          .map(ContentReport.fromFirestore)
          .whereType<ContentReport>()
          .toList();
    } catch (e) {
      AppLogger.error('[ReportRepository] Failed to get user reports', e);
      return [];
    }
  }

  /// Delete reports by a specific user (for account deletion / GDPR Art. 17).
  Future<int> deleteUserReports(String userId) async {
    try {
      final snapshot = await firestore
          .collection(collectionName)
          .where('reporterId', isEqualTo: userId)
          .get();

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      AppLogger.info(
        '[ReportRepository] Deleted ${snapshot.docs.length} reports for user ${userId.maskedUserId}',
      );
      return snapshot.docs.length;
    } catch (e) {
      AppLogger.error('[ReportRepository] Failed to delete user reports', e);
      return 0;
    }
  }
}
