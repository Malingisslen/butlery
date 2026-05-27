/// Unit tests for FirebaseSocialRequestRepository.
///
/// The repo lives in the unified `social_requests` collection with a
/// `type` discriminator (friend / groupInvitation) and a `status`
/// state machine (pending/accepted/rejected/cancelled/expired). We
/// exercise both branches plus the cleanup/stats helpers.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _carol = 'user-carol';

FirebaseSocialRequestRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId, displayName: 'A'),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseSocialRequestRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

SocialRequest _friendReq({
  String id = 'req-1',
  String from = _alice,
  String to = _bob,
  SocialRequestStatus status = SocialRequestStatus.pending,
  DateTime? sentAt,
}) {
  return SocialRequest(
    id: id,
    type: SocialRequestType.friend,
    fromUserId: from,
    toUserId: to,
    status: status,
    sentAt: sentAt ?? DateTime.utc(2026, 1, 1),
    expiresAt:
        (sentAt ?? DateTime.utc(2026, 1, 1)).add(const Duration(days: 14)),
  );
}

SocialRequest _groupInv({
  String id = 'inv-1',
  String from = _alice,
  String to = _bob,
  String groupId = 'g1',
  SocialRequestStatus status = SocialRequestStatus.pending,
  DateTime? sentAt,
}) {
  return SocialRequest(
    id: id,
    type: SocialRequestType.groupInvitation,
    fromUserId: from,
    toUserId: to,
    groupId: groupId,
    groupName: 'Team',
    groupEmoji: '🍳',
    fromUserName: from,
    status: status,
    sentAt: sentAt ?? DateTime.utc(2026, 1, 1),
    expiresAt:
        (sentAt ?? DateTime.utc(2026, 1, 1)).add(const Duration(days: 14)),
  );
}

Future<void> _seed(
  FakeFirebaseFirestore firestore,
  SocialRequest req,
) async {
  await firestore
      .collection('social_requests')
      .doc(req.id)
      .set(req.toFirestore());
}

void main() {
  group('createRequest', () {
    test('writes request doc and rate-limit doc atomically', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);

      await repo.createRequest(_friendReq());

      final reqDoc =
          await firestore.collection('social_requests').doc('req-1').get();
      expect(reqDoc.exists, isTrue);
      expect(reqDoc.data()?['type'], 'friend');
      expect(reqDoc.data()?['status'], 'pending');

      final rateDoc = await firestore
          .collection('users')
          .doc(_alice)
          .collection('rate_limits')
          .doc('social_requests')
          .get();
      expect(rateDoc.exists, isTrue);
      expect(rateDoc.data()?['expireAt'], isNotNull);
    });

    test('rejects non-pending initial status', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo
            .createRequest(_friendReq(status: SocialRequestStatus.accepted)),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('rejects when sender is not current user', () async {
      final repo = _repo(FakeFirebaseFirestore(), authedUserId: _carol);

      expect(
        () => repo.createRequest(_friendReq()),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('getRequest', () {
    test('returns parsed request when doc exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq());

      final got = await repo.getRequest('req-1');
      expect(got, isNotNull);
      expect(got!.fromUserId, _alice);
      expect(got.type, SocialRequestType.friend);
    });

    test('returns null when missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.getRequest('ghost'), isNull);
    });
  });

  group('updateRequestStatus', () {
    test('sender can cancel', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq());

      await repo.updateRequestStatus(
          'req-1', {'status': SocialRequestStatus.cancelled.name});

      final doc =
          await firestore.collection('social_requests').doc('req-1').get();
      expect(doc.data()?['status'], 'cancelled');
    });

    test('recipient cannot cancel', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(firestore, _friendReq());

      expect(
        () => repo.updateRequestStatus(
            'req-1', {'status': SocialRequestStatus.cancelled.name}),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('recipient can accept', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(firestore, _friendReq());

      await repo.updateRequestStatus(
          'req-1', {'status': SocialRequestStatus.accepted.name});

      final doc =
          await firestore.collection('social_requests').doc('req-1').get();
      expect(doc.data()?['status'], 'accepted');
    });

    test('sender cannot accept their own request', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq());

      expect(
        () => repo.updateRequestStatus(
            'req-1', {'status': SocialRequestStatus.accepted.name}),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('missing request throws ResourceNotFound', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(
        () => repo.updateRequestStatus(
            'ghost', {'status': SocialRequestStatus.accepted.name}),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });
  });

  group('deleteRequest', () {
    test('sender can delete', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq());

      await repo.deleteRequest('req-1');

      expect(
          (await firestore.collection('social_requests').doc('req-1').get())
              .exists,
          isFalse);
    });

    test('recipient can delete', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(firestore, _friendReq());

      await repo.deleteRequest('req-1');

      expect(
          (await firestore.collection('social_requests').doc('req-1').get())
              .exists,
          isFalse);
    });

    test('third party cannot delete', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _carol);
      await _seed(firestore, _friendReq());

      expect(
        () => repo.deleteRequest('req-1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('missing request is a silent no-op', () async {
      final repo = _repo(FakeFirebaseFirestore());

      // Should not throw.
      await repo.deleteRequest('ghost');
    });
  });

  group('friend request queries', () {
    test('getIncomingFriendRequests returns only pending requests to me',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(firestore, _friendReq(id: 'r1', from: _alice, to: _bob));
      await _seed(
          firestore, _friendReq(id: 'r2', from: _carol, to: _bob)); // pending
      await _seed(
          firestore,
          _friendReq(
              id: 'r3',
              from: _alice,
              to: _bob,
              status: SocialRequestStatus.accepted)); // not pending
      await _seed(
          firestore, _groupInv(id: 'g1', from: _alice, to: _bob)); // wrong type

      final results = await repo.getIncomingFriendRequests();

      expect(results.map((r) => r.id).toSet(), {'r1', 'r2'});
    });

    test('getSentFriendRequests returns only pending requests from me',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq(id: 'r1', from: _alice, to: _bob));
      await _seed(firestore, _friendReq(id: 'r2', from: _bob, to: _alice));

      final results = await repo.getSentFriendRequests();
      expect(results.map((r) => r.id), ['r1']);
    });

    test('friendRequestExists true when pending pair found', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq(id: 'r1', from: _alice, to: _bob));

      expect(await repo.friendRequestExists(_alice, _bob), isTrue);
      expect(await repo.friendRequestExists(_bob, _alice), isFalse);
    });
  });

  group('friend request streams', () {
    test('incomingFriendRequestsStream emits pending requests', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(firestore, _friendReq(id: 'r1', from: _alice, to: _bob));

      final first = await repo.incomingFriendRequestsStream(_bob).first;
      expect(first.length, 1);
      expect(first[0].id, 'r1');
    });

    test('sentFriendRequestsStream emits pending sent requests', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq(id: 'r1', from: _alice, to: _bob));
      await _seed(firestore, _friendReq(id: 'r2', from: _alice, to: _carol));

      final first = await repo.sentFriendRequestsStream(_alice).first;
      expect(first.map((r) => r.id).toSet(), {'r1', 'r2'});
    });
  });

  group('group invitation queries', () {
    test('getReceivedInvitations returns invitations sent to current user',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: _bob);
      await _seed(firestore, _groupInv(id: 'g1', to: _bob));
      await _seed(firestore, _groupInv(id: 'g2', to: _carol));
      await _seed(firestore, _friendReq(id: 'f1', to: _bob)); // not a group inv

      final results = await repo.getReceivedInvitations();
      expect(results.map((g) => g.id), ['g1']);
    });

    test('getSentInvitations returns invitations sent by current user',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _groupInv(id: 'g1', from: _alice, to: _bob));
      await _seed(firestore, _groupInv(id: 'g2', from: _carol, to: _bob));

      final results = await repo.getSentInvitations();
      expect(results.map((g) => g.id), ['g1']);
    });

    test('hasPendingInvitation distinguishes group + recipient pair', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _groupInv(id: 'g1', groupId: 'team-1', to: _bob));

      expect(await repo.hasPendingInvitation('team-1', _bob), isTrue);
      expect(await repo.hasPendingInvitation('team-2', _bob), isFalse);
      expect(await repo.hasPendingInvitation('team-1', _carol), isFalse);
    });
  });

  group('group invitation streams', () {
    test('receivedInvitationsStream emits pending invitations for user',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _groupInv(id: 'g1', to: _bob));

      final first = await repo.receivedInvitationsStream(_bob).first;
      expect(first.length, 1);
      expect(first[0].id, 'g1');
    });

    test('sentInvitationsStream emits invitations from user', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _groupInv(id: 'g1', from: _alice, to: _bob));
      await _seed(firestore, _groupInv(id: 'g2', from: _alice, to: _carol));

      final first = await repo.sentInvitationsStream(_alice).first;
      expect(first.map((g) => g.id).toSet(), {'g1', 'g2'});
    });
  });

  group('cleanup operations', () {
    test('expiredRequests returns refs for pending requests past expiry',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Past expiry (sentAt was 2026-01-01, expiry = +14 days → 2026-01-15)
      await _seed(firestore, _friendReq(id: 'r1'));
      // Not expired by virtue of "as of" check
      await _seed(
          firestore,
          _friendReq(
              id: 'r2',
              sentAt: DateTime.utc(2026, 5, 1))); // expires 2026-05-15
      await _seed(
          firestore,
          _friendReq(
              id: 'r3', status: SocialRequestStatus.accepted)); // not pending

      final refs = await repo.expiredRequests(DateTime.utc(2026, 2, 1));
      expect(refs.map((r) => r.id), ['r1']);
    });

    test('oldRequests returns requests with sentAt < cutoff', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq(id: 'r1', to: _bob));
      await _seed(firestore,
          _friendReq(id: 'r2', to: _bob, sentAt: DateTime.utc(2026, 6, 1)));

      final docs = await repo.oldRequests(_bob, DateTime.utc(2026, 3, 1));
      expect(docs.map((d) => d.id), ['r1']);
    });

    test('deleteDocuments batch-removes given refs', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq(id: 'r1'));
      await _seed(firestore, _friendReq(id: 'r2', to: _carol));

      final refs = (await firestore.collection('social_requests').get())
          .docs
          .map((d) => d.reference)
          .toList();

      await repo.deleteDocuments(refs);

      final remaining =
          (await firestore.collection('social_requests').get()).docs;
      expect(remaining, isEmpty);
    });

    test('deleteDocuments no-ops on empty list', () async {
      final repo = _repo(FakeFirebaseFirestore());

      // Should not throw or call requireCurrentUserId.
      await repo.deleteDocuments(const []);
    });

    test('updateDocuments batch-updates given refs', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq(id: 'r1'));
      await _seed(firestore, _friendReq(id: 'r2', to: _carol));

      final refs = (await firestore.collection('social_requests').get())
          .docs
          .map((d) => d.reference)
          .toList();

      await repo.updateDocuments(refs, {'status': 'expired'});

      final after = await firestore.collection('social_requests').get();
      for (final doc in after.docs) {
        expect(doc.data()['status'], 'expired');
      }
    });

    test('cleanupExpired marks expired pending requests', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Default expiry of _friendReq is sentAt + 14d = 2026-01-15 — expired
      // by today (2026-05-21).
      await _seed(firestore, _friendReq(id: 'r1'));
      await _seed(firestore, _friendReq(id: 'r2', to: _carol));

      final count = await repo.cleanupExpired();

      expect(count, 2);
      final docs = await firestore.collection('social_requests').get();
      for (final doc in docs.docs) {
        expect(doc.data()['status'], 'expired');
      }
    });

    test('cleanupExpired returns 0 when no expired requests', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(
          firestore,
          _friendReq(
              id: 'r1', sentAt: DateTime.utc(2030, 1, 1))); // future expiry

      expect(await repo.cleanupExpired(), 0);
    });
  });

  group('statistics', () {
    test('getFriendRequestStatistics counts pending incoming + sent', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Pending to Alice
      await _seed(firestore, _friendReq(id: 'r1', from: _bob, to: _alice));
      await _seed(firestore, _friendReq(id: 'r2', from: _carol, to: _alice));
      // Pending from Alice
      await _seed(firestore, _friendReq(id: 'r3', from: _alice, to: _bob));

      final stats = await repo.getFriendRequestStatistics(_alice);
      expect(stats['incoming'], 2);
      expect(stats['sent'], 1);
    });

    test('getInvitationStatistics counts pending received + sent', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _groupInv(id: 'g1', from: _bob, to: _alice));
      await _seed(firestore, _groupInv(id: 'g2', from: _alice, to: _bob));
      await _seed(firestore, _groupInv(id: 'g3', from: _alice, to: _carol));

      final stats = await repo.getInvitationStatistics(_alice);
      expect(stats['pendingReceived'], 1);
      expect(stats['pendingSent'], 2);
    });
  });

  group('permission validators', () {
    test('validateCreatePermission only true when current user is sender',
        () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(await repo.validateCreatePermission(_alice, _friendReq()), isTrue);
      expect(
          await repo.validateCreatePermission(_carol, _friendReq()), isFalse);
    });

    test('validateReadPermission true for sender or recipient', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final req = _friendReq();

      expect(await repo.validateReadPermission(_alice, 'r', req), isTrue);
      expect(await repo.validateReadPermission(_bob, 'r', req), isTrue);
      expect(await repo.validateReadPermission(_carol, 'r', req), isFalse);
      expect(await repo.validateReadPermission(_alice, 'r', null), isFalse);
    });

    test('validateUpdatePermission true for sender or recipient', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final req = _friendReq();

      expect(await repo.validateUpdatePermission(_alice, 'r', req), isTrue);
      expect(await repo.validateUpdatePermission(_bob, 'r', req), isTrue);
      expect(await repo.validateUpdatePermission(_carol, 'r', req), isFalse);
    });

    test('validateDeletePermission reads then checks parties', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seed(firestore, _friendReq());

      expect(await repo.validateDeletePermission(_alice, 'req-1'), isTrue);
      expect(await repo.validateDeletePermission(_bob, 'req-1'), isTrue);
      expect(await repo.validateDeletePermission(_carol, 'req-1'), isFalse);
    });

    test('validateDeletePermission false when missing', () async {
      final repo = _repo(FakeFirebaseFirestore());

      expect(await repo.validateDeletePermission(_alice, 'ghost'), isFalse);
    });
  });
}
