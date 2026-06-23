import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Admin-only, read-only repository for the latest daily snapshot of a metric
/// group (`analytics/<group>/daily/{date}`, written nightly by the snapshot
/// jobs). Used to give the registry scalars a `previous` value for delta arrows
/// on the non-time-series tabs (recipes, import). Admin-gated by `analytics/**`.
class DailySnapshotRepository {
  final FirebaseFirestore _firestore;

  DailySnapshotRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// The most recent daily snapshot doc for [group] (e.g. 'recipes',
  /// 'import_health'), or null when none exist yet / on error. Doc id = date,
  /// so ordering by id descending yields the newest.
  Future<Map<String, dynamic>?> getLatest(String group) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.analytics)
          .doc(group)
          .collection('daily')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
    } catch (e) {
      AppLogger.warning('DailySnapshotRepository: failed for $group: $e');
      return null;
    }
  }
}
