// Rewritten: local pure-Mocks for UnifiedFriendsService and sub-operations
// to avoid centralized concrete @override conflicts with when().

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/add_members_to_group_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

// Local pure-Mocks: no concrete @override, so when() works on every method.
class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockManagement extends Mock implements FriendsManagementOperations {}

class _MockCategories extends Mock implements FriendsCategoriesOperations {}

class _MockInvitations extends Mock implements FriendsInvitationsOperations {}

void main() {
  late AddMembersToGroupViewModel viewModel;
  late _MockFriendsService mockFriendsService;
  late _MockManagement mockManagement;
  late _MockCategories mockCategories;
  late _MockInvitations mockInvitations;

  const testGroupId = 'group-123';
  late FriendCategory testGroup;
  late List<UserProfile> testFriends;
  late List<GroupInvitation> testInvitations;

  setUpAll(() {
    registerFallbackValue(GroupInvitationStatus.pending);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();

    mockFriendsService = _MockFriendsService();
    mockManagement = _MockManagement();
    mockCategories = _MockCategories();
    mockInvitations = _MockInvitations();

    testGroup = FriendCategory(
      id: testGroupId,
      ownerId: 'current-user',
      name: 'Min Receptgrupp',
      description: 'En grupp',
      emoji: '🍴',
      friendUserIds: ['existing-member-1', 'existing-member-2'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sortOrder: 0,
      isDefault: false,
    );

    testFriends = [
      _profile('friend-1', 'Anna Andersson', email: 'anna@example.com'),
      _profile('friend-2', 'Erik Eriksson', email: 'erik@example.com'),
      _profile('friend-3', 'Maria Nilsson', email: 'maria@example.com'),
      _profile('existing-member-1', 'Existing Member 1'),
      _profile('friend-with-pending', 'Pending Invitation'),
    ];

    testInvitations = [
      GroupInvitation(
        id: 'inv-1',
        fromUserId: 'current-user',
        fromUserName: 'Current User',
        toUserId: 'friend-with-pending',
        groupId: testGroupId,
        groupName: 'Min Receptgrupp',
        groupEmoji: '🍴',
        personalMessage: null,
        status: GroupInvitationStatus.pending,
        sentAt: DateTime.now(),
        respondedAt: null,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    ];

    // Wire sub-mocks into the friends service
    when(() => mockFriendsService.categories).thenReturn(mockCategories);
    when(() => mockFriendsService.management).thenReturn(mockManagement);
    when(() => mockFriendsService.invitations).thenReturn(mockInvitations);
    when(() => mockFriendsService.currentUserId).thenReturn('current-user');
    when(() => mockFriendsService.hasError).thenReturn(false);
    when(() => mockFriendsService.error).thenReturn(null);
    when(() => mockFriendsService.refresh()).thenAnswer((_) async {});

    // Categories stubs
    when(
      () => mockCategories.getCategoryById(testGroupId),
    ).thenReturn(testGroup);
    when(() => mockCategories.getCategoryById(any())).thenReturn(null);
    // Override specific ID after generic stub
    when(
      () => mockCategories.getCategoryById(testGroupId),
    ).thenReturn(testGroup);

    // Management stubs
    when(() => mockManagement.getAllFriends()).thenReturn(testFriends);

    // Invitations stubs
    when(
      () => mockInvitations.getSentInvitations(),
    ).thenReturn(testInvitations);
    when(
      () => mockInvitations.sendGroupInvitationToUser(
        userId: any(named: 'userId'),
        groupId: any(named: 'groupId'),
        customMessage: any(named: 'customMessage'),
      ),
    ).thenAnswer((_) async => true);

    viewModel = AddMembersToGroupViewModel(
      groupId: testGroupId,
      friendsService: mockFriendsService,
    );
    await Future.delayed(Duration.zero);
  });

  tearDown(() async {
    viewModel.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('Initialization', () {
    test('should initialize with correct group ID', () {
      expect(viewModel.groupId, equals(testGroupId));
    });

    test('should load group data', () {
      expect(viewModel.group, isNotNull);
      expect(viewModel.group?.name, equals('Min Receptgrupp'));
      expect(viewModel.groupName, equals('Min Receptgrupp'));
    });

    test('should exclude existing members from available friends', () {
      expect(viewModel.availableFriends.length, equals(3));
      expect(
        viewModel.availableFriends.any((f) => f.uid == 'existing-member-1'),
        isFalse,
      );
    });

    test('should exclude friends with pending invitations', () {
      expect(
        viewModel.availableFriends.any((f) => f.uid == 'friend-with-pending'),
        isFalse,
      );
    });

    test('should sort available friends alphabetically', () {
      final names = viewModel.availableFriends
          .map((f) => f.displayName)
          .toList();
      expect(names, equals(List.of(names)..sort()));
    });

    test('should initialize with empty selection', () {
      expect(viewModel.selectedFriendIds, isEmpty);
      expect(viewModel.hasSelectedFriends, isFalse);
      expect(viewModel.selectedCount, equals(0));
    });

    test('should initialize filtered friends same as available', () {
      expect(viewModel.filteredFriends, equals(viewModel.availableFriends));
    });

    test('should handle missing group gracefully', () async {
      when(() => mockCategories.getCategoryById(any())).thenReturn(null);
      final vm = AddMembersToGroupViewModel(
        groupId: 'invalid-group',
        friendsService: mockFriendsService,
      );
      await Future.delayed(Duration.zero);

      expect(vm.hasError, isTrue);
      expect(vm.groupName, equals('Grupp'));
      vm.dispose();
    });
  });

  group('Friend Selection', () {
    test('should toggle selection', () {
      viewModel.toggleFriendSelection('friend-1');
      expect(viewModel.isFriendSelected('friend-1'), isTrue);
      expect(viewModel.selectedCount, equals(1));

      viewModel.toggleFriendSelection('friend-1');
      expect(viewModel.isFriendSelected('friend-1'), isFalse);
      expect(viewModel.selectedCount, equals(0));
    });

    test('should select multiple', () {
      viewModel.toggleFriendSelection('friend-1');
      viewModel.toggleFriendSelection('friend-2');
      viewModel.toggleFriendSelection('friend-3');
      expect(viewModel.selectedCount, equals(3));
    });

    test('should select all visible', () {
      viewModel.selectAllVisible();
      expect(viewModel.selectedCount, equals(viewModel.filteredFriends.length));
    });

    test('should clear all selections', () {
      viewModel.selectAllVisible();
      viewModel.clearAllSelections();
      expect(viewModel.hasSelectedFriends, isFalse);
    });

    test('should get selected profiles', () {
      viewModel.toggleFriendSelection('friend-1');
      viewModel.toggleFriendSelection('friend-2');
      final selected = viewModel.selectedFriends;
      expect(selected.length, equals(2));
      expect(selected.any((f) => f.uid == 'friend-1'), isTrue);
    });

    test('should maintain selection when filtering', () {
      viewModel.toggleFriendSelection('friend-1');
      viewModel.toggleFriendSelection('friend-2');
      viewModel.updateSearch('Anna');
      expect(viewModel.selectedCount, equals(2));
    });

    test('should provide immutable selected IDs', () {
      viewModel.toggleFriendSelection('friend-1');
      expect(
        () => viewModel.selectedFriendIds.add('x'),
        throwsUnsupportedError,
      );
    });
  });

  group('Search', () {
    test('should filter by name', () {
      viewModel.updateSearch('Anna');
      expect(viewModel.filteredFriends.length, equals(1));
      expect(
        viewModel.filteredFriends.first.displayName,
        equals('Anna Andersson'),
      );
    });

    test('should be case-insensitive', () {
      viewModel.updateSearch('ERIK');
      expect(viewModel.filteredFriends.length, equals(1));
    });

    test('should trim query', () {
      viewModel.updateSearch('  Anna  ');
      expect(viewModel.searchQuery, equals('anna'));
      expect(viewModel.filteredFriends.length, equals(1));
    });

    test('should clear search', () {
      viewModel.updateSearch('Anna');
      viewModel.clearSearch();
      expect(viewModel.hasSearchQuery, isFalse);
      expect(
        viewModel.filteredFriends.length,
        equals(viewModel.availableFriends.length),
      );
    });

    test('should show empty for no matches', () {
      viewModel.updateSearch('xyz123');
      expect(viewModel.filteredFriends, isEmpty);
    });
  });

  group('Invitation Sending', () {
    test('should send invitations to selected friends', () async {
      viewModel.toggleFriendSelection('friend-1');
      viewModel.toggleFriendSelection('friend-2');

      final result = await viewModel.sendInvitations(
        personalMessage: 'Välkommen!',
      );

      expect(result, isTrue);
      verify(
        () => mockInvitations.sendGroupInvitationToUser(
          userId: 'friend-1',
          groupId: testGroupId,
          customMessage: 'Välkommen!',
        ),
      ).called(1);
      verify(
        () => mockInvitations.sendGroupInvitationToUser(
          userId: 'friend-2',
          groupId: testGroupId,
          customMessage: 'Välkommen!',
        ),
      ).called(1);
    });

    test('should clear selections after success', () async {
      viewModel.toggleFriendSelection('friend-1');
      await viewModel.sendInvitations();
      expect(viewModel.selectedFriendIds, isEmpty);
    });

    test('should update invitation status on success', () async {
      viewModel.toggleFriendSelection('friend-1');
      await viewModel.sendInvitations();
      expect(viewModel.getInvitationStatusForUser('friend-1'), equals('sent'));
      expect(viewModel.hasInvitationStatus('friend-1'), isTrue);
    });

    test('should handle invitation failure', () async {
      when(
        () => mockInvitations.sendGroupInvitationToUser(
          userId: any(named: 'userId'),
          groupId: any(named: 'groupId'),
          customMessage: any(named: 'customMessage'),
        ),
      ).thenAnswer((_) async => false);

      viewModel.toggleFriendSelection('friend-1');
      final result = await viewModel.sendInvitations();

      expect(result, isFalse);
      expect(
        viewModel.getInvitationStatusForUser('friend-1'),
        equals('failed'),
      );
    });

    test('should set sending state during invitation', () async {
      viewModel.toggleFriendSelection('friend-1');
      bool wasSending = false;
      viewModel.addListener(() {
        if (viewModel.isSendingInvitations) wasSending = true;
      });
      await viewModel.sendInvitations();
      expect(wasSending, isTrue);
      expect(viewModel.isSendingInvitations, isFalse);
    });

    test('should not send if no friends selected', () async {
      final result = await viewModel.sendInvitations();
      expect(result, isFalse);
      verifyNever(
        () => mockInvitations.sendGroupInvitationToUser(
          userId: any(named: 'userId'),
          groupId: any(named: 'groupId'),
          customMessage: any(named: 'customMessage'),
        ),
      );
    });

    test('should handle service exception', () async {
      when(
        () => mockInvitations.sendGroupInvitationToUser(
          userId: any(named: 'userId'),
          groupId: any(named: 'groupId'),
          customMessage: any(named: 'customMessage'),
        ),
      ).thenThrow(Exception('Network error'));

      viewModel.toggleFriendSelection('friend-1');
      final result = await viewModel.sendInvitations();

      expect(result, isFalse);
      expect(viewModel.invitationError, isNotNull);
    });
  });

  group('UI State', () {
    test('should not be loading after init', () {
      expect(viewModel.isLoading, isFalse);
    });

    test('should not have error after successful init', () {
      expect(viewModel.hasError, isFalse);
      expect(viewModel.error, isNull);
    });

    test('should clear errors', () {
      viewModel.clearError();
      expect(viewModel.hasError, isFalse);
      expect(viewModel.invitationError, isNull);
    });

    test('should enable send when friends selected', () {
      expect(viewModel.canSendInvitations, isFalse);
      viewModel.toggleFriendSelection('friend-1');
      expect(viewModel.canSendInvitations, isTrue);
    });

    test('should show empty state when no friends', () async {
      when(() => mockManagement.getAllFriends()).thenReturn([]);
      final vm = AddMembersToGroupViewModel(
        groupId: testGroupId,
        friendsService: mockFriendsService,
      );
      await Future.delayed(Duration.zero);
      expect(vm.showEmptyState, isTrue);
      vm.dispose();
    });

    test('should provide available friends count', () {
      expect(viewModel.availableFriendsCount, equals(3));
    });

    test('should provide immutable lists', () {
      expect(
        () => viewModel.availableFriends.add(testFriends[0]),
        throwsUnsupportedError,
      );
      expect(() => viewModel.filteredFriends.clear(), throwsUnsupportedError);
    });
  });

  group('Invitation Status', () {
    test('should check existing invitations', () {
      expect(viewModel.hasExistingInvitation('friend-with-pending'), isTrue);
    });

    test('should get sent invitations for group', () {
      final invitations = viewModel.getSentInvitationsForGroup();
      expect(invitations.length, equals(1));
    });

    test('should provide immutable status map', () {
      expect(
        () => viewModel.invitationStatus['x'] = 'y',
        throwsUnsupportedError,
      );
    });
  });

  group('Edge Cases', () {
    test('should handle null group', () async {
      when(() => mockCategories.getCategoryById(any())).thenReturn(null);
      final vm = AddMembersToGroupViewModel(
        groupId: 'non-existent',
        friendsService: mockFriendsService,
      );
      await Future.delayed(Duration.zero);
      expect(vm.group, isNull);
      expect(vm.groupName, equals('Grupp'));
      expect(vm.hasError, isTrue);
      vm.dispose();
    });

    test('should handle empty friends list', () async {
      when(() => mockManagement.getAllFriends()).thenReturn([]);
      final vm = AddMembersToGroupViewModel(
        groupId: testGroupId,
        friendsService: mockFriendsService,
      );
      await Future.delayed(Duration.zero);
      expect(vm.availableFriends, isEmpty);
      expect(vm.availableFriendsCount, equals(0));
      vm.dispose();
    });

    test('should handle all friends being members', () async {
      final fullGroup = FriendCategory(
        id: testGroupId,
        ownerId: 'current-user',
        name: 'Full Group',
        description: 'Full',
        emoji: '👥',
        friendUserIds: testFriends.map((f) => f.uid).toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        sortOrder: 0,
        isDefault: false,
      );
      when(
        () => mockCategories.getCategoryById(testGroupId),
      ).thenReturn(fullGroup);

      final vm = AddMembersToGroupViewModel(
        groupId: testGroupId,
        friendsService: mockFriendsService,
      );
      await Future.delayed(Duration.zero);
      expect(vm.availableFriends, isEmpty);
      vm.dispose();
    });
  });

  group('Dispose', () {
    test('should dispose without errors', () async {
      final vm = AddMembersToGroupViewModel(
        groupId: testGroupId,
        friendsService: mockFriendsService,
      );
      await Future.delayed(Duration.zero);
      expect(() => vm.dispose(), returnsNormally);
    });
  });
}

UserProfile _profile(String uid, String name, {String email = ''}) {
  return UserProfile(
    uid: uid,
    email: email,
    displayName: name,
    avatarUrl: null,
    isOnline: false,
    joinedAt: DateTime.now().subtract(const Duration(days: 30)),
    lastActiveAt: DateTime.now(),
  );
}
