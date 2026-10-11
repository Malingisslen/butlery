/// ListInvitationOperations turns the repository's answers and exceptions
/// into the outcomes the view model renders. The repository is the mocked
/// dependency; the mapping is the subject.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/firebase/friends/list_invitation_repository.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';

class _MockRepo extends Mock implements ListInvitationRepository {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockSocial extends Mock implements SocialEventsTracker {}

FirebaseFunctionsException _fn(String code) =>
    FirebaseFunctionsException(message: code, code: code);

void main() {
  late _MockRepo repo;
  late _MockSocial social;
  late ListInvitationOperations ops;
  String? uid;

  setUp(() {
    repo = _MockRepo();
    social = _MockSocial();
    final analytics = _MockAnalytics();
    when(() => analytics.social).thenReturn(social);
    when(
      () => social.logListInvitationSent(count: any(named: 'count')),
    ).thenAnswer((_) async {});
    uid = 'bob';
    ops = ListInvitationOperations(
      repository: repo,
      getCurrentUserId: () => uid,
      analytics: analytics,
    );
  });

  group('acceptListInvitation', () {
    test('a seat taken is accepted', () async {
      when(() => repo.acceptListInvitationViaFunction('inv')).thenAnswer(
        (_) async => const AcceptListInvitationResult(
          alreadyMember: false,
          listId: 'l',
        ),
      );

      expect(
        await ops.acceptListInvitation('inv'),
        ListInvitationOutcome.accepted,
      );
    });

    test(
      'a repeated tap by someone already on the list is alreadyMember',
      () async {
        when(() => repo.acceptListInvitationViaFunction('inv')).thenAnswer(
          (_) async => const AcceptListInvitationResult(
            alreadyMember: true,
            listId: 'l',
          ),
        );

        expect(
          await ops.acceptListInvitation('inv'),
          ListInvitationOutcome.alreadyMember,
        );
      },
    );

    test('a failed-precondition refusal is notAvailable', () async {
      when(
        () => repo.acceptListInvitationViaFunction('inv'),
      ).thenThrow(_fn('failed-precondition'));

      expect(
        await ops.acceptListInvitation('inv'),
        ListInvitationOutcome.notAvailable,
      );
    });

    test('unavailable (no connection) is offline', () async {
      when(
        () => repo.acceptListInvitationViaFunction('inv'),
      ).thenThrow(_fn('unavailable'));

      expect(
        await ops.acceptListInvitation('inv'),
        ListInvitationOutcome.offline,
      );
    });

    for (final code in ['internal', 'permission-denied', 'unauthenticated']) {
      test('$code is a plain failure, not a refusal', () async {
        when(
          () => repo.acceptListInvitationViaFunction('inv'),
        ).thenThrow(_fn(code));

        expect(
          await ops.acceptListInvitation('inv'),
          ListInvitationOutcome.failed,
        );
      });
    }

    test('an error that is not Firebase is a plain failure', () async {
      when(
        () => repo.acceptListInvitationViaFunction('inv'),
      ).thenThrow(StateError('boom'));

      expect(
        await ops.acceptListInvitation('inv'),
        ListInvitationOutcome.failed,
      );
    });
  });

  group('declineListInvitation', () {
    test('a decline that landed is declined', () async {
      when(() => repo.declineListInvitation('inv')).thenAnswer((_) async {});

      expect(
        await ops.declineListInvitation('inv'),
        ListInvitationOutcome.declined,
      );
      verify(() => repo.declineListInvitation('inv')).called(1);
    });

    test('a server read that cannot reach the server is offline', () async {
      when(() => repo.declineListInvitation('inv')).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      expect(
        await ops.declineListInvitation('inv'),
        ListInvitationOutcome.offline,
      );
    });

    test('a row the sender already took back is notAvailable', () async {
      when(() => repo.declineListInvitation('inv')).thenThrow(
        ResourceNotFoundException(
          'gone',
          resourceType: 'social_request',
          resourceId: 'inv',
        ),
      );

      expect(
        await ops.declineListInvitation('inv'),
        ListInvitationOutcome.notAvailable,
      );
    });

    test('any other error is a plain failure', () async {
      when(() => repo.declineListInvitation('inv')).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(
        await ops.declineListInvitation('inv'),
        ListInvitationOutcome.failed,
      );
    });
  });

  group('revokeListInvitation', () {
    test('deletes the row and says revoked', () async {
      when(() => repo.revokeListInvitation('inv')).thenAnswer((_) async {});

      expect(
        await ops.revokeListInvitation('inv'),
        ListInvitationOutcome.revoked,
      );
      verify(() => repo.revokeListInvitation('inv')).called(1);
    });

    test('a refused delete (no longer pending) is a plain failure', () async {
      when(() => repo.revokeListInvitation('inv')).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      expect(
        await ops.revokeListInvitation('inv'),
        ListInvitationOutcome.failed,
      );
    });
  });

  group('sendListInvitations', () {
    test('returns the repository result with outcome sent', () async {
      const result = SendListInvitationsResult(sent: {'u1': 'inv-1'});
      when(
        () => repo.sendListInvitationsViaFunction(
          listId: 'l',
          userIds: ['u1'],
          permission: 'view',
        ),
      ).thenAnswer((_) async => result);

      final out = await ops.sendListInvitations(
        listId: 'l',
        userIds: ['u1'],
        permission: 'view',
      );

      expect(out.outcome, ListInvitationOutcome.sent);
      expect(out.result, same(result));
    });

    test('nothing to send never reaches the server', () async {
      final out = await ops.sendListInvitations(listId: 'l', userIds: []);

      expect(out.outcome, ListInvitationOutcome.failed);
      verifyNever(
        () => repo.sendListInvitationsViaFunction(
          listId: any(named: 'listId'),
          userIds: any(named: 'userIds'),
          permission: any(named: 'permission'),
        ),
      );
    });

    test('a refused call maps like the others', () async {
      when(
        () => repo.sendListInvitationsViaFunction(
          listId: 'l',
          userIds: ['u1'],
          permission: 'edit',
        ),
      ).thenThrow(_fn('unavailable'));

      final out = await ops.sendListInvitations(listId: 'l', userIds: ['u1']);

      expect(out.outcome, ListInvitationOutcome.offline);
      expect(out.result, isNull);
    });
  });

  group('invite', () {
    void stubSend(SendListInvitationsResult result) => when(
      () => repo.sendListInvitationsViaFunction(
        listId: 'l',
        userIds: any(named: 'userIds'),
        permission: any(named: 'permission'),
      ),
    ).thenAnswer((_) async => result);

    test('names who went out and who did not, folding not-a-friend and '
        'unavailable into one list', () async {
      stubSend(
        const SendListInvitationsResult(
          sent: {'u1': 'inv-1'},
          skipped: [
            ListInviteSkip('u2', ListInviteSkipReason.notFriends),
            ListInviteSkip('u3', ListInviteSkipReason.unavailable),
            ListInviteSkip('u4', ListInviteSkipReason.alreadyMember),
            ListInviteSkip('u5', ListInviteSkipReason.alreadyInvited),
            ListInviteSkip('u6', ListInviteSkipReason.self),
          ],
        ),
      );

      final out = await ops.invite(
        listId: 'l',
        userIds: ['u1', 'u2', 'u3', 'u4', 'u5', 'u6'],
      );

      expect(out.invited, ['u1']);
      expect(
        out.notInvited,
        ['u2', 'u3'],
        reason:
            'a block and a missing friendship must read the same; members, '
            'invited and self are already true and are not reported',
      );
      expect(out.callFailed, isFalse);
    });

    test('a call that did not go through reports everyone as not invited, '
        'with the reason', () async {
      when(
        () => repo.sendListInvitationsViaFunction(
          listId: 'l',
          userIds: any(named: 'userIds'),
          permission: any(named: 'permission'),
        ),
      ).thenThrow(_fn('unavailable'));

      final out = await ops.invite(listId: 'l', userIds: ['u1', 'u2']);

      expect(out.callFailed, isTrue);
      expect(out.outcome, ListInvitationOutcome.offline);
      expect(out.notInvited, ['u1', 'u2']);
      expect(out.invited, isEmpty);
      verifyNever(
        () => social.logListInvitationSent(count: any(named: 'count')),
      );
    });

    test(
      'logs one sent event counting the invitations that went out',
      () async {
        stubSend(
          const SendListInvitationsResult(
            sent: {'u1': 'inv-1', 'u2': 'inv-2'},
            skipped: [ListInviteSkip('u3', ListInviteSkipReason.notFriends)],
          ),
        );

        await ops.invite(listId: 'l', userIds: ['u1', 'u2', 'u3']);

        verify(() => social.logListInvitationSent(count: 2)).called(1);
      },
    );

    test('logs nothing when every invitee was skipped', () async {
      stubSend(
        const SendListInvitationsResult(
          skipped: [ListInviteSkip('u1', ListInviteSkipReason.alreadyMember)],
        ),
      );

      await ops.invite(listId: 'l', userIds: ['u1']);

      verifyNever(
        () => social.logListInvitationSent(count: any(named: 'count')),
      );
    });

    test('passes the picked level to the server', () async {
      stubSend(const SendListInvitationsResult());

      await ops.invite(listId: 'l', userIds: ['u1'], permission: 'view');

      verify(
        () => repo.sendListInvitationsViaFunction(
          listId: 'l',
          userIds: ['u1'],
          permission: 'view',
        ),
      ).called(1);
    });
  });

  group('pendingSentForList', () {
    test(
      'streams the signed-in user\'s own pending rows for that list',
      () async {
        final row = SocialRequest.fromMap('inv', {
          'type': 'listInvitation',
          'fromUserId': 'bob',
          'toUserId': 'carol',
          'listId': 'l',
        });
        when(
          () => repo.sentListInvitationsStream('bob', 'l'),
        ).thenAnswer((_) => Stream.value([row]));

        expect(await ops.pendingSentForList('l').first, [row]);
      },
    );

    test('is empty when nobody is signed in', () async {
      uid = null;

      expect(await ops.pendingSentForList('l').toList(), isEmpty);
      verifyNever(() => repo.sentListInvitationsStream(any(), any()));
    });
  });

  group('pendingReceived', () {
    test('streams the repository\'s rows for the signed-in user', () async {
      final row = SocialRequest.fromMap('inv', {
        'type': 'listInvitation',
        'fromUserId': 'anna',
        'toUserId': 'bob',
      });
      when(
        () => repo.receivedListInvitationsStream('bob'),
      ).thenAnswer((_) => Stream.value([row]));

      expect(await ops.pendingReceived.first, [row]);
    });

    test('is empty when nobody is signed in', () async {
      uid = null;

      expect(await ops.pendingReceived.toList(), isEmpty);
      verifyNever(() => repo.receivedListInvitationsStream(any()));
    });
  });
}
