/// Integration tests for Firebase Notifications Repository
///
/// Tests Firebase-specific functionality including FieldValue operations,
/// batch writes, and real-time streams using FakeFirebaseFirestore.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../test_support/test_field_values.dart';
import '../../../test_support/test_data_isolator.dart';

void main() {
  group('Firebase Notifications Repository Integration', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseNotificationsRepository repository;
    late FirebaseAuthRepository authRepository;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    const testUserId = 'test-user-123';
    const testUserEmail = 'test@example.com';
    const testUserDisplayName = 'Test User';

    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest(
        'notifications_repository_integration_test',
      );

      // Set up fake Firebase instances
      fakeFirestore = FirestoreSingleton.instance;
      mockUser = MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: testUserDisplayName,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Setup auth repository
      authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);

      // Create repository with fake Firestore
      repository = FirebaseNotificationsRepository(
        firestore: fakeFirestore,
        authRepository: authRepository,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest(
        'notifications_repository_integration_test',
      );
    });

    group('Notifications with FieldValue operations', () {
      test('should create notification with server timestamp', () async {
        // Arrange
        const userId = 'target_user';
        const type = NotificationType.immediate;
        const title = 'New Friend Request';
        const body = 'Someone wants to be your friend!';
        final data = {'requestId': 'req_123'};

        // Act
        await repository.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        final notifications = await fakeFirestore
            .collection('user_notifications')
            .where('userId', isEqualTo: userId)
            .get();

        expect(notifications.docs.length, equals(1));
        final notification = notifications.docs.first.data();

        // Verify server timestamp was set
        expect(notification['createdAt'], isA<Timestamp>());
        final timestamp = notification['createdAt'] as Timestamp;
        expect(
          timestamp.toDate().difference(DateTime.now()).inMinutes.abs(),
          lessThan(1),
        );

        expect(notification['title'], equals(title));
        expect(notification['body'], equals(body));
        expect(notification['isRead'], isFalse);
      });

      test('should mark notification as read with readAt timestamp', () async {
        // Arrange
        const userId = testUserId;

        // Create notification with server timestamp
        final docRef = await fakeFirestore.collection('user_notifications').add(
          {
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Test Notification',
            'body': 'Test Body',
            'isRead': false,
            'createdAt': TestFieldValues.serverTimestamp(),
          },
        );

        // Act
        await repository.markAsRead(docRef.id);

        // Assert
        final doc = await docRef.get();
        final data = doc.data()!;

        expect(data['isRead'], isTrue);
        expect(data['readAt'], isA<Timestamp>());

        // Verify readAt is at least as new as createdAt. We use isAtSameMoment
        // || isAfter because the TestTimestampProvider resolves both in the
        // same event-loop tick when the machine is fast (intermittent
        // cross-file flake when this test ran after a reset).
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final readAt = (data['readAt'] as Timestamp).toDate();
        expect(readAt.isBefore(createdAt), isFalse);
      });

      test(
        'should stream notifications with proper timestamp ordering',
        () async {
          // Arrange
          const userId = testUserId;

          // Create notifications with server timestamps
          for (int i = 0; i < 3; i++) {
            await fakeFirestore.collection('user_notifications').add({
              'userId': userId,
              'type': NotificationType.optional.toString(),
              'title': 'Notification $i',
              'body': 'Body $i',
              'isRead': false,
              'createdAt': TestFieldValues.serverTimestamp(),
            });

            // Small delay to ensure different timestamps
            await Future.delayed(const Duration(milliseconds: 50));
          }

          // Act
          final stream = repository.getNotificationsStream(userId);
          final notifications = await stream.first;

          // Assert
          expect(notifications.length, equals(3));

          // Verify notifications are ordered by createdAt descending (newest first)
          for (int i = 0; i < notifications.length - 1; i++) {
            expect(
              notifications[i].createdAt.isAfter(
                notifications[i + 1].createdAt,
              ),
              isTrue,
            );
          }
        },
      );
    });

    group('Batch Operations', () {
      test('should send bulk notifications using batch write', () async {
        // Arrange
        final userIds = ['user_1', 'user_2', 'user_3', 'user_4', 'user_5'];
        const type = NotificationType.batchable;
        const title = 'New Recipe Shared';
        const body = 'Check out this amazing recipe!';
        final data = {'recipeId': 'recipe_456'};

        // Act
        await repository.sendBulkNotifications(
          userIds: userIds,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        for (final userId in userIds) {
          final notifications = await fakeFirestore
              .collection('user_notifications')
              .where('userId', isEqualTo: userId)
              .get();

          expect(notifications.docs.length, equals(1));
          final notification = notifications.docs.first.data();

          // Verify all notifications have server timestamp
          expect(notification['createdAt'], isA<Timestamp>());
          expect(notification['title'], equals(title));
          expect(notification['body'], equals(body));
          expect(notification['data']['recipeId'], equals('recipe_456'));
        }
      });

      test('should mark multiple notifications as read in batch', () async {
        // Arrange
        const userId = testUserId;
        final notificationIds = <String>[];

        // Create multiple unread notifications
        for (int i = 0; i < 5; i++) {
          final docRef = await fakeFirestore
              .collection('user_notifications')
              .add({
                'userId': userId,
                'type': NotificationType.optional.toString(),
                'title': 'Notification $i',
                'body': 'Body $i',
                'isRead': false,
                'createdAt': TestFieldValues.serverTimestamp(),
              });
          notificationIds.add(docRef.id);
        }

        // Act
        await repository.markMultipleAsRead(notificationIds);

        // Assert
        for (final id in notificationIds) {
          final doc = await fakeFirestore
              .collection('user_notifications')
              .doc(id)
              .get();

          final data = doc.data()!;
          expect(data['isRead'], isTrue);
          expect(data['readAt'], isA<Timestamp>());
        }
      });
    });

    group('Complex Queries with Timestamps', () {
      test('should retrieve notifications since specific date', () async {
        // Arrange
        const userId = testUserId;
        final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

        // Create old notifications
        for (int i = 10; i < 13; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Old Notification $i',
            'body': 'Old Body $i',
            'isRead': false,
            'createdAt': Timestamp.fromDate(
              cutoffDate.subtract(Duration(days: i)),
            ),
          });
        }

        // Create recent notifications
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Recent Notification $i',
            'body': 'Recent Body $i',
            'isRead': false,
            'createdAt': Timestamp.fromDate(
              cutoffDate.add(Duration(days: i)),
            ),
          });
        }

        // Act
        final notifications = await repository.getUserNotifications(
          userId,
          since: cutoffDate,
        );

        // Assert
        expect(notifications.length, equals(3));
        expect(
          notifications.every((n) => n.createdAt.isAfter(cutoffDate)),
          isTrue,
        );
        expect(
          notifications.every((n) => n.title.startsWith('Recent')),
          isTrue,
        );
      });

      test('should handle unread count with real-time updates', () async {
        // Arrange
        const userId = testUserId;

        // Create mix of read and unread notifications.
        // i % 3 == 0 hits 0, 3, 6, 9 → 4 read, 6 unread across i=0..9.
        for (int i = 0; i < 10; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': i % 3 == 0,
            'createdAt': TestFieldValues.serverTimestamp(),
          });
        }

        // Act
        final unreadCount = await repository.getUnreadCount(userId);

        // Assert — 10 total, 4 read (0,3,6,9), 6 unread.
        expect(unreadCount, equals(6));

        // Mark all as read
        await repository.markAllAsRead(userId);

        // Verify all are now read
        final newUnreadCount = await repository.getUnreadCount(userId);
        expect(newUnreadCount, equals(0));
      });
    });

    group('Notification Preferences', () {
      test('should save and retrieve notification preferences', () async {
        // Arrange — use the authenticated user, otherwise
        // PermissionValidationMixin.validateSelfOperation rejects the write.
        const userId = testUserId;
        // Every asserted value differs from defaults() on purpose. A missing
        // document ALSO returns defaults(), and the parser reads a missing key
        // as its default — so the defaults() fixture this replaced passed its
        // assertions whether or not the write ever landed.
        final defaults = NotificationPreferences.defaults();
        final preferences = NotificationPreferences(
          enabled: false,
          categorySettings: defaults.categorySettings,
          typeSettings: defaults.typeSettings,
          allowBatching: false,
          digestFrequency: 'weekly',
          quietHoursStart: defaults.quietHoursStart,
          quietHoursEnd: defaults.quietHoursEnd,
          lastUpdated: defaults.lastUpdated,
        );

        // Act
        await repository.updateNotificationPreferences(userId, preferences);

        // Assert
        final savedPreferences = await repository.getNotificationPreferences(
          userId,
        );

        expect(savedPreferences.enabled, isFalse);
        expect(savedPreferences.allowBatching, isFalse);
        expect(savedPreferences.digestFrequency, 'weekly');
      });

      // What the merge protects is BACKEND-OWNED keys. `quiet-hours.ts` reads
      // a `timezone` field off this same document that the Dart model neither
      // writes nor parses; nothing writes it yet, but the day something does,
      // an overwriting save would erase it on every settings change — silently,
      // and with the whole Dart suite still green.
      //
      // The retired BUT-1783 keys are the weaker half of the same invariant:
      // merging is why they stay on disk, i.e. why that removal is
      // forward-only rather than a migration. Nothing reads them, so losing
      // them would be harmless; losing `timezone` would not.
      //
      // No other test can see any of this: none of them drives this write
      // against an EXISTING document, and on a fresh one a merging write and an
      // overwriting one are byte-identical.
      test('a save MERGES: fields the model does not know survive it', () async {
        const userId = testUserId;
        final doc = fakeFirestore
            .collection('user_notification_preferences')
            .doc(userId);

        // The pre-BUT-1783 field set, plus a field only the backend knows
        // about. Only three of the four assertions below can tell merge from
        // overwrite; the fourth is the control. Every other key here is
        // re-sent by the save, so none of them could.
        await doc.set({
          'enabled': true,
          'categorySettings': const <String, dynamic>{},
          'typeSettings': const <String, dynamic>{},
          'allowBatching': true,
          'digestFrequency': 'never',
          'quietHoursStart': {'hour': 22, 'minute': 0},
          'quietHoursEnd': {'hour': 8, 'minute': 0},
          'soundEnabled': false,
          'vibrationEnabled': false,
          'timezone': 'Europe/Stockholm',
        });

        final defaults = NotificationPreferences.defaults();
        await repository.updateNotificationPreferences(
          userId,
          NotificationPreferences(
            enabled: defaults.enabled,
            categorySettings: defaults.categorySettings,
            typeSettings: defaults.typeSettings,
            allowBatching: defaults.allowBatching,
            digestFrequency: 'weekly',
            quietHoursStart: defaults.quietHoursStart,
            quietHoursEnd: defaults.quietHoursEnd,
            lastUpdated: defaults.lastUpdated,
          ),
        );

        final raw = (await doc.get()).data()!;
        // Control: the write landed. Without this the survival assertions pass
        // on a save that never happened.
        expect(raw['digestFrequency'], 'weekly');
        expect(raw['timezone'], 'Europe/Stockholm');
        expect(raw['soundEnabled'], isFalse);
        expect(raw['vibrationEnabled'], isFalse);
      });
    });
  });
}
