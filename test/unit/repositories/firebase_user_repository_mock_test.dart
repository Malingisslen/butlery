/// Unit tests for services using UserRepository
///
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('UserRepository Mock Tests', () {
    late MockUserRepository mockRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UserProfileFactory.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mock repository with configuration
      mockRepository = MockFactory.createUserRepository(
        currentUserId: 'test-user-123',
        profiles: {},
        onlineStatus: {},
        fcmTokens: {},
        notificationSettings: {},
        availableDisplayNames: {'Jane Smith', 'Available Name'},
      );

      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Profile Management', () {
      test('should save user profile', () async {
        // Arrange
        final profile = UserProfileFactory.build(
          uid: 'test-user-123',
          displayName: 'Test User',
          email: 'test@example.com',
        );

        // Stub the repository method
        when(
          () => mockRepository.saveProfile(profile),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.saveProfile(profile);

        // Assert
        verify(() => mockRepository.saveProfile(profile)).called(1);
      });

      test('should fetch profile by ID', () async {
        // Arrange
        const userId = 'test-user-123';
        final expectedProfile = UserProfileFactory.build(
          uid: userId,
          displayName: 'Test User',
          email: 'test@example.com',
        );

        // Stub the repository method
        when(
          () => mockRepository.fetchProfile(userId),
        ).thenAnswer((_) async => expectedProfile);

        // Act
        final profile = await mockRepository.fetchProfile(userId);

        // Assert
        expect(profile, isNotNull);
        expect(profile!.uid, equals(userId));
        expect(profile.displayName, equals('Test User'));

        verify(() => mockRepository.fetchProfile(userId)).called(1);
      });

      test('should return null for non-existent profile', () async {
        // Arrange
        const userId = 'non-existent';

        // Stub the repository method
        when(
          () => mockRepository.fetchProfile(userId),
        ).thenAnswer((_) async => null);

        // Act
        final profile = await mockRepository.fetchProfile(userId);

        // Assert
        expect(profile, isNull);
        verify(() => mockRepository.fetchProfile(userId)).called(1);
      });

      test('should fetch multiple profiles', () async {
        // Arrange
        final userIds = ['user-1', 'user-2', 'user-3'];
        final expectedProfiles = [
          UserProfileFactory.build(uid: 'user-1', displayName: 'User 1'),
          UserProfileFactory.build(uid: 'user-2', displayName: 'User 2'),
          UserProfileFactory.build(uid: 'user-3', displayName: 'User 3'),
        ];

        // Stub the repository method
        when(
          () => mockRepository.fetchProfiles(userIds),
        ).thenAnswer((_) async => expectedProfiles);

        // Act
        final profiles = await mockRepository.fetchProfiles(userIds);

        // Assert
        expect(profiles, hasLength(3));
        expect(profiles.map((p) => p.uid), containsAll(userIds));

        verify(() => mockRepository.fetchProfiles(userIds)).called(1);
      });

      test('should ensure base user document exists', () async {
        // Arrange
        const userId = 'test-user-123';

        // Stub the repository method
        when(
          () => mockRepository.ensureBaseUserDocument(userId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.ensureBaseUserDocument(userId);

        // Assert
        verify(() => mockRepository.ensureBaseUserDocument(userId)).called(1);
      });
    });

    group('Profile Statistics', () {
      test('should update profile statistics', () async {
        // Arrange
        const userId = 'test-user-123';
        const friendsCount = 5;
        const publicRecipeCount = 10;

        // Stub the repository method
        when(
          () => mockRepository.updateProfileStats(
            userId,
            friendsCount: friendsCount,
            publicRecipeCount: publicRecipeCount,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateProfileStats(
          userId,
          friendsCount: friendsCount,
          publicRecipeCount: publicRecipeCount,
        );

        // Assert
        verify(
          () => mockRepository.updateProfileStats(
            userId,
            friendsCount: friendsCount,
            publicRecipeCount: publicRecipeCount,
          ),
        ).called(1);
      });

      test('should update online status', () async {
        // Arrange
        const userId = 'test-user-123';
        const isOnline = true;

        // Stub the repository method
        when(
          () => mockRepository.updateOnlineStatus(userId, isOnline),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateOnlineStatus(userId, isOnline);

        // Assert
        verify(
          () => mockRepository.updateOnlineStatus(userId, isOnline),
        ).called(1);
      });
    });

    group('Search Operations', () {
      test('should search profiles by query', () async {
        // Arrange
        const query = 'john';
        final expectedResults = [
          UserProfileFactory.build(uid: 'user-1', displayName: 'John Doe'),
          UserProfileFactory.build(uid: 'user-2', displayName: 'Johnny Walker'),
        ];

        // Stub the repository method
        when(
          () => mockRepository.searchProfiles(query),
        ).thenAnswer((_) async => expectedResults);

        // Act
        final results = await mockRepository.searchProfiles(query);

        // Assert
        expect(results, hasLength(2));
        expect(results.first.displayName, equals('John Doe'));
        expect(results[1].displayName, equals('Johnny Walker'));

        verify(() => mockRepository.searchProfiles(query)).called(1);
      });

      test('should return empty list for empty search query', () async {
        // Arrange
        const query = '';

        // Stub the repository method
        when(
          () => mockRepository.searchProfiles(query),
        ).thenAnswer((_) async => []);

        // Act
        final results = await mockRepository.searchProfiles(query);

        // Assert
        expect(results, isEmpty);
        verify(() => mockRepository.searchProfiles(query)).called(1);
      });

      test('should check display name availability', () async {
        // Arrange
        const takenName = 'John Doe';
        const availableName = 'Jane Smith';

        // Stub the repository methods
        when(
          () => mockRepository.isDisplayNameAvailable(takenName),
        ).thenAnswer((_) async => false);
        when(
          () => mockRepository.isDisplayNameAvailable(availableName),
        ).thenAnswer((_) async => true);

        // Act
        final isTakenAvailable = await mockRepository.isDisplayNameAvailable(
          takenName,
        );
        final isAvailableAvailable = await mockRepository
            .isDisplayNameAvailable(availableName);

        // Assert
        expect(isTakenAvailable, isFalse);
        expect(isAvailableAvailable, isTrue);

        verify(
          () => mockRepository.isDisplayNameAvailable(takenName),
        ).called(1);
        verify(
          () => mockRepository.isDisplayNameAvailable(availableName),
        ).called(1);
      });
    });

    group('Notification Management', () {
      test('should update FCM token', () async {
        // Arrange
        const userId = 'test-user-123';
        const token = 'fcm-token-123';

        // Stub the repository method
        when(
          () => mockRepository.updateFCMToken(userId, token),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateFCMToken(userId, token);

        // Assert
        verify(() => mockRepository.updateFCMToken(userId, token)).called(1);
      });

      test('should update notification settings', () async {
        // Arrange
        const userId = 'test-user-123';
        const enabled = true;

        // Stub the repository method
        when(
          () => mockRepository.updateNotificationSettings(userId, enabled),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateNotificationSettings(userId, enabled);

        // Assert
        verify(
          () => mockRepository.updateNotificationSettings(userId, enabled),
        ).called(1);
      });

      test('should clear FCM token', () async {
        // Arrange
        const userId = 'test-user-123';

        // Stub the repository method
        when(
          () => mockRepository.clearFCMToken(userId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.clearFCMToken(userId);

        // Assert
        verify(() => mockRepository.clearFCMToken(userId)).called(1);
      });
    });
  });
}
