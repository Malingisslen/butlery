import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/group_invitations_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/permission_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test data builders
class GroupInvitationBuilder {
  static GroupInvitation build({
    String? id,
    String? groupId,
    String? groupName,
    String? groupEmoji,
    String? fromUserId,
    String? fromUserName,
    String? toUserId,
    GroupInvitationStatus status = GroupInvitationStatus.pending,
    String? personalMessage,
    DateTime? sentAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
  }) {
    final now = DateTime.now();
    return GroupInvitation(
      id: id ?? 'invitation_${now.millisecondsSinceEpoch}',
      groupId: groupId ?? 'group_123',
      groupName: groupName ?? 'Test Grupp',
      groupEmoji: groupEmoji ?? '👥',
      fromUserId: fromUserId ?? 'sender_123',
      fromUserName: fromUserName ?? 'Anna Andersson',
      toUserId: toUserId ?? 'test-user-123',
      status: status,
      personalMessage: personalMessage,
      sentAt: sentAt ?? now,
      respondedAt: respondedAt,
      expiresAt: expiresAt ?? now.add(const Duration(days: 7)),
    );
  }
}

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
      ownerId: ownerId ?? 'owner_123',
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

// Using centralized MockUnifiedFriendsService with enhanced setFriendsState() method

// Using local mock patterns that follow centralized architecture
// Using centralized mocks from production_mocks.dart

void main() {
  group('GroupInvitationsViewModel', () {
    late GroupInvitationsViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsCategoriesOperations mockCategoriesOps;
    late MockFriendsInvitationsOperations mockInvitationsOps;
    late MockFriendsManagementOperations mockManagementOps;

    // Test data
    final friend1 = UserProfileBuilder.build(
      uid: 'friend_1',
      displayName: 'Erik Svensson',
      email: 'erik@example.com',
    );

    final friend2 = UserProfileBuilder.build(
      uid: 'friend_2',
      displayName: 'Maria Öberg',
      email: 'maria@example.com',
    );

    final availableGroup1 = FriendCategoryBuilder.build(
      id: 'available_group_1',
      name: 'Matlagningsgruppen',
      description: 'En grupp för matintresserade',
      emoji: '🍳',
      ownerId: 'another_user',
      friendUserIds: ['friend_1', 'friend_2'],
    );

    final availableGroup2 = FriendCategoryBuilder.build(
      id: 'available_group_2',
      name: 'Familjen',
      description: 'Familjegrupp',
      emoji: '👨‍👩‍👧‍👦',
      ownerId: 'family_admin',
      friendUserIds: [],
    );

    final ownedGroup = FriendCategoryBuilder.build(
      id: 'owned_group',
      name: 'Min Grupp',
      ownerId: 'test-user-123', // Use the default mock user ID
      friendUserIds: ['friend_1'],
    );

    final memberGroup = FriendCategoryBuilder.build(
      id: 'member_group',
      name: 'Redan Medlem',
      ownerId: 'another_user',
      friendUserIds: [
        'test-user-123',
        'friend_1'
      ], // Use the default mock user ID
    );

    final pendingInvitation1 = GroupInvitationBuilder.build(
      id: 'invitation_1',
      groupId: 'group_123',
      groupName: 'Receptgruppen',
      groupEmoji: '🍴',
      fromUserId: 'sender_123',
      fromUserName: 'Anna Andersson',
      toUserId: 'test-user-123', // Use the default mock user ID
      status: GroupInvitationStatus.pending,
      personalMessage: 'Välkommen till vår receptgrupp!',
    );

    final pendingInvitation2 = GroupInvitationBuilder.build(
      id: 'invitation_2',
      groupId: 'group_456',
      groupName: 'Träningsgruppen',
      groupEmoji: '💪',
      fromUserId: 'sender_456',
      fromUserName: 'Johan Johansson',
      toUserId: 'test-user-123', // Use the default mock user ID
      status: GroupInvitationStatus.pending,
    );

    final acceptedInvitation = GroupInvitationBuilder.build(
      id: 'invitation_3',
      toUserId: 'test-user-123', // Use the default mock user ID
      status: GroupInvitationStatus.accepted,
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FriendCategoryBuilder.build());
      registerFallbackValue(UserProfileBuilder.build());
      registerFallbackValue(GroupInvitationBuilder.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create centralized mocks
      mockFriendsService = MockUnifiedFriendsService();
      mockCategoriesOps = MockFriendsCategoriesOperations();
      mockInvitationsOps = MockFriendsInvitationsOperations();
      mockManagementOps = MockFriendsManagementOperations();

      // Configure mock service operations using enhanced setFriendsState()
      mockFriendsService.setFriendsState(
        error: null,
        management: mockManagementOps,
        categoriesList: [],
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
      );

      // Configure default mock behavior
      when(() => mockCategoriesOps.getAllCategories()).thenReturn([
        availableGroup1,
        availableGroup2,
        ownedGroup,
        memberGroup,
      ]);

      when(() => mockInvitationsOps.getSentInvitations()).thenReturn([
        pendingInvitation1,
        pendingInvitation2,
        acceptedInvitation,
      ]);

      when(() => mockManagementOps.getAllFriends()).thenReturn([
        friend1,
        friend2,
      ]);

      when(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
          .thenAnswer((_) async => true);

      when(() => mockInvitationsOps.markInvitationAsViewed(any()))
          .thenAnswer((_) async => true);

      when(() => mockInvitationsOps.cancelInvitation(any()))
          .thenAnswer((_) async => true);

      // Create viewModel
      viewModel = GroupInvitationsViewModel(
        friendsService: mockFriendsService,
      );

      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));
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
      test('should load available groups on init', () {
        // All groups except ownedGroup and memberGroup should be available
        // since test_user owns ownedGroup and is a member of memberGroup
        expect(viewModel.availableGroups.length, equals(2));
        expect(
            viewModel.availableGroups
                .any((g) => g.name == 'Matlagningsgruppen'),
            isTrue);
        expect(
            viewModel.availableGroups.any((g) => g.name == 'Familjen'), isTrue);
      });

      test('should filter out owned groups', () {
        // ownedGroup has test_user as owner, so it should be filtered out
        expect(viewModel.availableGroups.any((g) => g.name == 'Min Grupp'),
            isFalse);
      });

      test('should filter out groups where user is member', () {
        // memberGroup has test_user as a member, so it should be filtered out
        expect(viewModel.availableGroups.any((g) => g.name == 'Redan Medlem'),
            isFalse);
      });

      test('should load received invitations on init', () {
        expect(viewModel.receivedInvitations.length, equals(2)); // Only pending
        expect(viewModel.allReceivedInvitations.length, equals(3)); // All
      });

      test('should load members for available groups', () {
        final members = viewModel.getMembersForGroup('available_group_1');
        expect(members.length, equals(2));
        expect(members.any((m) => m.displayName == 'Erik Svensson'), isTrue);
      });

      test('should calculate pending invitations count', () {
        expect(viewModel.pendingInvitationsCount, equals(2));
      });

      test('should have content when groups or invitations exist', () {
        expect(viewModel.hasContent, isTrue);
      });
    });

    group('Available Groups', () {
      test('should return immutable list of available groups', () {
        final groups = viewModel.availableGroups;
        expect(() => groups.add(FriendCategoryBuilder.build()),
            throwsUnsupportedError);
      });

      test('should get members for specific group', () {
        final members = viewModel.getMembersForGroup('available_group_1');
        expect(members.length, equals(2));
        expect(members.every((m) => m.displayName.isNotEmpty), isTrue);
      });

      test('should return empty list for unknown group', () {
        final members = viewModel.getMembersForGroup('non_existent');
        expect(members, isEmpty);
      });

      test('should handle empty available groups', () async {
        when(() => mockCategoriesOps.getAllCategories()).thenReturn([
          ownedGroup,
          memberGroup,
        ]);

        await viewModel.refresh();

        expect(viewModel.availableGroups, isEmpty);
        expect(viewModel.hasContent, isTrue); // Still has invitations
      });
    });

    group('Received Invitations', () {
      test('should filter pending invitations', () {
        final pending = viewModel.receivedInvitations;
        expect(pending.length, equals(2));
        expect(
            pending.every((inv) => inv.status == GroupInvitationStatus.pending),
            isTrue);
      });

      test('should get all invitations including accepted/rejected', () {
        final all = viewModel.allReceivedInvitations;
        expect(all.length, equals(3));
      });

      test('should check if responding to invitation', () {
        expect(viewModel.isRespondingToInvitation('invitation_1'), isFalse);
      });

      test('should handle empty invitations', () async {
        when(() => mockInvitationsOps.getSentInvitations()).thenReturn([]);

        await viewModel.refresh();

        expect(viewModel.receivedInvitations, isEmpty);
        expect(viewModel.pendingInvitationsCount, equals(0));
      });
    });

    group('Join Group', () {
      test('should join group successfully', () async {
        when(() => mockCategoriesOps.assignFriendToCategory(
                'test-user-123', 'available_group_1'))
            .thenAnswer((_) async => true);

        await viewModel.joinGroup('available_group_1');

        expect(
            viewModel.availableGroups.any((g) => g.id == 'available_group_1'),
            isFalse);
        expect(viewModel.error, isNull);

        verify(() => mockCategoriesOps.assignFriendToCategory(
            'test-user-123', 'available_group_1')).called(1);
      });

      test('should set joining state during operation', () async {
        bool wasJoining = false;
        viewModel.addListener(() {
          if (viewModel.isJoiningGroup('available_group_1')) {
            wasJoining = true;
          }
        });

        await viewModel.joinGroup('available_group_1');

        expect(wasJoining, isTrue);
        expect(viewModel.isJoiningGroup('available_group_1'), isFalse);
      });

      test('should handle join group failure', () async {
        when(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
            .thenAnswer((_) async => false);

        mockFriendsService.setFriendsState(error: 'Network error');

        await viewModel.joinGroup('available_group_1');

        // ErrorHandler translates to Swedish
        expect(viewModel.error, contains('internetanslutningen'));
        expect(
            viewModel.availableGroups.any((g) => g.id == 'available_group_1'),
            isTrue);
      });

      test('should prevent duplicate join attempts', () async {
        // Start first join
        final future1 = viewModel.joinGroup('available_group_1');

        // Try to join again immediately
        await viewModel.joinGroup('available_group_1');

        await future1;

        // Should only call once
        verify(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
            .called(1);
      });

      test('should handle non-existent group', () async {
        await viewModel.joinGroup('non_existent_group');

        // ErrorHandler translates to Swedish generic error
        expect(viewModel.error, contains('oväntat fel'));
      });
    });

    group('Accept Invitation', () {
      test('should accept invitation successfully', () async {
        when(() => mockInvitationsOps.markInvitationAsViewed('invitation_1'))
            .thenAnswer((_) async => true);

        // Update mock to return empty after accepting
        when(() => mockInvitationsOps.getSentInvitations()).thenReturn([
          pendingInvitation2,
          acceptedInvitation,
        ]);

        await viewModel.acceptInvitation('invitation_1');

        expect(viewModel.error, isNull);
        expect(viewModel.receivedInvitations.length, equals(1));

        verify(() => mockInvitationsOps.markInvitationAsViewed('invitation_1'))
            .called(1);
      });

      test('should set responding state during operation', () async {
        bool wasResponding = false;
        viewModel.addListener(() {
          if (viewModel.isRespondingToInvitation('invitation_1')) {
            wasResponding = true;
          }
        });

        await viewModel.acceptInvitation('invitation_1');

        expect(wasResponding, isTrue);
        expect(viewModel.isRespondingToInvitation('invitation_1'), isFalse);
      });

      test('should handle accept failure', () async {
        when(() => mockInvitationsOps.markInvitationAsViewed(any()))
            .thenAnswer((_) async => false);

        mockFriendsService.setFriendsState(error: 'Permission denied');

        await viewModel.acceptInvitation('invitation_1');

        // ErrorHandler translates to Swedish permission error
        expect(viewModel.error, contains('behörighet'));
        expect(viewModel.receivedInvitations.length, equals(2)); // Unchanged
      });

      test('should prevent duplicate accept attempts', () async {
        // Start first accept
        final future1 = viewModel.acceptInvitation('invitation_1');

        // Try to accept again immediately
        await viewModel.acceptInvitation('invitation_1');

        await future1;

        // Should only call once
        verify(() => mockInvitationsOps.markInvitationAsViewed(any()))
            .called(1);
      });

      test('should handle non-existent invitation', () async {
        await viewModel.acceptInvitation('non_existent');

        // ErrorHandler translates to Swedish generic error
        expect(viewModel.error, contains('oväntat fel'));
      });
    });

    group('Reject Invitation', () {
      test('should reject invitation successfully', () async {
        when(() => mockInvitationsOps.cancelInvitation('invitation_1'))
            .thenAnswer((_) async => true);

        // Update mock to return without rejected invitation
        when(() => mockInvitationsOps.getSentInvitations()).thenReturn([
          pendingInvitation2,
          acceptedInvitation,
        ]);

        await viewModel.rejectInvitation('invitation_1');

        expect(viewModel.error, isNull);
        expect(viewModel.receivedInvitations.length, equals(1));

        verify(() => mockInvitationsOps.cancelInvitation('invitation_1'))
            .called(1);
      });

      test('should handle reject failure', () async {
        when(() => mockInvitationsOps.cancelInvitation(any()))
            .thenAnswer((_) async => false);

        mockFriendsService.setFriendsState(error: 'Cannot reject');

        await viewModel.rejectInvitation('invitation_1');

        // ErrorHandler translates to Swedish generic error
        expect(viewModel.error, contains('oväntat fel'));
        expect(viewModel.receivedInvitations.length, equals(2)); // Unchanged
      });

      test('should prevent duplicate reject attempts', () async {
        // Start first reject
        final future1 = viewModel.rejectInvitation('invitation_1');

        // Try to reject again immediately
        await viewModel.rejectInvitation('invitation_1');

        await future1;

        // Should only call once
        verify(() => mockInvitationsOps.cancelInvitation(any())).called(1);
      });
    });

    group('Refresh', () {
      test('should refresh all data', () async {
        // Change mock data
        when(() => mockCategoriesOps.getAllCategories()).thenReturn([
          availableGroup1,
        ]);

        when(() => mockInvitationsOps.getSentInvitations()).thenReturn([
          pendingInvitation1,
        ]);

        await viewModel.refresh();

        expect(viewModel.availableGroups.length, equals(1));
        expect(viewModel.receivedInvitations.length, equals(1));
      });

      test('should set loading state during refresh', () async {
        bool wasLoading = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasLoading = true;
        });

        await viewModel.refresh();

        expect(wasLoading, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('should handle refresh errors gracefully', () async {
        when(() => mockCategoriesOps.getAllCategories())
            .thenThrow(Exception('Network error'));

        await viewModel.refresh();

        // ErrorHandler translates to Swedish network error
        expect(viewModel.error, contains('internetanslutningen'));
        expect(viewModel.availableGroups, isNotEmpty); // Keeps existing data
      });
    });

    group('Error Handling', () {
      test('should clear error', () async {
        // Set an error
        await viewModel.joinGroup('non_existent');
        expect(viewModel.hasError, isTrue);

        // Clear it
        viewModel.clearError();
        expect(viewModel.hasError, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should notify listeners on error changes', () {
        int notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.clearError();
        expect(notificationCount, equals(1));
      });
    });

    group('Edge Cases', () {
      test('should handle null current user ID', () async {
        // Mock permission service to return null user ID
        final mockPermissionService =
            ServiceLocator.get<PermissionService>() as MockPermissionService;
        mockPermissionService.setPermissionState(currentUserId: null);

        await viewModel.joinGroup('available_group_1');

        expect(viewModel.error, equals('Ingen användare inloggad'));
      });

      test('should handle empty friend list for member loading', () async {
        when(() => mockManagementOps.getAllFriends()).thenReturn([]);

        await viewModel.refresh();

        final members = viewModel.getMembersForGroup('available_group_1');
        expect(members, isEmpty);
      });

      test('should handle exception during group join', () async {
        when(() => mockCategoriesOps.assignFriendToCategory(any(), any()))
            .thenThrow(Exception('Database error'));

        await viewModel.joinGroup('available_group_1');

        // ErrorHandler may translate the error message
        expect(viewModel.error, isNotNull);
        expect(
            viewModel.error,
            anyOf(
              contains('Database error'),
              contains('oväntat fel'),
            ));
      });

      test('should handle exception during invitation accept', () async {
        when(() => mockInvitationsOps.markInvitationAsViewed(any()))
            .thenThrow(Exception('Server error'));

        await viewModel.acceptInvitation('invitation_1');

        // ErrorHandler may translate the error message
        expect(viewModel.error, isNotNull);
        expect(
            viewModel.error,
            anyOf(
              contains('Server error'),
              contains('oväntat fel'),
            ));
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () async {
        final testViewModel = GroupInvitationsViewModel(
          friendsService: mockFriendsService,
        );

        // Wait for initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));

        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle operations after dispose', () async {
        final testViewModel = GroupInvitationsViewModel(
          friendsService: mockFriendsService,
        );

        // Wait for initialization to complete
        await Future.delayed(const Duration(milliseconds: 100));

        testViewModel.dispose();

        // Operations that call notifyListeners should throw
        expect(() => testViewModel.clearError(), throwsFlutterError);
      });
    });
  });
}
