import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Repository for storing parsing correction analytics.
///
/// This is a lightweight repository optimized for fire-and-forget writes.
/// It's used to collect training data for parser improvement without
/// blocking the main user flow.
///
/// SECURITY: Authentication is enforced via Firestore rules:
/// - Users can only create corrections with their own userId
/// - Users can only read/delete their own corrections
/// - Prevents data poisoning and unauthorized access
///
/// BUT-886 (wave-7 audit gap): intentional bypass of [BaseFirebaseRepository]
/// + [PermissionValidationMixin] + audit logging.
///
/// Every mutation is the caller's OWN data (`userId == auth.uid` enforced
/// by Firestore rules in `firestore.rules:parsing_corrections`). There is
/// no cross-user write surface, no permission boundary to validate, and
/// audit logging would be a per-keystroke storm during interactive parser
/// correction without serving any GDPR Art. 17 / Art. 30 purpose. Reads are
/// also rule-gated to the caller's own docs.
///
/// If this repository ever gains a cross-user write (e.g. shared parser
/// corrections), reassess this bypass.
///
/// Firestore structure:
/// ```
/// parsing_corrections/{correctionId}
///   ├── id, recipeId, userId, timestamp
///   ├── source, domain, successfulTier, originalQuality
///   ├── titleCorrection, portionsCorrection, timeCorrection
///   ├── ingredientCorrections: [...]
///   └── instructionCorrections: [...]
/// ```
class ParsingCorrectionRepository {
  final FirebaseFirestore _firestore;

  ParsingCorrectionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.parsingCorrections);

  /// Save a parsing correction (fire-and-forget).
  ///
  /// This method catches all exceptions and logs them without rethrowing.
  /// Analytics should never break the user experience.
  Future<void> save(ParsingCorrection correction) async {
    try {
      await _collection.doc(correction.id).set(correction.toFirestore());
      AppLogger.debug(
        '📊 ParsingCorrection saved: ${correction.id} '
        '(${correction.totalCorrections} corrections for ${correction.domain ?? correction.source.name})',
      );
    } catch (e) {
      // CRITICAL: Never throw - this is analytics, not critical functionality
      AppLogger.warning('Failed to save parsing correction: $e');
    }
  }

  /// Get corrections for a specific domain (for admin analysis).
  ///
  /// Returns empty list on error.
  Future<List<ParsingCorrection>> getByDomain(
    String domain, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _collection
          .where('domain', isEqualTo: domain)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ParsingCorrection.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.warning('Failed to get corrections by domain: $e');
      return [];
    }
  }

  /// Get corrections for a specific tier (for parser improvement).
  ///
  /// Returns empty list on error.
  Future<List<ParsingCorrection>> getByTier(
    String tier, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _collection
          .where('successfulTier', isEqualTo: tier)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ParsingCorrection.fromFirestore(doc))
          .toList();
    } catch (e) {
      AppLogger.warning('Failed to get corrections by tier: $e');
      return [];
    }
  }

  /// Get aggregated stats for all domains.
  ///
  /// Returns map of domain -> correction count.
  Future<Map<String, int>> getDomainStats() async {
    try {
      final stats = <String, int>{};
      DocumentSnapshot? lastDoc;
      const batchSize = 500;

      while (true) {
        Query<Map<String, dynamic>> query =
            _collection.orderBy(FieldPath.documentId).limit(batchSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;

        for (final doc in snapshot.docs) {
          final domain = doc.data()['domain'] as String? ?? 'unknown';
          stats[domain] = (stats[domain] ?? 0) + 1;
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < batchSize) break;
      }

      return stats;
    } catch (e) {
      AppLogger.warning('Failed to get domain stats: $e');
      return {};
    }
  }

  /// GDPR: Delete all corrections for a user.
  ///
  /// Must be called when user requests data deletion.
  Future<void> deleteUserCorrections(String userId) async {
    try {
      final snapshot =
          await _collection.where('userId', isEqualTo: userId).get();

      if (snapshot.docs.isEmpty) {
        AppLogger.info(
            'No parsing corrections to delete for user: ${userId.maskedUserId}');
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      AppLogger.info(
        '🗑️ Deleted ${snapshot.docs.length} parsing corrections for user: ${userId.maskedUserId}',
      );
    } catch (e) {
      // GDPR deletions should be retried, so we log but also rethrow
      AppLogger.error('Failed to delete user corrections: $e');
      rethrow;
    }
  }

  /// Get total correction count for monitoring.
  Future<int> getTotalCount() async {
    try {
      final snapshot = await _collection.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      AppLogger.warning('Failed to get total correction count: $e');
      return 0;
    }
  }
}
