import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/tag_override_log_entry.dart';

/// BUT-1473: fire-and-forget writer for allergen tag-override corrections.
///
/// Mirrors [ParsingCorrectionRepository]'s deliberate bypass of
/// `BaseFirebaseRepository` + `PermissionValidationMixin` (BUT-886): every
/// write is the caller's OWN data (`userId == auth.uid`, enforced by the
/// `tag_overrides_log` Firestore rule), so there is no cross-user surface and
/// no permission boundary to validate, and per-correction audit logging would
/// be noise serving no GDPR purpose. Writes NEVER throw — capturing a
/// correction is analytics and must never break the user's edit flow.
///
/// The collection name is inlined (not routed through `FirestoreCollections`)
/// so this ships within the tagging cluster without editing the shared
/// constants file another change may be touching in parallel.
///
/// The `tag_overrides_log` Firestore rule (own-data create/read/delete,
/// append-only) ships alongside this repository (BUT-1473), so an authenticated
/// owner's writes land; a cross-user or malformed write still default-denies.
/// The account-deletion cascade removes these server-side.
class TagOverridesLogRepository {
  final FirebaseFirestore _firestore;

  TagOverridesLogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String collectionName = 'tag_overrides_log';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(collectionName);

  /// Persists one override correction (fire-and-forget). Catches everything.
  Future<void> save(TagOverrideLogEntry entry) async {
    try {
      await _collection.doc(entry.id).set(entry.toFirestore());
      AppLogger.debug(
        '📝 Tag override logged: ${entry.type}/${entry.tag} ${entry.direction}',
      );
    } catch (e) {
      // Analytics, not critical functionality — never rethrow.
      AppLogger.warning('Failed to log tag override: $e');
    }
  }
}
