// ignore_for_file: subtype_of_sealed_class
library;

import 'package:collection/collection.dart';
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_change_request_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

IngredientChangeRequest _draft({String? batchId}) => IngredientChangeRequest(
  ingredientId: 'milk',
  batchId: batchId,
  changes: const [
    IngredientFieldChange(
      column: IngredientColumn.status,
      oldValue: 'draft',
      newValue: 'verified',
    ),
  ],
);

FirebaseIngredientChangeRequestRepository _repo(
  FakeFirebaseFirestore fs, {
  String? uid = 'admin-1',
}) {
  final auth = FakeAuthRepository();
  if (uid != null) {
    auth.setAuthState(
      user: FakeUser(uid: uid),
      userId: uid,
      isAuthenticated: true,
    );
  }
  return FirebaseIngredientChangeRequestRepository(
    firestore: fs,
    authRepository: auth,
  );
}

void main() {
  test('create writes a client id, creator and pending status', () async {
    final fs = FakeFirebaseFirestore();
    final saved = await _repo(fs).create(_draft());
    final doc = await fs
        .collection('ingredient_change_requests')
        .doc(saved.id)
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['createdBy'], 'admin-1');
    expect(doc.data()!['status'], 'pending');
    expect(saved.id, isNotEmpty);
  });

  test('create without a signed-in user throws and writes nothing', () async {
    final fs = FakeFirebaseFirestore();
    await expectLater(_repo(fs, uid: null).create(_draft()), throwsA(anything));
    expect(
      (await fs.collection('ingredient_change_requests').get()).docs,
      isEmpty,
    );
  });

  test('createBatch writes all rows, each with its own id', () async {
    final fs = FakeFirebaseFirestore();
    await _repo(fs).createBatch([_draft(batchId: 'b'), _draft(batchId: 'b')]);
    final docs = (await fs.collection('ingredient_change_requests').get()).docs;
    expect(docs.length, 2);
    expect(docs.every((d) => d.data()['batchId'] == 'b'), isTrue);
    // The rules refuse a create whose createdBy is not the caller.
    expect(docs.every((d) => d.data()['createdBy'] == 'admin-1'), isTrue);
  });

  test('createBatch accepts exactly 50', () async {
    final fs = FakeFirebaseFirestore();
    await _repo(fs).createBatch([for (var i = 0; i < 50; i++) _draft()]);
    expect(
      (await fs.collection('ingredient_change_requests').get()).docs.length,
      50,
    );
  });

  test('createBatch refuses more than 50 and writes nothing', () async {
    final fs = FakeFirebaseFirestore();
    await expectLater(
      _repo(fs).createBatch([for (var i = 0; i < 51; i++) _draft()]),
      throwsArgumentError,
    );
    expect(
      (await fs.collection('ingredient_change_requests').get()).docs,
      isEmpty,
    );
  });

  test('withdraw writes exactly the four withdrawal keys', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    final saved = await repo.create(_draft());
    final doc = fs.collection('ingredient_change_requests').doc(saved.id);
    final before = (await doc.get()).data()!;
    await withClock(Clock.fixed(DateTime.utc(2026, 11, 2)), () async {
      await repo.withdraw(saved.id);
    });
    final data = (await doc.get()).data()!;
    // The fake's update merges, so compare whole key sets: an extra key here
    // would make every real withdrawal fail the rules.
    expect(
      data.keys.toSet().difference(before.keys.toSet()),
      {'withdrawnAt', 'withdrawnBy', 'expireAt'},
    );
    const eq = DeepCollectionEquality();
    final changed = before.keys
        .where((k) => !eq.equals(before[k], data[k]))
        .toSet();
    expect(changed, {'status'});
    expect(data['status'], 'withdrawn');
    expect(data['withdrawnBy'], 'admin-1');
    expect(data['withdrawnAt'], isNotNull);
    expect(
      (data['expireAt'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2027, 11, 2),
    );
    // The creation fields are untouched.
    expect(data['changes'], isNotNull);
    expect(data['createdBy'], 'admin-1');
  });

  Future<String> setStatus(
    FakeFirebaseFirestore fs,
    IngredientChangeRequest saved,
    String status,
  ) async {
    await fs.collection('ingredient_change_requests').doc(saved.id).update({
      'status': status,
    });
    return saved.id;
  }

  test('watchOpen streams pending, inReview and conflict only', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    final ids = <String, String>{};
    for (final status in [
      'pending',
      'inReview',
      'conflict',
      'applied',
      'rejected',
      'withdrawn',
    ]) {
      ids[status] = await setStatus(fs, await repo.create(_draft()), status);
    }
    final items = await repo.watchOpen().first;
    expect(items.map((r) => r.id).toSet(), {
      ids['pending'],
      ids['inReview'],
      ids['conflict'],
    });
  });

  test('watchApplied and watchRejected each stream their own status', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    final applied = await setStatus(fs, await repo.create(_draft()), 'applied');
    final rejected = await setStatus(
      fs,
      await repo.create(_draft()),
      'rejected',
    );
    await setStatus(fs, await repo.create(_draft()), 'pending');
    expect((await repo.watchApplied().first).map((r) => r.id), [applied]);
    expect((await repo.watchRejected().first).map((r) => r.id), [rejected]);
  });

  test('watchApplied returns the newest appliedAt first', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    final ids = <String>[];
    for (final day in [1, 3, 2]) {
      final saved = await repo.create(_draft());
      await fs.collection('ingredient_change_requests').doc(saved.id).update({
        'status': 'applied',
        'appliedAt': Timestamp.fromDate(DateTime.utc(2026, 11, day)),
      });
      ids.add(saved.id);
    }
    final items = await repo.watchApplied().first;
    expect(items.map((r) => r.id), [ids[1], ids[2], ids[0]]);
    expect(items.first.appliedAt!.toUtc(), DateTime.utc(2026, 11, 3));
  });

  test('withdraw works from pending, conflict and inReview', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    for (final status in ['pending', 'conflict', 'inReview']) {
      final id = await setStatus(fs, await repo.create(_draft()), status);
      await repo.withdraw(id);
      final data =
          (await fs.collection('ingredient_change_requests').doc(id).get())
              .data()!;
      expect(data['status'], 'withdrawn', reason: status);
    }
  });

  group('query shape', () {
    late _MockFirestore firestore;
    late _MockCollection col;
    late _MockQuery query;
    late List<Map<String, Object?>> whereCalls;
    late List<int> limits;

    setUp(() {
      firestore = _MockFirestore();
      col = _MockCollection();
      query = _MockQuery();
      whereCalls = [];
      limits = [];
      when(
        () => firestore.collection('ingredient_change_requests'),
      ).thenReturn(col);
      when(
        () => col.where(any(), whereIn: any(named: 'whereIn')),
      ).thenAnswer((inv) {
        whereCalls.add({
          'field': inv.positionalArguments.first,
          'whereIn': inv.namedArguments[#whereIn],
        });
        return query;
      });
      when(() => query.limit(any())).thenAnswer((inv) {
        limits.add(inv.positionalArguments.first as int);
        return query;
      });
      when(() => query.snapshots()).thenAnswer((_) => const Stream.empty());
    });

    FirebaseIngredientChangeRequestRepository build() =>
        FirebaseIngredientChangeRequestRepository(
          firestore: firestore,
          authRepository: FakeAuthRepository(),
        );

    test('open: one whereIn on status, capped at 500, no orderBy', () async {
      await build().watchOpen().toList();
      expect(whereCalls, [
        {
          'field': 'status',
          'whereIn': ['pending', 'inReview', 'conflict'],
        },
      ]);
      expect(limits, [500]);
      verifyNever(() => col.orderBy(any()));
      verifyNever(() => query.orderBy(any()));
    });

    test('applied: equality on status, orderBy appliedAt desc, 30', () async {
      final orderCalls = <Object?>[];
      final eqQuery = _MockQuery();
      when(
        () => col.where('status', isEqualTo: 'applied'),
      ).thenReturn(eqQuery);
      when(
        () => eqQuery.orderBy('appliedAt', descending: true),
      ).thenAnswer((inv) {
        orderCalls.add(inv.namedArguments[#descending]);
        return query;
      });
      await build().watchApplied().toList();
      expect(orderCalls, [true]);
      expect(limits, [30]);
    });

    test('rejected: equality on status, 20, no orderBy', () async {
      final eqQuery = _MockQuery();
      when(
        () => col.where('status', isEqualTo: 'rejected'),
      ).thenReturn(eqQuery);
      when(() => eqQuery.limit(any())).thenAnswer((inv) {
        limits.add(inv.positionalArguments.first as int);
        return query;
      });
      await build().watchRejected().toList();
      expect(limits, [20]);
      verifyNever(() => eqQuery.orderBy(any()));
      verifyNever(
        () => eqQuery.orderBy(any(), descending: any(named: 'descending')),
      );
    });
  });

  test('delete is never allowed', () async {
    final repo = _repo(FakeFirebaseFirestore());
    expect(await repo.validateDeletePermission('admin-1', 'x'), isFalse);
  });
}
