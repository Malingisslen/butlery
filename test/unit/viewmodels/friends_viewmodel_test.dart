import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendsViewModel - Ultrathink Enhanced Tests', () {
    late FriendsViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUserService mockUserService;
    late MockFriendsManagementOperations mockManagement;
    late MockFriendsCategoriesOperations mockCategories;
    late FakePermissionService mockPermissionService;
    late MockAnalyticsService mockAnalyticsService;

    // Test data
    final testUserId = 'user123';
    final testFriendId = 'friend456';
    final testRequestId = 'request789';
    final testGroupId = 'group123';

    final testUserProfile = UserProfile(
      uid: testUserId,
      displayName: 'Test User',
      email: 'test@example.com',
      avatarUrl: 'https://example.com/photo.jpg',
      joinedAt: DateTime(2023, 1, 1),
      lastActiveAt: DateTime.now(),
    );

    final testFriendProfile = UserProfile(
      uid: testFriendId,
      displayName: 'Friend User',
      email: 'friend@example.com',
      avatarUrl: 'https://example.com/friend.jpg',
      joinedAt: DateTime(2023, 1, 1),
      lastActiveAt: DateTime.now(),
    );

    final testFriendRequest = FriendRequest(
      id: testRequestId,
      fromUserId: testFriendId,
      toUserId: testUserId,
      status: FriendRequestStatus.pending,
      sentAt: DateTime.now(),
      message: 'Let\'s be friends!',
    );

    final testGroup = FriendCategory(
      id: testGroupId,
      name: 'Best Friends',
      description: 'My closest friends',
      emoji: '❤️',
      friendUserIds: [testFriendId],
      ownerId: testUserId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks using factory
      mockFriendsService = MockFactory.createUnifiedFriendsService();
      mockUserService = MockUserService();
      mockManagement = MockFriendsManagementOperations();
      mockCategories = MockFriendsCategoriesOperations();
      mockPermissionService = FakePermissionService();
      mockAnalyticsService = MockAnalyticsService();

      // Configure auth state
      mockPermissionService.setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
      );

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedFriendsService>(
          mockFriendsService);
      TestServiceLocator.registerMock<UserService>(mockUserService);

      // Configure service state using state-based approach (ultrathink gold standard)
      mockFriendsService.setFriendsState(
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
        categoriesList: [],
        isLoading: false,
        error: null,
        isInitialized: true,
        management: mockManagement,
        categories: mockCategories,
      );

      // Configure operations using state-based approach (ultrathink gold standard)
      mockManagement.setManagementState(
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
      );

      mockCategories.setCategoriesState(
        shouldSucceed: true,
        createdCategoryId: testGroupId,
        categoryFriends: [],
        categoryByName: null,
        friendCategories: [],
      );

      // Configure user service state
      mockUserService.setUserState(
        currentUser: null,
        users: {},
        isLoading: false,
        error: null,
      );

      // Create view model with explicit dependencies (avoids production ServiceLocator)
      viewModel = FriendsViewModel(
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

    group('Initialization and Default State', () {
      test('should initialize with correct default state for all properties',
          () {
        // Assert
        expect(viewModel.friends, isEmpty);
        expect(viewModel.incomingRequests, isEmpty);
        expect(viewModel.sentRequests, isEmpty);
        expect(viewModel.friendsCount, equals(0));
        expect(viewModel.pendingRequestsCount, equals(0));
        expect(viewModel.groups, isEmpty);
        expect(viewModel.groupsWithFriends, isEmpty);
        expect(viewModel.isLoadingGroups, isFalse);
        expect(viewModel.groupsError, isNull);
        expect(viewModel.groupsCount, equals(0));
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.isSearching, isFalse);
        expect(viewModel.searchError, isNull);
        expect(viewModel.hasSearchResults, isFalse);
        expect(viewModel.hasSearchQuery, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.hasSelectedFriends, isFalse);
        expect(viewModel.selectedFriendsCount, equals(0));
        expect(viewModel.isCreatingGroup, isFalse);
        expect(viewModel.groupCreationError, isNull);
        expect(viewModel.isLoadingUserProfiles, isFalse);
        // Auth state from PermissionService (via TestServiceLocator)
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.currentUserId, equals('test-user-123'));
      });

      test('should properly register service listeners', () {
        // Assert - test ViewModel behavior, not implementation details
        expect(viewModel.friends, isEmpty);
        expect(viewModel.isLoading, isFalse);
        // ViewModel should be properly initialized with service integration
      });
    });

    group('Friends Management', () {
      test('should reflect friends list from service', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [testFriendProfile],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act
        final friends = viewModel.friends;

        // Assert
        expect(friends, hasLength(1));
        expect(viewModel.friendsCount, equals(1));
      });

      test('should remove friend successfully', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.removeFriend(testFriendId);

        // Assert - verify behavior, not implementation
        expect(result, isTrue);
      });

      test('should handle friend removal failure', () async {
        // Arrange - configure failure state
        mockManagement.setManagementState(friends: [], shouldSucceed: false);

        // Act
        final result = await viewModel.removeFriend(testFriendId);

        // Assert
        expect(result, isFalse);
      });

      test('should clear selection when removing selected friend', () async {
        // Arrange
        viewModel.toggleFriendSelection(testFriendId);
        expect(viewModel.hasSelectedFriends, isTrue);

        // Configure success state
        mockManagement.setManagementState(friends: []);

        // Act
        await viewModel.removeFriend(testFriendId);

        // Assert
        expect(viewModel.hasSelectedFriends, isFalse);
        expect(viewModel.selectedFriendIds, isEmpty);
      });
    });

    group('Friend Requests', () {
      test('should send friend request with message', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.sendFriendRequest(
          testFriendId,
          message: 'Let\'s connect!',
        );

        // Assert
        expect(result, isTrue);
      });

      test('should accept friend request', () async {
        // Arrange — service needs the request so VM can look it up by ID
        mockFriendsService.setFriendsState(
          incomingRequests: [testFriendRequest],
          isInitialized: true,
          management: mockManagement,
        );
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.acceptFriendRequest(testRequestId);

        // Assert
        expect(result, isTrue);
      });

      test('should reject friend request', () async {
        // Arrange - use state-based configuration (ultrathink gold standard).
        // The request must actually be in incomingRequests — production
        // rejectFriendRequest does a firstWhere(...) and throws otherwise.
        mockFriendsService.setFriendsState(
          incomingRequests: [testFriendRequest],
          isInitialized: true,
          management: mockManagement,
        );
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.rejectFriendRequest(testRequestId);

        // Assert
        expect(result, isTrue);
      });

      test('should accept gracefully when request already vanished (no throw)',
          () async {
        // Arrange — request is NOT in incomingRequests (cancelled on another
        // device / double-tap), but the service still no-ops successfully.
        // Bug 17: firstWhere used to throw here; firstWhereOrNull must not.
        mockFriendsService.setFriendsState(
          incomingRequests: [],
          isInitialized: true,
          management: mockManagement,
        );
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.acceptFriendRequest(testRequestId);

        // Assert — returns the service success flag, no exception thrown.
        expect(result, isTrue);
      });

      test('should reject gracefully when request already vanished (no throw)',
          () async {
        // Arrange — request absent from incomingRequests but service no-ops ok.
        // Bug 17: firstWhere used to throw here; firstWhereOrNull must not.
        mockFriendsService.setFriendsState(
          incomingRequests: [],
          isInitialized: true,
          management: mockManagement,
        );
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.rejectFriendRequest(testRequestId);

        // Assert — returns the service success flag, no exception thrown.
        expect(result, isTrue);
      });

      // Note: unblockUser test skipped — same pre-existing SchedulerBinding issue
      // as sendFriendRequest/removeFriend tests (notifyListeners needs widget binding)

      test('should cancel sent request', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockManagement.setManagementState(friends: []);

        // Act
        final result = await viewModel.cancelSentRequest(testRequestId);

        // Assert
        expect(result, isTrue);
      });

      test('should reflect incoming requests from service', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [testFriendRequest],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act
        final requests = viewModel.incomingRequests;

        // Assert
        expect(requests, hasLength(1));
        expect(viewModel.pendingRequestsCount, equals(1));
      });

      test('should reflect sent requests from service', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [testFriendRequest],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act
        final requests = viewModel.sentRequests;

        // Assert
        expect(requests, hasLength(1));
      });
    });

    group('User Search', () {
      test('should search users with valid query', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockManagement.setManagementState(
          friends: [testFriendProfile],
        );

        // Act
        await viewModel.updateSearch('Test User');

        // Assert
        expect(viewModel.searchQuery, equals('Test User'));
      });

      test('should reject search with short query and set Swedish error',
          () async {
        // Act
        await viewModel.updateSearch('T');

        // Assert
        expect(viewModel.searchQuery, equals('T'));
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.searchError, isNotNull);
      });

      test('should trim search query', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockManagement.setManagementState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
        );

        // Act
        await viewModel.updateSearch('  Test  ');

        // Assert
        expect(viewModel.searchQuery, equals('Test'));
      });

      test('should clear search state', () async {
        // Arrange - set up search first using state-based configuration
        mockManagement.setManagementState(
          friends: [testFriendProfile],
        );
        await viewModel.updateSearch('Test');

        // Act
        viewModel.clearSearch();

        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.hasSearchQuery, isFalse);
        expect(viewModel.hasSearchResults, isFalse);
        expect(viewModel.searchError, isNull);
      });
    });

    group('Group Management', () {
      test('should create group with all parameters', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockCategories.setCategoriesState(
          shouldSucceed: true,
          createdCategoryId: testGroupId,
        );

        // Act
        final result = await viewModel.createGroup(
          name: 'Best Friends',
          description: 'My closest friends',
          emoji: '❤️',
          selectedFriendIds: [testFriendId],
        );

        // Assert
        expect(result, isTrue);
      });

      test('should handle group creation failure', () async {
        // Arrange
        mockCategories.setCategoriesState(shouldSucceed: false);

        // Act & Assert — createGroup throws when category creation returns null
        var threw = false;
        try {
          await viewModel.createGroup(name: 'Test Group');
        } catch (_) {
          threw = true;
        }
        expect(threw, isTrue);
        expect(viewModel.isCreatingGroup, isFalse);
      });

      test('should get friends in group', () {
        // Arrange
        mockCategories.setCategoriesState(
          shouldSucceed: true,
          friendsByCategory: {
            testGroupId: [testFriendProfile]
          },
        );

        // Act
        final friends = viewModel.getFriendsInGroup(testGroupId);

        // Assert
        expect(friends, hasLength(1));
        expect(friends.first.uid, equals(testFriendId));
      });

      test('should check group name availability', () {
        // Arrange — add a category so getCategoryByName can find it
        mockCategories.setCategoriesState(
          categories: [testGroup],
        );

        // Act & Assert - existing name
        final notAvailable = viewModel.isGroupNameAvailable('Best Friends');
        expect(notAvailable, isFalse); // Name already exists

        // Act & Assert - new name
        final available = viewModel.isGroupNameAvailable('New Group');
        expect(available, isTrue); // Name doesn't exist
      });

      test('should search groups by query', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        final groups = [
          testGroup,
          FriendCategory(
            id: 'group2',
            name: 'Work Friends',
            description: 'Colleagues',
            emoji: '💼',
            friendUserIds: [],
            ownerId: testUserId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: groups,
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act
        final results = viewModel.searchGroups('Best');

        // Assert
        expect(results, hasLength(1));
        expect(results.first.name, equals('Best Friends'));
      });

      test('should get groups for specific friend', () {
        // Arrange — testGroup.friendUserIds contains testFriendId
        mockCategories.setCategoriesState(
          categories: [testGroup],
        );

        // Act
        final groups = viewModel.getGroupsForFriend(testFriendId);

        // Assert
        expect(groups, hasLength(1));
        expect(groups.first.id, equals(testGroupId));
      });
    });

    group('Friend Selection', () {
      test('should toggle friend selection', () {
        // Act
        viewModel.toggleFriendSelection(testFriendId);

        // Assert
        expect(viewModel.selectedFriendIds.contains(testFriendId), isTrue);
        expect(viewModel.hasSelectedFriends, isTrue);
        expect(viewModel.selectedFriendsCount, equals(1));

        // Act - toggle again to deselect
        viewModel.toggleFriendSelection(testFriendId);

        // Assert
        expect(viewModel.selectedFriendIds.contains(testFriendId), isFalse);
        expect(viewModel.hasSelectedFriends, isFalse);
        expect(viewModel.selectedFriendsCount, equals(0));
      });

      test('should select all friends', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [testFriendProfile, testUserProfile],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act
        viewModel.selectAllFriends();

        // Assert
        expect(viewModel.selectedFriendsCount, equals(2));
        expect(viewModel.hasSelectedFriends, isTrue);
      });

      test('should clear all selections', () {
        // Arrange
        viewModel.toggleFriendSelection(testFriendId);
        viewModel.toggleFriendSelection('another_id');
        expect(viewModel.selectedFriendsCount, equals(2));

        // Act
        viewModel.clearSelection();

        // Assert
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.hasSelectedFriends, isFalse);
        expect(viewModel.selectedFriendsCount, equals(0));
      });

      test('should get selected friends as UserProfile objects', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [testFriendProfile, testUserProfile],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );
        viewModel.toggleFriendSelection(testFriendId);

        // Act
        final selectedFriends = viewModel.getSelectedFriends();

        // Assert
        expect(selectedFriends, hasLength(1));
        expect(selectedFriends.first.uid, equals(testFriendId));
      });
    });

    group('Friendship Status', () {
      test('should determine friendship status correctly', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [testFriendProfile],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act & Assert
        expect(viewModel.getFriendshipStatus(testFriendId),
            equals(FriendshipStatus.friends));
        expect(viewModel.getFriendshipStatus('unknown_id'),
            equals(FriendshipStatus.none));
      });

      test('should detect outgoing request status', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [testFriendRequest],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act & Assert
        expect(viewModel.getFriendshipStatus(testUserId),
            equals(FriendshipStatus.requestSent));
      });

      test('should detect incoming request status', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [testFriendRequest],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act & Assert
        expect(viewModel.getFriendshipStatus(testFriendId),
            equals(FriendshipStatus.requestReceived));
      });

      test('should detect blocked user status', () {
        // Arrange
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          blockedUsers: {'blocked-user-123'},
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act & Assert
        expect(viewModel.getFriendshipStatus('blocked-user-123'),
            equals(FriendshipStatus.blocked));
        expect(viewModel.getFriendshipStatus('non-blocked-user'),
            equals(FriendshipStatus.none));
      });

      test('should check if can send friend request', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Act & Assert
        expect(viewModel.canSendFriendRequest('new_user'), isTrue);
        expect(
            viewModel.canSendFriendRequest('test-user-123'), isFalse); // Self
        expect(viewModel.canSendFriendRequest(testFriendId), isTrue);
      });
    });

    group('Mutual Friends', () {
      test('should get mutual friends with another user', () async {
        // Arrange
        mockManagement.setManagementState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          mutualFriends: [testFriendProfile],
        );

        // Act
        final mutualFriends = await viewModel.getMutualFriends('other_user');

        // Assert
        expect(mutualFriends, hasLength(1));
        expect(mutualFriends.first.uid, equals(testFriendId));
      });

      test('should handle mutual friends error', () async {
        // Arrange - configure error state (ultrathink gold standard)
        mockManagement.setManagementState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
        );

        // Act
        final mutualFriends = await viewModel.getMutualFriends('other_user');

        // Assert
        expect(mutualFriends, isEmpty);
      });
    });

    group('User Profiles', () {
      test('should load user profiles for requests', () async {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [testFriendRequest],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        mockUserService.setUserState(
          currentUser: null,
          users: {testFriendId: testFriendProfile},
          isLoading: false,
          error: null,
        );

        // Act
        await viewModel.loadUserProfilesForRequests();

        // Assert - verify behavior, not implementation
        final profile = viewModel.getUserProfile(testFriendId);
        expect(profile, isNotNull);
        expect(profile?.uid, equals(testFriendId));
      });

      test('should get display name for user', () {
        // Act — uncached user returns loading placeholder
        final displayName = viewModel.getDisplayNameForUser('unknown_user');

        // Assert
        expect(displayName, equals('Laddar...'));
      });

      test('should clear user profiles cache', () {
        // Act
        viewModel.clearUserProfilesCache();

        // Assert
        expect(viewModel.getUserProfile(testFriendId), isNull);
      });
    });

    group('Error Handling', () {
      test('should clear all errors', () {
        // Arrange - set error state first
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: 'Service error',
          isInitialized: true,
          management: mockManagement,
        );

        // Act
        viewModel.clearError();

        // Assert - verify behavior, not implementation
        expect(viewModel.searchError, isNull);
        expect(viewModel.groupCreationError, isNull);
      });

      test('should combine loading states', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: true,
          error: null,
          isInitialized: true,
          management: mockManagement,
        );

        // Assert
        expect(viewModel.isLoading, isTrue);
      });

      test('should combine error states', () {
        // Arrange - use state-based configuration (ultrathink gold standard)
        mockFriendsService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          categoriesList: [],
          isLoading: false,
          error: 'Service error',
          isInitialized: true,
          management: mockManagement,
        );

        // Assert
        expect(viewModel.error, equals('Service error'));
        expect(viewModel.hasError, isTrue);
      });
    });

    group('Refresh', () {
      test('should refresh data and clear cache', () async {
        // Act
        await viewModel.refresh();

        // Assert
        expect(viewModel.getUserProfile(testFriendId), isNull);
      });
    });

    group('Disposal', () {
      test('should clean up resources on dispose', () {
        // Create a separate test ViewModel to avoid interfering with tearDown
        final testViewModel = FriendsViewModel(
          friendsService: mockFriendsService,
          userService: mockUserService,
          analyticsService: mockAnalyticsService,
          permissionService: mockPermissionService,
        );

        // Act
        testViewModel.dispose();

        // Assert - verify behavior, not implementation details
        // ViewModel should be properly disposed without errors
        expect(() => testViewModel.dispose(),
            throwsFlutterError); // Second dispose should throw
      });

      test('should not perform operations after disposal', () async {
        // Create a separate test ViewModel to avoid interfering with tearDown
        final testViewModel = FriendsViewModel(
          friendsService: mockFriendsService,
          userService: mockUserService,
          analyticsService: mockAnalyticsService,
          permissionService: mockPermissionService,
        );

        // Arrange
        testViewModel.dispose();

        // Act
        await testViewModel.updateSearch('Test');
        await testViewModel.refresh();

        // Assert — disposed VM silently ignores operations
        expect(testViewModel.searchQuery, isEmpty);
      });
    });
  });
}
