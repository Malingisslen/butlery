// test/unit/viewmodels/friends_viewmodel_batch_test.dart
//
// The bulk friend-request paths. Until this suite existed the three batch
// methods in `FriendRequestActions` were stubs that delayed a second and
// reported success without writing anything, and nothing could tell the
// difference — the count they returned was invented.
//
// So these tests assert the ids the service was actually called with, not
// only the returned count: a batch that runs the wrong verb, or silently
// skips an id, returns the same number as one that does it right.

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendsViewModel batch request operations', () {
    late FriendsViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUserService mockUserService;
    late MockFriendsManagementOperations mockManagement;
    late FakePermissionService mockPermissionService;
    late MockAnalyticsService mockAnalyticsService;

    const currentUserId = 'test-user-123';
    final requestIds = ['req-1', 'req-2', 'req-3'];

    FriendRequest incoming(String id) => FriendRequest(
      id: id,
      fromUserId: 'sender-$id',
      toUserId: currentUserId,
      status: FriendRequestStatus.pending,
      sentAt: DateTime(2026, 9, 1),
    );

    FriendRequest outgoing(String id) => FriendRequest(
      id: id,
      fromUserId: currentUserId,
      toUserId: 'recipient-$id',
      status: FriendRequestStatus.pending,
      sentAt: DateTime(2026, 9, 1),
    );

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockFriendsService = MockFactory.createUnifiedFriendsService();
      mockUserService = MockUserService();
      mockManagement = MockFriendsManagementOperations();
      mockPermissionService = FakePermissionService();
      mockAnalyticsService = MockAnalyticsService();

      mockPermissionService.setPermissionState(
        currentUserId: currentUserId,
        isAuthenticated: true,
      );

      TestServiceLocator.registerMock<UnifiedFriendsService>(
        mockFriendsService,
      );
      TestServiceLocator.registerMock<UserService>(mockUserService);

      mockFriendsService.setFriendsState(
        friends: [],
        incomingRequests: requestIds.map(incoming).toList(),
        outgoingRequests: requestIds.map(outgoing).toList(),
        categoriesList: [],
        isLoading: false,
        error: null,
        isInitialized: true,
        management: mockManagement,
      );

      mockManagement.setManagementState(
        friends: [],
        incomingRequests: requestIds.map(incoming).toList(),
        outgoingRequests: requestIds.map(outgoing).toList(),
        shouldSucceed: true,
        failingRequestIds: {},
      );

      mockUserService.setUserState(
        currentUser: null,
        users: {},
        isLoading: false,
        error: null,
      );

      viewModel = FriendsViewModel(
        authRepository: FakeAuthRepository(),
        maturityHelper: FakeMaturedAccountHelper(),
        friendsService: mockFriendsService,
        userService: mockUserService,
        analyticsService: mockAnalyticsService,
        permissionService: mockPermissionService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('accepting all three writes all three', () async {
      final landed = await viewModel.acceptFriendRequests(requestIds);

      expect(landed, requestIds);
      expect(mockManagement.acceptCalls, requestIds);
      expect(mockManagement.rejectCalls, isEmpty);
      expect(mockManagement.cancelCalls, isEmpty);
    });

    test('rejecting all three writes all three', () async {
      final landed = await viewModel.rejectFriendRequests(requestIds);

      expect(landed, requestIds);
      expect(mockManagement.rejectCalls, requestIds);
      expect(mockManagement.acceptCalls, isEmpty);
    });

    test('cancelling all three writes all three', () async {
      final landed = await viewModel.cancelSentRequests(requestIds);

      expect(landed, requestIds);
      expect(mockManagement.cancelCalls, requestIds);
      expect(mockManagement.acceptCalls, isEmpty);
    });

    test('one failure does not strand the rest', () async {
      mockManagement.setManagementState(failingRequestIds: {'req-2'});

      final landed = await viewModel.acceptFriendRequests(requestIds);

      // WHICH ids landed, not just how many: the view reconciles its
      // selection from this list, so a result that merely counted would not
      // carry enough.
      expect(landed, ['req-1', 'req-3']);
      expect(mockManagement.acceptCalls, requestIds);
    });

    test('a batch where nothing lands returns an empty list', () async {
      mockManagement.setManagementState(shouldSucceed: false);

      final landed = await viewModel.rejectFriendRequests(requestIds);

      expect(landed, isEmpty);
      expect(mockManagement.rejectCalls, requestIds);
    });

    test('an empty selection never reaches the service', () async {
      final landed = await viewModel.acceptFriendRequests(const []);

      expect(landed, isEmpty);
      expect(mockManagement.acceptCalls, isEmpty);
    });

    test('an id that throws does not strand the ids after it', () async {
      mockManagement.setManagementState(throwingRequestIds: {'req-1'});

      final landed = await viewModel.acceptFriendRequests(requestIds);

      // Without the catch the whole batch dies on the first id and the two
      // behind it are never attempted.
      expect(landed, ['req-2', 'req-3']);
      expect(mockManagement.acceptCalls, requestIds);
    });
  });
}
