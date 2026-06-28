/// Direct unit tests for [batchDeleteDocs] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Chunked batch-delete used by account-deletion and shared-content cascades.
/// The contract covered here (against fake_cloud_firestore): an empty input is
/// a no-op, and the call deletes exactly the documents it is handed — leaving
/// any others intact. The partial-write/rethrow path (commit N+1 fails mid-run)
/// can't be simulated with the in-memory fake and is left to integration cover.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> seed(
    int count,
  ) async {
    for (var i = 0; i < count; i++) {
      await firestore.collection('c').add({'i': i});
    }
    return (await firestore.collection('c').get()).docs;
  }

  test('empty input is a no-op (does not throw)', () async {
    await batchDeleteDocs(
      firestore,
      <QueryDocumentSnapshot<Map<String, dynamic>>>[],
    );
    // Nothing to assert beyond "no throw"; the collection stays empty.
    expect((await firestore.collection('c').get()).docs, isEmpty);
  });

  test('deletes every document it is handed', () async {
    final docs = await seed(12);
    await batchDeleteDocs(firestore, docs, operationLabel: 'test');
    expect((await firestore.collection('c').get()).docs, isEmpty);
  });

  test('deletes only the documents passed, leaving the rest intact', () async {
    final docs = await seed(5);
    // Hand it only the first 3 snapshots.
    await batchDeleteDocs(firestore, docs.take(3).toList());
    final remaining = await firestore.collection('c').get();
    expect(remaining.docs, hasLength(2));
  });
}
