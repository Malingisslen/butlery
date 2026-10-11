/// Hosts for the friends, groups and sharing views the register had not
/// compared.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/social/activity_feed_viewmodel.dart';
import 'package:butlery/views/social/create_shared_shopping_list_view.dart';
import 'package:butlery/views/social/friend_requests/friend_requests_view.dart';
import 'package:butlery/views/social/friends_list_view.dart';

import '../../../helpers/user_profile_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../state_harness.dart';
import '../state_host.dart';

class _MockFlags extends Mock implements FeatureFlagService {}

final _anna = testUserProfile(uid: 'u-anna', displayName: 'Anna Lindqvist');
final _per = testUserProfile(uid: 'u-per', displayName: 'Per Nilsson');
final _cecilia = testUserProfile(uid: 'u-cecilia', displayName: 'Cecilia Berg');

/// The friends service every social host starts from, with [friends].
MockUnifiedFriendsService _friendsService({
  List<UserProfile> friends = const [],
  List<FriendRequest> incoming = const [],
  List<FriendRequest> outgoing = const [],
}) {
  Provider.debugCheckInvalidValueType = null;
  final service =
      TestServiceLocator.get<UnifiedFriendsService>()
          as MockUnifiedFriendsService;
  final invitations = MockFriendsInvitationsOperations();
  when(
    () => invitations.pendingReceivedInvitations,
  ).thenReturn(<GroupInvitation>[]);
  service.setFriendsState(
    friends: friends,
    incomingRequests: incoming,
    outgoingRequests: outgoing,
    categoriesList: const [],
    invitations: invitations,
    isInitialized: true,
  );
  when(() => service.refresh()).thenAnswer((_) async {});
  return service;
}

MockFriendsViewModel _friendsModel(List<UserProfile> friends) {
  final vm = MockFriendsViewModel()
    ..setFriendsState(friends: friends, isLoading: false);
  when(() => vm.searchQuery).thenReturn('');
  when(() => vm.searchResults).thenReturn(<UserProfile>[]);
  when(() => vm.incomingRequests).thenReturn(<FriendRequest>[]);
  when(() => vm.sentRequests).thenReturn(<FriendRequest>[]);
  when(() => vm.friendsCount).thenReturn(friends.length);
  when(() => vm.isSearching).thenReturn(false);
  when(() => vm.searchDegraded).thenReturn(false);
  when(() => vm.updateSearch(any())).thenAnswer((_) async {});
  TestServiceLocator.registerMock<FriendsViewModel>(vm);
  return vm;
}

FriendRequest _request(String id, String from) => FriendRequest(
  id: id,
  fromUserId: from,
  toUserId: 'test-user-123',
  sentAt: DateTime(2026, 9, 25),
  message: 'Hej! Vi lagar ju ihop på söndagar.',
);

final reviewSocialHosts = <String, StateHost>{
  'FriendsListView': StateHost(
    build: (ctx) async {
      _friendsService(friends: [_anna, _per, _cecilia]);
      final vm = _friendsModel([_anna, _per, _cecilia]);
      ctx.disposers.add(vm.dispose);
      final feed = MockActivityFeedViewModel()..setFeedState(events: const []);
      when(() => feed.isLoading).thenReturn(false);
      when(() => feed.error).thenReturn(null);
      TestServiceLocator.registerMock<ActivityFeedViewModel>(feed);
      final flags = _MockFlags();
      when(() => flags.isEnabled(any())).thenReturn(true);
      TestServiceLocator.registerMock<FeatureFlagService>(flags);
      final offline = MockOfflineService();
      when(() => offline.isOnline).thenReturn(true);
      when(() => offline.addListener(any())).thenReturn(null);
      when(() => offline.removeListener(any())).thenReturn(null);
      TestServiceLocator.registerMock<OfflineService>(offline);
      return const FriendsListView();
    },
    reach: (tester, ctx) async {
      await tester.tap(find.text(sv.socialFriends).first);
      await tester.pump(const Duration(milliseconds: 500));
    },
  ),
  'FriendRequestsView': StateHost(
    build: (ctx) async {
      final incoming = [
        _request('req-1', 'u-anna'),
        _request('req-2', 'u-per'),
      ];
      final management = MockFriendsManagementOperations()
        ..setManagementState(
          friends: [],
          incomingRequests: incoming,
          outgoingRequests: [
            FriendRequest(
              id: 'sent-1',
              fromUserId: 'test-user-123',
              toUserId: 'u-cecilia',
              sentAt: DateTime(2026, 9, 24),
            ),
          ],
        );
      final service = MockFactory.createUnifiedFriendsService();
      service.setFriendsState(
        incomingRequests: incoming,
        outgoingRequests: [
          FriendRequest(
            id: 'sent-1',
            fromUserId: 'test-user-123',
            toUserId: 'u-cecilia',
            sentAt: DateTime(2026, 9, 24),
          ),
        ],
        categoriesList: [],
        isInitialized: true,
        management: management,
      );
      Provider.debugCheckInvalidValueType = null;
      TestServiceLocator.registerMock<UnifiedFriendsService>(service);
      final users = MockUserService()
        ..setUserState(
          users: {
            'u-anna': _anna,
            'u-per': _per,
            'u-cecilia': _cecilia,
          },
        );
      TestServiceLocator.registerMock<UserService>(users);
      TestServiceLocator.registerMock<FriendsViewModel>(
        FriendsViewModel(
          authRepository: FakeAuthRepository(),
          maturityHelper: FakeMaturedAccountHelper(),
          friendsService: service,
          userService: users,
          analyticsService: MockAnalyticsService(),
          permissionService: FakePermissionService()
            ..setPermissionState(
              currentUserId: 'test-user-123',
              isAuthenticated: true,
            ),
        ),
      );
      return const FriendRequestsView();
    },
  ),
  'CreateSharedShoppingListView': StateHost(
    build: (ctx) async {
      _friendsService(friends: [_anna, _per]);
      final vm = _friendsModel([_anna, _per]);
      ctx.disposers.add(vm.dispose);
      TestServiceLocator.get<UnifiedShoppingService>();
      return const CreateSharedShoppingListView();
    },
  ),
};
