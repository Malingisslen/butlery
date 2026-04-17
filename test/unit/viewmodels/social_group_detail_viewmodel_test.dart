import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class MockFriendCategoryRepository extends Mock
    implements FriendCategoryRepository {}

void main() {
  group('SocialGroupDetailViewModel', () {
    late SocialGroupDetailViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUserService mockUserService;
    late FakePermissionService mockPermissionService;
    late MockFriendsCategoriesOperations mockCategoriesOps;
    late MockFriendCategoryRepository mockCategoryRepo;

    const testGroupId = 'test_group_123';
    const testUserId = 'test_user_123';
    const otherUserId = 'other_user_456';
    final now = DateTime(2026, 4, 14);

    final testGroup = FriendCategory(
      id: testGroupId,
      name: 'Test Social Group',
      description: 'A test group',
      emoji: 'party',
      ownerId: testUserId,
      friendUserIds: [testUserId, otherUserId],
      createdAt: now,
      updatedAt: now,
    );

    final currentUser = UserProfile(
      uid: testUserId,
      displayName: 'Test Owner',
      email: 'owner@example.com',
      joinedAt: now,
      lastActiveAt: now,
    );

    final otherMember = UserProfile(
      uid: otherUserId,
      displayName: 'Other Member',
      email: 'member@example.com',
      joinedAt: now,
      lastActiveAt: now,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(
        FriendCategory(
          id: 'fb',
          ownerId: 'fb',
          name: 'fb',
          createdAt: now,
          updatedAt: now,
        ),
      );
      registerFallbackValue(currentUser);
    });

    setUp(() {
      mockFriendsService = MockUnifiedFriendsService();
      mockUserService = MockUserService();
      mockPermissionService = FakePermissionService();
      mockCategoriesOps = MockFriendsCategoriesOperations();
      mockCategoryRepo = MockFriendCategoryRepository();

      // Wire categories ops through setFriendsState (concrete override)
      mockFriendsService.setFriendsState(
        categories: mockCategoriesOps,
      );

      // Stubs on mock (not concrete overrides -- safe to use when())
      when(() => mockFriendsService.refresh()).thenAnswer((_) async {});
      when(() => mockFriendsService.getCategoryById(testGroupId))
          .thenReturn(testGroup);
      when(() => mockFriendsService.sentInvitations).thenReturn([]);
      when(() => mockFriendsService.friendsCategoryRepositoryInternal)
          .thenReturn(mockCategoryRepo);

      // MockUserService.getUserProfiles is a concrete override using _users map
      mockUserService.setUserState(
        users: {
          testUserId: currentUser,
          otherUserId: otherMember,
        },
      );

      // FakePermissionService uses setPermissionState
      mockPermissionService.setPermissionState(
        currentUserId: testUserId,
        isAuthenticated: true,
      );

      // isGroupAdmin is not a concrete override -- stub it
      when(() => mockPermissionService.isGroupAdmin(any())).thenReturn(true);

      when(() => mockCategoriesOps.removeFriendFromCategory(any(), any()))
          .thenAnswer((_) async => true);

      when(() => mockCategoryRepo.transferOwnership(any(), any(), any()))
          .thenAnswer((_) async {});

      viewModel = SocialGroupDetailViewModel(
        groupId: testGroupId,
        friendsService: mockFriendsService,
        userService: mockUserService,
        permissionService: mockPermissionService,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('loads group data on initialization', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.group, isNotNull);
        expect(viewModel.group?.id, equals(testGroupId));
        expect(viewModel.group?.name, equals('Test Social Group'));
      });

      test('loads member profiles', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.members, hasLength(2));
        expect(viewModel.members.map((m) => m.uid),
            containsAll([testUserId, otherUserId]));
      });
    });

    group('Permission Getters', () {
      test('isAdmin returns true when user is group admin', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.isAdmin, isTrue);
      });

      test('isAdmin returns false when user is not admin', () async {
        when(() => mockPermissionService.isGroupAdmin(testGroupId))
            .thenReturn(false);

        await viewModel.loadGroupData();

        expect(viewModel.isAdmin, isFalse);
      });

      test('canEditGroup returns true when user is admin', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.canEditGroup, isTrue);
      });

      test('canDeleteGroup returns true when user is admin', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.canDeleteGroup, isTrue);
      });

      test('canLeaveGroup returns true when user is a member', () async {
        await Future.delayed(const Duration(milliseconds: 100));

        expect(viewModel.canLeaveGroup, isTrue);
      });
    });

    group('loadGroupData', () {
      test('loads group and member data successfully', () async {
        await viewModel.loadGroupData();

        expect(viewModel.group, isNotNull);
        expect(viewModel.members, hasLength(2));
        expect(viewModel.isLoading, isFalse);
      });

      test('handles null group gracefully', () async {
        when(() => mockFriendsService.getCategoryById(testGroupId))
            .thenReturn(null);

        await viewModel.loadGroupData();

        expect(viewModel.group, isNull);
        expect(viewModel.members, isEmpty);
      });
    });

    group('refreshData', () {
      test('refreshes all data', () async {
        await viewModel.refreshData();

        verify(() => mockFriendsService.refresh()).called(greaterThan(0));
        expect(viewModel.group, isNotNull);
      });
    });

    group('checkLeaveGroupRequirements', () {
      test('returns no transfer needed for non-owner', () async {
        when(() => mockPermissionService.isGroupAdmin(testGroupId))
            .thenReturn(false);

        await viewModel.loadGroupData();
        final decision = viewModel.checkLeaveGroupRequirements();

        expect(decision.requiresOwnershipTransfer, isFalse);
        expect(decision.groupIsEmpty, isFalse);
        expect(decision.availableNewOwners, isEmpty);
      });

      test('returns empty group for owner with no other members', () async {
        final emptyGroup = testGroup.copyWith(friendUserIds: [testUserId]);
        when(() => mockFriendsService.getCategoryById(testGroupId))
            .thenReturn(emptyGroup);

        // getUserProfiles will return only currentUser based on _users map
        await viewModel.loadGroupData();
        final decision = viewModel.checkLeaveGroupRequirements();

        expect(decision.requiresOwnershipTransfer, isFalse);
        expect(decision.groupIsEmpty, isTrue);
        expect(decision.availableNewOwners, isEmpty);
      });

      test('returns transfer required for owner with other members', () async {
        await viewModel.loadGroupData();
        final decision = viewModel.checkLeaveGroupRequirements();

        expect(decision.requiresOwnershipTransfer, isTrue);
        expect(decision.groupIsEmpty, isFalse);
        expect(decision.availableNewOwners, hasLength(1));
        expect(decision.availableNewOwners.first.uid, equals(otherUserId));
      });
    });

    group('leaveGroup', () {
      test('successfully leaves group', () async {
        when(() => mockCategoriesOps.removeFriendFromCategory(
              testUserId,
              testGroupId,
            )).thenAnswer((_) async => true);

        await viewModel.loadGroupData();
        final result = await viewModel.leaveGroup();

        expect(result, isTrue);
        expect(viewModel.group, isNull);
        verify(() => mockCategoriesOps.removeFriendFromCategory(
            testUserId, testGroupId)).called(1);
      });

      test('returns false when leave fails', () async {
        when(() => mockCategoriesOps.removeFriendFromCategory(
              testUserId,
              testGroupId,
            )).thenAnswer((_) async => false);

        await viewModel.loadGroupData();
        final result = await viewModel.leaveGroup();

        expect(result, isFalse);
      });

      test('throws StateError when group is null', () async {
        when(() => mockFriendsService.getCategoryById(testGroupId))
            .thenReturn(null);

        await viewModel.loadGroupData();

        expect(
          () => viewModel.leaveGroup(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('transferGroupOwnership', () {
      test('successfully transfers ownership', () async {
        await viewModel.loadGroupData();
        final result = await viewModel.transferGroupOwnership(otherMember);

        expect(result, isTrue);
        verify(() => mockCategoryRepo.transferOwnership(
            testUserId, testGroupId, otherUserId)).called(1);
      });

      test('returns false when transfer fails', () async {
        when(() => mockCategoryRepo.transferOwnership(any(), any(), any()))
            .thenThrow(Exception('Transfer failed'));

        await viewModel.loadGroupData();
        final result = await viewModel.transferGroupOwnership(otherMember);

        expect(result, isFalse);
      });

      test('throws StateError when group is null', () async {
        when(() => mockFriendsService.getCategoryById(testGroupId))
            .thenReturn(null);

        await viewModel.loadGroupData();

        expect(
          () => viewModel.transferGroupOwnership(otherMember),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Content Sharing Coordination', () {
      test('canShareRecipeWithGroup returns true when authenticated', () async {
        await viewModel.loadGroupData();

        expect(viewModel.canShareRecipeWithGroup(), isTrue);
      });

      test('canShareMenuWithGroup returns true when authenticated', () async {
        await viewModel.loadGroupData();

        expect(viewModel.canShareMenuWithGroup(), isTrue);
      });

      test('canShareShoppingListWithGroup returns true when authenticated',
          () async {
        await viewModel.loadGroupData();

        expect(viewModel.canShareShoppingListWithGroup(), isTrue);
      });

      test('sharing methods return false when not authenticated', () async {
        mockPermissionService.setPermissionState(isAuthenticated: false);

        final unAuthViewModel = SocialGroupDetailViewModel(
          groupId: testGroupId,
          friendsService: mockFriendsService,
          userService: mockUserService,
          permissionService: mockPermissionService,
        );

        await unAuthViewModel.loadGroupData();

        expect(unAuthViewModel.canShareRecipeWithGroup(), isFalse);
        expect(unAuthViewModel.canShareMenuWithGroup(), isFalse);
        expect(unAuthViewModel.canShareShoppingListWithGroup(), isFalse);

        unAuthViewModel.dispose();
      });
    });
  });
}
