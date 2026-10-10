/// Which friend-group decisions reach the persistent `audit_logs` trail
/// (BUT-2324). Refusals made through FriendCategoryRepository are persisted when
/// an audit repository is injected; grants stay in the console log only.
// ignore_for_file: subtype_of_sealed_class
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/group_hand_over_outcome.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _ThrowingAudit extends Mock implements FirebaseAuditRepository {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _FakeCallableResult extends Fake implements HttpsCallableResult<Object?> {
  @override
  Object? get data => null;
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockMetadata extends Mock implements SnapshotMetadata {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

const _alice = 'user-alice';
const _bob = 'user-bob';

FakeAuthRepository _auth(String uid) {
  final auth = FakeAuthRepository();
  auth.setAuthState(
    user: FakeUser(uid: uid),
    userId: uid,
    isAuthenticated: true,
  );
  return auth;
}

FriendCategory _cat({List<String> members = const []}) => FriendCategory(
  id: 'c1',
  ownerId: _alice,
  name: 'Fredagsmiddag',
  emoji: '👥',
  friendUserIds: members,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Future<void> _seed(
  FakeFirebaseFirestore firestore,
  String ownerId,
  FriendCategory category,
) => firestore
    .collection('users')
    .doc(ownerId)
    .collection('friend_categories')
    .doc(category.id)
    .set(category.toFirestore());

FirebaseFirestore _offlineDb() {
  final db = _MockFirestore();
  final users = _MockCollection();
  final userDoc = _MockDoc();
  final groups = _MockCollection();
  final groupDoc = _MockDoc();
  final snap = _MockSnapshot();
  final metadata = _MockMetadata();
  when(() => db.collection('users')).thenReturn(users);
  when(() => users.doc(_alice)).thenReturn(userDoc);
  when(() => userDoc.collection('friend_categories')).thenReturn(groups);
  when(() => groups.doc('c1')).thenReturn(groupDoc);
  when(() => groupDoc.get(any())).thenAnswer((_) async => snap);
  when(() => metadata.isFromCache).thenReturn(true);
  when(() => snap.metadata).thenReturn(metadata);
  return db;
}

Future<List<Map<String, dynamic>>> _rows(FakeFirebaseFirestore audit) async {
  await pumpEventQueue();
  final snap = await audit.collection('audit_logs').get();
  return snap.docs.map((d) => d.data()).toList();
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeFirebaseFirestore audit;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    audit = FakeFirebaseFirestore();
  });

  FriendCategoryRepository repoFor(
    String uid, {
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    bool withAudit = true,
  }) => FriendCategoryRepository(
    firestore: db ?? firestore,
    authRepository: _auth(uid),
    auditRepository: withAudit ? FirebaseAuditRepository(audit) : null,
    functions: functions,
  );

  Future<void> refuseBobUpdate(FriendCategoryRepository repo) async {
    final previous = _cat(members: [_alice]);
    await _seed(firestore, _alice, previous);
    await expectLater(
      repo.updateOwnedCategory(
        _alice,
        previous,
        previous.copyWith(name: 'Vänner'),
      ),
      throwsA(isA<PermissionDeniedException>()),
    );
  }

  test('a non-owner refused an update leaves one denied audit row', () async {
    await refuseBobUpdate(repoFor(_bob));

    final rows = await _rows(audit);
    expect(rows, hasLength(1));
    expect(rows.single['granted'], false);
    expect(rows.single['operation'], 'update');
    expect(rows.single['userId'], _bob);
    expect(rows.single['resourceType'], 'friend_category');
  });

  test('a repository built without an audit repository persists no row on '
      'a refusal', () async {
    await refuseBobUpdate(repoFor(_bob, withAudit: false));

    expect(await _rows(audit), isEmpty);
  });

  group('handOverGroup', () {
    late _MockFunctions functions;
    late _MockCallable callable;

    setUp(() async {
      functions = _MockFunctions();
      callable = _MockCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      await _seed(firestore, _alice, _cat(members: [_bob]));
    });

    test('a group not stored under the caller is refused and audited as '
        'denied', () async {
      await firestore.doc('users/$_alice/friend_categories/c1').delete();
      await _seed(firestore, _bob, _cat());

      final outcome = await repoFor(
        _alice,
        functions: functions,
      ).handOverGroup('c1', _bob);

      expect(outcome, GroupHandOverOutcome.failed);
      final rows = await _rows(audit);
      expect(rows, hasLength(1));
      expect(rows.single['granted'], false);
      expect(rows.single['operation'], 'hand_over_group');
      expect(
        (rows.single['metadata'] as Map)['details'],
        contains('not-stored-under-caller'),
      );
    });

    test('a transport failure with the group still stored records no '
        'denial', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(code: 'unavailable', message: 'network'),
      );

      final outcome = await repoFor(
        _alice,
        functions: functions,
      ).handOverGroup('c1', _bob);

      expect(outcome, GroupHandOverOutcome.failed);
      final rows = await _rows(audit);
      expect(rows.where((r) => r['granted'] == false), isEmpty);
    });
  });

  test('leaving a group offline is refused and audited as denied', () async {
    await expectLater(
      repoFor(_bob, db: _offlineDb()).removeSelfFromCategory(_alice, 'c1'),
      throwsA(isA<OfflineAccessControlChangeException>()),
    );

    final rows = await _rows(audit);
    expect(rows, hasLength(1));
    expect(rows.single['granted'], false);
    expect(rows.single['operation'], 'remove_self_as_member');
  });

  test('a successful save by the owner persists no audit row', () async {
    await repoFor(_alice).saveCategory(_alice, _cat(members: [_alice]));

    expect(await _rows(audit), isEmpty);
  });

  test('a successful hand-over persists no audit row', () async {
    final functions = _MockFunctions();
    final callable = _MockCallable();
    when(() => functions.httpsCallable(any())).thenReturn(callable);
    when(
      () => callable.call<Object?>(any()),
    ).thenAnswer((_) async => _FakeCallableResult());
    await _seed(firestore, _alice, _cat(members: [_bob]));

    final outcome = await repoFor(
      _alice,
      functions: functions,
    ).handOverGroup('c1', _bob);

    expect(outcome, GroupHandOverOutcome.done);
    expect(await _rows(audit), isEmpty);
  });

  group('when the audit write itself fails', () {
    late _ThrowingAudit broken;

    void expectAuditAttempted() => verify(
      () => broken.logPermissionCheck(
        userId: any(named: 'userId'),
        operation: any(named: 'operation'),
        resourceType: any(named: 'resourceType'),
        granted: false,
        resourceId: any(named: 'resourceId'),
        metadata: any(named: 'metadata'),
      ),
    ).called(1);

    FriendCategoryRepository repoWithBrokenAudit(
      String uid, {
      FirebaseFirestore? db,
    }) {
      broken = _ThrowingAudit();
      when(
        () => broken.logPermissionCheck(
          userId: any(named: 'userId'),
          operation: any(named: 'operation'),
          resourceType: any(named: 'resourceType'),
          granted: any(named: 'granted'),
          resourceId: any(named: 'resourceId'),
          metadata: any(named: 'metadata'),
        ),
      ).thenThrow(Exception('audit down'));
      return FriendCategoryRepository(
        firestore: db ?? firestore,
        authRepository: _auth(uid),
        auditRepository: broken,
      );
    }

    test('a refused update still throws PermissionDeniedException', () async {
      await refuseBobUpdate(repoWithBrokenAudit(_bob));
      expectAuditAttempted();
    });

    test('a refused offline leave still throws '
        'OfflineAccessControlChangeException', () async {
      await expectLater(
        repoWithBrokenAudit(
          _bob,
          db: _offlineDb(),
        ).removeSelfFromCategory(_alice, 'c1'),
        throwsA(isA<OfflineAccessControlChangeException>()),
      );
      expectAuditAttempted();
    });
  });

  test('a change that adds and removes members on a group no longer stored '
      'under the owner throws and recreates nothing', () async {
    final previous = _cat(members: [_alice, _bob]);

    await expectLater(
      repoFor(_alice).updateOwnedCategory(
        _alice,
        previous,
        previous.copyWith(friendUserIds: [_alice, 'user-carol']),
      ),
      throwsA(anything),
    );

    final doc = await firestore.doc('users/$_alice/friend_categories/c1').get();
    expect(doc.exists, isFalse);
  });
}
