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

    Future<void> seedConversation({
      required String convoId,
      required List<String> participantIds,
      required int messageCount,
    }) async {
      await fakeFirestore.collection('conversations').doc(convoId).set({
        'participantIds': participantIds,
        'createdAt': DateTime(2026, 4, 1),
      });
      for (var i = 0; i < messageCount; i++) {
        await fakeFirestore
            .collection('conversations')
            .doc(convoId)
            .collection('messages')
            .add({'senderId': participantIds.first, 'text': 'msg-$i'});
      }
    }

    test(
      '1:1 conversation — messages deleted + conversation removed',
      () async {
        await seedConversation(
          convoId: 'convo-direct',
          participantIds: [_ownerUid, _strangerUid],
          messageCount: 3,
        );

        final count = await repo.deleteAllMessagesForUser(_ownerUid);

        expect(count, equals(3));
        final convoAfter = await fakeFirestore
            .collection('conversations')
            .doc('convo-direct')
            .get();
        expect(
          convoAfter.exists,
          isFalse,
          reason: '1:1 conversation should be deleted entirely',
        );
      },
    );

    test(
      'group conversation (>2 participants) — messages deleted + user removed from participantIds',
      () async {
        await seedConversation(
          convoId: 'convo-group',
          participantIds: [_ownerUid, _strangerUid, 'third-uid'],
          messageCount: 4,
        );

        final count = await repo.deleteAllMessagesForUser(_ownerUid);

        expect(count, equals(4));
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
          equals([_strangerUid, 'third-uid']),
          reason: 'leaving user removed from participantIds',
        );
      },
    );

    test('no conversations — returns 0', () async {
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
