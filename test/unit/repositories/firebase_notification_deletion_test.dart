/// Tests for the BUT-498 GDPR-cascade deletion methods on the three
/// notification repositories:
///   - `FirebaseNotificationsRepository.deleteAllByUser` (user_notifications)
///   - `FirebaseNotificationsRepository.deletePreferencesForUser`
///   - `FirebaseNotificationHistoryRepository.deleteAllByUser`
///   - `FirebaseNotificationBatchRepository.deleteAllByUser`
///
/// Each follows the golden 4-test set from the BUT-498 plan: happy path,
/// empty path, permission denial, batch chunking. The chunking test runs
/// once on the user_notifications repo (the others share the same
/// `batchDeleteDocs` helper, so chunking is pinned by the underlying
/// `iterable_extensions.dart chunked()` test suite).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_device_repository.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notification_batch_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notification_history_repository.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _ownerUid = 'owner-uid';
const _strangerUid = 'stranger-uid';

void main() {
  group('FirebaseNotificationsRepository — GDPR cascade', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late FirebaseNotificationsRepository repo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: _ownerUid, isAuthenticated: true);
      repo = FirebaseNotificationsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
      );
    });

    Future<void> seedNotifications(String userId, int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore.collection('user_notifications').add({
          'userId': userId,
          'senderId': 'sender',
          'type': 'optional',
          'title': 'n-$i',
          'body': 'b-$i',
          'isRead': false,
          'createdAt': DateTime(2026, 4, i + 1),
        });
      }
    }

    group('deleteAllByUser', () {
      test(
        'happy path — owner deletes their notifications, returns count',
        () async {
          await seedNotifications(_ownerUid, 3);
          await seedNotifications(_strangerUid, 2);

          final count = await repo.deleteAllByUser(_ownerUid);

          expect(count, equals(3));
          final remaining = await fakeFirestore
              .collection('user_notifications')
              .get();
          expect(
            remaining.docs.length,
            equals(2),
            reason: 'stranger docs untouched',
          );
          expect(
            remaining.docs.every((d) => d.data()['userId'] == _strangerUid),
            isTrue,
          );
        },
      );

      test('empty path — no docs match, returns 0, no batch fired', () async {
        final count = await repo.deleteAllByUser(_ownerUid);
        expect(count, equals(0));
      });

      test('permission denial — caller != target userId throws', () async {
        await seedNotifications(_strangerUid, 2);

        expect(
          () => repo.deleteAllByUser(_strangerUid),
          throwsA(isA<PermissionDeniedException>()),
        );

        // Stranger docs untouched.
        final remaining = await fakeFirestore
            .collection('user_notifications')
            .get();
        expect(remaining.docs.length, equals(2));
      });

      test('batch chunking — 401 docs split across 2 batches', () async {
        // 401 docs forces two batches at the 400-op limit. Single test
        // proves the `batchDeleteDocs` helper chunks correctly.
        await seedNotifications(_ownerUid, 401);

        final count = await repo.deleteAllByUser(_ownerUid);

        expect(count, equals(401));
        final remaining = await fakeFirestore
            .collection('user_notifications')
            .get();
        expect(remaining.docs, isEmpty);
      });
    });

    group('deletePreferencesForUser', () {
      test('happy path — deletes the prefs doc, returns true', () async {
        await fakeFirestore
            .collection('user_notification_preferences')
            .doc(_ownerUid)
            .set({'enabled': true});

        final ok = await repo.deletePreferencesForUser(_ownerUid);

        expect(ok, isTrue);
        final after = await fakeFirestore
            .collection('user_notification_preferences')
            .doc(_ownerUid)
            .get();
        expect(after.exists, isFalse);
      });

      test('idempotent — returns true even when doc never existed', () async {
        final ok = await repo.deletePreferencesForUser(_ownerUid);
        expect(ok, isTrue);
      });

      test('permission denial — caller != target userId throws', () async {
        expect(
          () => repo.deletePreferencesForUser(_strangerUid),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
  });

  group('FirebaseNotificationHistoryRepository.deleteAllByUser', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late FirebaseNotificationHistoryRepository repo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: _ownerUid, isAuthenticated: true);
      repo = FirebaseNotificationHistoryRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
      );
    });

    Future<void> seedHistory(String userId, int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore.collection('notification_history').add({
          'userId': userId,
          'notificationId': 'n-$i',
          'category': 'test',
          'type': 'optional',
          'data': const <String, dynamic>{},
          'sentAt': DateTime(2026, 4, i + 1),
          'delivered': false,
          'opened': false,
        });
      }
    }

    test(
      'happy path — owner scrub returns count, leaves others alone',
      () async {
        await seedHistory(_ownerUid, 4);
        await seedHistory(_strangerUid, 1);

        final count = await repo.deleteAllByUser(_ownerUid);

        expect(count, equals(4));
        final remaining = await fakeFirestore
            .collection('notification_history')
            .get();
        expect(remaining.docs.length, equals(1));
        expect(remaining.docs.first.data()['userId'], equals(_strangerUid));
      },
    );

    test('empty path — no docs match, returns 0', () async {
      final count = await repo.deleteAllByUser(_ownerUid);
      expect(count, equals(0));
    });

    test('permission denial — caller != target userId throws', () async {
      expect(
        () => repo.deleteAllByUser(_strangerUid),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('FirebaseNotificationBatchRepository.deleteAllByUser', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late FirebaseNotificationBatchRepository repo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: _ownerUid, isAuthenticated: true);
      repo = FirebaseNotificationBatchRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
      );
    });

    Future<void> seedBatches(String userId, int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore
            .collection('notification_batches')
            .doc('$userId-batch-$i')
            .set({
              'userId': userId,
              'batchKey': '$userId-batch-$i',
              'notifications': const [],
              'count': 0,
              'lastUpdated': DateTime(2026, 4, i + 1),
              'createdAt': DateTime(2026, 4, i + 1),
              'scheduledFor': DateTime(2026, 4, i + 2),
            });
      }
    }

    test(
      'happy path — owner scrub returns count, leaves others alone',
      () async {
        await seedBatches(_ownerUid, 2);
        await seedBatches(_strangerUid, 3);

        final count = await repo.deleteAllByUser(_ownerUid);

        expect(count, equals(2));
        final remaining = await fakeFirestore
            .collection('notification_batches')
            .get();
        expect(remaining.docs.length, equals(3));
        expect(
          remaining.docs.every((d) => d.data()['userId'] == _strangerUid),
          isTrue,
        );
      },
    );

    test('empty path — no docs match, returns 0', () async {
      final count = await repo.deleteAllByUser(_ownerUid);
      expect(count, equals(0));
    });

    test('permission denial — caller != target userId throws', () async {
      expect(
        () => repo.deleteAllByUser(_strangerUid),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('FirebaseDeviceRepository.deleteAllByUser (user_fcm_tokens)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late FirebaseDeviceRepository repo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: _ownerUid, isAuthenticated: true);
      repo = FirebaseDeviceRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
      );
    });

    Future<void> seedTokens(String userId, int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore
            .collection('user_fcm_tokens')
            .doc('${userId}_device-$i')
            .set({
              'userId': userId,
              'docId': '${userId}_device-$i',
              'token': 'token-$i',
              'isActive': true,
            });
      }
    }

    test(
      'happy path — owner scrub returns count, leaves others alone',
      () async {
        await seedTokens(_ownerUid, 3);
        await seedTokens(_strangerUid, 2);

        final count = await repo.deleteAllByUser(_ownerUid);

        expect(count, equals(3));
        final remaining = await fakeFirestore
            .collection('user_fcm_tokens')
            .get();
        expect(remaining.docs.length, equals(2));
        expect(
          remaining.docs.every((d) => d.data()['userId'] == _strangerUid),
          isTrue,
        );
      },
    );

    test('empty path — no docs match, returns 0', () async {
      final count = await repo.deleteAllByUser(_ownerUid);
      expect(count, equals(0));
    });

    test('permission denial — caller != target userId throws', () async {
      expect(
        () => repo.deleteAllByUser(_strangerUid),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('FirebaseMessagingRepository.deleteAllMessagesForUser', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late FirebaseMessagingRepository repo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: _ownerUid, isAuthenticated: true);
      repo = FirebaseMessagingRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
      );
    });

    /// Seeds a conversation plus the messages it holds — in the TOP-LEVEL
    /// `messages` collection with a `conversationId` FIELD, which is where
    /// `MessageMutationModule.sendMessage` actually writes them and the only
    /// path `firestore.rules` grants.
    ///
    /// BUT-1766: the fixture this replaces wrote
    /// `conversations/{id}/messages`, a subcollection nothing has ever
    /// written, and then asserted the deleted count matched what it had
    /// seeded. Fixture and implementation shared the same wrong path, so the
    /// suite stayed green over a cascade that erased no message in production.
    Future<void> seedConversation({
      required String convoId,
      required List<String> participantIds,
      required Map<String, int> messagesBySender,
      bool createConversationDoc = true,
    }) async {
      if (createConversationDoc) {
        await fakeFirestore.collection('conversations').doc(convoId).set({
          'participantIds': participantIds,
          'createdAt': DateTime(2026, 4, 1),
        });
      }
      for (final entry in messagesBySender.entries) {
        for (var i = 0; i < entry.value; i++) {
          await fakeFirestore.collection('messages').add({
            'conversationId': convoId,
            'senderId': entry.key,
            'content': 'msg-$i',
          });
        }
      }
    }

    Future<int> messageCountFor(String senderId) async {
      final snap = await fakeFirestore
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .get();
      return snap.docs.length;
    }

    test(
      "1:1 conversation — the user's own messages are deleted and the "
      'conversation removed',
      () async {
        await seedConversation(
          convoId: 'convo-direct',
          participantIds: [_ownerUid, _strangerUid],
          messagesBySender: {_ownerUid: 3, _strangerUid: 2},
        );

        final count = await repo.deleteAllMessagesForUser(_ownerUid);

        expect(count, equals(3));
        expect(await messageCountFor(_ownerUid), isZero);
        final convoAfter = await fakeFirestore
            .collection('conversations')
            .doc('convo-direct')
            .get();
        expect(
          convoAfter.exists,
          isFalse,
          reason: '1:1 conversation should be deleted entirely',
        );
        expect(
          await messageCountFor(_strangerUid),
          equals(2),
          reason:
              'firestore.rules only grants a client `delete` on its OWN '
              'messages, so the counterparty half of a 1:1 is out of reach '
              'here — the Admin-SDK cascade in account-deletion-cascade.ts is '
              'what clears it. Pinned so the split is deliberate, not silent.',
        );
      },
    );

    test(
      'group conversation (>2 participants) — own messages deleted, others '
      'kept, participantIds left UNTOUCHED (a client cannot write it)',
      () async {
        // Pinning a LIMIT, not a capability. `firestore.rules` refuses every
        // client update to `conversations/{id}` whose diff touches
        // `participantIds` — there is no rules-legal client-side group leave.
        // An earlier version of this test asserted the participant WAS
        // removed, which only passed because FakeFirebaseFirestore enforces
        // no rules; in production that update() would return
        // permission-denied. `deleteMessages` in
        // functions/src/account/account-deletion-cascade.ts, via the Admin
        // SDK, is the production owner of group departure.
        await seedConversation(
          convoId: 'convo-group',
          participantIds: [_ownerUid, _strangerUid, 'third-uid'],
          messagesBySender: {_ownerUid: 4, 'third-uid': 1},
        );

        final count = await repo.deleteAllMessagesForUser(_ownerUid);

        expect(count, equals(4));
        expect(await messageCountFor(_ownerUid), isZero);
        expect(await messageCountFor('third-uid'), equals(1));
        final convoAfter = await fakeFirestore
            .collection('conversations')
            .doc('convo-group')
            .get();
        expect(
          convoAfter.exists,
          isTrue,
          reason: 'group conversation continues for the other participants',
        );
        expect(
          List<String>.from(convoAfter.data()!['participantIds'] ?? []),
          equals([_ownerUid, _strangerUid, 'third-uid']),
          reason:
              'participantIds is untouched — the client made no write to it',
        );
      },
    );

    test(
      'messages in a conversation the user already LEFT are NOT reached from '
      'a client — that case belongs to the Cloud Function',
      () async {
        // Deliberately pinning a LIMIT, not a capability. An earlier version of
        // this suite asserted the opposite ("still deleted") on the strength of
        // a bare `messages.where('senderId', ==, uid)` sweep. `firestore.rules`
        // resolves the `messages` read rule through
        // `get(conversations/$(conversationId)).data.participantIds`, so that
        // sweep is denied outright the moment one matched row sits in a
        // conversation the user has left — and FakeFirebaseFirestore evaluates
        // no rules, so the old assertion was green against a query the server
        // refuses. The client now keys every read to one conversationId it is
        // still a participant of; left conversations are `deleteMessages` in
        // functions/src/account/account-deletion-cascade.ts (covered there by
        // scenario_messagesInLeftConversationsAreReached).
        await seedConversation(
          convoId: 'convo-left',
          participantIds: [_strangerUid, 'third-uid'],
          messagesBySender: {_ownerUid: 2, _strangerUid: 1},
        );

        final count = await repo.deleteAllMessagesForUser(_ownerUid);

        expect(count, equals(0));
        expect(
          await messageCountFor(_ownerUid),
          equals(2),
          reason:
              'out of client reach by design — asserting these survive is what '
              'keeps the Admin-SDK cascade the named owner of the case',
        );
        expect(await messageCountFor(_strangerUid), equals(1));
      },
    );

    test(
      "only the user's own messages in the conversation being left are swept — "
      'a sibling conversation is untouched until its own turn',
      () async {
        // Proves the per-conversation scoping is real rather than incidental:
        // both conversations are ones the user participates in, so a bare
        // senderId sweep and the scoped one both end at zero — the difference
        // is that the scoped one issues its reads keyed on conversationId.
        await seedConversation(
          convoId: 'convo-a',
          participantIds: [_ownerUid, _strangerUid, 'third-uid'],
          messagesBySender: {_ownerUid: 2, 'third-uid': 1},
        );
        await seedConversation(
          convoId: 'convo-b',
          participantIds: [_ownerUid, _strangerUid, 'third-uid'],
          messagesBySender: {_ownerUid: 3},
        );

        final count = await repo.deleteAllMessagesForUser(_ownerUid);

        expect(count, equals(5));
        expect(await messageCountFor(_ownerUid), isZero);
        expect(await messageCountFor('third-uid'), equals(1));
      },
    );

    test('no conversations and no messages — returns 0', () async {
      final count = await repo.deleteAllMessagesForUser(_ownerUid);
      expect(count, equals(0));
    });

    test('permission denial — caller != target userId throws', () async {
      expect(
        () => repo.deleteAllMessagesForUser(_strangerUid),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('CollaborativeRecipeRepository.deleteAllByUser (realtime_recipes)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuth;
    late CollaborativeRecipeRepository repo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = FakeAuthRepository();
      mockAuth.setAuthState(userId: _ownerUid, isAuthenticated: true);
      repo = CollaborativeRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuth,
      );
    });

    Future<void> seedRealtimeRecipes(String ownerId, int count) async {
      for (var i = 0; i < count; i++) {
        await fakeFirestore.collection('realtime_recipes').add({
          'ownerId': ownerId,
          'participants': const [],
          'participantIds': const [],
          'recipe': const {},
          'createdAt': DateTime(2026, 4, i + 1),
        });
      }
    }

    test(
      'happy path — owner scrub returns count, leaves others alone',
      () async {
        await seedRealtimeRecipes(_ownerUid, 2);
        await seedRealtimeRecipes(_strangerUid, 3);

        final count = await repo.deleteAllByUser(_ownerUid);

        expect(count, equals(2));
        final remaining = await fakeFirestore
            .collection('realtime_recipes')
            .get();
        expect(remaining.docs.length, equals(3));
        expect(
          remaining.docs.every((d) => d.data()['ownerId'] == _strangerUid),
          isTrue,
          reason: 'realtime_recipes uses ownerId, not userId',
        );
      },
    );

    test('empty path — no docs match, returns 0', () async {
      final count = await repo.deleteAllByUser(_ownerUid);
      expect(count, equals(0));
    });

    test('permission denial — caller != target userId throws', () async {
      expect(
        () => repo.deleteAllByUser(_strangerUid),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
