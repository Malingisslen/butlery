import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/engagement_stats.dart';

/// Admin-only, read-only repository for the engagement dashboard tab.
///
/// Reads the nightly `analytics/feature_retention/daily/{date}` rollups and a
/// `count()` of the `users` collection. Both reads are gated to admins by
/// `firestore.rules` (admin-only). No writes — the rollups are produced
/// server-side by scheduled Cloud Functions.
///
/// Follows the lightweight admin-repo pattern (cf. [SiteConfigRepository]):
/// direct Firestore access, no PermissionValidationMixin. Bypass rationale:
/// admin-only aggregate data, read gated by `isAdmin()` in the rules; there is
/// no per-user permission surface to validate.
class EngagementRepository {
  final FirebaseFirestore _firestore;

  /// `analytics/feature_retention` parent doc + its `daily` subcollection.
  static const String _featureRetentionDoc = 'feature_retention';
  static const String _dailySubcollection = 'daily';

  EngagementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Total registered user accounts via a `count()` aggregate (cheap — ~1 read).
  /// Returns 0 on error so the tab degrades to an empty state, never crashes.
  Future<int> getUserCount() async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      AppLogger.warning('EngagementRepository: failed to count users: $e');
      return 0;
    }
  }

  /// The most recent [limit] daily aggregates, newest first. The doc id is the
  /// UTC date, so ordering by document id descending yields newest-first.
  Future<List<DailyEngagement>> getDailyFeatureRetention({
    int limit = 14,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.analytics)
          .doc(_featureRetentionDoc)
          .collection(_dailySubcollection)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => DailyEngagement.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      AppLogger.warning(
        'EngagementRepository: failed to load daily retention: $e',
      );
      return [];
    }
  }
}
