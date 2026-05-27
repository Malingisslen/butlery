/// Unit tests for BaseSharedContentRepository contract.
///
/// The class is abstract; we exercise it via FirebaseSharedShoppingRepository
/// (a concrete subclass) so the base-class behaviours under test — member /
/// collaborator subcollections, denormalized counters, view/engagement/dismissal
/// metadata delegation, content lookup via collection-group query — get real
/// coverage without owning the concrete class's specifics.
///
/// Pattern follows test/unit/repositories/firebase/modules/conversation_mutation_module_test.dart
/// — FakeFirebaseFirestore directly, no global ServiceLocator wiring.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_dismissal_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_engagement_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_view_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _userId = 'user-alice';
const _otherUserId = 'user-bob';
const _listId = 'list-1';

SharedShoppingList _list({
  String id = _listId,
  String sharedBy = _userId,
  String listName = 'Veckohandling',
  DateTime? sharedAt,
}) {
  return SharedShoppingList(
    id: id,
    sharedByUserId: sharedBy,
    sharedByDisplayName: 'Alice',
    sharedAt: sharedAt ?? DateTime.utc(2026, 1, 15),
    listName: listName,
    itemCount: 3,
    originalOwnerId: sharedBy,
    originalOwnerDisplayName: 'Alice',
  );
}

FirebaseSharedShoppingRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _userId,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId, displayName: 'A'),
    userId: authedUserId,
    isAuthenticated: true,
  );

  return FirebaseSharedShoppingRepository(
    firestore: firestore,
    authRepository: mockAuth,
    viewRepository: SharedShoppingViewRepository(
      firestore: firestore,
      authRepository: mockAuth,
    ),
    engagementRepository: SharedShoppingEngagementRepository(
      firestore: firestore,
      authRepository: mockAuth,
    ),
    dismissalRepository: SharedShoppingDismissalRepository(
      firestore: firestore,
      authRepository: mockAuth,
    ),
  );
}

Future<void> _seedDoc(
  FakeFirebaseFirestore firestore,
  SharedShoppingList list, {
  List<String>? members,
}) async {
  final data = list.toFirestore();
  data['contentType'] = 'shopping_list';
  await firestore.collection('shared_content').doc(list.id).set(data);
  if (members != null) {
    for (final uid in members) {
      await firestore
          .collection('shared_content')
          .doc(list.id)
          .collection('members')
          .doc(uid)
          .set({
        'userId': uid,
        'displayName': uid,
        'addedAt': DateTime.utc(2026, 1, 15).millisecondsSinceEpoch,
        'addedBy': list.sharedByUserId,
        'role': 'viewer',
      });
    }
  }
}

void main() {
  group('BaseSharedContentRepository — counter operations', () {
    test('incrementUnreadCounter creates counter doc with merge', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.incrementUnreadCounter(_userId);

      final doc = await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .get();
      expect(doc.exists, isTrue);
      // FakeFirestore resolves FieldValue.increment(1) to 1 on first write.
      expect(doc.data()?['unreadSharedShoppingLists'], 1);
      expect(doc.data()?['totalSharedContent'], 1);
    });

    test('incrementUnreadCounter increments existing value', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.incrementUnreadCounter(_userId);
      await repo.incrementUnreadCounter(_userId);

      final doc = await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .get();
      expect(doc.data()?['unreadSharedShoppingLists'], 2);
      expect(doc.data()?['totalSharedContent'], 2);
    });

    test('decrementUnreadCounter no-ops when counter is missing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.decrementUnreadCounter(_userId);

      final doc = await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .get();
      // Transaction reads then no-ops because exists==false → still no doc.
      expect(doc.exists, isFalse);
    });

    test('decrementUnreadCounter no-ops when count is already 0', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Seed counter at 0.
      await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .set({'unreadSharedShoppingLists': 0});

      await repo.decrementUnreadCounter(_userId);

      final doc = await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .get();
      expect(doc.data()?['unreadSharedShoppingLists'], 0);
    });

    test('decrementUnreadCounter decrements when count > 0', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.incrementUnreadCounter(_userId);
      await repo.incrementUnreadCounter(_userId);

      await repo.decrementUnreadCounter(_userId);

      final doc = await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .get();
      expect(doc.data()?['unreadSharedShoppingLists'], 1);
    });

    test('getUnreadCountFromCounter returns 0 when doc missing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      expect(await repo.getUnreadCountFromCounter(_userId), 0);
    });

    test('getUnreadCountFromCounter returns stored value', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .set({'unreadSharedShoppingLists': 7});

      expect(await repo.getUnreadCountFromCounter(_userId), 7);
    });

    test('getUnreadCountForUser delegates to counter doc for self', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await repo.incrementUnreadCounter(_userId);

      expect(await repo.getUnreadCountForUser(_userId), 1);
    });

    test('getUnreadCountForUser rejects access for another user', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo.getUnreadCountForUser(_otherUserId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('BaseSharedContentRepository — createSharedContent', () {
    test('persists doc with contentType discriminator', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      final id = await repo.createSharedContent(_list());

      final doc = await firestore.collection('shared_content').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['contentType'], 'shopping_list');
      expect(doc.data()?['listName'], 'Veckohandling');
    });

    test('initialSharedToUserIds becomes denormalized array', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      final id = await repo.createSharedContent(
        _list(),
        initialSharedToUserIds: ['friend-1', 'friend-2'],
      );

      final doc = await firestore.collection('shared_content').doc(id).get();
      expect(doc.data()?['sharedToUserIds'], ['friend-1', 'friend-2']);
    });
  });

  group('BaseSharedContentRepository — members subcollection', () {
    test('addMember writes member doc + sharedToUserIds + counter bump',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      await repo.addMember(_listId, 'friend-1',
          addedBy: _userId, displayName: 'Bob', role: 'editor');

      final memberDoc = await firestore
          .collection('shared_content')
          .doc(_listId)
          .collection('members')
          .doc('friend-1')
          .get();
      expect(memberDoc.exists, isTrue);
      expect(memberDoc.data()?['role'], 'editor');
      expect(memberDoc.data()?['displayName'], 'Bob');

      final parent =
          await firestore.collection('shared_content').doc(_listId).get();
      expect(parent.data()?['sharedToUserIds'], contains('friend-1'));

      final counter = await firestore
          .collection('users')
          .doc('friend-1')
          .collection('counters')
          .doc('shared_content')
          .get();
      expect(counter.data()?['unreadSharedShoppingLists'], 1);
    });

    test('addMember rejects when current user is not owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _otherUserId);
      await _seedDoc(firestore, _list()); // owner = _userId

      expect(
        () => repo.addMember(_listId, 'friend-1', addedBy: _otherUserId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('addMember throws repository exception when content missing',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Owner check reads the doc, gets null → wrapped as PermissionDenied.
      expect(
        () => repo.addMember('missing', 'friend-1', addedBy: _userId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('getMembers and getMembersWithInfo round-trip in addedAt order',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      // Seed members with explicit ordering timestamps.
      final listRef = firestore.collection('shared_content').doc(_listId);
      await listRef.collection('members').doc('m1').set({
        'userId': 'm1',
        'displayName': 'Alice One',
        'addedAt': DateTime.utc(2026, 1, 10).millisecondsSinceEpoch,
        'addedBy': _userId,
        'role': 'viewer',
      });
      await listRef.collection('members').doc('m2').set({
        'userId': 'm2',
        'displayName': 'Bob Two',
        'addedAt': DateTime.utc(2026, 1, 11).millisecondsSinceEpoch,
        'addedBy': _userId,
        'role': 'editor',
      });

      final ids = await repo.getMembers(_listId);
      expect(ids, ['m1', 'm2']);

      final infos = await repo.getMembersWithInfo(_listId, limit: 5);
      expect(infos.length, 2);
      expect(infos[0].userId, 'm1');
      expect(infos[1].role, 'editor');
    });

    test('isMember returns true/false correctly', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list(), members: ['m1']);

      expect(await repo.isMember(_listId, 'm1'), isTrue);
      expect(await repo.isMember(_listId, 'm2'), isFalse);
    });

    test('removeMember allows self-removal even without owner status',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'm1');
      await _seedDoc(firestore, _list(), members: ['m1']);

      await repo.removeMember(_listId, 'm1');

      final stillMember = await repo.isMember(_listId, 'm1');
      expect(stillMember, isFalse);
    });

    test('removeMember rejects removing someone else when not owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'm1');
      await _seedDoc(firestore, _list(), members: ['m1', 'm2']);

      expect(
        () => repo.removeMember(_listId, 'm2'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('removeMember by owner strips sharedToUserIds entry', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());
      await repo.addMember(_listId, 'friend-1', addedBy: _userId);

      await repo.removeMember(_listId, 'friend-1');

      final parent =
          await firestore.collection('shared_content').doc(_listId).get();
      expect(parent.data()?['sharedToUserIds'] ?? const [],
          isNot(contains('friend-1')));
    });
  });

  group('BaseSharedContentRepository — collaborators subcollection', () {
    test('addCollaborator writes joinedAt/lastEditAt doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      await repo.addCollaborator(_listId, 'collab-1');

      final doc = await firestore
          .collection('shared_content')
          .doc(_listId)
          .collection('collaborators')
          .doc('collab-1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['userId'], 'collab-1');
      expect(doc.data()?['joinedAt'], isNotNull);
    });

    test('addCollaborator rejects when not owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _otherUserId);
      await _seedDoc(firestore, _list());

      expect(
        () => repo.addCollaborator(_listId, 'collab-1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('isCollaborator + getCollaborators reflect subcollection state',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());
      await repo.addCollaborator(_listId, 'collab-1');

      expect(await repo.isCollaborator(_listId, 'collab-1'), isTrue);
      expect(await repo.isCollaborator(_listId, 'collab-2'), isFalse);
      expect(await repo.getCollaborators(_listId, limit: 5), ['collab-1']);
    });

    test('removeCollaborator allows self-removal', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());
      await repo.addCollaborator(_listId, 'collab-1');
      // Now authenticate as that collaborator.
      final selfRepo = _repo(firestore, authedUserId: 'collab-1');

      await selfRepo.removeCollaborator(_listId, 'collab-1');

      expect(await selfRepo.isCollaborator(_listId, 'collab-1'), isFalse);
    });

    test('removeCollaborator rejects removing another when not owner',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());
      await repo.addCollaborator(_listId, 'collab-2');

      final intruder = _repo(firestore, authedUserId: 'collab-1');
      expect(
        () => intruder.removeCollaborator(_listId, 'collab-2'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('BaseSharedContentRepository — view / engagement / dismissal', () {
    test('addView + hasViewed round-trip via subrepo', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      expect(await repo.hasViewed(_listId, _userId), isFalse);
      await repo.addView(_listId, _userId);
      expect(await repo.hasViewed(_listId, _userId), isTrue);
    });

    test('addEngagement + hasEngaged round-trip', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      expect(await repo.hasEngaged(_listId, _userId), isFalse);
      await repo.addEngagement(_listId, _userId,
          action: 'import', targetId: 'recipe-9');
      expect(await repo.hasEngaged(_listId, _userId), isTrue);
    });

    test('addDismissal + hasDismissed + removeDismissal round-trip', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      await repo.addDismissal(_listId, _userId, reason: 'not relevant');
      expect(await repo.hasDismissed(_listId, _userId), isTrue);
      await repo.removeDismissal(_listId, _userId);
      expect(await repo.hasDismissed(_listId, _userId), isFalse);
    });

    test('markAsImportedOrJoined writes engagement + view + bumps counter',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());
      // Pre-bump counter so decrement has somewhere to land.
      await repo.incrementUnreadCounter(_userId);

      await repo.markAsImportedOrJoined(_listId, _userId);

      expect(await repo.hasEngaged(_listId, _userId), isTrue);
      expect(await repo.hasViewed(_listId, _userId), isTrue);
    });

    test('markAsImportedOrJoined rejects acting on another user', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo.markAsImportedOrJoined(_listId, _otherUserId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('markAsDismissed + undismiss delegate to dismissal subrepo', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      await repo.markAsDismissed(_listId, _userId);
      expect(await repo.hasDismissed(_listId, _userId), isTrue);
      await repo.undismiss(_listId, _userId);
      expect(await repo.hasDismissed(_listId, _userId), isFalse);
    });
  });

  group('BaseSharedContentRepository — delete / lookup / deprecated', () {
    test('deleteSharedContent removes doc when owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      await repo.deleteSharedContent(_listId);

      final doc =
          await firestore.collection('shared_content').doc(_listId).get();
      expect(doc.exists, isFalse);
    });

    test('deleteSharedContent throws ResourceNotFound when missing', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo.deleteSharedContent('ghost'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('deleteSharedContent rejects non-owner', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _otherUserId);
      await _seedDoc(firestore, _list()); // owner = _userId

      expect(
        () => repo.deleteSharedContent(_listId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('getLastDocumentForUser is deprecated and returns null', () async {
      final repo = _repo(FakeFirebaseFirestore());

      // ignore: deprecated_member_use_from_same_package
      expect(await repo.getLastDocumentForUser(_userId), isNull);
    });

    test('getSharedContentForUser filters by contentType discriminator',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Seed one matching shopping_list and one foreign-type doc.
      await _seedDoc(firestore, _list(), members: [_userId]);
      await firestore
          .collection('shared_content')
          .doc('foreign')
          .set({'contentType': 'recipe', 'sharedAt': Timestamp.now()});
      await firestore
          .collection('shared_content')
          .doc('foreign')
          .collection('members')
          .doc(_userId)
          .set({
        'userId': _userId,
        'displayName': _userId,
        'addedAt': DateTime.utc(2026, 1, 15).millisecondsSinceEpoch,
        'addedBy': _userId,
        'role': 'viewer',
      });

      final results = await repo.getSharedContentForUser(_userId);

      expect(results.map((l) => l.id), [_listId]);
    });

    test('getSharedContentForUser empty when user has no memberships',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Owner doc, no member subcollection for _userId.
      await _seedDoc(firestore, _list(sharedBy: _otherUserId));

      expect(await repo.getSharedContentForUser(_userId), isEmpty);
    });

    test('getSharedContentForUser rejects cross-user access', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo.getSharedContentForUser(_otherUserId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('recalculateUnreadCount syncs counter to actual unread membership',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Two lists the user is a member of; neither viewed.
      await _seedDoc(firestore, _list(id: 'l1'), members: [_userId]);
      await _seedDoc(firestore, _list(id: 'l2'), members: [_userId]);

      final count = await repo.recalculateUnreadCount(_userId);

      // FirebaseSharedShoppingRepository.shouldShowToUser → true,
      // isViewedByUser → false, so both contribute.
      expect(count, 2);
      final counter = await firestore
          .collection('users')
          .doc(_userId)
          .collection('counters')
          .doc('shared_content')
          .get();
      expect(counter.data()?['unreadSharedShoppingLists'], 2);
    });

    test('recalculateUnreadCount rejects cross-user', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo.recalculateUnreadCount(_otherUserId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('BaseSharedContentRepository — permission validators', () {
    test('validateCreatePermission only true when sharedByUserId matches',
        () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(await repo.validateCreatePermission(_userId, _list()), isTrue);
      expect(
          await repo.validateCreatePermission(_otherUserId, _list()), isFalse);
    });

    test('validateReadPermission is true for any non-null entity', () async {
      final repo = _repo(FakeFirebaseFirestore());

      // FirebaseSharedShoppingRepository.shouldShowToUser always returns true.
      expect(
          await repo.validateReadPermission(_userId, _listId, _list()), isTrue);
      expect(
          await repo.validateReadPermission(_userId, _listId, null), isFalse);
    });

    test('validateUpdatePermission delegates to isCreatedBy', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(await repo.validateUpdatePermission(_userId, _listId, _list()),
          isTrue);
      expect(
          await repo.validateUpdatePermission(_otherUserId, _listId, _list()),
          isFalse);
    });

    test('validateDeletePermission reads content then checks ownership',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedDoc(firestore, _list());

      expect(await repo.validateDeletePermission(_userId, _listId), isTrue);
      expect(
          await repo.validateDeletePermission(_otherUserId, _listId), isFalse);
    });

    test('validateDeletePermission false when content missing', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(await repo.validateDeletePermission(_userId, 'ghost'), isFalse);
    });
  });
}
