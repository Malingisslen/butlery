import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/account_security_viewmodel.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('AccountSecurityViewModel', () {
    late AccountSecurityViewModel viewModel;
    late MockAuthService mockAuthService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // Bridge production ServiceLocator to test GetIt instance
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockAuthService = MockFactory.createAuthService(
        isAuthenticated: true,
        userId: 'test-user-123',
      );

      TestServiceLocator.registerMock<AuthService>(mockAuthService);

      viewModel = AccountSecurityViewModel();
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

      test('should expose current email from auth service', () {
        expect(viewModel.currentEmail, equals('test@example.com'));
      });
    });

    group('changePassword - validation', () {
      // Behavior: rejects password change when current password is empty
      test('should return false when current password is empty', () async {
        final result = await viewModel.changePassword(
          currentPassword: '',
          newPassword: 'newPass123',
          confirmPassword: 'newPass123',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: rejects password change when new password is empty
      test('should return false when new password is empty', () async {
        final result = await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: '',
          confirmPassword: 'newPass123',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: rejects password change when confirm password is empty
      test('should return false when confirm password is empty', () async {
        final result = await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'newPass123',
          confirmPassword: '',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: rejects passwords shorter than minimum length
      test('should return false when new password is too short', () async {
        final result = await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'short',
          confirmPassword: 'short',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: rejects when new and confirm passwords don't match
      test('should return false when passwords do not match', () async {
        final result = await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'newPassword123',
          confirmPassword: 'differentPassword123',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: validation failures should not call any auth service methods
      test('should not call auth service when validation fails', () async {
        await viewModel.changePassword(
          currentPassword: '',
          newPassword: 'newPass123',
          confirmPassword: 'newPass123',
        );

        verifyNever(() => mockAuthService.reauthenticateWithPassword(any()));
        verifyNever(() => mockAuthService.changePassword(any()));
      });
    });

    group('changePassword - successful operation', () {
      // Behavior: completes password change when all inputs valid and auth succeeds
      test('should return true when password change succeeds', () async {
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changePassword(any()))
            .thenAnswer((_) async => true);

        final result = await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123',
        );

        expect(result, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
      });

      // Behavior: calls reauthenticate then changePassword in sequence
      test('should reauthenticate before changing password', () async {
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changePassword(any()))
            .thenAnswer((_) async => true);

        await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123',
        );

        verify(() => mockAuthService.reauthenticateWithPassword('current123'))
            .called(1);
        verify(() => mockAuthService.changePassword('newPassword123'))
            .called(1);
      });
    });

    group('changePassword - auth failures', () {
      // Behavior: returns false with error when reauthentication fails
      test('should return false when reauthentication fails', () async {
        mockAuthService.setAuthState(
          isAuthenticated: true,
          currentUser: MockFactory.createMockUser(uid: 'test-user-123'),
          error: 'Wrong password',
        );
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => false);

        final result = await viewModel.changePassword(
          currentPassword: 'wrongPassword',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: does not attempt password change if reauthentication fails
      test('should not call changePassword when reauthentication fails',
          () async {
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => false);

        await viewModel.changePassword(
          currentPassword: 'wrongPassword',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123',
        );

        verifyNever(() => mockAuthService.changePassword(any()));
      });

      // Behavior: returns false with error when changePassword itself fails
      test('should return false when changePassword service call fails',
          () async {
        mockAuthService.setAuthState(
          isAuthenticated: true,
          currentUser: MockFactory.createMockUser(uid: 'test-user-123'),
          error: 'Password update failed',
        );
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changePassword(any()))
            .thenAnswer((_) async => false);

        final result = await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('changeEmail - validation', () {
      // Behavior: rejects email change when current password is empty
      test('should return false when current password is empty', () async {
        final result = await viewModel.changeEmail(
          currentPassword: '',
          newEmail: 'new@example.com',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: rejects email change when email format is invalid
      test('should return false when email is invalid', () async {
        final result = await viewModel.changeEmail(
          currentPassword: 'current123',
          newEmail: 'not-an-email',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: rejects email change when email is empty
      test('should return false when email is empty', () async {
        final result = await viewModel.changeEmail(
          currentPassword: 'current123',
          newEmail: '',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
      });

      // Behavior: validation failures should not call any auth service methods
      test('should not call auth service when validation fails', () async {
        await viewModel.changeEmail(
          currentPassword: '',
          newEmail: 'new@example.com',
        );

        verifyNever(() => mockAuthService.reauthenticateWithPassword(any()));
        verifyNever(() => mockAuthService.changeEmail(any()));
      });
    });

    group('changeEmail - successful operation', () {
      // Behavior: completes email change when inputs valid and auth succeeds
      test('should return true when email change succeeds', () async {
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changeEmail(any()))
            .thenAnswer((_) async => true);

        final result = await viewModel.changeEmail(
          currentPassword: 'current123',
          newEmail: 'new@example.com',
        );

        expect(result, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
      });

      // Behavior: calls reauthenticate then changeEmail in sequence
      test('should reauthenticate before changing email', () async {
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changeEmail(any()))
            .thenAnswer((_) async => true);

        await viewModel.changeEmail(
          currentPassword: 'current123',
          newEmail: 'new@example.com',
        );

        verify(() => mockAuthService.reauthenticateWithPassword('current123'))
            .called(1);
        verify(() => mockAuthService.changeEmail('new@example.com')).called(1);
      });
    });

    group('changeEmail - auth failures', () {
      // Behavior: returns false with error when reauthentication fails
      test('should return false when reauthentication fails', () async {
        mockAuthService.setAuthState(
          isAuthenticated: true,
          currentUser: MockFactory.createMockUser(uid: 'test-user-123'),
          error: 'Wrong password',
        );
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => false);

        final result = await viewModel.changeEmail(
          currentPassword: 'wrongPassword',
          newEmail: 'new@example.com',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: does not attempt email change if reauthentication fails
      test('should not call changeEmail when reauthentication fails', () async {
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => false);

        await viewModel.changeEmail(
          currentPassword: 'wrongPassword',
          newEmail: 'new@example.com',
        );

        verifyNever(() => mockAuthService.changeEmail(any()));
      });

      // Behavior: returns false with error when changeEmail itself fails
      test('should return false when changeEmail service call fails', () async {
        mockAuthService.setAuthState(
          isAuthenticated: true,
          currentUser: MockFactory.createMockUser(uid: 'test-user-123'),
          error: 'Email update failed',
        );
        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changeEmail(any()))
            .thenAnswer((_) async => false);

        final result = await viewModel.changeEmail(
          currentPassword: 'current123',
          newEmail: 'new@example.com',
        );

        expect(result, isFalse);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('Loading state management', () {
      // Behavior: sets loading during password change operation
      test('should set loading true during password change', () async {
        final loadingStates = <bool>[];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changePassword(any()))
            .thenAnswer((_) async => true);

        await viewModel.changePassword(
          currentPassword: 'current123',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123',
        );

        expect(loadingStates, contains(true),
            reason: 'Loading should be true during async operation');
        expect(viewModel.isLoading, isFalse,
            reason: 'Loading should be false after completion');
      });

      // Behavior: sets loading during email change operation
      test('should set loading true during email change', () async {
        final loadingStates = <bool>[];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        when(() => mockAuthService.reauthenticateWithPassword(any()))
            .thenAnswer((_) async => true);
        when(() => mockAuthService.changeEmail(any()))
            .thenAnswer((_) async => true);

        await viewModel.changeEmail(
          currentPassword: 'current123',
          newEmail: 'new@example.com',
        );

        expect(loadingStates, contains(true),
            reason: 'Loading should be true during async operation');
        expect(viewModel.isLoading, isFalse,
            reason: 'Loading should be false after completion');
      });
    });
  });
}
