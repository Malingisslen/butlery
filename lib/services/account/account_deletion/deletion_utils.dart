import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Batch-delete Firestore documents, chunked at [kFirestoreBatchOpLimit].
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
