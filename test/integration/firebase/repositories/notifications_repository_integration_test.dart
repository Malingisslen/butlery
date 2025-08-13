/// Integration tests for Firebase Notifications Repository
/// 
/// Tests actual Firebase operations with emulator including FieldValue operations,
/// batch writes, and real-time streams.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import '../setup/firebase_test_setup.dart';
import '../../../infrastructure/factories/mock_factory.dart';

void main() {
  group('Firebase Notifications Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseNotificationsRepository repository;
    late AuthRepository mockAuthRepository;
    late User testUser;
    
    setUpAll(() async {
      await FirebaseTestSetup.initialize();
      firestore = FirebaseFirestore.instance;
    });
    
    setUp(() async {
      await FirebaseTestSetup.clearEmulatorData();
      
      // Create test user
      testUser = await FirebaseTestSetup.createTestUser(
        email: 'test@example.com',
        password: 'test123',
      );
      
      // Setup mock auth repository
      mockAuthRepository = MockFactory.createAuthRepository(
        isAuthenticated: true,
        userId: testUser.uid,
        user: testUser,
      );
      
      // Create repository with Firebase emulator
      repository = FirebaseNotificationsRepository(
        firestore: firestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      await FirebaseAuth.instance.signOut();
    });
    
    group('Notifications with FieldValue.serverTimestamp', () {
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
        final notifications = await firestore
            .collection('user_notifications')
            .where('userId', isEqualTo: userId)
            .get();
        
        expect(notifications.docs.length, equals(1));
        final notification = notifications.docs.first.data();
        
        // Verify server timestamp was set
        expect(notification['createdAt'], isA<Timestamp>());
        final timestamp = notification['createdAt'] as Timestamp;
        expect(timestamp.toDate().difference(DateTime.now()).inMinutes.abs(), lessThan(1));
        
        expect(notification['title'], equals(title));
        expect(notification['body'], equals(body));
        expect(notification['isRead'], isFalse);
      });
      
      test('should mark notification as read with readAt timestamp', () async {
        // Arrange
        const userId = 'test_user';
        
        // Create notification with server timestamp
        final docRef = await firestore.collection('user_notifications').add({
          'userId': userId,
          'type': NotificationType.optional.toString(),
          'title': 'Test Notification',
          'body': 'Test Body',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        await repository.markAsRead(docRef.id);
        
        // Assert
        final doc = await docRef.get();
        final data = doc.data()!;
        
        expect(data['isRead'], isTrue);
        expect(data['readAt'], isA<Timestamp>());
        
        // Verify readAt is after createdAt
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final readAt = (data['readAt'] as Timestamp).toDate();
        expect(readAt.isAfter(createdAt), isTrue);
      });
      
      test('should stream notifications with proper timestamp ordering', () async {
        // Arrange
        const userId = 'test_user';
        
        // Create notifications with server timestamps
        for (int i = 0; i < 3; i++) {
          await firestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
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
            notifications[i].createdAt.isAfter(notifications[i + 1].createdAt),
            isTrue,
          );
        }
      });
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
          final notifications = await firestore
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
        const userId = 'test_user';
        final notificationIds = <String>[];
        
        // Create multiple unread notifications
        for (int i = 0; i < 5; i++) {
          final docRef = await firestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          notificationIds.add(docRef.id);
        }
        
        // Act
        await repository.markMultipleAsRead(notificationIds);
        
        // Assert
        for (final id in notificationIds) {
          final doc = await firestore
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
        const userId = 'test_user';
        final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
        
        // Create old notifications
        for (int i = 10; i < 13; i++) {
          await firestore.collection('user_notifications').add({
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
          await firestore.collection('user_notifications').add({
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
        const userId = 'test_user';
        
        // Create mix of read and unread notifications
        for (int i = 0; i < 10; i++) {
          await firestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': i % 3 == 0, // Every third is read
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Act
        final unreadCount = await repository.getUnreadCount(userId);
        
        // Assert
        expect(unreadCount, equals(7)); // 10 total, 3 read, 7 unread
        
        // Mark all as read
        await repository.markAllAsRead(userId);
        
        // Verify all are now read
        final newUnreadCount = await repository.getUnreadCount(userId);
        expect(newUnreadCount, equals(0));
      });
    });
    
    group('Notification Preferences', () {
      test('should save and retrieve notification preferences', () async {
        // Arrange
        const userId = 'test_user';
        final preferences = NotificationPreferences(
          enableRecipeSharing: true,
          enableFriendRequests: false,
          enableGroupInvitations: true,
          enableComments: false,
          enableRatings: true,
          enableCollaborativeEditing: false,
          enableMenuSharing: true,
          enableGeneralUpdates: false,
        );
        
        // Act
        await repository.updateNotificationPreferences(userId, preferences);
        
        // Assert
        final savedPreferences = await repository.getNotificationPreferences(userId);
        
        expect(savedPreferences.enableRecipeSharing, isTrue);
        expect(savedPreferences.enableFriendRequests, isFalse);
        expect(savedPreferences.enableGroupInvitations, isTrue);
        expect(savedPreferences.enableComments, isFalse);
        expect(savedPreferences.enableRatings, isTrue);
        expect(savedPreferences.enableCollaborativeEditing, isFalse);
        expect(savedPreferences.enableMenuSharing, isTrue);
        expect(savedPreferences.enableGeneralUpdates, isFalse);
      });
    });
    
    group('FCM Token Management', () {
      test('should update and remove FCM tokens', () async {
        // Arrange
        const userId = 'test_user';
        const token1 = 'fcm_token_123';
        const token2 = 'fcm_token_456';
        
        // Act - Update tokens
        await repository.updateFCMToken(userId, token1);
        await repository.updateFCMToken(userId, token2);
        
        // Assert - Check tokens were saved
        final userDoc = await firestore
            .collection('users')
            .doc(userId)
            .get();
        
        final fcmTokens = List<String>.from(userDoc.data()?['fcmTokens'] ?? []);
        expect(fcmTokens, contains(token1));
        expect(fcmTokens, contains(token2));
        
        // Act - Remove one token
        await repository.removeFCMToken(userId, token1);
        
        // Assert - Check token was removed
        final updatedDoc = await firestore
            .collection('users')
            .doc(userId)
            .get();
        
        final updatedTokens = List<String>.from(updatedDoc.data()?['fcmTokens'] ?? []);
        expect(updatedTokens, isNot(contains(token1)));
        expect(updatedTokens, contains(token2));
      });
    });
  });
}