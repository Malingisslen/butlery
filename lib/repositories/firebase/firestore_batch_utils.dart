import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Batch-delete Firestore documents, chunked at [kFirestoreBatchSafeChunkSize].
///
/// Lives in `lib/repositories/firebase/` — the dependency arrow is
/// repositories ← services, never the reverse. This was previously
/// in `services/account/account_deletion/deletion_utils.dart`, which
/// forced 8 repository files to import from a service folder.
///
/// **Partial-write contract**: if commit N succeeds and N+1 fails (e.g.
/// network drop), the first N chunks are persisted and the remainder is
/// left intact. The exception is rethrown so the caller can surface the
/// failure; the caller is responsible for retry. Re-running a delete is
/// idempotent (Firestore deletes of already-gone docs are no-ops), so a
/// fresh call after a transient failure completes the remaining work.
/// Partial-failure context (chunk index and total chunk count) is logged
/// at error level — vital for diagnosing half-applied deletions in
/// account-deletion or shared-content cascades. [operationLabel] tags the
/// log line with the calling subsystem.
Future<void> batchDeleteDocs(
  FirebaseFirestore firestore,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
  String? operationLabel,
}) async {
  if (docs.isEmpty) return;
  final chunks = docs.chunked(kFirestoreBatchSafeChunkSize);
  for (var i = 0; i < chunks.length; i++) {
    final batch = firestore.batch();
    for (final doc in chunks[i]) {
      batch.delete(doc.reference);
    }
    try {
      await batch.commit();
    } catch (e) {
      final tag = operationLabel ?? 'batchDeleteDocs';
      AppLogger.error(
        '[$tag] batch delete failed at chunk ${i + 1}/${chunks.length} '
        '(${chunks[i].length} docs in failed chunk; '
        '${i * kFirestoreBatchSafeChunkSize} docs already deleted): $e',
      );
      rethrow;
    }
  }
}
