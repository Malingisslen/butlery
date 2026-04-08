import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/account/account_deletion_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

void main() {
  group('ProfileViewModel', () {
    late ProfileViewModel viewModel;
    late MockAuthService mockAuthService;
    late MockUserService mockUserService;
    late MockAccountDeletionService mockAccountDeletionService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockAuthService = MockFactory.createAuthService(
        isAuthenticated: true,
        userId: 'test-user-123',
      );
      mockUserService = MockFactory.createUserService() as MockUserService;
      mockAccountDeletionService = MockAccountDeletionService();

      TestServiceLocator.registerMock<AuthService>(mockAuthService);
      TestServiceLocator.registerMock<UserService>(mockUserService);

      viewModel = ProfileViewModel(
        authService: mockAuthService,
        userService: mockUserService,
        accountDeletionService: mockAccountDeletionService,
      );
    });

    tearDown(() async {
      try {
        viewModel.dispose();
      } catch (_) {}
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initial State', () {
      test('should start with loading false and no error', () {
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should expose current user id from auth service', () {
        expect(viewModel.currentUserId, equals('test-user-123'));
      });

      test('should expose email from auth service when stubbed', () {
        // currentUserEmail is not concretely overridden in MockAuthService,
        // so stub it to verify the VM delegates correctly.
        when(() => mockAuthService.currentUserEmail)
            .thenReturn('test@example.com');
        expect(viewModel.email, equals('test@example.com'));
      });

      test('should report authenticated when user id is present', () {
        expect(viewModel.isAuthenticated, isTrue);
      });

      test('should report not authenticated when user id is null', () {
        mockAuthService.setAuthState(isAuthenticated: false);
        final unauthVM = ProfileViewModel(
          authService: mockAuthService,
          userService: mockUserService,
          accountDeletionService: mockAccountDeletionService,
        );

        expect(unauthVM.isAuthenticated, isFalse);
        unauthVM.dispose();
      });
    });

    group('Display name resolution', () {
      // Behavior: prefers UserProfile displayName over AuthService displayName
      test('should return profile display name when available', () {
        final profile = MockFactory.createUserProfile(
          userId: 'test-user-123',
          displayName: 'Profile Name',
        );
        mockUserService.setUserState(currentUser: profile);
        when(() => mockUserService.currentUserProfile).thenReturn(profile);

        expect(viewModel.displayName, equals('Profile Name'));
      });

      // Behavior: falls back to auth display name when profile is null
      test('should fall back to auth display name when no profile', () {
        when(() => mockUserService.currentUserProfile).thenReturn(null);
        when(() => mockAuthService.currentUserDisplayName)
            .thenReturn('Auth User');
        expect(viewModel.displayName, equals('Auth User'));
      });
    });

    group('logout', () {
      // Behavior: successfully completes logout without error
      // (signOut is concretely overridden in MockAuthService, so we test the effect)
      test('should complete logout without error', () async {
        await viewModel.logout();

        expect(viewModel.hasError, isFalse);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: manages loading state during logout
      test('should set loading during logout operation', () async {
        final loadingStates = <bool>[];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        await viewModel.logout();

        expect(loadingStates, contains(true),
            reason: 'Loading should be true during logout');
        expect(viewModel.isLoading, isFalse,
            reason: 'Loading should be false after logout');
      });

      // Behavior: propagates error when signOut fails
      test('should set error when logout fails', () async {
        mockAuthService.setAuthState(
          isAuthenticated: true,
          currentUser: MockFactory.createMockUser(uid: 'test-user-123'),
          error: 'Sign out failed',
        );

        // executeAsync catches the rethrown error and sets error state
        try {
          await viewModel.logout();
        } catch (_) {
          // executeAsync rethrows
        }

        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('deleteAccount', () {
      // Behavior: returns true when account deletion succeeds
      test('should return true when deletion succeeds', () async {
        when(() => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            )).thenAnswer((_) async => {'success': true});

        final result =
            await viewModel.deleteAccount(reason: 'No longer needed');

        expect(result, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: passes reason and audit log flag to deletion service
      test('should pass reason to deletion service', () async {
        when(() => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            )).thenAnswer((_) async => {'success': true});

        await viewModel.deleteAccount(reason: 'Privacy concerns');

        verify(() => mockAccountDeletionService.deleteUserAccount(
              reason: 'Privacy concerns',
              createAuditLog: true,
            )).called(1);
      });

      // Behavior: returns false when deletion reports failure
      test('should return false when deletion result is not successful',
          () async {
        when(() => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            )).thenAnswer((_) async => {
              'success': false,
              'errors': ['profile: deletion failed']
            });

        final result = await viewModel.deleteAccount(reason: 'Testing');

        expect(result, isFalse);
      });

      // Behavior: returns false when no user is logged in
      test('should return false when no user is logged in', () async {
        mockAuthService.setAuthState(isAuthenticated: false);
        final noUserVM = ProfileViewModel(
          authService: mockAuthService,
          userService: mockUserService,
          accountDeletionService: mockAccountDeletionService,
        );

        bool result = false;
        try {
          result = await noUserVM.deleteAccount(reason: 'Test');
        } catch (_) {
          // executeAsync rethrows the 'No user logged in' exception
        }

        expect(result, isFalse);
        noUserVM.dispose();
      });

      // Behavior: returns false when deletion service throws
      test('should return false when deletion service throws', () async {
        when(() => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            )).thenThrow(Exception('Network error'));

        bool result = false;
        try {
          result = await viewModel.deleteAccount(reason: 'Test');
        } catch (_) {
          // executeAsync rethrows
        }

        expect(result, isFalse);
      });

      // Behavior: manages loading state during deletion
      test('should set loading during account deletion', () async {
        final loadingStates = <bool>[];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        when(() => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            )).thenAnswer((_) async => {'success': true});

        await viewModel.deleteAccount(reason: 'Test');

        expect(loadingStates, contains(true),
            reason: 'Loading should be true during deletion');
        expect(viewModel.isLoading, isFalse,
            reason: 'Loading should be false after deletion');
      });
    });

    group('updateProfile', () {
      // Behavior: calls createOrUpdateProfile on user service with correct args
      test('should call user service with profile data', () async {
        when(() => mockUserService.createOrUpdateProfile(
              displayName: any(named: 'displayName'),
              isSearchable: any(named: 'isSearchable'),
              allowEmailSearch: any(named: 'allowEmailSearch'),
            )).thenAnswer((_) async => null);

        await viewModel.updateProfile(
          displayName: 'New Name',
          isSearchable: true,
          allowEmailSearch: false,
        );

        verify(() => mockUserService.createOrUpdateProfile(
              displayName: 'New Name',
              isSearchable: true,
              allowEmailSearch: false,
            )).called(1);
      });

      // Behavior: completes without error on success
      test('should not have error after successful update', () async {
        when(() => mockUserService.createOrUpdateProfile(
              displayName: any(named: 'displayName'),
              isSearchable: any(named: 'isSearchable'),
              allowEmailSearch: any(named: 'allowEmailSearch'),
            )).thenAnswer((_) async => null);

        await viewModel.updateProfile(
          displayName: 'Updated Name',
        );

        expect(viewModel.hasError, isFalse);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: sets error when user service throws
      test('should set error when update fails', () async {
        when(() => mockUserService.createOrUpdateProfile(
              displayName: any(named: 'displayName'),
              isSearchable: any(named: 'isSearchable'),
              allowEmailSearch: any(named: 'allowEmailSearch'),
            )).thenThrow(Exception('Update failed'));

        try {
          await viewModel.updateProfile(displayName: 'Fail');
        } catch (_) {
          // executeAsync rethrows
        }

        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: manages loading state during profile update
      test('should set loading during profile update', () async {
        final loadingStates = <bool>[];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        when(() => mockUserService.createOrUpdateProfile(
              displayName: any(named: 'displayName'),
              isSearchable: any(named: 'isSearchable'),
              allowEmailSearch: any(named: 'allowEmailSearch'),
            )).thenAnswer((_) async => null);

        await viewModel.updateProfile(displayName: 'Name');

        expect(loadingStates, contains(true),
            reason: 'Loading should be true during update');
        expect(viewModel.isLoading, isFalse,
            reason: 'Loading should be false after update');
      });
    });

    group('Dispose', () {
      // Behavior: dispose does not throw
      test('should dispose cleanly', () {
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
