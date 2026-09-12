import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// The signed-in user's own moderation counters, projected to the fields
/// `firestore.rules` lets them read.
///
/// The key set is held against the rule and the Art. 15 projection by
/// `rules_allowlist_drift_test.dart`; a third hand-written copy that nothing
/// compares is how the three drift apart.
class ModerationCounters {
  const ModerationCounters({required this.totalReports});

  /// The fields `firestore.rules` permits the subject to read on
  /// `user_moderation/{uid}` — the rule is a `hasOnly` allowlist, so this is
  /// the whole document as far as any client is concerned.
  ///
  /// Declared rather than inlined so `rules_allowlist_drift_test.dart` can
  /// read it out of this file and hold it against the rule and the Art. 15
  /// projection. Three hand-kept copies of one key set is how the three drift
  /// apart, and that drift is silent in the direction that matters: rules and
  /// the writer widening together while a reader does not.
  static const readableFields = ['totalReports', 'lastReportedAt'];

  /// How many reports have ever been filed against this user — NOT how many
  /// cases are open. A closed or dismissed report counts here too, which is
  /// why every sentence built on it has to be hedged.
  final int totalReports;

  bool get hasAnyReport => totalReports > 0;
}

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

  /// The signed-in user's own moderation counters, or null when the read did
  /// not answer.
  ///
  /// Null means the read FAILED or was denied — never "this person has never
  /// been reported", which is an absent document and returns zero. The caller
  /// must keep the two apart: `firestore.rules` gates this document on
  /// `hasOnly(['totalReports','lastReportedAt'])`, so the day any writer adds a
  /// field here the read is refused for EVERYONE rather than narrowed, and a
  /// null collapsed into "not reported" would switch the pre-deletion warning
  /// off silently for exactly the people who have an open case.
  ///
  /// Reads `user_moderation`, not this repository's own `reports` collection,
  /// so the inherited permission methods — scoped to `reports` — cannot apply
  /// to it. `firestore.rules` is authoritative here. Kept on this repository
  /// rather than given one of its own on the precedent of
  /// `FirebaseDataExportRepository.exportModerationCounters`, which reads the
  /// same document from a repository whose own collection differs.
  ///
  /// The projection mirrors the rule's allowlist rather than taking
  /// `doc.data()` whole: a field nobody has decided about must not ride along
  /// silently.
  Future<ModerationCounters?> fetchOwnModerationCounters(String userId) async {
    try {
      // From the SERVER, never the cache. Offline persistence is on, so a
      // plain `.get()` answers `exists == false` for a document simply not in
      // the cache — WITHOUT throwing. That would return zero, resolve to
      // `none`, and silently suppress the warning for a reported person, with
      // nothing in the three-state design able to see it: no throw, so the
      // catch never runs, and `unknown` is never reached. A negative cache
      // entry has no expiry, so it can outlast the install.
      //
      // Offline this throws `unavailable`, lands in the catch below and
      // answers `unknown` — which is what the caller already wants. Same shape
      // as `FirebaseBlockRepository._blockAlreadyStands` (BUT-1922): an answer
      // that decides what the user is told is not evidence unless the server
      // gave it.
      final doc = await firestore
          .collection(FirestoreCollections.userModeration)
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      final data = doc.data();
      if (!doc.exists || data == null) {
        return const ModerationCounters(totalReports: 0);
      }
      return ModerationCounters(
        totalReports: (data['totalReports'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      AppLogger.error(
        '[ReportRepository] Could not read own moderation counters',
        e,
      );
      return null;
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
