/// Direct unit tests for [batchDeleteDocs] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Chunked batch-delete used by account-deletion and shared-content cascades.
/// The contract covered here (against fake_cloud_firestore): an empty input is
/// a no-op, and the call deletes exactly the documents it is handed — leaving
/// any others intact. The partial-write/rethrow path (commit N+1 fails mid-run)
/// can't be simulated with the in-memory fake and is left to integration cover.
// ignore_for_file: subtype_of_sealed_class
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  // BUT-2169: an `in` query on document ids is refused WHOLE when one id is
  // unreadable, which is what a row a block has taken the caller off looks
  // like. On the emulator the received-menus query came back
  // permission-denied, so the doubles below refuse the query the same way.
  group('fetchReadableByIds', () {
    late _MockFirestore db;
    late _MockCollection col;
    late _MockQuery query;

    _MockDoc doc(String id, Map<String, dynamic>? data, {bool denied = false}) {
      final ref = _MockDoc();
      final snap = _MockSnapshot();
      when(() => snap.data()).thenReturn(data);
      when(() => col.doc(id)).thenReturn(ref);
      if (denied) {
        when(() => ref.get()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
      } else {
        when(() => ref.get()).thenAnswer((_) async => snap);
      }
      return ref;
    }

    setUp(() {
      db = _MockFirestore();
      col = _MockCollection();
      query = _MockQuery();
      when(() => db.collection('c')).thenReturn(col);
      when(
        () => col.where(FieldPath.documentId, whereIn: any(named: 'whereIn')),
      ).thenReturn(query);
    });

    test('a refused chunk falls back to one read per id and skips the '
        'unreadable one', () async {
      when(() => query.get()).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      doc('ok', {'n': 1});
      doc('held', null, denied: true);

      final result = await fetchReadableByIds(db, 'c', ['ok', 'held']);

      expect(result, {
        'ok': {'n': 1},
      });
    });

    test('any other failure still propagates', () async {
      when(() => query.get()).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      await expectLater(
        fetchReadableByIds(db, 'c', ['ok']),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}
