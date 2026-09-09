import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/account/retained_record.dart';
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
        when(
          () => mockAuthService.currentUserEmail,
        ).thenReturn('test@example.com');
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
        when(
          () => mockAuthService.currentUserDisplayName,
        ).thenReturn('Auth User');
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

        expect(
          loadingStates,
          contains(true),
          reason: 'Loading should be true during logout',
        );
        expect(
          viewModel.isLoading,
          isFalse,
          reason: 'Loading should be false after logout',
        );
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
      // Behavior: reports success, and keeps nothing
      test(
        'reports success, and keeps nothing, on an ordinary deletion',
        () async {
          when(
            () => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            ),
          ).thenAnswer((_) async => {'success': true});

          final result = await viewModel.deleteAccount(
            reason: 'No longer needed',
          );

          expect(result.success, isTrue);
          // BUT-2046 follow-up: an ordinary deletion keeps nothing, so the
          // Art. 12(4) notice is not shown. The common path must stay exactly
          // as it was.
          expect(result.retained, isEmpty);
          expect(result.hasRetainedRecords, isFalse);
          // The fixture omits `failedCollections` entirely, which makes this
          // the witness for the `?? const []` fail-open direction: flipping
          // that default closed would redden here.
          expect(result.accountDeleted, isTrue);
          expect(viewModel.isLoading, isFalse);
        },
      );

      // Behavior: passes reason and audit log flag to deletion service
      test('should pass reason to deletion service', () async {
        when(
          () => mockAccountDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer((_) async => {'success': true});

        await viewModel.deleteAccount(reason: 'Privacy concerns');

        verify(
          () => mockAccountDeletionService.deleteUserAccount(
            reason: 'Privacy concerns',
            createAuditLog: true,
          ),
        ).called(1);
      });

      // Behavior: carries a legal hold OUT of the service and into the outcome
      test('carries a retained record through to the outcome', () async {
        // Every other stub in this file omits `retained`, so the extraction in
        // `deleteAccount` was only ever exercised on its NULL branch —
        // replacing the read with a constant empty list passed all of them.
        // This is the wiring, not the parse: `RetainedRecord.listFrom` is
        // pinned separately as a pure function.
        final holdUntil = DateTime.utc(2027, 3, 8);
        when(
          () => mockAccountDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer(
          (_) async => {
            'success': true,
            'retained': [
              RetainedRecord(
                resourceType: 'user_moderation',
                legalBasis: 'GDPR Art. 17(3)(e)',
                holdUntil: holdUntil,
                provisional: true,
              ),
            ],
          },
        );

        final result = await viewModel.deleteAccount(reason: 'Testing');

        expect(result.success, isTrue);
        expect(result.hasRetainedRecords, isTrue);
        expect(result.retained, hasLength(1));
        // The DATE specifically: the dialog renders it, so losing it here
        // would show the notice without the one fact that bounds the hold.
        expect(result.retained.first.holdUntil, holdUntil);
        expect(result.retained.first.legalBasis, 'GDPR Art. 17(3)(e)');
        // The flag the Art. 12(4) notice hedges on (BUT-2047). Seeded TRUE on
        // purpose: the constructor defaults it to false, so a fixture that left
        // it out would assert the default rather than the pass-through.
        expect(result.retained.first.provisional, isTrue);
      });

      // Behavior: tells a failed AUTH delete apart from any other failed step
      test('accountDeleted is false only when auth deletion failed', () async {
        // The Art. 12(4) notice opens with "Ditt konto är raderat", so it hangs
        // on THIS and not on `success`. Every other failed step still leaves
        // the account genuinely gone, which is the distinction being pinned.
        when(
          () => mockAccountDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'failedCollections': ['auth_deletion'],
          },
        );
        final authFailed = await viewModel.deleteAccount(reason: 'x');
        expect(authFailed.accountDeleted, isFalse);

        when(
          () => mockAccountDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'failedCollections': ['erasure_hold_evaluated'],
          },
        );
        final otherStepFailed = await viewModel.deleteAccount(reason: 'x');
        expect(
          otherStepFailed.accountDeleted,
          isTrue,
          reason: 'a failed hold evaluation does not keep the account alive',
        );
      });

      // Behavior: reports the failure, and keeps nothing either way
      test(
        'reports failure when the deletion result is not successful',
        () async {
          when(
            () => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            ),
          ).thenAnswer(
            (_) async => {
              'success': false,
              'errors': ['profile: deletion failed'],
            },
          );

          final result = await viewModel.deleteAccount(reason: 'Testing');

          expect(result.success, isFalse);
          // A FAILED deletion keeps nothing either — `retained` records a
          // lawful hold, never an error. Pinned so the two can never be read
          // as the same signal.
          expect(result.retained, isEmpty);
        },
      );

      // Behavior: the exception escapes; no outcome is produced
      test(
        'throws rather than returning an outcome when no user is logged in',
        () async {
          mockAuthService.setAuthState(isAuthenticated: false);
          final noUserVM = ProfileViewModel(
            authService: mockAuthService,
            userService: mockUserService,
            accountDeletionService: mockAccountDeletionService,
          );

          AccountDeletionOutcome? result;
          try {
            result = await noUserVM.deleteAccount(reason: 'Test');
          } catch (_) {
            // executeAsync rethrows the 'No user logged in' exception
          }

          expect(result, isNull);
          noUserVM.dispose();
        },
      );

      // Behavior: the exception escapes; no outcome is produced
      test(
        'throws rather than returning an outcome when the service throws',
        () async {
          when(
            () => mockAccountDeletionService.deleteUserAccount(
              reason: any(named: 'reason'),
              createAuditLog: any(named: 'createAuditLog'),
            ),
          ).thenThrow(Exception('Network error'));

          AccountDeletionOutcome? result;
          try {
            result = await viewModel.deleteAccount(reason: 'Test');
          } catch (_) {
            // executeAsync rethrows
          }

          // Null because the throw escaped before any outcome was built. Written
          // as a null check rather than a `success` check on a default outcome:
          // a default would let a future refactor return "not held, not
          // successful" here and read the same.
          expect(result, isNull);
        },
      );

      // Behavior: manages loading state during deletion
      test('should set loading during account deletion', () async {
        final loadingStates = <bool>[];
        viewModel.addListener(() {
          loadingStates.add(viewModel.isLoading);
        });

        when(
          () => mockAccountDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer((_) async => {'success': true});

        await viewModel.deleteAccount(reason: 'Test');

        expect(
          loadingStates,
          contains(true),
          reason: 'Loading should be true during deletion',
        );
        expect(
          viewModel.isLoading,
          isFalse,
          reason: 'Loading should be false after deletion',
        );
      });
    });

    group('updateProfile', () {
      // Behavior: calls createOrUpdateProfile on user service with correct args
      test('should call user service with profile data', () async {
        when(
          () => mockUserService.createOrUpdateProfile(
            displayName: any(named: 'displayName'),
            isSearchable: any(named: 'isSearchable'),
            allowEmailSearch: any(named: 'allowEmailSearch'),
          ),
        ).thenAnswer((_) async => null);

        await viewModel.updateProfile(
          displayName: 'New Name',
          isSearchable: true,
          allowEmailSearch: false,
        );

        verify(
          () => mockUserService.createOrUpdateProfile(
            displayName: 'New Name',
            isSearchable: true,
            allowEmailSearch: false,
          ),
        ).called(1);
      });

      // Behavior: completes without error on success
      test('should not have error after successful update', () async {
        when(
          () => mockUserService.createOrUpdateProfile(
            displayName: any(named: 'displayName'),
            isSearchable: any(named: 'isSearchable'),
            allowEmailSearch: any(named: 'allowEmailSearch'),
          ),
        ).thenAnswer((_) async => null);

        await viewModel.updateProfile(
          displayName: 'Updated Name',
        );

        expect(viewModel.hasError, isFalse);
        expect(viewModel.isLoading, isFalse);
      });

      // Behavior: sets error when user service throws
      test('should set error when update fails', () async {
        when(
          () => mockUserService.createOrUpdateProfile(
            displayName: any(named: 'displayName'),
            isSearchable: any(named: 'isSearchable'),
            allowEmailSearch: any(named: 'allowEmailSearch'),
          ),
        ).thenThrow(Exception('Update failed'));

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

        when(
          () => mockUserService.createOrUpdateProfile(
            displayName: any(named: 'displayName'),
            isSearchable: any(named: 'isSearchable'),
            allowEmailSearch: any(named: 'allowEmailSearch'),
          ),
        ).thenAnswer((_) async => null);

        await viewModel.updateProfile(displayName: 'Name');

        expect(
          loadingStates,
          contains(true),
          reason: 'Loading should be true during update',
        );
        expect(
          viewModel.isLoading,
          isFalse,
          reason: 'Loading should be false after update',
        );
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
