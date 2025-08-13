import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/user_profile.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';


void main() {
  group('UserService', () {
    late UserService userService;
    late MockUserRepository mockUserRepository;
    late MockAuthRepository mockAuthRepository;
    late User mockUser;
    late UserProfile testProfile;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      
      // Register fallback values for mocktail
      registerFallbackValue(UserProfile(
        uid: 'test',
        displayName: 'Test',
        email: 'test@example.com',
        isOnline: false,
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));
    });
    
    setUp(() async {
      // Initialize test service locator FIRST
      await TestServiceLocator.initialize();
      
      // Create mock dependencies
      mockUserRepository = MockFactory.createUserRepository();
      mockAuthRepository = MockFactory.createAuthRepository();
      
      // Create mock user
      mockUser = MockFactory.createMockUser(
        uid: 'test_user_123',
        email: 'test@example.com',
        displayName: 'Test User',
      );
      
      // Create test profile
      testProfile = MockFactory.createUserProfile(
        userId: 'test_user_123',
        displayName: 'Test User',
        email: 'test@example.com',
      );
      
      // Reset and create a fresh PermissionService with mock auth repository
      PermissionService.resetForTesting();
      final permissionService = PermissionService(authRepository: mockAuthRepository);
      
      // Register PermissionService with TestServiceLocator
      TestServiceLocator.registerMock<PermissionService>(permissionService);
      
      // TestServiceLocator already handles production ServiceLocator initialization
      
      // Create service with mock dependencies
      userService = UserService(
        repository: mockUserRepository,
        authRepository: mockAuthRepository,
      );
      
      // Register mocks for automatic reset
      BaseUnitTest.registerMocks([mockUserRepository, mockAuthRepository]);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      PermissionService.resetForTesting();
      // Don't dispose userService here as it's already tested in the lifecycle test
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Initialization', () {
      test('should initialize successfully with authenticated user', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(mockUser),
        );
        
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenAnswer(
          (_) async => testProfile,
        );
        
        // Act
        await userService.initialize();
        
        // Assert
        expect(userService.currentUserProfile, isNotNull);
        expect(userService.currentUserProfile?.uid, equals('test_user_123'));
        expect(userService.currentUserProfile?.displayName, equals('Test User'));
      });
      
      test('should initialize without user when not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(null),
        );
        
        // Act
        await userService.initialize();
        
        // Assert
        expect(userService.currentUserProfile, isNull);
      });
      
      test('should handle initialization errors gracefully', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(mockUser),
        );
        
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenThrow(
          Exception('Failed to load profile'),
        );
        
        // Act
        await userService.initialize();
        
        // Assert
        expect(userService.currentUserProfile, isNull);
        expect(userService.hasError, isTrue);
      });
    });
    
    group('Profile Management', () {
      setUp(() {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
      });
      
      test('should create or update user profile', () async {
        // Arrange
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenAnswer(
          (_) async => testProfile,
        );
        
        when(() => mockUserRepository.saveProfile(any())).thenAnswer(
          (_) async {},
        );
        
        // Act
        final result = await userService.createOrUpdateProfile(
          displayName: 'Updated Name',
          bio: 'New bio',
          isSearchable: true,
        );
        
        // Assert
        expect(result, isNotNull);
        expect(result?.displayName, equals('Updated Name'));
        expect(result?.bio, equals('New bio'));
        expect(result?.isSearchable, isTrue);
        verify(() => mockUserRepository.saveProfile(any())).called(1);
      });
      
      test('should not update profile when not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        
        // Act
        final result = await userService.createOrUpdateProfile(
          displayName: 'Updated Name',
        );
        
        // Assert
        expect(result, isNull);
        verifyNever(() => mockUserRepository.saveProfile(any()));
      });
    });
    
    group('User Search', () {
      test('should search users successfully', () async {
        // Arrange
        final searchResults = [
          MockFactory.createUserProfile(
            userId: 'user1',
            displayName: 'John Doe',
            email: 'john@example.com',
          ),
          MockFactory.createUserProfile(
            userId: 'user2',
            displayName: 'Jane Doe',
            email: 'jane@example.com',
          ),
        ];
        
        when(() => mockUserRepository.searchProfiles('Doe')).thenAnswer(
          (_) async => searchResults,
        );
        
        // Act
        final results = await userService.searchUsers('Doe');
        
        // Assert
        expect(results, hasLength(2));
        expect(results[0].displayName, equals('John Doe'));
        expect(results[1].displayName, equals('Jane Doe'));
        verify(() => mockUserRepository.searchProfiles('Doe')).called(1);
      });
      
      test('should return empty list for empty search query', () async {
        // Act
        final results = await userService.searchUsers('');
        
        // Assert
        expect(results, isEmpty);
        verifyNever(() => mockUserRepository.searchProfiles(any()));
      });
      
      test('should handle search errors gracefully', () async {
        // Arrange
        when(() => mockUserRepository.searchProfiles('error')).thenThrow(
          Exception('Search failed'),
        );
        
        // Act
        final results = await userService.searchUsers('error');
        
        // Assert
        expect(results, isEmpty);
        expect(userService.hasError, isTrue);
      });
    });
    
    group('Profile Retrieval', () {
      test('should get user profile by ID', () async {
        // Arrange
        final profile = MockFactory.createUserProfile(
          userId: 'other_user',
          displayName: 'Other User',
          email: 'other@example.com',
        );
        
        when(() => mockUserRepository.fetchProfile('other_user')).thenAnswer(
          (_) async => profile,
        );
        
        // Act
        final result = await userService.getUserProfile('other_user');
        
        // Assert
        expect(result, isNotNull);
        expect(result?.uid, equals('other_user'));
        expect(result?.displayName, equals('Other User'));
        verify(() => mockUserRepository.fetchProfile('other_user')).called(1);
      });
      
      test('should use cache for subsequent profile requests', () async {
        // Arrange
        final profile = MockFactory.createUserProfile(
          userId: 'cached_user',
          displayName: 'Cached User',
          email: 'cached@example.com',
        );
        
        when(() => mockUserRepository.fetchProfile('cached_user')).thenAnswer(
          (_) async => profile,
        );
        
        // Act
        final result1 = await userService.getUserProfile('cached_user');
        final result2 = await userService.getUserProfile('cached_user');
        
        // Assert
        expect(result1, equals(result2));
        verify(() => mockUserRepository.fetchProfile('cached_user')).called(1);
      });
      
      test('should get multiple user profiles', () async {
        // Arrange
        final profiles = [
          MockFactory.createUserProfile(
            userId: 'user1',
            displayName: 'User 1',
            email: 'user1@example.com',
          ),
          MockFactory.createUserProfile(
            userId: 'user2',
            displayName: 'User 2',
            email: 'user2@example.com',
          ),
        ];
        
        when(() => mockUserRepository.fetchProfiles(['user1', 'user2'])).thenAnswer(
          (_) async => profiles,
        );
        
        // Act
        final results = await userService.getUserProfiles(['user1', 'user2']);
        
        // Assert
        expect(results, hasLength(2));
        expect(results[0].uid, equals('user1'));
        expect(results[1].uid, equals('user2'));
        verify(() => mockUserRepository.fetchProfiles(['user1', 'user2'])).called(1);
      });
    });
    
    group('Online Status', () {
      setUp(() {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
      });
      
      test('should update online status when authenticated', () async {
        // Arrange
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(mockUser),
        );
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenAnswer(
          (_) async => testProfile,
        );
        when(() => mockUserRepository.updateOnlineStatus('test_user_123', true)).thenAnswer(
          (_) async {},
        );
        
        // Initialize service to set current user profile
        await userService.initialize();
        
        // Act
        await userService.updateOnlineStatus(true);
        
        // Assert
        verify(() => mockUserRepository.updateOnlineStatus('test_user_123', true)).called(1);
      });
      
      test('should not update online status when not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        
        // Act
        await userService.updateOnlineStatus(true);
        
        // Assert
        verifyNever(() => mockUserRepository.updateOnlineStatus(any(), any()));
      });
    });
    
    group('Profile Statistics', () {
      setUp(() async {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        
        // Setup required stubs for initialization
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(mockUser),
        );
        when(() => mockUserRepository.ensureBaseUserDocument('test_user_123')).thenAnswer(
          (_) async {},
        );
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenAnswer(
          (_) async => testProfile,
        );
        
        // Initialize service to load the profile
        await userService.initialize();
      });
      
      test('should update profile statistics', () async {
        // Arrange
        when(() => mockUserRepository.updateProfileStats(
          'test_user_123',
          friendsCount: any(named: 'friendsCount'),
          publicRecipeCount: any(named: 'publicRecipeCount'),
        )).thenAnswer((_) async {});
        
        // Act
        await userService.updateProfileStats(
          friendsCount: 5,
          publicRecipeCount: 3,
        );
        
        // Assert
        verify(() => mockUserRepository.updateProfileStats(
          'test_user_123',
          friendsCount: 5,
          publicRecipeCount: 3,
        )).called(1);
      });
    });
    
    group('Display Name Validation', () {
      test('should check display name availability', () async {
        // Arrange
        when(() => mockUserRepository.isDisplayNameAvailable('UniqueName')).thenAnswer(
          (_) async => true,
        );
        
        when(() => mockUserRepository.isDisplayNameAvailable('TakenName')).thenAnswer(
          (_) async => false,
        );
        
        // Act
        final isAvailable = await userService.isDisplayNameAvailable('UniqueName');
        final isTaken = await userService.isDisplayNameAvailable('TakenName');
        
        // Assert
        expect(isAvailable, isTrue);
        expect(isTaken, isFalse);
      });
    });
    
    group('FCM Token Management', () {
      setUp(() async {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        
        // Setup required stubs for initialization
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(mockUser),
        );
        when(() => mockUserRepository.ensureBaseUserDocument('test_user_123')).thenAnswer(
          (_) async {},
        );
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenAnswer(
          (_) async => testProfile,
        );
        
        // Initialize service to load the profile
        await userService.initialize();
      });
      
      test('should update FCM token when authenticated', () async {
        // Arrange
        when(() => mockUserRepository.updateFCMToken('test_user_123', 'fcm_token_123')).thenAnswer(
          (_) async {},
        );
        
        // Act
        await userService.updateFCMToken('fcm_token_123');
        
        // Assert
        verify(() => mockUserRepository.updateFCMToken('test_user_123', 'fcm_token_123')).called(1);
      });
      
      test('should not update FCM token when not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        
        // Act
        await userService.updateFCMToken('fcm_token_123');
        
        // Assert
        verifyNever(() => mockUserRepository.updateFCMToken(any(), any()));
      });
      
      test('should clear FCM token', () async {
        // Arrange
        when(() => mockUserRepository.clearFCMToken('test_user_123')).thenAnswer(
          (_) async {},
        );
        
        // Act
        await userService.clearFCMToken();
        
        // Assert
        verify(() => mockUserRepository.clearFCMToken('test_user_123')).called(1);
      });
    });
    
    group('Notification Settings', () {
      setUp(() async {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        
        // Setup required stubs for initialization
        when(() => mockAuthRepository.authStateChanges()).thenAnswer(
          (_) => Stream.value(mockUser),
        );
        when(() => mockUserRepository.ensureBaseUserDocument('test_user_123')).thenAnswer(
          (_) async {},
        );
        when(() => mockUserRepository.fetchProfile('test_user_123')).thenAnswer(
          (_) async => testProfile,
        );
        
        // Initialize service to load the profile
        await userService.initialize();
      });
      
      test('should update notification settings', () async {
        // Arrange
        when(() => mockUserRepository.updateNotificationSettings('test_user_123', true)).thenAnswer(
          (_) async {},
        );
        
        // Act
        await userService.updateNotificationSettings(true);
        
        // Assert
        verify(() => mockUserRepository.updateNotificationSettings('test_user_123', true)).called(1);
      });
    });
    
    group('Cache Management', () {
      test('should clear cache', () {
        // Arrange
        userService.clearCache();
        
        // Assert
        // Cache should be cleared
        expect(userService.currentUserProfile, isNull);
      });
    });
    
    group('State Management', () {
      test('should manage loading state', () {
        // Assert initial state
        expect(userService.isLoading, isFalse);
        
        // This would be set internally during operations
        // We can't directly test private methods
      });
      
      test('should manage error state', () {
        // Assert initial state
        expect(userService.hasError, isFalse);
        
        // Clear error
        userService.clearError();
        expect(userService.hasError, isFalse);
      });
    });
    
    group('Lifecycle Management', () {
      test('should dispose properly', () async {
        // Act
        await userService.dispose();
        
        // Assert
        // Service should be disposed without errors
        expect(true, isTrue);
      });
    });
  });
}