import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friends_categories_operations.dart';

import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/factories/user_profile_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Mock dependencies
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {}
class MockUserService extends Mock implements UserService {}
class MockFriendsManagementOperations extends Mock implements FriendsManagementOperations {}
class MockFriendsCategoriesOperations extends Mock implements FriendsCategoriesOperations {}

// Fake implementations for testing
class FakeFriendRequest extends Fake implements FriendRequest {
  @override
  final String id;
  @override
  final String fromUserId;
  @override
  final String toUserId;
  @override
  final String? message;
  @override
  final DateTime sentAt;
  @override
  final FriendRequestStatus status;
  @override
  final DateTime? respondedAt;

  FakeFriendRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    this.message,
    DateTime? sentAt,
    this.respondedAt,
    this.status = FriendRequestStatus.pending,
  }) : sentAt = sentAt ?? DateTime.now();
}

class FakeFriendCategory extends Fake implements FriendCategory {
  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String? emoji;
  @override
  final List<String> memberIds;
  @override
  final int friendCount;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  FakeFriendCategory({
    required this.id,
    required this.name,
    this.description,
    this.emoji,
    List<String>? memberIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : memberIds = memberIds ?? [],
        friendCount = memberIds?.length ?? 0,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

void main() {
  group('FriendsViewModel', () {
    late FriendsViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUserService mockUserService;
    late MockFriendsManagementOperations mockManagementOps;
    late MockFriendsCategoriesOperations mockCategoryOps;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // TestServiceLocator is already initialized in setUpAll via BaseUnitTest.setupUnit()
      
      // Create mocks
      mockFriendsService = MockUnifiedFriendsService();
      mockUserService = MockUserService();
      mockManagementOps = MockFriendsManagementOperations();
      mockCategoryOps = MockFriendsCategoriesOperations();
      
      // Setup default mock behaviors for UnifiedFriendsService
      when(() => mockFriendsService.friends).thenReturn([]);
      when(() => mockFriendsService.incomingRequests).thenReturn([]);
      when(() => mockFriendsService.outgoingRequests).thenReturn([]);
      when(() => mockFriendsService.categoriesList).thenReturn([]);
      when(() => mockFriendsService.isLoading).thenReturn(false);
      when(() => mockFriendsService.error).thenReturn(null);
      when(() => mockFriendsService.hasError).thenReturn(false);
      when(() => mockFriendsService.management).thenReturn(mockManagementOps);
      when(() => mockFriendsService.categories).thenReturn(mockCategoryOps);
      when(() => mockFriendsService.addListener(any())).thenReturn(null);
      when(() => mockFriendsService.removeListener(any())).thenReturn(null);
      when(() => mockFriendsService.clearError()).thenReturn(null);
      
      // Setup default mock behaviors for UserService
      when(() => mockUserService.addListener(any())).thenReturn(null);
      when(() => mockUserService.removeListener(any())).thenReturn(null);
      when(() => mockUserService.getUserProfiles(any())).thenAnswer(
        (_) async => [],
      );
      
      // Setup default mock behaviors for operations
      when(() => mockManagementOps.sendFriendRequest(any(), message: any(named: 'message')))
          .thenAnswer((_) async => true);
      when(() => mockManagementOps.acceptFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagementOps.rejectFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagementOps.cancelFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagementOps.removeFriend(any())).thenAnswer((_) async => true);
      when(() => mockManagementOps.searchUsers(any())).thenAnswer((_) async => []);
      when(() => mockManagementOps.getMutualFriends(any())).thenAnswer((_) async => []);
      
      when(() => mockCategoryOps.createCategory(
        name: any(named: 'name'),
        description: any(named: 'description'),
        initialMemberIds: any(named: 'initialMemberIds'),
      )).thenAnswer((_) async => 'category-123');
      when(() => mockCategoryOps.getFriendsInCategory(any())).thenReturn([]);
      when(() => mockCategoryOps.getCategoryByName(any())).thenReturn(null);
      when(() => mockCategoryOps.getCategoriesForFriend(any())).thenReturn([]);
      
      // Create viewModel
      viewModel = FriendsViewModel(
        friendsService: mockFriendsService,
        userService: mockUserService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      viewModel.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel already initialized in setUp
        
        // Act - no action needed, checking initial state
        
        // Assert
        expect(viewModel.friends, isEmpty);
        expect(viewModel.incomingRequests, isEmpty);
        expect(viewModel.sentRequests, isEmpty);
        expect(viewModel.groups, isEmpty);
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
      });

      test('should register service listeners on creation', () {
        // Arrange - viewModel created in setUp
        
        // Act - no action needed, verifying constructor behavior
        
        // Assert
        verify(() => mockFriendsService.addListener(any())).called(1);
        verify(() => mockUserService.addListener(any())).called(1);
      });
    });

    group('State Accessors', () {
      test('should return friends from service', () {
        // Arrange
        final friends = [
          UserProfileFactory.build(uid: 'friend1'),
          UserProfileFactory.build(uid: 'friend2'),
        ];
        when(() => mockFriendsService.friends).thenReturn(friends);
        
        // Act - accessing friends property
        
        // Assert
        expect(viewModel.friends, equals(friends));
        expect(viewModel.friendsCount, equals(2));
      });

      test('should return friend requests from service', () {
        // Arrange
        final incoming = [
          FakeFriendRequest(id: 'req1', fromUserId: 'user1', toUserId: 'current'),
        ];
        final outgoing = [
          FakeFriendRequest(id: 'req2', fromUserId: 'current', toUserId: 'user2'),
        ];
        
        when(() => mockFriendsService.incomingRequests).thenReturn(incoming);
        when(() => mockFriendsService.outgoingRequests).thenReturn(outgoing);
        
        // Act - accessing request properties
        
        // Assert
        expect(viewModel.incomingRequests, equals(incoming));
        expect(viewModel.sentRequests, equals(outgoing));
        expect(viewModel.pendingRequestsCount, equals(1));
      });

      test('should return groups from service', () {
        // Arrange
        final groups = [
          FakeFriendCategory(id: 'g1', name: 'Family', memberIds: ['f1', 'f2']),
          FakeFriendCategory(id: 'g2', name: 'Work', memberIds: []),
        ];
        when(() => mockFriendsService.categoriesList).thenReturn(groups);
        
        // Act - accessing groups properties
        
        // Assert
        expect(viewModel.groups, equals(groups));
        expect(viewModel.groupsCount, equals(2));
        expect(viewModel.groupsWithFriends, hasLength(1));
        expect(viewModel.groupsWithFriends.first.name, equals('Family'));
      });

      test('should return loading and error states', () {
        // Arrange
        when(() => mockFriendsService.isLoading).thenReturn(true);
        when(() => mockFriendsService.error).thenReturn('Test error');
        when(() => mockFriendsService.hasError).thenReturn(true);
        
        // Act - accessing state properties
        
        // Assert
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.error, equals('Test error'));
        expect(viewModel.hasError, isTrue);
      });
    });

    group('Search Functionality', () {
      test('should update search query and perform search', () async {
        // Arrange
        final searchResults = [
          UserProfileFactory.build(uid: 'result1', displayName: 'Anna'),
        ];
        when(() => mockManagementOps.searchUsers('anna')).thenAnswer(
          (_) async => searchResults,
        );
        
        // Act
        await viewModel.updateSearch('anna');
        
        // Assert
        expect(viewModel.searchQuery, equals('anna'));
        expect(viewModel.searchResults, equals(searchResults));
        expect(viewModel.hasSearchResults, isTrue);
        verify(() => mockManagementOps.searchUsers('anna')).called(1);
      });

      test('should clear search when query is empty', () async {
        // Arrange - initial state from setUp
        
        // Act
        await viewModel.updateSearch('');
        
        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.hasSearchResults, isFalse);
      });

      test('should show error for short search query', () async {
        // Arrange - initial state from setUp
        
        // Act
        await viewModel.updateSearch('a');
        
        // Assert
        expect(viewModel.searchQuery, equals('a'));
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.searchError, contains('minst 2 tecken'));
      });

      test('should clear search state explicitly', () {
        // Arrange - initial state from setUp
        
        // Act
        viewModel.clearSearch();
        
        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.searchResults, isEmpty);
        expect(viewModel.searchError, isNull);
      });
    });

    group('Friend Request Operations', () {
      test('should send friend request successfully', () async {
        // Arrange
        when(() => mockManagementOps.sendFriendRequest('user123', message: 'Hi!'))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.sendFriendRequest('user123', message: 'Hi!');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagementOps.sendFriendRequest('user123', message: 'Hi!')).called(1);
      });

      test('should accept friend request', () async {
        // Arrange
        when(() => mockManagementOps.acceptFriendRequest('req123'))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.acceptFriendRequest('req123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagementOps.acceptFriendRequest('req123')).called(1);
      });

      test('should reject friend request', () async {
        // Arrange
        when(() => mockManagementOps.rejectFriendRequest('req123'))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.rejectFriendRequest('req123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagementOps.rejectFriendRequest('req123')).called(1);
      });

      test('should cancel sent request', () async {
        // Arrange
        when(() => mockManagementOps.cancelFriendRequest('req123'))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.cancelSentRequest('req123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagementOps.cancelFriendRequest('req123')).called(1);
      });

      test('should remove friend', () async {
        // Arrange
        when(() => mockManagementOps.removeFriend('friend123'))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await viewModel.removeFriend('friend123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagementOps.removeFriend('friend123')).called(1);
      });
    });

    group('Group Management', () {
      test('should create group successfully', () async {
        // Arrange
        when(() => mockCategoryOps.createCategory(
          name: 'Family',
          description: 'Close family',
          initialMemberIds: ['f1', 'f2'],
        )).thenAnswer((_) async => 'category-123');
        
        // Act
        final result = await viewModel.createGroup(
          name: 'Family',
          description: 'Close family',
          selectedFriendIds: ['f1', 'f2'],
        );
        
        // Assert
        expect(result, isTrue);
        expect(viewModel.isCreatingGroup, isFalse);
        verify(() => mockCategoryOps.createCategory(
          name: 'Family',
          description: 'Close family',
          initialMemberIds: ['f1', 'f2'],
        )).called(1);
      });

      test('should handle group creation failure', () async {
        // Arrange
        when(() => mockCategoryOps.createCategory(
          name: any(named: 'name'),
          description: any(named: 'description'),
          initialMemberIds: any(named: 'initialMemberIds'),
        )).thenAnswer((_) async => null);
        when(() => mockFriendsService.error).thenReturn('Creation failed');
        
        // Act
        final result = await viewModel.createGroup(name: 'Test');
        
        // Assert
        expect(result, isFalse);
        expect(viewModel.groupCreationError, contains('Creation failed'));
      });

      test('should get friends in group', () {
        // Arrange
        final friendsInGroup = [
          UserProfileFactory.build(uid: 'f1'),
          UserProfileFactory.build(uid: 'f2'),
        ];
        when(() => mockCategoryOps.getFriendsInCategory('group123'))
            .thenReturn(friendsInGroup);
        
        // Act
        final result = viewModel.getFriendsInGroup('group123');
        
        // Assert
        expect(result, equals(friendsInGroup));
      });

      test('should check group name availability', () {
        // Arrange
        when(() => mockCategoryOps.getCategoryByName('Family'))
            .thenReturn(FakeFriendCategory(id: 'g1', name: 'Family'));
        when(() => mockCategoryOps.getCategoryByName('Work'))
            .thenReturn(null);
        
        // Act & Assert
        expect(viewModel.isGroupNameAvailable('Family'), isFalse);
        expect(viewModel.isGroupNameAvailable('Work'), isTrue);
      });

      test('should search groups', () {
        // Arrange
        final groups = [
          FakeFriendCategory(id: 'g1', name: 'Family'),
          FakeFriendCategory(id: 'g2', name: 'Work Friends'),
          FakeFriendCategory(id: 'g3', name: 'Sports'),
        ];
        when(() => mockFriendsService.categoriesList).thenReturn(groups);
        
        // Act
        final results = viewModel.searchGroups('fam');
        
        // Assert
        expect(results, hasLength(1));
        expect(results.first.name, equals('Family'));
      });
    });

    group('Friend Selection', () {
      test('should toggle friend selection', () {
        // Arrange - initial state from setUp
        
        // Act
        viewModel.toggleFriendSelection('friend1');
        
        // Assert
        expect(viewModel.selectedFriendIds, contains('friend1'));
        expect(viewModel.hasSelectedFriends, isTrue);
        expect(viewModel.selectedFriendsCount, equals(1));
        
        // Act - toggle again
        viewModel.toggleFriendSelection('friend1');
        
        // Assert
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.hasSelectedFriends, isFalse);
      });

      test('should select all friends', () {
        // Arrange
        final friends = [
          UserProfileFactory.build(uid: 'f1'),
          UserProfileFactory.build(uid: 'f2'),
          UserProfileFactory.build(uid: 'f3'),
        ];
        when(() => mockFriendsService.friends).thenReturn(friends);
        
        // Act
        viewModel.selectAllFriends();
        
        // Assert
        expect(viewModel.selectedFriendIds, hasLength(3));
        expect(viewModel.selectedFriendIds, containsAll(['f1', 'f2', 'f3']));
      });

      test('should clear selection', () {
        // Arrange
        viewModel.toggleFriendSelection('f1');
        viewModel.toggleFriendSelection('f2');
        expect(viewModel.selectedFriendsCount, equals(2));
        
        // Act
        viewModel.clearSelection();
        
        // Assert
        expect(viewModel.selectedFriendIds, isEmpty);
      });

      test('should get selected friends as UserProfile objects', () {
        // Arrange
        final friends = [
          UserProfileFactory.build(uid: 'f1', displayName: 'Friend 1'),
          UserProfileFactory.build(uid: 'f2', displayName: 'Friend 2'),
          UserProfileFactory.build(uid: 'f3', displayName: 'Friend 3'),
        ];
        when(() => mockFriendsService.friends).thenReturn(friends);
        
        // Act
        viewModel.toggleFriendSelection('f1');
        viewModel.toggleFriendSelection('f3');
        
        final selected = viewModel.getSelectedFriends();
        
        // Assert
        expect(selected, hasLength(2));
        expect(selected.map((f) => f.uid), containsAll(['f1', 'f3']));
      });
    });

    group('Friendship Status', () {
      test('should determine friendship status correctly', () {
        // Arrange
        final friends = [UserProfileFactory.build(uid: 'friend1')];
        final outgoing = [
          FakeFriendRequest(id: 'r1', fromUserId: 'current', toUserId: 'pending1'),
        ];
        final incoming = [
          FakeFriendRequest(id: 'r2', fromUserId: 'pending2', toUserId: 'current'),
        ];
        
        when(() => mockFriendsService.friends).thenReturn(friends);
        when(() => mockFriendsService.outgoingRequests).thenReturn(outgoing);
        when(() => mockFriendsService.incomingRequests).thenReturn(incoming);
        
        // Act & Assert
        expect(viewModel.getFriendshipStatus('friend1'), equals(FriendshipStatus.friends));
        expect(viewModel.getFriendshipStatus('pending1'), equals(FriendshipStatus.requestSent));
        expect(viewModel.getFriendshipStatus('pending2'), equals(FriendshipStatus.requestReceived));
        expect(viewModel.getFriendshipStatus('unknown'), equals(FriendshipStatus.none));
      });

      test('should check if can send friend request', () {
        // Arrange - initial state
        
        // Act & Assert - test current user
        expect(viewModel.canSendFriendRequest('mock-user-id'), isFalse); // Same as current user
        expect(viewModel.canSendFriendRequest('other-user'), isTrue);
        
        // Arrange - add as friend
        when(() => mockFriendsService.friends).thenReturn([
          UserProfileFactory.build(uid: 'other-user'),
        ]);
        
        // Assert - check again
        expect(viewModel.canSendFriendRequest('other-user'), isFalse);
      });
    });

    group('User Profile Management', () {
      test('should load user profiles for requests', () async {
        // Arrange
        final incoming = [
          FakeFriendRequest(id: 'r1', fromUserId: 'user1', toUserId: 'current'),
        ];
        final outgoing = [
          FakeFriendRequest(id: 'r2', fromUserId: 'current', toUserId: 'user2'),
        ];
        final profiles = [
          UserProfileFactory.build(uid: 'user1', displayName: 'User One'),
          UserProfileFactory.build(uid: 'user2', displayName: 'User Two'),
        ];
        
        when(() => mockFriendsService.incomingRequests).thenReturn(incoming);
        when(() => mockFriendsService.outgoingRequests).thenReturn(outgoing);
        when(() => mockUserService.getUserProfiles(['user1', 'user2']))
            .thenAnswer((_) async => profiles);
        
        // Act
        await viewModel.loadUserProfilesForRequests();
        
        // Assert
        expect(viewModel.getUserProfile('user1')?.displayName, equals('User One'));
        expect(viewModel.getUserProfile('user2')?.displayName, equals('User Two'));
        verify(() => mockUserService.getUserProfiles(any())).called(1);
      });

      test('should get display name with fallback', () {
        // Arrange - initial state
        
        // Act & Assert - test unknown user
        expect(viewModel.getDisplayNameForUser('unknown123'), contains('Användare unknow'));
        
        // Arrange - add profile
        viewModel.loadUserProfilesForRequests(); // Initialize cache
        final profile = UserProfileFactory.build(uid: 'user123', displayName: 'John Doe');
        when(() => mockUserService.getUserProfiles(['user123']))
            .thenAnswer((_) async => [profile]);
        
        // Act & Assert - test with profile
        expect(viewModel.getDisplayNameForUser('user123'), contains('Användare user12'));
      });

      test('should clear user profiles cache', () {
        // Arrange - initial state
        
        // Act
        viewModel.clearUserProfilesCache();
        
        // Assert
        expect(viewModel.getUserProfile('any'), isNull);
      });
    });

    group('Mutual Friends', () {
      test('should get mutual friends', () async {
        // Arrange
        final mutualFriends = [
          UserProfileFactory.build(uid: 'mutual1'),
          UserProfileFactory.build(uid: 'mutual2'),
        ];
        when(() => mockManagementOps.getMutualFriends('user123'))
            .thenAnswer((_) async => mutualFriends);
        
        // Act
        final result = await viewModel.getMutualFriends('user123');
        
        // Assert
        expect(result, equals(mutualFriends));
        verify(() => mockManagementOps.getMutualFriends('user123')).called(1);
      });
    });

    group('Error Handling', () {
      test('should clear all errors', () {
        // Arrange - initial state
        
        // Act
        viewModel.clearError();
        
        // Assert
        verify(() => mockFriendsService.clearError()).called(1);
        expect(viewModel.searchError, isNull);
        expect(viewModel.groupCreationError, isNull);
      });

      test('should handle refresh', () async {
        // Arrange - initial state
        
        // Act
        await viewModel.refresh();
        
        // Assert - should clear cache and load profiles
        expect(viewModel.getUserProfile('any'), isNull);
      });
    });

    group('Lifecycle', () {
      test('should notify listeners when services change', () async {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act - simulate service updates
        final friendsListener = verify(() => mockFriendsService.addListener(captureAny())).captured.first;
        verify(() => mockUserService.addListener(captureAny())).captured.first;
        
        friendsListener();
        // Wait for async operation
        await Future.delayed(Duration(milliseconds: 10));
        
        // Assert
        expect(notificationCount, greaterThan(0));
      });

      test('should cleanup on dispose', () {
        // Arrange
        final testViewModel = FriendsViewModel(
          friendsService: mockFriendsService,
          userService: mockUserService,
        );
        
        // Act
        testViewModel.dispose();
        
        // Assert
        verify(() => mockFriendsService.removeListener(any())).called(1);
        verify(() => mockUserService.removeListener(any())).called(1);
      });
    });
  });
}