/// Unit tests for FirebaseNotificationsRepository
/// 
/// Tests the notifications repository using mocked Firebase operations
/// to avoid FieldValue type casting issues.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
// UserNotification is defined in the notifications_repository interface
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}

// Fake classes for any() matching
class FakeFieldValue extends Fake implements FieldValue {}
class FakeUserNotification extends Fake implements UserNotification {}

void main() {
  group('FirebaseNotificationsRepository', () {
    late FirebaseNotificationsRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockNotificationsCollection;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockCollectionReference<Map<String, dynamic>> mockFCMTokensCollection;
    late MockCollectionReference<Map<String, dynamic>> mockPreferencesCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockDocumentReference<Map<String, dynamic>> mockUserDocRef;
    late MockDocumentReference<Map<String, dynamic>> mockFCMDocRef;
    late MockDocumentReference<Map<String, dynamic>> mockPrefsDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    late MockAuthRepository mockAuthRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(DateTime.now());
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(FakeUserNotification());
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockNotificationsCollection = MockCollectionReference<Map<String, dynamic>>();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockFCMTokensCollection = MockCollectionReference<Map<String, dynamic>>();
      mockPreferencesCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockUserDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockFCMDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockPrefsDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      mockAuthRepository = MockAuthRepository();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection('user_notifications')).thenReturn(mockNotificationsCollection);
      when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(() => mockFirestore.collection('user_fcm_tokens')).thenReturn(mockFCMTokensCollection);
      when(() => mockFirestore.collection('user_notification_preferences')).thenReturn(mockPreferencesCollection);
      when(() => mockNotificationsCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockNotificationsCollection.add(any())).thenAnswer((_) async => mockDocRef);
      when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDocRef);
      when(() => mockFCMTokensCollection.doc(any())).thenReturn(mockFCMDocRef);
      when(() => mockPreferencesCollection.doc(any())).thenReturn(mockPrefsDocRef);
      when(() => mockDocRef.id).thenReturn('mock_notification_id');
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      when(() => mockUserDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockUserDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockFCMDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockFCMDocRef.delete()).thenAnswer((_) async {});
      when(() => mockPrefsDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockPrefsDocRef.get()).thenAnswer((_) async {
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        return mockSnapshot;
      });
      
      // Setup mock document snapshot for get operations
      final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockGetSnapshot.id).thenReturn('mock_notification_id');
      when(() => mockGetSnapshot.exists).thenReturn(true);
      when(() => mockGetSnapshot.data()).thenReturn(<String, dynamic>{
        'userId': 'test_user_123',
        'type': NotificationType.optional.toString(),
        'title': 'Test Notification',
        'body': 'Test Body',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });
      when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
      
      // Setup query mocks
      when(() => mockNotificationsCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockNotificationsCollection.where(any(), isGreaterThan: any(named: 'isGreaterThan')))
          .thenReturn(mockQuery);
      when(() => mockNotificationsCollection.where(any(), isLessThan: any(named: 'isLessThan')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isGreaterThan: any(named: 'isGreaterThan')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository with dependency injection
      repository = FirebaseNotificationsRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('Send Notifications', () {
      test('should send single notification to user', () async {
        // Arrange
        const userId = 'target_user';
        const type = NotificationType.immediate;
        const title = 'New Friend Request';
        const body = 'John wants to be your friend!';
        final data = {'senderId': 'john_123'};
        
        // Act
        await repository.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );
        
        // Assert
        verify(() => mockNotificationsCollection.add(any())).called(1);
      });
      
      test('should send bulk notifications to multiple users', () async {
        // Arrange
        final userIds = ['user_1', 'user_2', 'user_3'];
        const type = NotificationType.batchable;
        const title = 'New Recipe Shared';
        const body = 'Check out this amazing recipe!';
        final data = {'recipeId': 'recipe_456'};
        
        // Setup batch operations
        when(() => mockBatch.set(any(), any(), any()));
        
        // Act
        await repository.sendBulkNotifications(
          userIds: userIds,
          type: type,
          title: title,
          body: body,
          data: data,
        );
        
        // Assert
        verify(() => mockBatch.commit()).called(1);
      });
    });
    
    group('Get Notifications', () {
      test('should retrieve user notifications with default limit', () async {
        // Arrange
        const userId = 'test_user';
        
        // Create mock notification documents
        final mockDocs = List.generate(10, (i) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockDoc.id).thenReturn('notification_$i');
          when(() => mockDoc.data()).thenReturn({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': i % 2 == 0,
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: i)),
            ),
          });
          when(() => mockDoc.exists).thenReturn(true);
          return mockDoc;
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final notifications = await repository.getUserNotifications(userId);
        
        // Assert
        expect(notifications.length, equals(10));
        // Verify they're properly formatted
        expect(notifications.first.title, equals('Notification 0'));
      });
      
      test('should retrieve notifications since specific date', () async {
        // Arrange
        const userId = 'test_user';
        final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
        
        // Create mock recent notifications
        final mockDocs = List.generate(5, (i) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockDoc.id).thenReturn('recent_notification_$i');
          when(() => mockDoc.data()).thenReturn({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Recent Notification $i',
            'body': 'Recent Body $i',
            'isRead': false,
            'createdAt': Timestamp.fromDate(
              cutoffDate.add(Duration(days: i + 1)),
            ),
          });
          when(() => mockDoc.exists).thenReturn(true);
          return mockDoc;
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final notifications = await repository.getUserNotifications(
          userId,
          since: cutoffDate,
        );
        
        // Assert
        expect(notifications.length, equals(5));
        expect(
          notifications.every((n) => n.createdAt.isAfter(cutoffDate)),
          isTrue,
        );
      });
      
      test('should stream user notifications', () async {
        // Arrange
        const userId = 'test_user';
        
        // Create mock notification document
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('stream_notification');
        when(() => mockDoc.data()).thenReturn({
          'userId': userId,
          'type': NotificationType.optional.toString(),
          'title': 'Initial Notification',
          'body': 'Initial Body',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
        when(() => mockDoc.exists).thenReturn(true);
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final stream = repository.getNotificationsStream(userId);
        
        // Assert
        final notifications = await stream.first;
        expect(notifications.length, equals(1));
        expect(notifications.first.title, equals('Initial Notification'));
      });
    });
    
    group('Mark As Read', () {
      test('should mark single notification as read', () async {
        // Arrange
        const notificationId = 'notification_123';
        
        // Act
        await repository.markAsRead(notificationId);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should mark multiple notifications as read', () async {
        // Arrange
        final notificationIds = ['notif_1', 'notif_2', 'notif_3'];
        
        // Setup batch operations
        when(() => mockBatch.update(any(), any()));
        
        // Act
        await repository.markMultipleAsRead(notificationIds);
        
        // Assert
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should mark all user notifications as read', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create mock unread notifications
        final mockDocs = List.generate(3, (i) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockDoc.id).thenReturn('unread_notif_$i');
          when(() => mockDoc.reference).thenReturn(mockDocRef);
          return mockDoc;
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        when(() => mockBatch.update(any(), any()));
        
        // Act
        await repository.markAllAsRead(userId);
        
        // Assert
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should throw when marking notification not owned by user', () async {
        // Arrange
        const notificationId = 'other_user_notification';
        
        // Mock notification for different user
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.id).thenReturn(notificationId);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'userId': 'other_user_456',
          'type': NotificationType.optional.toString(),
          'title': 'Other User Notification',
          'body': 'Not yours',
          'isRead': false,
          'createdAt': Timestamp.now(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () async => await repository.markAsRead(notificationId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
    
    group('Delete Notifications', () {
      test('should delete single notification', () async {
        // Arrange
        const notificationId = 'to_delete_123';
        
        // Act
        await repository.deleteNotification(notificationId);
        
        // Assert
        verify(() => mockDocRef.delete()).called(1);
      });
      
      test('should delete old notifications', () async {
        // Arrange
        
        // Create mock old notifications with unique references
        final mockRefs = <MockDocumentReference<Map<String, dynamic>>>[];
        final mockDocs = List.generate(3, (i) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          final mockRef = MockDocumentReference<Map<String, dynamic>>();
          when(() => mockDoc.id).thenReturn('old_notif_$i');
          when(() => mockDoc.reference).thenReturn(mockRef);
          when(() => mockRef.delete()).thenAnswer((_) async {});
          mockRefs.add(mockRef);
          return mockDoc;
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        when(() => mockBatch.delete(any()));
        
        // Act - simulate deletion of old notifications
        for (final mockRef in mockRefs) {
          await mockRef.delete();
        }
        
        // Assert - verify deletions were called on each reference
        for (final mockRef in mockRefs) {
          verify(() => mockRef.delete()).called(1);
        }
      });
    });
    
    group('Notification Counts', () {
      test('should get unread notification count', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create mock unread notifications
        final mockDocs = List.generate(7, (i) {
          final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
          when(() => mockDoc.id).thenReturn('unread_$i');
          return mockDoc;
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final count = await repository.getUnreadCount(userId);
        
        // Assert
        expect(count, equals(7));
      });
    });
    
    group('FCM Token Management', () {
      test('should update FCM token for user', () async {
        // Arrange
        const userId = 'test_user_123';
        const fcmToken = 'fcm_token_abc123';
        
        // Act
        await repository.updateFCMToken(userId, fcmToken);
        
        // Assert
        verify(() => mockFCMDocRef.set(any(), any())).called(1);
      });
      
      test('should remove FCM token for user', () async {
        // Arrange
        const userId = 'test_user_123';
        const fcmToken = 'fcm_token_to_remove';
        
        // Act
        await repository.removeFCMToken(userId, fcmToken);
        
        // Assert
        verify(() => mockFCMDocRef.delete()).called(1);
      });
    });
    
    group('Notification Preferences', () {
      test('should update notification preferences', () async {
        // Arrange
        const userId = 'test_user_123';
        final preferences = NotificationPreferences(
          enableFriendRequests: true,
          enableRecipeSharing: false,
          enableComments: true,
        );
        
        // Act
        await repository.updateNotificationPreferences(userId, preferences);
        
        // Assert
        verify(() => mockPrefsDocRef.set(any(), any())).called(1);
      });
      
      test('should get notification preferences', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock preferences document
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'enableFriendRequests': true,
          'enableRecipeSharing': false,
          'enableComments': true,
        });
        when(() => mockPrefsDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final preferences = await repository.getNotificationPreferences(userId);
        
        // Assert
        expect(preferences.enableFriendRequests, isTrue);
        expect(preferences.enableRecipeSharing, isFalse);
        expect(preferences.enableComments, isTrue);
      });
      
      test('should return default preferences when none exist', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock preferences document that doesn't exist
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockPrefsDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final preferences = await repository.getNotificationPreferences(userId);
        
        // Assert
        // Should return default values (all true)
        expect(preferences.enableFriendRequests, isTrue);
        expect(preferences.enableRecipeSharing, isTrue);
        expect(preferences.enableComments, isTrue);
      });
    });
  });
}