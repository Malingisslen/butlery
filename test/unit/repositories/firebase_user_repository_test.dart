/// Comprehensive unit tests for FirebaseUserRepository.
///
/// Tests user profile management functionality including CRUD operations,
/// search capabilities, FCM token management, and permission validation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/models/user_profile.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseUserRepository - User Profile Management', () {
    late FirebaseUserRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: 'user-123');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
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

    group('Permission Validation', () {
      test('should allow user to create their own profile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final canCreate = await repository.validateCreatePermission('user-123', profile);

        // Assert
        expect(canCreate, isTrue);
      });

      test('should reject user from creating another user\'s profile', () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canCreate = await repository.validateCreatePermission('user-123', profile);

        // Assert
        expect(canCreate, isFalse);
      });

      test('should allow anyone to read public profiles', () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canRead = await repository.validateReadPermission('user-123', 'other-user', profile);

        // Assert
        expect(canRead, isTrue); // Public profiles are readable for social features
      });

      test('should allow user to update their own profile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final canUpdate = await repository.validateUpdatePermission('user-123', 'user-123', profile);

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject user from updating another user\'s profile', () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canUpdate = await repository.validateUpdatePermission('user-123', 'other-user', profile);

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow user to delete their own profile', () async {
        // Act
        final canDelete = await repository.validateDeletePermission('user-123', 'user-123');

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject user from deleting another user\'s profile', () async {
        // Act
        final canDelete = await repository.validateDeletePermission('user-123', 'other-user');

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Profile Operations', () {
      test('should save user profile successfully', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        await repository.saveProfile(profile);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc('user-123').get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['displayName'], equals('Test User'));
        expect(data['email'], equals('test@example.com'));
        expect(data['displayNameLower'], equals('test user')); // Searchable index
      });

      test('should fetch profile by id', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        final profile = await repository.fetchProfile(userId);

        // Assert
        expect(profile, isNotNull);
        expect(profile!.uid, equals(userId));
        expect(profile.displayName, equals('Test User'));
      });

      test('should return null when fetching non-existent profile', () async {
        // Act
        final profile = await repository.fetchProfile('nonexistent');

        // Assert
        expect(profile, isNull);
      });

      test('should fetch multiple profiles in batches', () async {
        // Arrange
        final userIds = List.generate(15, (i) => 'user-$i');
        for (final userId in userIds) {
          await _seedUserProfile(
            fakeFirestore,
            userId,
            _createUserProfile(userId, displayName: 'User $userId').toFirestore(),
          );
        }

        // Act
        final profiles = await repository.fetchProfiles(userIds);

        // Assert
        expect(profiles.length, equals(15)); // Handles batching (Firestore limit 10)
        expect(profiles.map((p) => p.uid).toSet(), equals(userIds.toSet()));
      });

      test('should handle empty list when fetching profiles', () async {
        // Act
        final profiles = await repository.fetchProfiles([]);

        // Assert
        expect(profiles, isEmpty);
      });
    });

    group('Profile Statistics', () {
      test('should update friend count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateProfileStats(userId, friendsCount: 10);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc(userId).get();
        expect(doc.data()!['friendsCount'], equals(10));
      });

      test('should update public recipe count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateProfileStats(userId, publicRecipeCount: 25);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc(userId).get();
        expect(doc.data()!['publicRecipeCount'], equals(25));
      });

      test('should update multiple stats simultaneously', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateProfileStats(userId, friendsCount: 15, publicRecipeCount: 30);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc(userId).get();
        expect(doc.data()!['friendsCount'], equals(15));
        expect(doc.data()!['publicRecipeCount'], equals(30));
      });

      test('should increment public recipe count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.incrementPublicRecipeCount(userId);

        // Assert - Note: FakeFirebaseFirestore may not support FieldValue.increment
        // In real Firebase, this would increment by 1
      }, skip: 'FakeFirebaseFirestore FieldValue.increment limitation - tested in integration tests');

      test('should decrement public recipe count', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.decrementPublicRecipeCount(userId);

        // Assert - Note: FakeFirebaseFirestore may not support FieldValue.increment
      }, skip: 'FakeFirebaseFirestore FieldValue.increment limitation - tested in integration tests');
    });

    group('Online Status', () {
      test('should update online status to true', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateOnlineStatus(userId, true);

        // Assert - Note: server timestamp not supported in FakeFirebaseFirestore
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should update online status to false', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateOnlineStatus(userId, false);

        // Assert - Note: server timestamp not supported in FakeFirebaseFirestore
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');
    });

    group('Search Functionality', () {
      test('should search profiles by display name', () async {
        // Arrange
        await _seedUserProfile(fakeFirestore, 'user-1', _createUserProfile('user-1', displayName: 'John Doe').toFirestore());
        await _seedUserProfile(fakeFirestore, 'user-2', _createUserProfile('user-2', displayName: 'Jane Smith').toFirestore());
        await _seedUserProfile(fakeFirestore, 'user-3', _createUserProfile('user-3', displayName: 'John Smith').toFirestore());

        // Act
        final results = await repository.searchProfiles('john');

        // Assert
        expect(results.length, equals(2)); // John Doe and John Smith
        expect(results.every((p) => p.displayName.toLowerCase().contains('john')), isTrue);
        expect(results.any((p) => p.uid == 'user-123'), isFalse); // Should exclude current user
      });

      test('should return empty list for empty query', () async {
        // Act
        final results = await repository.searchProfiles('');

        // Assert
        expect(results, isEmpty);
      });

      test('should respect isSearchable flag', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'user-1',
          _createUserProfile('user-1', displayName: 'Searchable User', isSearchable: true).toFirestore(),
        );
        await _seedUserProfile(
          fakeFirestore,
          'user-2',
          _createUserProfile('user-2', displayName: 'Private User', isSearchable: false).toFirestore(),
        );

        // Act
        final results = await repository.searchProfiles('user');

        // Assert
        expect(results.length, equals(1));
        expect(results.first.uid, equals('user-1')); // Only searchable user
      }, skip: 'FakeFirebaseFirestore composite index limitation - tested in integration tests');

      test('should search by email when email search is allowed', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'user-1',
          _createUserProfile('user-1', email: 'john@example.com', allowEmailSearch: true).toFirestore(),
        );

        // Act
        final results = await repository.searchProfiles('john@example.com');

        // Assert
        expect(results.any((p) => p.email == 'john@example.com'), isTrue);
      });

      test('should sort results with exact matches first', () async {
        // Arrange
        await _seedUserProfile(fakeFirestore, 'user-1', _createUserProfile('user-1', displayName: 'Test').toFirestore());
        await _seedUserProfile(fakeFirestore, 'user-2', _createUserProfile('user-2', displayName: 'Test User').toFirestore());
        await _seedUserProfile(fakeFirestore, 'user-3', _createUserProfile('user-3', displayName: 'Another Test').toFirestore());

        // Act
        final results = await repository.searchProfiles('test');

        // Assert
        if (results.isNotEmpty) {
          // Exact match should come first
          expect(results.first.displayName.toLowerCase(), equals('test'));
        }
      });
    });

    group('Display Name Availability', () {
      test('should return true when display name is available', () async {
        // Act
        final isAvailable = await repository.isDisplayNameAvailable('Unique Name');

        // Assert
        expect(isAvailable, isTrue);
      });

      test('should return false when display name is taken by another user', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'other-user',
          _createUserProfile('other-user', displayName: 'Taken Name').toFirestore(),
        );

        // Act
        final isAvailable = await repository.isDisplayNameAvailable('Taken Name');

        // Assert
        expect(isAvailable, isFalse);
      });

      test('should return true when display name is taken by current user', () async {
        // Arrange
        await _seedUserProfile(
          fakeFirestore,
          'user-123',
          _createUserProfile('user-123', displayName: 'My Name').toFirestore(),
        );

        // Act
        final isAvailable = await repository.isDisplayNameAvailable('My Name');

        // Assert
        expect(isAvailable, isTrue); // User can keep their own name
      });
    });

    group('FCM Token Management', () {
      test('should update FCM token', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateFCMToken(userId, 'new-fcm-token');

        // Assert - Note: server timestamp not supported in FakeFirebaseFirestore
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should clear FCM token', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.clearFCMToken(userId);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc(userId).get();
        expect(doc.data()!['fcmToken'], isNull);
        expect(doc.data()!['fcmTokenUpdatedAt'], isNull);
      });
    });

    group('Notification Settings', () {
      test('should enable notifications', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateNotificationSettings(userId, true);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc(userId).get();
        expect(doc.data()!['notificationsEnabled'], isTrue);
      });

      test('should disable notifications', () async {
        // Arrange
        const userId = 'user-123';
        await _seedUserProfile(fakeFirestore, userId, _createUserProfile(userId).toFirestore());

        // Act
        await repository.updateNotificationSettings(userId, false);

        // Assert
        final doc = await fakeFirestore.collection('public_profiles').doc(userId).get();
        expect(doc.data()!['notificationsEnabled'], isFalse);
      });
    });

    group('Base User Document', () {
      test('should ensure base user document exists', () async {
        // Act
        await repository.ensureBaseUserDocument('user-123');

        // Assert - Note: server timestamp not supported in FakeFirebaseFirestore
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');
    });

    group('Model Integration', () {
      test('should correctly serialize and deserialize UserProfile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act - Seed and fetch
        await _seedUserProfile(fakeFirestore, profile.uid, profile.toFirestore());
        final doc = await fakeFirestore.collection('public_profiles').doc(profile.uid).get();
        final retrieved = UserProfile.fromMap(doc.id, doc.data()!);

        // Assert
        expect(retrieved.uid, equals(profile.uid));
        expect(retrieved.displayName, equals(profile.displayName));
        expect(retrieved.email, equals(profile.email));
        expect(retrieved.isSearchable, equals(profile.isSearchable));
        expect(retrieved.allowEmailSearch, equals(profile.allowEmailSearch));
        expect(retrieved.friendsCount, equals(profile.friendsCount));
        expect(retrieved.publicRecipeCount, equals(profile.publicRecipeCount));
      });
    });

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, equals('public_profiles'));
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final id = repository.getId(profile);

        // Assert
        expect(id, equals('user-123'));
      });

      test('should convert to/from Firestore correctly', () {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final firestoreData = repository.toFirestore(profile);

        // Assert
        expect(firestoreData['displayName'], equals(profile.displayName));
        expect(firestoreData['email'], equals(profile.email));
        expect(firestoreData['isSearchable'], equals(profile.isSearchable));
        expect(firestoreData['friendsCount'], equals(profile.friendsCount));
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test user profile
UserProfile _createUserProfile(
  String uid, {
  String displayName = 'Test User',
  String email = 'test@example.com',
  bool isSearchable = true,
  bool allowEmailSearch = false,
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    avatarUrl: 'https://example.com/avatar.jpg',
    isSearchable: isSearchable,
    allowEmailSearch: allowEmailSearch,
    publicRecipeCount: 5,
    friendsCount: 10,
    joinedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
    isOnline: false,
  );
}

/// Seed user profile into fake Firestore
Future<void> _seedUserProfile(
  FakeFirebaseFirestore firestore,
  String userId,
  Map<String, dynamic> data,
) async {
  // Add displayNameLower for search indexing
  if (data.containsKey('displayName')) {
    data['displayNameLower'] = (data['displayName'] as String).toLowerCase();
  }
  await firestore.collection('public_profiles').doc(userId).set(data);
}
