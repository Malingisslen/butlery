import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/group_invitations_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

final _now = DateTime(2026, 4, 14);

UserProfile _user(String uid, String name) => UserProfile(
    uid: uid,
    displayName: name,
    email: '$uid@test.com',
    joinedAt: _now,
    lastActiveAt: _now);

FriendCategory _group(String id, String name, String owner,
        {List<String> members = const []}) =>
    FriendCategory(
        id: id,
        name: name,
        ownerId: owner,
        friendUserIds: members,
        createdAt: _now,
        updatedAt: _now);

GroupInvitation _invitation(String id,
        {GroupInvitationStatus status = GroupInvitationStatus.pending}) =>
    GroupInvitation(
        id: id,
        groupId: 'group_$id',
        groupName: 'Grupp $id',
        groupEmoji: 'x',
        fromUserId: 'sender_$id',
        fromUserName: 'Sender $id',
        toUserId: 'test-user-123',
        status: status,
        sentAt: _now,
        expiresAt: _now.add(const Duration(days: 7)));

void main() {
  group('GroupInvitationsViewModel', () {
    late GroupInvitationsViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsCategoriesOperations mockCategoriesOps;
    late MockFriendsInvitationsOperations mockInvitationsOps;
    late MockFriendsManagementOperations mockManagementOps;

    final friend1 = _user('friend_1', 'Erik Svensson');
    final friend2 = _user('friend_2', 'Maria Oberg');

    final availableGroup1 = _group('avail_1', 'Matlagning', 'other',
        members: ['friend_1', 'friend_2']);
    final availableGroup2 = _group('avail_2', 'Familjen', 'admin');
    final ownedGroup =
        _group('owned', 'Min Grupp', 'test-user-123', members: ['friend_1']);
    final memberGroup = _group('member', 'Redan Medlem', 'other',
        members: ['test-user-123', 'friend_1']);

    final pending1 = _invitation('inv_1');
    final pending2 = _invitation('inv_2');
    final accepted =
        _invitation('inv_3', status: GroupInvitationStatus.accepted);

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      final perm =
          ServiceLocator.get<PermissionService>() as FakePermissionService;
      perm.setPermissionState(
          currentUserId: 'test-user-123', isAuthenticated: true);

      mockFriendsService = MockUnifiedFriendsService();
      mockCategoriesOps = MockFriendsCategoriesOperations();
      mockInvitationsOps = MockFriendsInvitationsOperations();
      mockManagementOps = MockFriendsManagementOperations();

      mockFriendsService.setFriendsState(
        error: null,
        management: mockManagementOps,
        categories: mockCategoriesOps,
        invitations: mockInvitationsOps,
      );

      when(() => mockCategoriesOps.getAllCategories()).thenReturn(
          [availableGroup1, availableGroup2, ownedGroup, memberGroup]);
      when(() => mockInvitationsOps.pendingReceivedInvitations)
          .thenReturn([pending1, pending2, accepted]);
      when(() => mockManagementOps.getAllFriends())
          .thenReturn([friend1, friend2]);
      when(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockInvitationsOps.acceptGroupInvitation(any()))
          .thenAnswer((_) async => true);
      when(() => mockInvitationsOps.cancelInvitation(any()))
          .thenAnswer((_) async => true);

      viewModel = GroupInvitationsViewModel(friendsService: mockFriendsService);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('filters available groups excluding owned and member groups', () {
        expect(viewModel.availableGroups.length, equals(2));
        expect(viewModel.availableGroups.any((g) => g.name == 'Matlagning'),
            isTrue);
        expect(
            viewModel.availableGroups.any((g) => g.name == 'Familjen'), isTrue);
        expect(viewModel.availableGroups.any((g) => g.name == 'Min Grupp'),
            isFalse);
        expect(viewModel.availableGroups.any((g) => g.name == 'Redan Medlem'),
            isFalse);
      });

      test('loads pending and all received invitations', () {
        expect(viewModel.receivedInvitations.length, equals(2));
        expect(viewModel.allReceivedInvitations.length, equals(3));
        expect(viewModel.pendingInvitationsCount, equals(2));
      });

      test('loads members for available groups', () {
        final members = viewModel.getMembersForGroup('avail_1');
        expect(members.length, equals(2));
        expect(members.any((m) => m.displayName == 'Erik Svensson'), isTrue);
      });

      test('hasContent is true when groups or invitations exist', () {
        expect(viewModel.hasContent, isTrue);
      });
    });

    group('Available Groups', () {
      test('returns immutable list', () {
        final groups = viewModel.availableGroups;
        expect(() => (groups as List).add(availableGroup1),
            throwsUnsupportedError);
      });

      test('returns empty list for unknown group members', () {
        expect(viewModel.getMembersForGroup('non_existent'), isEmpty);
      });

      test('handles empty available groups while keeping invitations',
          () async {
        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([ownedGroup, memberGroup]);

        await viewModel.refresh();

        expect(viewModel.availableGroups, isEmpty);
        expect(viewModel.hasContent, isTrue);
      });
    });

    group('Received Invitations', () {
      test('isRespondingToInvitation starts false', () {
        expect(viewModel.isRespondingToInvitation('inv_1'), isFalse);
      });

      test('handles empty invitations after refresh', () async {
        when(() => mockInvitationsOps.pendingReceivedInvitations)
            .thenReturn([]);
        await viewModel.refresh();

        expect(viewModel.receivedInvitations, isEmpty);
        expect(viewModel.pendingInvitationsCount, equals(0));
      });
    });

    group('Join Group', () {
      test('joins successfully and removes from available', () async {
        await viewModel.joinGroup('avail_1');

        expect(
            viewModel.availableGroups.any((g) => g.id == 'avail_1'), isFalse);
        expect(viewModel.error, isNull);
        verify(() => mockCategoriesOps.assignFriendToCategory(
            'test-user-123', 'avail_1')).called(1);
      });

      test('tracks joining state during operation', () async {
        bool wasJoining = false;
        viewModel.addListener(() {
          if (viewModel.isJoiningGroup('avail_1')) wasJoining = true;
        });

        await viewModel.joinGroup('avail_1');

        expect(wasJoining, isTrue);
        expect(viewModel.isJoiningGroup('avail_1'), isFalse);
      });

      test('handles failure keeping group available', () async {
        when(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
            .thenAnswer((_) async => false);
        mockFriendsService.setFriendsState(
          error: 'Network error',
          management: mockManagementOps,
          categories: mockCategoriesOps,
          invitations: mockInvitationsOps,
        );

        await viewModel.joinGroup('avail_1');

        expect(viewModel.error, isNotNull);
        expect(viewModel.availableGroups.any((g) => g.id == 'avail_1'), isTrue);
      });

      test('prevents duplicate join attempts', () async {
        final f1 = viewModel.joinGroup('avail_1');
        await viewModel.joinGroup('avail_1');
        await f1;

        verify(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
            .called(1);
      });

      test('handles non-existent group', () async {
        await viewModel.joinGroup('non_existent');
        expect(viewModel.error, isNotNull);
      });
    });

    group('Accept Invitation', () {
      test('accepts successfully and updates invitations', () async {
        when(() => mockInvitationsOps.pendingReceivedInvitations)
            .thenReturn([pending2, accepted]);

        await viewModel.acceptInvitation('inv_1');

        expect(viewModel.error, isNull);
        expect(viewModel.receivedInvitations.length, equals(1));
        verify(() => mockInvitationsOps.acceptGroupInvitation('inv_1'))
            .called(1);
      });

      test('tracks responding state during operation', () async {
        bool wasResponding = false;
        viewModel.addListener(() {
          if (viewModel.isRespondingToInvitation('inv_1')) {
            wasResponding = true;
          }
        });

        await viewModel.acceptInvitation('inv_1');

        expect(wasResponding, isTrue);
        expect(viewModel.isRespondingToInvitation('inv_1'), isFalse);
      });

      test('handles accept failure', () async {
        when(() => mockInvitationsOps.acceptGroupInvitation(any()))
            .thenAnswer((_) async => false);
        mockFriendsService.setFriendsState(
          error: 'Permission denied',
          management: mockManagementOps,
          categories: mockCategoriesOps,
          invitations: mockInvitationsOps,
        );

        await viewModel.acceptInvitation('inv_1');

        expect(viewModel.error, isNotNull);
        expect(viewModel.receivedInvitations.length, equals(2));
      });

      test('prevents duplicate accept attempts', () async {
        final f1 = viewModel.acceptInvitation('inv_1');
        await viewModel.acceptInvitation('inv_1');
        await f1;

        verify(() => mockInvitationsOps.acceptGroupInvitation(any())).called(1);
      });
    });

    group('Reject Invitation', () {
      test('rejects successfully', () async {
        when(() => mockInvitationsOps.pendingReceivedInvitations)
            .thenReturn([pending2, accepted]);

        await viewModel.rejectInvitation('inv_1');

        expect(viewModel.error, isNull);
        expect(viewModel.receivedInvitations.length, equals(1));
        verify(() => mockInvitationsOps.cancelInvitation('inv_1')).called(1);
      });

      test('handles reject failure', () async {
        when(() => mockInvitationsOps.cancelInvitation(any()))
            .thenAnswer((_) async => false);
        mockFriendsService.setFriendsState(
          error: 'Cannot reject',
          management: mockManagementOps,
          categories: mockCategoriesOps,
          invitations: mockInvitationsOps,
        );

        await viewModel.rejectInvitation('inv_1');

        expect(viewModel.error, isNotNull);
        expect(viewModel.receivedInvitations.length, equals(2));
      });

      test('prevents duplicate reject attempts', () async {
        final f1 = viewModel.rejectInvitation('inv_1');
        await viewModel.rejectInvitation('inv_1');
        await f1;

        verify(() => mockInvitationsOps.cancelInvitation(any())).called(1);
      });
    });

    group('Refresh', () {
      test('refreshes all data', () async {
        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([availableGroup1]);
        when(() => mockInvitationsOps.pendingReceivedInvitations)
            .thenReturn([pending1]);

        await viewModel.refresh();

        expect(viewModel.availableGroups.length, equals(1));
        expect(viewModel.receivedInvitations.length, equals(1));
      });

      test('handles refresh errors', () async {
        when(() => mockCategoriesOps.getAllCategories())
            .thenThrow(Exception('Network error'));

        await viewModel.refresh();
        expect(viewModel.error, isNotNull);
      });
    });

    group('Error Handling', () {
      test('clearError clears error state', () async {
        await viewModel.joinGroup('non_existent');
        expect(viewModel.hasError, isTrue);

        viewModel.clearError();
        expect(viewModel.hasError, isFalse);
        expect(viewModel.error, isNull);
      });
    });

    group('Edge Cases', () {
      test('handles null current user ID', () async {
        final perm =
            ServiceLocator.get<PermissionService>() as FakePermissionService;
        perm.setPermissionState(currentUserId: null);

        await viewModel.joinGroup('avail_1');
        expect(viewModel.error, isNotNull);
      });

      test('handles empty friend list for member loading', () async {
        when(() => mockManagementOps.getAllFriends()).thenReturn([]);
        await viewModel.refresh();

        expect(viewModel.getMembersForGroup('avail_1'), isEmpty);
      });

      test('handles exception during group join', () async {
        when(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
            .thenThrow(Exception('Database error'));

        await viewModel.joinGroup('avail_1');
        expect(viewModel.error, isNotNull);
      });

      test('handles exception during invitation accept', () async {
        when(() => mockInvitationsOps.acceptGroupInvitation(any()))
            .thenThrow(Exception('Server error'));

        await viewModel.acceptInvitation('inv_1');
        expect(viewModel.error, isNotNull);
      });
    });

    group('Lifecycle', () {
      test('disposes without errors', () async {
        final vm =
            GroupInvitationsViewModel(friendsService: mockFriendsService);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(() => vm.dispose(), returnsNormally);
      });

      test('clearError after dispose is a no-op', () async {
        final vm =
            GroupInvitationsViewModel(friendsService: mockFriendsService);
        await Future.delayed(const Duration(milliseconds: 50));
        vm.dispose();
        expect(() => vm.clearError(), returnsNormally);
      });
    });
  });
}
