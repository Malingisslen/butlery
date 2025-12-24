import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test data builders
class FriendCategoryBuilder {
  static FriendCategory build({
    String? id,
    String? name,
    String? description,
    String? emoji,
    String? ownerId,
    List<String>? friendUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int sortOrder = 0,
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return FriendCategory(
      id: id ?? 'category_${now.millisecondsSinceEpoch}',
      name: name ?? 'Test Grupp',
      description: description,
      emoji: emoji ?? '👥',
      ownerId: ownerId ?? 'test_user_123',
      friendUserIds: friendUserIds ?? [],
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      sortOrder: sortOrder,
      isDefault: isDefault,
    );
  }
}

class UserProfileBuilder {
  static UserProfile build({
    String? uid,
    String? displayName,
    String? email,
    String? avatarUrl,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'user_${now.millisecondsSinceEpoch}',
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      joinedAt: joinedAt ?? now,
      lastActiveAt: lastActiveAt ?? now,
      isOnline: isOnline,
    );
  }
}

void main() {
  group('SocialGroupDetailViewModel', () {
    late SocialGroupDetailViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUserService mockUserService;
    late MockPermissionService mockPermissionService;
    late MockFriendCategoriesOperations mockCategoriesOps;

    // Test data
    const testGroupId = 'test_group_123';
    const testUserId = 'test_user_123';
    const otherUserId = 'other_user_456';

    final testGroup = FriendCategoryBuilder.build(
      id: testGroupId,
      name: 'Test Social Group',
      description: 'A test group',
      emoji: '🎉',
      ownerId: testUserId,
      friendUserIds: [testUserId, otherUserId],
    );

    final currentUser = UserProfileBuilder.build(
      uid: testUserId,
      displayName: 'Test Owner',
      email: 'owner@example.com',
    );

    final otherMember = UserProfileBuilder.build(
      uid: otherUserId,
      displayName: 'Other Member',
      email: 'member@example.com',
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      mockFriendsService = MockUnifiedFriendsService();
      mockUserService = MockUserService();
      mockPermissionService = MockPermissionService();
      mockCategoriesOps = MockFriendCategoriesOperations();

      // Setup default mock behaviors
      when(() => mockFriendsService.categories).thenReturn(mockCategoriesOps);
      when(() => mockFriendsService.getCategoryById(testGroupId))
          .thenReturn(testGroup);
      when(() => mockFriendsService.refresh()).thenAnswer((_) async {});
      when(() => mockFriendsService.updateCategoryInternal(any(), any()))
          .thenReturn(null);
      when(() => mockFriendsService.syncCategoryToFirebaseInternal(any()))
          .thenAnswer((_) async {});

      when(() => mockUserService.getUserProfiles(any()))
          .thenAnswer((_) async => [currentUser, otherMember]);

      when(() => mockPermissionService.currentUserId).thenReturn(testUserId);
      when(() => mockPermissionService.isAuthenticated).thenReturn(true);
      when(() => mockPermissionService.isGroupAdmin(any())).thenReturn(true);

      when(() => mockCategoriesOps.removeFriendFromCategory(any(), any()))
          .thenAnswer((_) async => true);

      // Create ViewModel after all mocks are set up
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

    group('Initialization', () {
      test('loads group data on initialization', () async {
        // Wait for async initialization to complete
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
        verify(() => mockPermissionService.isGroupAdmin(testGroupId))
            .called(greaterThan(0));
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

        verify(() => mockFriendsService.refresh()).called(1);
        verify(() => mockFriendsService.getCategoryById(testGroupId)).called(1);
        verify(() => mockUserService.getUserProfiles([testUserId, otherUserId]))
            .called(1);
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
        when(() => mockUserService.getUserProfiles([testUserId]))
            .thenAnswer((_) async => [currentUser]);

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
        when(() => mockFriendsService.updateCategoryInternal(any(), any()))
            .thenReturn(null);
        when(() => mockFriendsService.syncCategoryToFirebaseInternal(any()))
            .thenAnswer((_) async => {});

        await viewModel.loadGroupData();
        final result = await viewModel.transferGroupOwnership(otherMember);

        expect(result, isTrue);
        verify(() =>
                mockFriendsService.updateCategoryInternal(testGroupId, any()))
            .called(1);
        verify(() => mockFriendsService.syncCategoryToFirebaseInternal(any()))
            .called(1);
      });

      test('returns false when transfer fails', () async {
        when(() => mockFriendsService.updateCategoryInternal(any(), any()))
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
        when(() => mockPermissionService.isAuthenticated).thenReturn(false);

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
