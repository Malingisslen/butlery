import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/anomaly_report.dart';

/// Admin-only, read-only repository for the anomaly banner. Reads the most
/// recent `analytics/anomalies/{date}` doc (written nightly by the
/// `detectAnomalies` job). Admin-gated by the `analytics/**` rule. No writes.
///
/// Lightweight admin-repo pattern (cf. SiteConfigRepository): direct Firestore,
/// no PermissionValidationMixin; admin read gated by `isAdmin()`.
class AnomalyRepository {
  final FirebaseFirestore _firestore;

  static const String _anomaliesDoc = 'anomalies';

  AnomalyRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// The latest anomaly report (doc id = date, so ordering by id desc yields
  /// newest). Returns an empty report on error or when none exist.
  Future<AnomalyReport> getLatest() async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.analytics)
          .doc(_anomaliesDoc)
          .collection('daily')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return AnomalyReport.empty;
      final doc = snapshot.docs.first;
      return AnomalyReport.fromFirestore(doc.id, doc.data());
    } catch (e) {
      AppLogger.warning('AnomalyRepository: failed to load anomalies: $e');
      return AnomalyReport.empty;
    }
  }
}
