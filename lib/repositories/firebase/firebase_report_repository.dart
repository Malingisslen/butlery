import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Repository for content reports, extending BaseFirebaseRepository for
/// CRUD + audit logging + permission validation.
class FirebaseReportRepository extends BaseFirebaseRepository<ContentReport> {
  FirebaseReportRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => 'reports';

  @override
  ContentReport fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ContentReport.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(ContentReport entity) {
    return entity.toFirestore();
  }

  /// Submit a new report. Returns the document ID.
  Future<String?> submitReport(ContentReport report) async {
    try {
      final docRef =
          await firestore.collection(collectionName).add(report.toFirestore());
      AppLogger.info(
          '[ReportRepository] Report submitted: ${docRef.id} for ${report.contentType}');
      return docRef.id;
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

      return snapshot.docs.map((doc) => ContentReport.fromFirestore(doc)).toList();
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
          '[ReportRepository] Deleted ${snapshot.docs.length} reports for user $userId');
      return snapshot.docs.length;
    } catch (e) {
      AppLogger.error('[ReportRepository] Failed to delete user reports', e);
      return 0;
    }
  }
}
