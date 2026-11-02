library;

import 'package:collection/collection.dart';
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_change_request_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

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

  test('watchPending streams only pending proposals', () async {
    final fs = FakeFirebaseFirestore();
    final repo = _repo(fs);
    final a = await repo.create(_draft());
    final b = await repo.create(_draft());
    await repo.withdraw(b.id);
    final items = await repo.watchPending().first;
    expect(items.map((r) => r.id), [a.id]);
    expect(items.single.status, IngredientChangeStatus.pending);
  });

  test('delete is never allowed', () async {
    final repo = _repo(FakeFirebaseFirestore());
    expect(await repo.validateDeletePermission('admin-1', 'x'), isFalse);
  });
}
