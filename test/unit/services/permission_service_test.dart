import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/permission_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('PermissionService', () {
    late PermissionService permissionService;
    late MockAuthRepository mockAuthRepository;
    late User mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      PermissionService.resetForTesting();

      mockUser = MockFactory.createMockUser(
        uid: 'test_user_123',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      mockAuthRepository = MockFactory.createAuthRepository(
        isAuthenticated: false,
        userId: null,
        user: null,
      );

      permissionService = PermissionService(authRepository: mockAuthRepository);

      BaseUnitTest.registerMocks([mockAuthRepository]);
    });

    tearDown(() async {
      PermissionService.resetForTesting();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Authentication State', () {
      test('should return null currentUserId when not authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        expect(permissionService.currentUserId, isNull);
      });

      test('should return currentUserId when authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        expect(permissionService.currentUserId, equals('test_user_123'));
      });

      test('should return currentUser when authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );

        final user = permissionService.currentUser;
        expect(user, isNotNull);
        expect(user?.uid, equals('test_user_123'));
        expect(user?.displayName, equals('Test User'));
        expect(user?.email, equals('test@example.com'));
      });

      test('should return null currentUser when not authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        expect(permissionService.currentUser, isNull);
      });

      test('should return currentUserDisplayName when authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        expect(
          permissionService.currentUserDisplayName,
          equals('Test User'),
        );
      });

      test('should check isAuthenticated correctly', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        expect(permissionService.isAuthenticated, isFalse);

        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
        expect(permissionService.isAuthenticated, isTrue);
      });
    });

    group('User Profile', () {
      test('should return current user profile for own user ID', () async {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );

        final profile = await permissionService.getUserProfile('test_user_123');

        expect(profile, isNotNull);
        expect(profile?.uid, equals('test_user_123'));
        expect(profile?.displayName, equals('Test User'));
        expect(profile?.email, equals('test@example.com'));
        expect(profile?.isOnline, isTrue);
      });

      test('should return null for empty user ID', () async {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );

        final profile = await permissionService.getUserProfile('');
        expect(profile, isNull);
      });

      // Note: getUserProfile for other users delegates to
      // UserService via production ServiceLocator, which requires
      // full DI. Tested at integration level instead.
    });

    group('Ownership (isOwner)', () {
      setUp(() {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
      });

      test('should identify current user as owner', () {
        expect(permissionService.isOwner('test_user_123'), isTrue);
      });

      test('should not identify other user as owner', () {
        expect(permissionService.isOwner('other_user_456'), isFalse);
      });

      test('should return false when not authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        expect(permissionService.isOwner('test_user_123'), isFalse);
      });

      test('should return false for empty owner ID', () {
        expect(permissionService.isOwner(''), isFalse);
      });
    });

    group('Group Permissions', () {
      // GroupPermissionModule does NOT use ServiceLocator, so these
      // tests work without full DI.
      setUp(() {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );
      });

      test('should deny canDeleteGroup when not authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        expect(permissionService.canDeleteGroup('group123'), isFalse);
      });

      test('should deny canDeleteGroup for empty group ID', () {
        expect(permissionService.canDeleteGroup(''), isFalse);
      });

      test('should deny canInviteToGroup when not authenticated', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: false,
          user: null,
          userId: null,
        );
        expect(permissionService.canInviteToGroup('group123'), isFalse);
      });

      test('should deny canInviteToGroup for empty group ID', () {
        expect(permissionService.canInviteToGroup(''), isFalse);
      });

      test('should check isGroupAdmin', () {
        // Without group data, defaults to false
        expect(permissionService.isGroupAdmin('group123'), isFalse);
      });
    });

    group('Singleton Pattern', () {
      test('should return same instance on multiple factory calls', () {
        final i1 = PermissionService(authRepository: mockAuthRepository);
        final i2 = PermissionService(authRepository: mockAuthRepository);
        expect(identical(i1, i2), isTrue);
      });

      test('should maintain state across instances', () {
        mockAuthRepository.setAuthState(
          isAuthenticated: true,
          user: mockUser,
          userId: 'test_user_123',
        );

        final i1 = PermissionService(authRepository: mockAuthRepository);
        final i2 = PermissionService(authRepository: mockAuthRepository);

        expect(i1.currentUserId, equals('test_user_123'));
        expect(i2.currentUserId, equals('test_user_123'));
      });
    });

    // Note: Recipe Permissions, Shopping List Permissions, and Resource
    // Permissions are NOT tested here because their lazy modules call
    // production ServiceLocator.get<UnifiedRecipeService>() /
    // ServiceLocator.get<UnifiedShoppingService>(), which requires full
    // DI initialisation. Those are covered by integration tests.
  });
}
