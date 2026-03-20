import 'package:cloud_firestore/cloud_firestore.dart';

/// Batch-delete Firestore documents with 500-op chunking.
/// Handles empty lists (no-op) and arbitrarily large result sets.
Future<void> batchDeleteDocs(
  FirebaseFirestore firestore,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) async {
  if (docs.isEmpty) return;
  const batchLimit = 500;
  for (var i = 0; i < docs.length; i += batchLimit) {
    final batch = firestore.batch();
    final end = (i + batchLimit).clamp(0, docs.length);
    final chunk = docs.sublist(i, end);
    for (final doc in chunk) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
