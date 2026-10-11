/// ListInvitationRepository: the two callables' answers, the recipient's
/// stream, and decline and revoke on the `social_requests` row.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';
import 'package:butlery/repositories/firebase/friends/list_invitation_repository.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

const _anna = 'anna';
const _bob = 'bob';
final _now = DateTime.utc(2026, 10, 11, 12);

void main() {
  late FakeFirebaseFirestore firestore;
  late _MockFunctions functions;
  late _MockCallable callable;

  ListInvitationRepository repoFor(String uid) {
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: uid, displayName: uid),
        userId: uid,
        isAuthenticated: true,
      );
    final social = FirebaseSocialRequestRepository(
      firestore: firestore,
      authRepository: auth,
      timestampProvider: TestTimestampProvider(),
    );
    return ListInvitationRepository(
      firestore: firestore,
      socialRequests: social,
      timestampProvider: TestTimestampProvider(),
      functions: functions,
    );
  }

  /// A server whose `social_requests` rules refuse every read of the row with
  /// [code], the way a get of a deleted row is refused in production.
  (ListInvitationRepository, _MockDoc) refusingRepoFor(
    String uid,
    String code,
  ) {
    final refusing = _MockFirestore();
    final collection = _MockCollection();
    final doc = _MockDoc();
    when(() => refusing.collection(any())).thenReturn(collection);
    when(() => collection.doc(any())).thenReturn(doc);
    final refusal = FirebaseException(plugin: 'cloud_firestore', code: code);
    when(() => doc.get(any())).thenThrow(refusal);
    when(() => doc.get()).thenThrow(refusal);
    final auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: uid, displayName: uid),
        userId: uid,
        isAuthenticated: true,
      );
    final repo = ListInvitationRepository(
      firestore: refusing,
      socialRequests: FirebaseSocialRequestRepository(
        firestore: refusing,
        authRepository: auth,
        timestampProvider: TestTimestampProvider(),
      ),
      timestampProvider: TestTimestampProvider(),
      functions: functions,
    );
    return (repo, doc);
  }

  /// The one row read happened, and it asked the server.
  void expectServerRead(_MockDoc doc) {
    final options = verify(() => doc.get(captureAny())).captured.single;
    expect((options as GetOptions).source, Source.server);
  }

  Future<void> seed(
    String id, {
    String from = _anna,
    String to = _bob,
    String type = 'listInvitation',
    String status = 'pending',
    DateTime? sentAt,
    DateTime? expiresAt,
    String listId = 'list-1',
  }) {
    final sent = sentAt ?? _now.subtract(const Duration(hours: 1));
    return firestore.collection('social_requests').doc(id).set({
      'type': type,
      'fromUserId': from,
      'toUserId': to,
      'status': status,
      'sentAt': sent,
      'expiresAt': expiresAt ?? sent.add(const Duration(days: 7)),
      'listId': listId,
      'listName': 'Veckohandling',
      'permission': 'edit',
      'fromUserName': 'Anna',
    });
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
  });

  void callableReturns(String name, Map<String, dynamic> data) {
    final result = _MockResult();
    when(() => functions.httpsCallable(name)).thenReturn(callable);
    when(
      () => callable.call<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => result);
    when(() => result.data).thenReturn(data);
  }

  group('sendListInvitationsViaFunction', () {
    test(
      'sends the list, the invitees and the level, and maps the answer',
      () async {
        callableReturns('sendListInvitations', {
          'sent': [
            {'userId': 'u1', 'invitationId': 'inv-1'},
          ],
          'skipped': [
            {'userId': 'u2', 'reason': 'self'},
            {'userId': 'u3', 'reason': 'already_member'},
            {'userId': 'u4', 'reason': 'already_invited'},
            {'userId': 'u5', 'reason': 'not_friends'},
            {'userId': 'u6', 'reason': 'unavailable'},
            {'userId': 'u7', 'reason': 'a reason from a newer server'},
          ],
        });

        final result = await repoFor(_anna).sendListInvitationsViaFunction(
          listId: 'list-1',
          userIds: ['u1', 'u2'],
          permission: 'view',
        );

        final sentArgs =
            verify(
                  () => callable.call<Map<String, dynamic>>(captureAny()),
                ).captured.single
                as Map<String, dynamic>;
        expect(sentArgs, {
          'listId': 'list-1',
          'userIds': ['u1', 'u2'],
          'permission': 'view',
        });
        expect(result.sent, {'u1': 'inv-1'});
        expect(
          {for (final s in result.skipped) s.userId: s.reason},
          {
            'u2': ListInviteSkipReason.self,
            'u3': ListInviteSkipReason.alreadyMember,
            'u4': ListInviteSkipReason.alreadyInvited,
            'u5': ListInviteSkipReason.notFriends,
            'u6': ListInviteSkipReason.unavailable,
            'u7': ListInviteSkipReason.unavailable,
          },
        );
      },
    );

    test('an answer with neither list is an empty result', () async {
      callableReturns('sendListInvitations', {});

      final result = await repoFor(_anna).sendListInvitationsViaFunction(
        listId: 'list-1',
        userIds: ['u1'],
      );

      expect(result.sent, isEmpty);
      expect(result.skipped, isEmpty);
    });

    test('a refused call is thrown to the caller', () async {
      when(() => functions.httpsCallable('sendListInvitations')).thenReturn(
        callable,
      );
      when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'no',
          code: 'permission-denied',
        ),
      );

      expect(
        repoFor(_anna).sendListInvitationsViaFunction(
          listId: 'list-1',
          userIds: ['u1'],
        ),
        throwsA(isA<FirebaseFunctionsException>()),
      );
    });
  });

  group('acceptListInvitationViaFunction', () {
    test('passes the invitation id and reads the answer', () async {
      callableReturns('acceptListInvitation', {
        'success': true,
        'alreadyMember': true,
        'listId': 'list-1',
      });

      final result = await repoFor(
        _bob,
      ).acceptListInvitationViaFunction('inv-1');

      final args =
          verify(
                () => callable.call<Map<String, dynamic>>(captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(args, {'invitationId': 'inv-1'});
      expect(result.alreadyMember, isTrue);
      expect(result.listId, 'list-1');
    });
  });

  group('receivedListInvitationsStream', () {
    test('lists only the recipient\'s pending, live list invitations, '
        'newest first', () async {
      await withClock(Clock.fixed(_now), () async {
        await seed(
          'old',
          sentAt: _now.subtract(const Duration(days: 2)),
        );
        await seed('new', sentAt: _now.subtract(const Duration(hours: 1)));
        await seed('expired', sentAt: _now.subtract(const Duration(days: 8)));
        await seed('accepted', status: 'accepted');
        await seed('group', type: 'groupInvitation');
        await seed('friend', type: 'friend');
        await seed('other-recipient', to: 'carol');

        final rows = await repoFor(
          _bob,
        ).receivedListInvitationsStream(_bob).first;

        expect(rows.map((r) => r.id), ['new', 'old']);
        expect(rows.every((r) => r.isListInvitation), isTrue);
        expect(rows.first.listName, 'Veckohandling');
      });
    });

    test('is empty when there is nothing', () async {
      expect(
        await repoFor(_bob).receivedListInvitationsStream(_bob).first,
        isEmpty,
      );
    });
  });

  group('sentListInvitationsStream', () {
    test('lists only the sender\'s own pending, live invitations to that '
        'list, oldest first', () async {
      await withClock(Clock.fixed(_now), () async {
        await seed(
          'first',
          to: 'carol',
          sentAt: _now.subtract(const Duration(days: 2)),
        );
        await seed('second', sentAt: _now.subtract(const Duration(hours: 1)));
        await seed('expired', sentAt: _now.subtract(const Duration(days: 8)));
        await seed('accepted', status: 'accepted');
        await seed('declined', status: 'rejected');
        await seed('other-list', listId: 'list-2');
        await seed('group', type: 'groupInvitation');
        await seed('co-admins', from: 'dora');

        final rows = await repoFor(
          _anna,
        ).sentListInvitationsStream(_anna, 'list-1').first;

        expect(rows.map((r) => r.id), ['first', 'second']);
        expect(rows.every((r) => r.fromUserId == _anna), isTrue);
      });
    });

    test('is empty when nothing was sent', () async {
      expect(
        await repoFor(_anna).sentListInvitationsStream(_anna, 'list-1').first,
        isEmpty,
      );
    });
  });

  group('declineListInvitation', () {
    test('the recipient writes status rejected and a response time', () async {
      await seed('inv-1');

      await repoFor(_bob).declineListInvitation('inv-1');

      final data =
          (await firestore.collection('social_requests').doc('inv-1').get())
              .data()!;
      expect(data['status'], 'rejected');
      expect(data['respondedAt'], isNotNull);
    });

    test(
      'the sender cannot decline their own invitation, row untouched',
      () async {
        await seed('inv-1');

        await expectLater(
          repoFor(_anna).declineListInvitation('inv-1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        final data =
            (await firestore.collection('social_requests').doc('inv-1').get())
                .data()!;
        expect(data['status'], 'pending');
      },
    );

    test('a row that is gone is reported as not found', () async {
      await expectLater(
        repoFor(_bob).declineListInvitation('missing'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test(
      'a row the rules refuse to read (deleted by its sender) is reported '
      'as not found',
      () async {
        final (repo, _) = refusingRepoFor(_bob, 'permission-denied');
        await expectLater(
          repo.declineListInvitation('inv-1'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );

    test('offline asks the server, and stays a FirebaseException with code '
        'unavailable', () async {
      final (repo, doc) = refusingRepoFor(_bob, 'unavailable');
      await expectLater(
        repo.declineListInvitation('inv-1'),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
      expectServerRead(doc);
    });
  });

  group('revokeListInvitation', () {
    test('the sender deletes the row', () async {
      await seed('inv-1');

      await repoFor(_anna).revokeListInvitation('inv-1');

      expect(
        (await firestore.collection('social_requests').doc('inv-1').get())
            .exists,
        isFalse,
      );
    });

    test(
      'a row the rules refuse to read (deleted) is reported as not found',
      () async {
        final (repo, _) = refusingRepoFor(_anna, 'permission-denied');
        await expectLater(
          repo.revokeListInvitation('inv-1'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );

    test('offline asks the server, and stays a FirebaseException with code '
        'unavailable', () async {
      final (repo, doc) = refusingRepoFor(_anna, 'unavailable');
      await expectLater(
        repo.revokeListInvitation('inv-1'),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
      expectServerRead(doc);
    });
  });
}
