import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

// BUT-2305: an unverified account was told to verify, with no way to get a new
// mail, and stayed blocked after opening the link until it signed out.
void main() {
  late FriendsViewModel viewModel;
  late MockUnifiedFriendsService friendsService;
  late MockFriendsManagementOperations management;
  late FakeAuthRepository authRepository;
  late MockAuthService auth;

  void signIn({required bool verified}) {
    final user = FakeUser(uid: 'me', emailVerified: verified);
    authRepository.setAuthState(user: user, isAuthenticated: true);
    auth.setAuthState(currentUser: user);
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    friendsService = MockFactory.createUnifiedFriendsService();
    management = MockFriendsManagementOperations();
    friendsService.setFriendsState(
      isInitialized: true,
      management: management,
    );
    management.setManagementState(friends: []);
    final userService = MockUserService()..setUserState(currentUser: null);
    TestServiceLocator.registerMock<UnifiedFriendsService>(friendsService);
    TestServiceLocator.registerMock<UserService>(userService);
    final permissions = FakePermissionService()
      ..setPermissionState(currentUserId: 'me', isAuthenticated: true);

    authRepository = FakeAuthRepository();
    auth = MockAuthService();
    when(() => auth.reloadUser()).thenAnswer((_) async {});
    when(() => auth.refreshSession()).thenAnswer((_) async => true);

    viewModel = FriendsViewModel(
      friendsService: friendsService,
      userService: userService,
      analyticsService: MockAnalyticsService(),
      permissionService: permissions,
      // No profile, so only a verified address passes the gate.
      maturityHelper: AccountMaturityHelper(),
      authRepository: authRepository,
      authService: auth,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  test(
    'a send that stays blocked after a reload is flagged, not sent',
    () async {
      signIn(verified: false);

      expect(await viewModel.sendFriendRequest('friend'), isFalse);

      verify(() => auth.reloadUser()).called(1);
      expect(viewModel.blockedByUnverifiedEmail, isTrue);
      expect(management.sendCalls, isEmpty);
      // The block is said once, by the caller's snackbar, not also as a banner.
      expect(viewModel.hasError, isFalse);
    },
  );

  test('a send after the link was opened reloads, refreshes the token and '
      'goes out', () async {
    signIn(verified: false);
    when(
      () => auth.reloadUser(),
    ).thenAnswer((_) async => signIn(verified: true));

    expect(await viewModel.sendFriendRequest('friend'), isTrue);

    verify(() => auth.refreshSession()).called(1);
    expect(viewModel.blockedByUnverifiedEmail, isFalse);
    expect(management.sendCalls, ['friend']);
  });

  test('a send that goes out after a blocked one clears the flag, so a later '
      'failure is not taken for the block', () async {
    signIn(verified: false);
    await viewModel.sendFriendRequest('friend');
    expect(viewModel.blockedByUnverifiedEmail, isTrue);

    signIn(verified: true);
    expect(await viewModel.sendFriendRequest('friend'), isTrue);
    expect(viewModel.blockedByUnverifiedEmail, isFalse);
  });

  test('Stäng clears an error the view model set itself', () {
    // ignore: invalid_use_of_protected_member
    viewModel.setError('Något gick fel');
    expect(viewModel.hasError, isTrue);

    viewModel.clearError();

    expect(viewModel.hasError, isFalse);
    expect(viewModel.error, isNull);
  });

  test('resending the mail reports whether it went', () async {
    when(() => auth.sendEmailVerification()).thenAnswer((_) async {});
    expect(await viewModel.resendVerificationEmail(), isTrue);

    when(() => auth.sendEmailVerification()).thenThrow(Exception('quota'));
    expect(await viewModel.resendVerificationEmail(), isFalse);
  });
}
