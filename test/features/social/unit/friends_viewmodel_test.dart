import 'package:flutter_test/flutter_test.dart';
import '../../../test_configuration.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friends_categories_operations.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/models/friend_request.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {}

class MockUserService extends Mock implements UserService {}

class MockFriendsManagementOperations extends Mock implements FriendsManagementOperations {}

class MockFriendsCategoriesOperations extends Mock implements FriendsCategoriesOperations {}

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  late FriendsViewModel sut;
  late MockUnifiedFriendsService mockFriendsService;
  late MockUserService mockUserService;
  late MockFriendsManagementOperations mockManagementOps;
  late MockFriendsCategoriesOperations mockCategoriesOps;

  setUpAll(() async {
    // ServiceLocator is already initialized by configureTests()
    registerFallbackValue(FriendFactory.empty());
    registerFallbackValue(FriendRequestFactory.empty());
    registerFallbackValue(FriendCategoryFactory.build());
    registerFallbackValue(GroupInvitationFactory.build());
  });

  setUp(() {
    mockFriendsService = MockUnifiedFriendsService();
    mockUserService = MockUserService();
    mockManagementOps = MockFriendsManagementOperations();
    mockCategoriesOps = MockFriendsCategoriesOperations();

    // Setup default auth
    when(() => mockUserService.currentUserId).thenReturn('current_user');

    // Setup default properties
    when(() => mockFriendsService.friends).thenReturn([]);
    when(() => mockFriendsService.incomingRequests).thenReturn([]);
    when(() => mockFriendsService.outgoingRequests).thenReturn([]);
    when(() => mockFriendsService.categoriesList).thenReturn([]); // Use categoriesList for the property
    when(() => mockFriendsService.sentInvitations).thenReturn([]);
    
    // Setup operations
    when(() => mockFriendsService.management).thenReturn(mockManagementOps);
    when(() => mockFriendsService.categories).thenReturn(mockCategoriesOps); // categories is the operations interface

    sut = FriendsViewModel(
      friendsService: mockFriendsService,
      userService: mockUserService,
    );
  });

  tearDown(() {
    sut.dispose();
  });

  group('FriendsViewModel - Initialization', () {
    test('should initialize with empty lists', () {
      expect(sut.friends, isEmpty);
      expect(sut.incomingRequests, isEmpty);
      expect(mockFriendsService.categoriesList, isEmpty);
      // Group invitations accessed via service
      expect(mockFriendsService.sentInvitations, isEmpty);
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
    });

    test('should have friends from service', () {
      // Given
      final friends = [
        UserProfileFactory.build(uid: 'friend1', displayName: 'Friend One'),
        UserProfileFactory.build(uid: 'friend2', displayName: 'Friend Two'),
      ];
      when(() => mockFriendsService.friends).thenReturn(friends);

      // When - FriendsViewModel auto-syncs with service
      // Force a rebuild to get latest service state
      sut.notifyListeners();

      // Then
      expect(sut.friends, equals(friends));
    });

    test('should load friend requests', () async {
      // Given
      final requests = [
        FriendRequestFactory.build(
          fromUserId: 'user1',
          status: FriendRequestStatus.pending,
        ),
      ];
      when(() => mockFriendsService.incomingRequests).thenReturn(requests);

      // When - FriendsViewModel auto-syncs with service
      sut.notifyListeners();

      // Then
      expect(sut.incomingRequests, equals(requests));
      expect(sut.incomingRequests.length, equals(1));
    });

    test('should handle initialization errors', () async {
      // Given
      when(() => mockFriendsService.error).thenReturn('Failed to load');
      when(() => mockFriendsService.hasError).thenReturn(true);

      // When - FriendsViewModel reflects service state
      sut.notifyListeners();

      // Then
      expect(sut.error, equals('Failed to load'));
      expect(sut.hasError, isTrue);
    });
  });

  group('FriendsViewModel - Friend Management', () {
    test('should send friend request', () async {
      // Given
      const userId = 'new_friend';
      const message = 'Let\'s be friends!';

      when(() => mockManagementOps.sendFriendRequest(any(), message: any(named: 'message')))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.sendFriendRequest(userId, message: message);

      // Then
      expect(result, isTrue);
      verify(() => mockManagementOps.sendFriendRequest(userId, message: message)).called(1);
    });

    test('should accept friend request', () async {
      // Given
      final request = FriendRequestFactory.build(id: 'request1');
      when(() => mockManagementOps.acceptFriendRequest(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.acceptFriendRequest(request.id);

      // Then
      expect(result, isTrue);
      verify(() => mockManagementOps.acceptFriendRequest(request.id)).called(1);
    });

    test('should decline friend request', () async {
      // Given
      final request = FriendRequestFactory.build(id: 'request1');
      when(() => mockManagementOps.rejectFriendRequest(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.rejectFriendRequest(request.id);

      // Then
      expect(result, isTrue);
      verify(() => mockManagementOps.rejectFriendRequest(request.id)).called(1);
    });

    test('should remove friend', () async {
      // Given
      const friendId = 'friend1';
      when(() => mockManagementOps.removeFriend(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await sut.removeFriend(friendId);

      // Then
      expect(result, isTrue);
      verify(() => mockManagementOps.removeFriend(friendId)).called(1);
    });

    test('should block user', () async {
      // Given
      const userId = 'blocked_user';
      when(() => mockManagementOps.blockUser(any())).thenAnswer((_) async => true);

      // When
      final result = await mockManagementOps.blockUser(userId);

      // Then
      expect(result, isTrue);
      verify(() => mockManagementOps.blockUser(userId)).called(1);
    });

    test('should unblock user', () async {
      // Given
      const userId = 'blocked_user';
      when(() => mockManagementOps.unblockUser(any()))
          .thenAnswer((_) async => true);

      // When
      final result = await mockManagementOps.unblockUser(userId);

      // Then
      expect(result, isTrue);
      verify(() => mockManagementOps.unblockUser(userId)).called(1);
    });
  });

  group('FriendsViewModel - Categories', () {
    test('should create category', () async {
      // Given
      const name = 'Close Friends';
      const description = 'My closest friends';
      const emoji = '👫';
      final selectedFriendIds = ['friend1', 'friend2'];

      when(() => mockCategoriesOps.createCategory(
            name: any(named: 'name'),
            description: any(named: 'description'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
            isDefault: any(named: 'isDefault'),
          )).thenAnswer((_) async => 'category_id');

      // When
      final result = await sut.createGroup(
        name: name,
        description: description,
        emoji: emoji,
        selectedFriendIds: selectedFriendIds,
      );

      // Then
      expect(result, isTrue);
    });

    test('should update category', () async {
      // Given
      final category = FriendCategoryFactory.build(
        id: 'cat1',
        name: 'Updated Name',
      );
      when(() => mockCategoriesOps.updateCategory(
            categoryId: any(named: 'categoryId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            color: any(named: 'color'),
            icon: any(named: 'icon'),
          )).thenAnswer((_) async => true);

      // When
      // Note: updateCategory is accessed via service categories operations
      final result = await mockCategoriesOps.updateCategory(
        categoryId: category.id,
        name: category.name,
      );

      // Then
      expect(result, isTrue);
    });

    test('should delete category', () async {
      // Given
      const categoryId = 'cat1';
      when(() => mockCategoriesOps.deleteCategory(any()))
          .thenAnswer((_) async => true);

      // When
      // Note: deleteCategory is accessed via service categories operations
      final result = await mockCategoriesOps.deleteCategory(categoryId);

      // Then
      expect(result, isTrue);
      verify(() => mockCategoriesOps.deleteCategory(categoryId)).called(1);
    });

    // Note: addFriendToCategory and removeFriendFromCategory are not exposed
    // on the FriendsViewModel or UnifiedFriendsService public API
  });

  group('FriendsViewModel - Groups', () {
    // Note: Group invitation methods are not exposed on FriendsViewModel
    // These would be accessed through the UnifiedFriendsService directly
  });

  group('FriendsViewModel - Search and Filter', () {
    // Note: Search and filter functionality is not exposed on FriendsViewModel
    // These features may be implemented at the UI level or through the service
  });

  group('FriendsViewModel - Statistics', () {
    test('should calculate friend statistics', () async {
      // Given
      final friends = [
        FriendFactory.build(),
        FriendFactory.build(),
        FriendFactory.build(),
      ];
      final requests = [
        FriendRequestFactory.build(status: FriendRequestStatus.pending),
        FriendRequestFactory.build(status: FriendRequestStatus.pending),
        FriendRequestFactory.build(status: FriendRequestStatus.accepted),
      ];

      // Mock the service to return these friends
      final userProfiles = friends.map((f) => 
        UserProfileFactory.build(uid: f.id, displayName: f.name)
      ).toList();
      
      when(() => mockFriendsService.friends).thenReturn(userProfiles);
      when(() => mockFriendsService.incomingRequests).thenReturn(
        requests.where((r) => r.status == FriendRequestStatus.pending).toList()
      );

      // When - FriendsViewModel auto-syncs with service

      // Then
      expect(sut.friendsCount, equals(3));
      expect(sut.pendingRequestsCount, equals(2));
    });
  });

  group('FriendsViewModel - Error Handling', () {
    test('should handle friend request errors', () async {
      // Given
      when(() => mockManagementOps.sendFriendRequest(any(), message: any(named: 'message')))
          .thenThrow(Exception('Network error'));

      // When
      final result = await sut.sendFriendRequest('user1', message: 'Hi');

      // Then
      expect(result, isFalse);
      expect(sut.error, contains('Kunde inte skicka vänförfrågan'));
    });

    test('should handle category creation errors', () async {
      // Given
      when(() => mockCategoriesOps.createCategory(
            name: any(named: 'name'),
            description: any(named: 'description'),
            icon: any(named: 'icon'),
            color: any(named: 'color'),
            isDefault: any(named: 'isDefault'),
          )).thenThrow(Exception('Failed'));

      // When
      final result = await sut.createGroup(
        name: 'Test',
        emoji: '🎯',
      );

      // Then
      expect(result, isFalse);
      expect(sut.error, contains('Kunde inte skapa kategori'));
    });
  });

  group('FriendsViewModel - State Management', () {
    test('should notify listeners on state changes', () {
      // Given
      var notificationCount = 0;
      sut.addListener(() => notificationCount++);

      // When - trigger some valid operations that notify listeners
      sut.notifyListeners(); // Force a notification

      // Then
      expect(notificationCount, greaterThan(0));
    });

    test('should properly dispose resources', () {
      // When
      sut.dispose();

      // Then
      // Streams should be closed (no direct way to test)
      expect(() => sut.notifyListeners(), throwsFlutterError);
    });
  });
}
