// BUT-2326: a facade that drops `previous` sends a whole-document set and
// seats a member who left. BUT-2324: the facade hands its audit repository
// to the group repository.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/group_hand_over_outcome.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

const _owner = 'test-user-id';

FriendCategory _group(List<String> members, {String name = 'Familj'}) =>
    FriendCategory(
      id: 'g1',
      ownerId: _owner,
      name: name,
      friendUserIds: members,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late UnifiedFriendsService friendsService;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());

    final authRepo = MockFirebaseAuthRepository();
    authRepo.setAuthState(
      user: FakeUser(uid: _owner),
      userId: _owner,
    );
    when(
      () => authRepo.authStateChanges(),
    ).thenAnswer((_) => const Stream<User?>.empty());
    TestServiceLocator.registerMock<AuthRepository>(authRepo);
    TestServiceLocator.registerMock<FirebaseBlockRepository>(
      FirebaseBlockRepository(
        firestore: FirestoreSingleton.instance,
        authRepository: authRepo,
      ),
    );

    friendsService = UnifiedFriendsService(
      firestoreRepository: FakeFirestoreRepository(),
      authRepository: authRepo,
      auditRepository: FirebaseAuditRepository(FirestoreSingleton.instance),
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  test('a rename from a copy that still lists a departed member keeps '
      'them out', () async {
    final ref = FirestoreSingleton.instance
        .collection('users')
        .doc(_owner)
        .collection('friend_categories')
        .doc('g1');
    await ref.set(_group([_owner, 'bob']).toFirestore());
    final before = _group([_owner, 'bob', 'carol']);

    await friendsService.syncCategoryToFirebaseInternal(
      _group([_owner, 'bob', 'carol'], name: 'Vänner'),
      previous: before,
    );

    final stored = (await ref.get()).data()!;
    expect(stored['name'], 'Vänner');
    expect(stored['friendUserIds'], [_owner, 'bob']);
  });

  test('a refusal in the group repository reaches audit_logs', () async {
    final outcome = await friendsService.friendsCategoryRepositoryInternal
        .handOverGroup('not-mine', 'bob');
    await pumpEventQueue();

    expect(outcome, GroupHandOverOutcome.failed);
    final rows = await FirestoreSingleton.instance
        .collection('audit_logs')
        .where('granted', isEqualTo: false)
        .get();
    expect(rows.docs.map((d) => d.data()['operation']), ['hand_over_group']);
  });
}
