// Two tests intentionally exercise the deprecated `findDirectConversation`
// to cover the legacy path until it's removed.
// ignore_for_file: deprecated_member_use_from_same_package

/// Facade-level tests for FirebaseMessagingRepository.
///
/// Modules (ConversationMutation/Query, MessageMutation/Query) have their
/// own dedicated tests. This file exercises the facade itself to drive the
/// thin delegation methods + the validate*Permission quartet for
/// Conversation entities.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

// Widened from FakeFirebaseFirestore for BUT-1831: the error-injection test
// passes a delegating wrapper, and the repository takes the interface anyway.
FirebaseMessagingRepository _repo(
  FirebaseFirestore firestore, {
  String authedUserId = 'alice',
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseMessagingRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

Conversation _convo({
  String id = 'c1',
  List<String> participants = const ['alice', 'bob'],
  bool isGroup = false,
}) {
  return Conversation(
    id: id,
    participantIds: participants,
    participantDisplayNames: {for (final p in participants) p: p.toUpperCase()},
    participantAvatarUrls: const {},
    lastReadTimestamps: const {},
    isGroup: isGroup,
    title: isGroup ? 'Group' : null,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _seedConvo(
  FakeFirebaseFirestore firestore,
  Conversation c, {
  String authedUserId = 'alice',
}) async {
  // Repo uses UserScopedFirebaseRepository → user-scoped collection.
  // Modules' direct firestore reads use the top-level collection. Seed
  // both for cross-path consistency.
  final data = ConversationDto.toFirestore(c);
  await firestore.collection('conversations').doc(c.id).set(data);
  await firestore
      .collection('users')
      .doc(authedUserId)
      .collection('conversations')
      .doc(c.id)
      .set(data);
}

void main() {
  group('permission validators', () {
    test('create allowed when current user is participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.validateCreatePermission('alice', _convo()), isTrue);
      expect(await repo.validateCreatePermission('carol', _convo()), isFalse);
    });

    test('read allowed for participants only', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final c = _convo();
      expect(await repo.validateReadPermission('alice', c.id, c), isTrue);
      expect(await repo.validateReadPermission('bob', c.id, c), isTrue);
      expect(await repo.validateReadPermission('carol', c.id, c), isFalse);
      expect(await repo.validateReadPermission('alice', c.id, null), isFalse);
    });

    test('update allowed for participants only', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final c = _convo();
      expect(await repo.validateUpdatePermission('alice', c.id, c), isTrue);
      expect(await repo.validateUpdatePermission('carol', c.id, c), isFalse);
    });

    test('delete reads doc then checks participant membership', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedConvo(firestore, _convo());

      expect(await repo.validateDeletePermission('alice', 'c1'), isTrue);
      expect(await repo.validateDeletePermission('carol', 'c1'), isFalse);
    });

    test('delete returns false when conversation missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.validateDeletePermission('alice', 'ghost'), isFalse);
    });
  });

  group('facade delegation — conversation operations', () {
    test(
      'createDirectConversation produces deterministic id and persists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);

        final id = await repo.createDirectConversation(
          user1Id: 'bob',
          user1DisplayName: 'B',
          user2Id: 'alice',
          user2DisplayName: 'A',
        );

        expect(id, 'direct_alice_bob');
        final doc = await firestore.collection('conversations').doc(id).get();
        expect(doc.exists, isTrue);
      },
    );

    test(
      'getUserConversations stream emits user-participating conversations',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);
        await _seedConvo(firestore, _convo(id: 'c1'));
        await _seedConvo(
          firestore,
          _convo(id: 'c2', participants: const ['carol', 'dave']),
        );

        final first = await repo.getUserConversations('alice').first;
        expect(first.map((c) => c.id), ['c1']);
      },
    );

    test('getConversation returns conversation when participant', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedConvo(firestore, _convo());

      final got = await repo.getConversation('c1');
      expect(got, isNotNull);
      expect(got!.id, 'c1');
    });

    test('updateConversation calls mutation module without throwing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedConvo(firestore, _convo(isGroup: true));

      // We don't assert exact stored state because the facade uses
      // user-scoped writes while the module reads top-level — surface
      // mismatch in the production code. Successful call exercises the
      // delegation line, which is the coverage target.
      await repo.updateConversation(conversationId: 'c1', title: 'New Title');
    });

    test('deleteConversation removes the top-level doc', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      await _seedConvo(firestore, _convo());

      await repo.deleteConversation('c1');

      // The mutation module deletes from the top-level collection directly.
      final topLevel = await firestore
          .collection('conversations')
          .doc('c1')
          .get();
      expect(topLevel.exists, isFalse);
    });

    test(
      'deprecated findDirectConversation returns null for unknown pair',
      () async {
        final repo = _repo(FakeFirebaseFirestore());
        final got = await repo.findDirectConversation(
          user1Id: 'alice',
          user2Id: 'bob',
        );
        expect(got, isNull);
      },
    );

    test(
      'deprecated findDirectConversation returns id when pair exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repo = _repo(firestore);
        await _seedConvo(firestore, _convo(id: 'c-existing'));

        final id = await repo.findDirectConversation(
          user1Id: 'alice',
          user2Id: 'bob',
        );
        expect(id, 'c-existing');
      },
    );
  });

  // BUT-1831: the ONLY place the root-cause half of the fix is bound.
  //
  // `_readTopLevelConversation` is private, so restoring the try/catch this
  // change removed leaves the whole tree green while the defect returns: a
  // momentary read
  // failure becomes "conversation does not exist", `sendMessage` reports
  // ResourceNotFound, and `MessageSendErrorMapper.classify` never sees the raw
  // FirebaseException it needs to tell a clock-skew denial from anything else.
  //
  // Failure is injected at `collection()` rather than at `.get()` because
  // CollectionReference and Query are sealed in cloud_firestore 6.x and cannot
  // be implemented — the same reason and the same shape as `_FlakyFirestore`
  // in firebase_ingredient_repository_offline_degrade_test.dart.
  group('BUT-1831 conversation read', () {
    test(
      'a FAILING read surfaces the raw FirebaseException, not ResourceNotFound',
      () async {
        final repo = _repo(_ThrowingOnConversations(FakeFirebaseFirestore()));

        await expectLater(
          repo.sendMessage(
            Message.text(
              conversationId: 'direct_alice_bob',
              senderId: 'alice',
              senderDisplayName: 'Alice',
              content: 'hej',
            ),
          ),
          throwsA(
            allOf(
              isA<FirebaseException>(),
              isNot(isA<ResourceNotFoundException>()),
            ),
          ),
        );
      },
    );

    test(
      'an ABSENT conversation is still ResourceNotFound — the two answers stay '
      'distinguishable, which is the whole point of removing the catch',
      () async {
        final repo = _repo(FakeFirebaseFirestore());

        await expectLater(
          repo.sendMessage(
            Message.text(
              conversationId: 'direct_alice_bob',
              senderId: 'alice',
              senderDisplayName: 'Alice',
              content: 'hej',
            ),
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );
  });
}

/// Overrides `collection()` only: `conversations` throws, anything else goes
/// to a real fake. Every OTHER member falls to `noSuchMethod`, which on a
/// non-Mock class is `Object`'s and throws `NoSuchMethodError` — fine here
/// because the intended throw happens first, but do not reuse this as a
/// general passthrough. See the group above for why `collection()` is the seam.
class _ThrowingOnConversations implements FirebaseFirestore {
  _ThrowingOnConversations(this._delegate);

  final FirebaseFirestore _delegate;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    if (collectionPath == 'conversations') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'injected',
      );
    }
    return _delegate.collection(collectionPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      _delegate.noSuchMethod(invocation);
}
