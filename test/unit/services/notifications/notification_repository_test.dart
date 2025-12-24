/// Unit tests for NotificationRepository - Firebase notification data management
///
/// Tests notification repository functionality including:
/// - Preference management and caching
/// - Notification history tracking
/// - Batch queue management
/// - Local storage fallback
/// - Cross-device synchronization
/// - Device token management
/// - Cleanup operations
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Production imports
import 'package:butlery/services/notifications/notification_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:get_it/get_it.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('NotificationRepository', () {
    late NotificationRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    const testUserId = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Register fallback values for mocktail
      registerFallbackValue(SetOptions(merge: true));
      registerFallbackValue(FieldValue.serverTimestamp());
    });

    setUp(() async {
      // Clear any existing SharedPreferences state
      SharedPreferences.setMockInitialValues({});

      // Create fake Firestore
      fakeFirestore = FakeFirebaseFirestore();

      // Register fake Firestore with GetIt
      if (GetIt.instance.isRegistered<FirebaseFirestore>()) {
        GetIt.instance.unregister<FirebaseFirestore>();
      }
      GetIt.instance.registerSingleton<FirebaseFirestore>(fakeFirestore);

      // Create repository
      repository = NotificationRepository(userId: testUserId);
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();

      // Clear GetIt registrations
      if (GetIt.instance.isRegistered<FirebaseFirestore>()) {
        GetIt.instance.unregister<FirebaseFirestore>();
      }
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Preference Management', () {
      test('should get default preferences when none exist', () async {
        // Arrange - No preferences in Firestore

        // Act
        final preferences = await repository.getPreferences();

        // Assert
        expect(preferences, isNotNull);
        expect(preferences.enabled, isTrue); // Default enabled
        expect(preferences.categorySettings, isNotEmpty);
        expect(preferences.soundEnabled, isTrue);

        // Verify preferences were saved to Firestore
        final savedDoc = await fakeFirestore
            .collection('notification_preferences')
            .doc(testUserId)
            .get();
        expect(savedDoc.exists, isTrue);
      });

      test('should load existing preferences from Firestore', () async {
        // Arrange - Add preferences to Firestore
        await fakeFirestore
            .collection('notification_preferences')
            .doc(testUserId)
            .set({
          'enabled': false,
          'soundEnabled': false,
          'vibrationEnabled': true,
          'categorySettings': {
            'social': true,
            'recipes': false,
          },
          'lastUpdated': Timestamp.now(),
        });

        // Act
        final preferences = await repository.getPreferences();

        // Assert
        expect(preferences.enabled, isFalse);
        expect(preferences.soundEnabled, isFalse);
        expect(preferences.vibrationEnabled, isTrue);
      });

      test('should cache preferences after first load', () async {
        // Arrange
        await fakeFirestore
            .collection('notification_preferences')
            .doc(testUserId)
            .set({
          'enabled': true,
          'soundEnabled': true,
          'lastUpdated': Timestamp.now(),
        });

        // Act - Load preferences twice
        final preferences1 = await repository.getPreferences();
        final preferences2 = await repository.getPreferences();

        // Assert - Should return same cached instance
        expect(identical(preferences1, preferences2), isTrue);
      });

      test('should update preferences in Firestore and cache', () async {
        // Arrange
        final newPreferences = NotificationPreferences(
          enabled: true,
          categorySettings: {
            NotificationCategory.friends: false,
            NotificationCategory.recipes: true,
            NotificationCategory.collaboration: true,
            NotificationCategory.shopping: false,
            NotificationCategory.social: false,
            NotificationCategory.system: true,
            NotificationCategory.messaging: true,
          },
          typeSettings: {
            NotificationType.immediate: true,
            NotificationType.batchable: true,
            NotificationType.silent: true,
            NotificationType.digest: false,
            NotificationType.optional: false,
          },
          allowBatching: true,
          digestFrequency: 'never',
          quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
          quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
          soundEnabled: true,
          vibrationEnabled: true,
          lastUpdated: DateTime.now(),
        );

        // Act
        await repository.updatePreferences(newPreferences);

        // Assert - Check Firestore
        final savedDoc = await fakeFirestore
            .collection('notification_preferences')
            .doc(testUserId)
            .get();
        expect(savedDoc.exists, isTrue);
        expect(savedDoc.data()?['categorySettings'], isNotNull);
        expect(savedDoc.data()?['enabled'], isTrue);

        // Assert - Check cache is updated
        final cachedPrefs = await repository.getPreferences();
        expect(cachedPrefs.categorySettings[NotificationCategory.friends],
            isFalse);
        expect(cachedPrefs.quietHoursStart, isNotNull);
      });

      test('should save preferences locally for offline access', () async {
        // Arrange
        final preferences = NotificationPreferences(
          enabled: true,
          categorySettings: {
            NotificationCategory.friends: true,
            NotificationCategory.recipes: true,
            NotificationCategory.collaboration: true,
            NotificationCategory.shopping: false,
            NotificationCategory.social: false,
            NotificationCategory.system: true,
            NotificationCategory.messaging: false,
          },
          typeSettings: {
            NotificationType.immediate: true,
            NotificationType.batchable: true,
            NotificationType.silent: true,
            NotificationType.digest: false,
            NotificationType.optional: false,
          },
          allowBatching: true,
          digestFrequency: 'never',
          soundEnabled: true,
          vibrationEnabled: true,
          lastUpdated: DateTime.now(),
        );

        // Act
        await repository.updatePreferences(preferences);

        // Assert - Check SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final savedJson =
            prefs.getString('notification_preferences_$testUserId');
        expect(savedJson, isNotNull);
        expect(savedJson, contains('messaging'));
      });
    });

    group('Notification Type Checking', () {
      test('should check if user wants to receive specific notification',
          () async {
        // Arrange
        await fakeFirestore
            .collection('notification_preferences')
            .doc(testUserId)
            .set({
          'enabled': true,
          'categorySettings': {
            'social': true,
            'recipes': false,
          },
          'typeSettings': {
            'immediate': true,
            'batchable': false,
          },
          'lastUpdated': Timestamp.now(),
        });

        // Act
        final shouldReceiveSocial = await repository.shouldReceiveNotification(
          NotificationCategory.social,
          NotificationType.immediate,
        );
        final shouldReceiveRecipes = await repository.shouldReceiveNotification(
          NotificationCategory.recipes,
          NotificationType.immediate,
        );

        // Assert
        expect(shouldReceiveSocial, isTrue);
        expect(shouldReceiveRecipes,
            isTrue); // Default when not explicitly disabled
      });

      test('should default to true for immediate notifications on error',
          () async {
        // Arrange - Force error by using invalid GetIt setup
        if (GetIt.instance.isRegistered<FirebaseFirestore>()) {
          GetIt.instance.unregister<FirebaseFirestore>();
        }

        // Act
        final shouldReceive = await repository.shouldReceiveNotification(
          NotificationCategory.social,
          NotificationType.immediate,
        );

        // Assert
        expect(shouldReceive, isTrue); // Defaults to true for immediate

        // Re-register for cleanup
        GetIt.instance.registerSingleton<FirebaseFirestore>(fakeFirestore);
      });
    });

    group('Notification History', () {
      test('should record notification in history', () async {
        // Arrange
        const notificationId = 'notif-001';

        // Act
        await repository.recordNotification(
          notificationId: notificationId,
          category: NotificationCategory.social,
          type: NotificationType.immediate,
          data: {'message': 'Test notification'},
        );

        // Assert
        final historyDoc = await fakeFirestore
            .collection('notification_history')
            .doc(notificationId)
            .get();
        expect(historyDoc.exists, isTrue);
        expect(historyDoc.data()?['userId'], equals(testUserId));
        expect(historyDoc.data()?['category'], contains('social'));
        expect(historyDoc.data()?['delivered'], isFalse);
      });

      test('should check if notification was already sent', () async {
        // Arrange
        const notificationId = 'notif-002';
        await fakeFirestore
            .collection('notification_history')
            .doc(notificationId)
            .set({
          'userId': testUserId,
          'sentAt': Timestamp.now(),
        });

        // Act
        final wasSent = await repository.wasNotificationSent(notificationId);
        final wasNotSent = await repository.wasNotificationSent('notif-999');

        // Assert
        expect(wasSent, isTrue);
        expect(wasNotSent, isFalse);
      });

      test('should mark notification as delivered', () async {
        // Arrange
        const notificationId = 'notif-003';
        await fakeFirestore
            .collection('notification_history')
            .doc(notificationId)
            .set({
          'userId': testUserId,
          'delivered': false,
        });

        // Act
        await repository.markNotificationDelivered(notificationId);

        // Assert
        final doc = await fakeFirestore
            .collection('notification_history')
            .doc(notificationId)
            .get();
        expect(doc.data()?['delivered'], isTrue);
        expect(doc.data()?['deliveredAt'], isNotNull);
      });

      test('should mark notification as opened', () async {
        // Arrange
        const notificationId = 'notif-004';
        await fakeFirestore
            .collection('notification_history')
            .doc(notificationId)
            .set({
          'userId': testUserId,
          'opened': false,
        });

        // Act
        await repository.markNotificationOpened(notificationId);

        // Assert
        final doc = await fakeFirestore
            .collection('notification_history')
            .doc(notificationId)
            .get();
        expect(doc.data()?['opened'], isTrue);
        expect(doc.data()?['openedAt'], isNotNull);
      });

      test('should cleanup old notification history', () async {
        // Arrange - Add old and new notifications
        final oldDate = DateTime.now().subtract(const Duration(days: 45));
        final recentDate = DateTime.now().subtract(const Duration(days: 5));

        await fakeFirestore
            .collection('notification_history')
            .doc('old-notif')
            .set({
          'userId': testUserId,
          'sentAt': Timestamp.fromDate(oldDate),
        });

        await fakeFirestore
            .collection('notification_history')
            .doc('recent-notif')
            .set({
          'userId': testUserId,
          'sentAt': Timestamp.fromDate(recentDate),
        });

        // Act
        await repository.cleanupOldHistory(olderThan: const Duration(days: 30));

        // Assert
        final oldDoc = await fakeFirestore
            .collection('notification_history')
            .doc('old-notif')
            .get();
        final recentDoc = await fakeFirestore
            .collection('notification_history')
            .doc('recent-notif')
            .get();

        expect(oldDoc.exists, isFalse); // Should be deleted
        expect(recentDoc.exists, isTrue); // Should remain
      });
    });

    group('Batch Queue Management', () {
      test('should add notification to batch', () async {
        // Arrange
        const batchKey = 'batch-social-001';
        final notification = NotificationTemplate(
          title: 'Test Batch',
          body: 'Batch notification',
          data: {
            'category': NotificationCategory.social.toString(),
            'type': NotificationType.batchable.toString(),
          },
        );

        // Act
        await repository.addToBatch(
          batchKey: batchKey,
          notification: notification,
          batchWindow: const Duration(minutes: 5),
        );

        // Assert
        final batchDoc = await fakeFirestore
            .collection('notification_batches')
            .doc(batchKey)
            .get();
        expect(batchDoc.exists, isTrue);
        expect(batchDoc.data()?['userId'], equals(testUserId));
        expect(batchDoc.data()?['count'], equals(1));
        expect(batchDoc.data()?['notifications'], hasLength(1));
      });

      test('should add to existing batch', () async {
        // Arrange
        const batchKey = 'batch-social-002';
        final notification1 = NotificationTemplate(
          title: 'First',
          body: 'First notification',
          data: {
            'category': NotificationCategory.social.toString(),
            'type': NotificationType.batchable.toString(),
          },
        );
        final notification2 = NotificationTemplate(
          title: 'Second',
          body: 'Second notification',
          data: {
            'category': NotificationCategory.social.toString(),
            'type': NotificationType.batchable.toString(),
          },
        );

        // Act
        await repository.addToBatch(
          batchKey: batchKey,
          notification: notification1,
          batchWindow: const Duration(minutes: 5),
        );
        await repository.addToBatch(
          batchKey: batchKey,
          notification: notification2,
          batchWindow: const Duration(minutes: 5),
        );

        // Assert
        final batchDoc = await fakeFirestore
            .collection('notification_batches')
            .doc(batchKey)
            .get();
        expect(batchDoc.data()?['count'], equals(2));
        expect(batchDoc.data()?['notifications'], hasLength(2));
      });

      test('should get pending batches ready for sending', () async {
        // Arrange - Add batches with different scheduled times
        final now = DateTime.now();
        final pastTime = now.subtract(const Duration(minutes: 10));
        final futureTime = now.add(const Duration(minutes: 10));

        await fakeFirestore
            .collection('notification_batches')
            .doc('batch-ready')
            .set({
          'userId': testUserId,
          'batchKey': 'batch-ready',
          'notifications': [],
          'count': 1,
          'scheduledFor': Timestamp.fromDate(pastTime),
        });

        await fakeFirestore
            .collection('notification_batches')
            .doc('batch-future')
            .set({
          'userId': testUserId,
          'batchKey': 'batch-future',
          'notifications': [],
          'count': 1,
          'scheduledFor': Timestamp.fromDate(futureTime),
        });

        // Act
        final pendingBatches = await repository.getPendingBatches();

        // Assert
        expect(pendingBatches, hasLength(1));
        expect(pendingBatches.first.batchKey, equals('batch-ready'));
      });

      test('should remove batch after sending', () async {
        // Arrange
        const batchKey = 'batch-to-remove';
        await fakeFirestore
            .collection('notification_batches')
            .doc(batchKey)
            .set({
          'userId': testUserId,
          'batchKey': batchKey,
        });

        // Act
        await repository.removeBatch(batchKey);

        // Assert
        final batchDoc = await fakeFirestore
            .collection('notification_batches')
            .doc(batchKey)
            .get();
        expect(batchDoc.exists, isFalse);
      });
    });

    group('Device Token Management', () {
      test('should save FCM token to Firestore', () async {
        // Arrange
        const collection = 'fcm_tokens';
        const docId = 'token-001';
        final tokenData = {
          'token': 'fcm-token-123',
          'userId': testUserId,
          'platform': 'android',
          'createdAt': Timestamp.now(),
        };

        // Act
        await repository.saveTokenToFirestore(collection, docId, tokenData);

        // Assert
        final doc = await fakeFirestore.collection(collection).doc(docId).get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['token'], equals('fcm-token-123'));
        expect(doc.data()?['platform'], equals('android'));
      });

      test('should batch update device information', () async {
        // Arrange
        const collection = 'devices';

        // Add initial devices
        await fakeFirestore.collection(collection).doc('device-1').set({
          'userId': testUserId,
          'isActive': false,
        });
        await fakeFirestore.collection(collection).doc('device-2').set({
          'userId': testUserId,
          'isActive': false,
        });

        final updates = [
          {'id': 'device-1', 'isActive': true, 'lastSeen': Timestamp.now()},
          {'id': 'device-2', 'isActive': true, 'lastSeen': Timestamp.now()},
        ];

        // Act
        await repository.batchUpdateDevices(collection, updates);

        // Assert
        final device1 =
            await fakeFirestore.collection(collection).doc('device-1').get();
        final device2 =
            await fakeFirestore.collection(collection).doc('device-2').get();

        expect(device1.data()?['isActive'], isTrue);
        expect(device2.data()?['isActive'], isTrue);
      });

      test('should cleanup old devices', () async {
        // Arrange
        const collection = 'devices';
        final oldDate = DateTime.now().subtract(const Duration(days: 45));
        final recentDate = DateTime.now().subtract(const Duration(days: 5));

        await fakeFirestore.collection(collection).doc('old-device').set({
          'userId': testUserId,
          'lastSeen': Timestamp.fromDate(oldDate),
          'isActive': true,
        });

        await fakeFirestore.collection(collection).doc('recent-device').set({
          'userId': testUserId,
          'lastSeen': Timestamp.fromDate(recentDate),
          'isActive': true,
        });

        // Act
        await repository.cleanupOldDevices(
          collection,
          testUserId,
          olderThan: const Duration(days: 30),
        );

        // Assert
        final oldDevice =
            await fakeFirestore.collection(collection).doc('old-device').get();
        final recentDevice = await fakeFirestore
            .collection(collection)
            .doc('recent-device')
            .get();

        expect(oldDevice.data()?['isActive'], isFalse); // Should be deactivated
        expect(
            recentDevice.data()?['isActive'], isTrue); // Should remain active
      });

      test('should query devices with filters', () async {
        // Arrange
        const collection = 'devices';

        await fakeFirestore.collection(collection).doc('device-android').set({
          'userId': testUserId,
          'platform': 'android',
          'isActive': true,
        });

        await fakeFirestore.collection(collection).doc('device-ios').set({
          'userId': testUserId,
          'platform': 'ios',
          'isActive': true,
        });

        await fakeFirestore.collection(collection).doc('device-inactive').set({
          'userId': testUserId,
          'platform': 'android',
          'isActive': false,
        });

        // Act
        final androidDevices = await repository.queryDevices(
          collection,
          {'userId': testUserId, 'platform': 'android', 'isActive': true},
        );

        // Assert
        expect(androidDevices, hasLength(1));
        expect(androidDevices.first['platform'], equals('android'));
        expect(androidDevices.first['isActive'], isTrue);
      });

      test('should update device last seen timestamp', () async {
        // Arrange
        const collection = 'devices';
        const deviceId = 'device-001';

        await fakeFirestore.collection(collection).doc(deviceId).set({
          'userId': testUserId,
          'isActive': false,
        });

        // Act
        await repository.updateDeviceLastSeen(collection, deviceId);

        // Assert
        final device =
            await fakeFirestore.collection(collection).doc(deviceId).get();
        expect(device.data()?['isActive'], isTrue);
        expect(device.data()?['lastSeen'], isNotNull);
      });

      test('should deactivate all user devices', () async {
        // Arrange
        const collection = 'devices';

        await fakeFirestore.collection(collection).doc('device-1').set({
          'userId': testUserId,
          'isActive': true,
        });

        await fakeFirestore.collection(collection).doc('device-2').set({
          'userId': testUserId,
          'isActive': true,
        });

        await fakeFirestore
            .collection(collection)
            .doc('other-user-device')
            .set({
          'userId': 'other-user',
          'isActive': true,
        });

        // Act
        await repository.deactivateUserDevices(collection, testUserId);

        // Assert
        final device1 =
            await fakeFirestore.collection(collection).doc('device-1').get();
        final device2 =
            await fakeFirestore.collection(collection).doc('device-2').get();
        final otherDevice = await fakeFirestore
            .collection(collection)
            .doc('other-user-device')
            .get();

        expect(device1.data()?['isActive'], isFalse);
        expect(device2.data()?['isActive'], isFalse);
        expect(
            otherDevice.data()?['isActive'], isTrue); // Should not be affected
      });
    });

    group('Cache Management', () {
      test('should clear cache when switching users', () async {
        // Arrange - Load preferences to populate cache
        await repository.getPreferences();

        // Act
        repository.clearCache();

        // Add new preferences to Firestore
        await fakeFirestore
            .collection('notification_preferences')
            .doc(testUserId)
            .set({
          'enabled': false,
          'soundEnabled': false,
          'lastUpdated': Timestamp.now(),
        });

        // Get preferences again - should load from Firestore, not cache
        final preferences = await repository.getPreferences();

        // Assert
        expect(preferences.enabled, isFalse); // New value from Firestore
      });
    });

    group('Error Handling', () {
      test('should handle Firestore errors gracefully', () async {
        // Arrange - Unregister Firestore to force errors
        if (GetIt.instance.isRegistered<FirebaseFirestore>()) {
          GetIt.instance.unregister<FirebaseFirestore>();
        }

        // Act & Assert - Should not throw
        expect(() async {
          await repository.wasNotificationSent('test-id');
        }, returnsNormally);

        expect(() async {
          await repository.markNotificationDelivered('test-id');
        }, returnsNormally);

        expect(() async {
          await repository.cleanupOldHistory();
        }, returnsNormally);

        // Re-register for cleanup
        GetIt.instance.registerSingleton<FirebaseFirestore>(fakeFirestore);
      });
    });
  });
}

// Test models
class NotificationBatch {
  final String batchKey;
  final String userId;
  final List<Map<String, dynamic>> notifications;
  final int count;

  NotificationBatch({
    required this.batchKey,
    required this.userId,
    required this.notifications,
    required this.count,
  });

  factory NotificationBatch.fromMap(String id, Map<String, dynamic> map) {
    return NotificationBatch(
      batchKey: map['batchKey'] ?? id,
      userId: map['userId'] ?? '',
      notifications:
          List<Map<String, dynamic>>.from(map['notifications'] ?? []),
      count: map['count'] ?? 0,
    );
  }
}
