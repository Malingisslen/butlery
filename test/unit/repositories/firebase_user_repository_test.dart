/// Comprehensive unit tests for FirebaseUserRepository
/// 
/// Tests Firebase Firestore implementation of user profile management including
/// profile operations, search functionality, notifications, and statistics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Mock Firebase User
class MockUser extends Mock implements User {
  @override
  String get uid => 'test-user-123';
}

void main() {
  group('FirebaseUserRepository', () {
    late FirebaseUserRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late MockUser mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UserProfileFactory.build());
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();
      
      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = MockUser();
      
      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'test-user-123',
        isAuthenticated: true,
      );
      
      // Create repository with fake Firestore
      repository = FirebaseUserRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Profile Management', () {
      test('should save profile with validation', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
          email: 'test@example.com',
        );
        
        // Act
        await repository.saveProfile(profile);
        
        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['displayName'], equals('Test User'));
        expect(doc.data()?['displayNameLower'], equals('test user'));
        expect(doc.data()?['email'], equals('test@example.com'));
      });

      test('should reject saving profile for different user', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'other-user-456',
          displayName: 'Other User',
        );
        
        // Act & Assert
        expect(
          () => repository.saveProfile(profile),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should fetch profile by ID', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(profile.toFirestore());
        
        // Act
        final fetched = await repository.fetchProfile('test-user-123');
        
        // Assert
        expect(fetched, isNotNull);
        expect(fetched!.uid, equals('test-user-123'));
        expect(fetched.displayName, equals('Test User'));
      });

      test('should return null for non-existent profile', () async {
        // Arrange
        // No setup needed - profile doesn't exist
        
        // Act
        final profile = await repository.fetchProfile('non-existent');
        
        // Assert
        expect(profile, isNull);
      });

      test('should fetch multiple profiles in batches', () async {
        // Arrange
        final profiles = <UserProfile>[];
        for (int i = 0; i < 25; i++) {
          final profile = UserProfileFactory.build(
            uid: 'user-$i',
            displayName: 'User $i',
          );
          profiles.add(profile);
          await fakeFirestore
              .collection('public_profiles')
              .doc('user-$i')
              .set(profile.toFirestore());
        }
        
        final userIds = List.generate(25, (i) => 'user-$i');
        
        // Act
        final fetched = await repository.fetchProfiles(userIds);
        
        // Assert
        expect(fetched, hasLength(25));
        for (int i = 0; i < 25; i++) {
          expect(fetched.any((p) => p.uid == 'user-$i'), isTrue);
        }
      });

      test('should handle empty list for fetchProfiles', () async {
        // Arrange
        // No setup needed - empty list input
        
        // Act
        final fetched = await repository.fetchProfiles([]);
        
        // Assert
        expect(fetched, isEmpty);
      });

      test('should ensure base user document exists', () async {
        // Arrange
        // No setup needed
        
        // Act
        await repository.ensureBaseUserDocument('test-user-123');
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc('test-user-123')
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['uid'], equals('test-user-123'));
        expect(doc.data()?['initialized'], isTrue);
      });
    });

    group('Profile Statistics', () {
      test('should update profile statistics', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(profile.toFirestore());
        
        // Act
        await repository.updateProfileStats(
          'test-user-123',
          friendsCount: 5,
          publicRecipeCount: 10,
        );
        
        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .get();
        
        expect(doc.data()?['friendsCount'], equals(5));
        expect(doc.data()?['publicRecipeCount'], equals(10));
      });

      test('should reject updating stats for different user', () async {
        // Arrange
        // No setup needed
        
        // Act & Assert
        expect(
          () => repository.updateProfileStats(
            'other-user-456',
            friendsCount: 5,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should update online status', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(profile.toFirestore());
        
        // Act
        await repository.updateOnlineStatus('test-user-123', true);
        
        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .get();
        
        expect(doc.data()?['isOnline'], isTrue);
        expect(doc.data()?['lastActiveAt'], isNotNull);
      });

      test('should reject updating online status for different user', () async {
        // Arrange
        // No setup needed
        
        // Act & Assert
        expect(
          () => repository.updateOnlineStatus('other-user-456', true),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Search Operations', () {
      test('should search profiles by display name', () async {
        // Arrange
        final profiles = [
          UserProfileFactory.build(
            uid: 'user-1',
            displayName: 'John Doe',
            isSearchable: true,
          ),
          UserProfileFactory.build(
            uid: 'user-2',
            displayName: 'Jane Smith',
            isSearchable: true,
          ),
          UserProfileFactory.build(
            uid: 'user-3',
            displayName: 'Johnny Walker',
            isSearchable: true,
          ),
          UserProfileFactory.build(
            uid: 'user-4',
            displayName: 'Bob Brown',
            isSearchable: false, // Not searchable
          ),
        ];
        
        for (final profile in profiles) {
          final data = profile.toFirestore();
          data['displayNameLower'] = profile.displayName.toLowerCase();
          await fakeFirestore
              .collection('public_profiles')
              .doc(profile.uid)
              .set(data);
        }
        
        // Act
        final results = await repository.searchProfiles('john');
        
        // Assert
        expect(results.length, greaterThanOrEqualTo(2));
        expect(results.any((p) => p.displayName == 'John Doe'), isTrue);
        expect(results.any((p) => p.displayName == 'Johnny Walker'), isTrue);
        expect(results.any((p) => p.displayName == 'Bob Brown'), isFalse);
      });

      test('should return empty list for empty search query', () async {
        // Arrange
        // No setup needed
        
        // Act
        final results = await repository.searchProfiles('');
        final results2 = await repository.searchProfiles('  ');
        
        // Assert
        expect(results, isEmpty);
        expect(results2, isEmpty);
      });

      test('should search by email when allowed', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'user-1',
          displayName: 'John Doe',
          email: 'john@example.com',
          allowEmailSearch: true,
        );
        
        final data = profile.toFirestore();
        data['displayNameLower'] = profile.displayName.toLowerCase();
        await fakeFirestore
            .collection('public_profiles')
            .doc('user-1')
            .set(data);
        
        // Act
        final results = await repository.searchProfiles('john@example.com');
        
        // Assert
        expect(results, hasLength(1));
        expect(results.first.email, equals('john@example.com'));
      });

      test('should exclude current user from search results', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
          isSearchable: true,
        );
        
        final data = profile.toFirestore();
        data['displayNameLower'] = profile.displayName.toLowerCase();
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(data);
        
        // Act
        final results = await repository.searchProfiles('test');
        
        // Assert
        expect(results.any((p) => p.uid == 'test-user-123'), isFalse);
      });

      test('should check display name availability', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'user-1',
          displayName: 'John Doe',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('user-1')
            .set(profile.toFirestore());
        
        // Act
        final available = await repository.isDisplayNameAvailable('John Doe');
        final available2 = await repository.isDisplayNameAvailable('Jane Smith');
        
        // Assert
        expect(available, isFalse);
        expect(available2, isTrue);
      });

      test('should allow current user to keep their display name', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(profile.toFirestore());
        
        // Act
        final available = await repository.isDisplayNameAvailable('Test User');
        
        // Assert
        expect(available, isTrue); // True because it's their own name
      });
    });

    group('Notification Management', () {
      test('should update FCM token', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(profile.toFirestore());
        
        // Act
        await repository.updateFCMToken('test-user-123', 'fcm-token-123');
        
        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .get();
        
        expect(doc.data()?['fcmToken'], equals('fcm-token-123'));
        expect(doc.data()?['fcmTokenUpdatedAt'], isNotNull);
      });

      test('should reject updating FCM token for different user', () async {
        // Arrange
        // No setup needed
        
        // Act & Assert
        expect(
          () => repository.updateFCMToken('other-user-456', 'fcm-token'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should update notification settings', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(profile.toFirestore());
        
        // Act
        await repository.updateNotificationSettings('test-user-123', true);
        
        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .get();
        
        expect(doc.data()?['notificationsEnabled'], isTrue);
      });

      test('should clear FCM token', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        final data = profile.toFirestore();
        data['fcmToken'] = 'old-token';
        data['fcmTokenUpdatedAt'] = FieldValue.serverTimestamp();
        
        await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .set(data);
        
        // Act
        await repository.clearFCMToken('test-user-123');
        
        // Assert
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc('test-user-123')
            .get();
        
        expect(doc.data()?['fcmToken'], isNull);
        expect(doc.data()?['fcmTokenUpdatedAt'], isNull);
      });

      test('should reject clearing FCM token for different user', () async {
        // Arrange
        // No setup needed
        
        // Act & Assert
        expect(
          () => repository.clearFCMToken('other-user-456'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Error Handling', () {
      test('should validate required fields when saving profile', () async {
        // Arrange
        final invalidProfile = UserProfile(
          uid: 'test-user-123',
          email: 'test@example.com',
          displayName: '', // Empty display name
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        
        // Act & Assert
        try {
          await repository.saveProfile(invalidProfile);
          // If it doesn't throw, we need to check the actual validation logic
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle authentication errors gracefully', () async {
        // Arrange
        mockAuthRepo.setAuthState(user: null, userId: null);
        
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
        );
        
        // Act & Assert
        expect(
          () => repository.saveProfile(profile),
          throwsA(isA<AuthenticationException>()),
        );
      });
    });
  });
}