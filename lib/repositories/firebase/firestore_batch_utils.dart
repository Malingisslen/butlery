import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Batch-delete Firestore documents, chunked at [kFirestoreBatchOpLimit].
///
/// Lives in `lib/repositories/firebase/` — the dependency arrow is
/// repositories ← services, never the reverse. This was previously
/// in `services/account/account_deletion/deletion_utils.dart`, which
/// forced 8 repository files to import from a service folder.
Future<void> batchDeleteDocs(
  FirebaseFirestore firestore,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) async {
  if (docs.isEmpty) return;
  for (final chunk in docs.chunked(kFirestoreBatchOpLimit)) {
    final batch = firestore.batch();
    for (final doc in chunk) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
