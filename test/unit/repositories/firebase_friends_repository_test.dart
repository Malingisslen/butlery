/// Comprehensive unit tests for FirebaseFriendsRepository (facade pattern).
///
/// Tests the facade repository coordination layer for friend management functionality.
/// Since FirebaseFriendsRepository delegates to 4 specialized sub-repositories,
/// these tests focus on permission validation and facade-level coordination.
/// Sub-repository functionality should be tested separately in their own test files.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseFriendsRepository - Social Friend Management Facade', () {
    late FirebaseFriendsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: 'user-123');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseFriendsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation - User Profiles', () {
      test('should allow user to create their own profile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final canCreate =
            await repository.validateCreatePermission('user-123', profile);

        // Assert
        expect(canCreate, isTrue);
      });

      test('should reject user from creating another user\'s profile',
          () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canCreate =
            await repository.validateCreatePermission('user-123', profile);

        // Assert
        expect(canCreate, isFalse);
      });

      test('should allow anyone to read public profiles', () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canRead = await repository.validateReadPermission(
            'user-123', 'other-user', profile);

        // Assert
        expect(canRead, isTrue); // Public profiles are readable
      });

      test('should allow user to update their own profile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final canUpdate = await repository.validateUpdatePermission(
            'user-123', 'user-123', profile);

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject user from updating another user\'s profile',
          () async {
        // Arrange
        final profile = _createUserProfile('other-user');

        // Act
        final canUpdate = await repository.validateUpdatePermission(
            'user-123', 'other-user', profile);

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow user to delete their own profile', () async {
        // Act
        final canDelete =
            await repository.validateDeletePermission('user-123', 'user-123');

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject user from deleting another user\'s profile',
          () async {
        // Act
        final canDelete =
            await repository.validateDeletePermission('user-123', 'other-user');

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Friend Request Operations - Delegation', () {
      // NOTE: These tests verify basic delegation to FriendRequestRepository.
      // Full request lifecycle testing is done in friend_request_repository_test.dart

      test('should handle request existence check', () async {
        // Arrange
        const fromUserId = 'user-123';
        const toUserId = 'user-456';

        // Seed a friend request
        await _seedFriendRequest(fakeFirestore, 'request-1', {
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        // Act
        final exists = await repository.requestExists(fromUserId, toUserId);

        // Assert
        expect(exists, isTrue);
      });

      test('should return false when no request exists', () async {
        // Act
        final exists = await repository.requestExists('user-123', 'user-456');

        // Assert
        expect(exists, isFalse);
      });

      test('should fetch request by id', () async {
        // Arrange
        const requestId = 'request-1';
        await _seedFriendRequest(fakeFirestore, requestId, {
          'fromUserId': 'user-123',
          'toUserId': 'user-456',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        // Act
        final request = await repository.fetchRequest(requestId);

        // Assert
        expect(request, isNotNull);
        expect(request!.id, equals(requestId));
        expect(request.fromUserId, equals('user-123'));
        expect(request.toUserId, equals('user-456'));
        expect(request.status, equals(FriendRequestStatus.pending));
      });

      test('should return null when fetching non-existent request', () async {
        // Act
        final request = await repository.fetchRequest('nonexistent');

        // Assert
        expect(request, isNull);
      });

      test('should stream incoming friend requests for user', () async {
        // Arrange
        const userId = 'user-123';
        await _seedFriendRequest(fakeFirestore, 'request-1', {
          'fromUserId': 'user-456',
          'toUserId': userId,
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });
        await _seedFriendRequest(fakeFirestore, 'request-2', {
          'fromUserId': 'user-789',
          'toUserId': userId,
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        // Act
        final stream = repository.incomingRequestsStream(userId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendRequest>>((requests) {
            return requests.length == 2 &&
                requests.every((r) => r.toUserId == userId && r.isPending);
          })),
        );
      });

      test('should stream sent friend requests for user', () async {
        // Arrange
        const userId = 'user-123';
        await _seedFriendRequest(fakeFirestore, 'request-1', {
          'fromUserId': userId,
          'toUserId': 'user-456',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });
        await _seedFriendRequest(fakeFirestore, 'request-2', {
          'fromUserId': userId,
          'toUserId': 'user-789',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        // Act
        final stream = repository.sentRequestsStream(userId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendRequest>>((requests) {
            return requests.length == 2 &&
                requests.every((r) => r.fromUserId == userId && r.isPending);
          })),
        );
      });
    });

    group('Friend Relationship Operations - Delegation', () {
      // NOTE: These tests verify basic delegation to FriendRelationshipRepository.
      // Full relationship management testing is done in friend_relationship_repository_test.dart

      test('should check if users are friends', () async {
        // Arrange
        const userId1 = 'user-123';
        const userId2 = 'user-456';

        // Seed friend relationship
        await _seedFriendship(fakeFirestore, userId1, userId2);

        // Act
        final areFriends = await repository.areFriends(userId1, userId2);

        // Assert
        expect(areFriends, isTrue);
      });

      test('should return false when users are not friends', () async {
        // Act
        final areFriends = await repository.areFriends('user-123', 'user-456');

        // Assert
        expect(areFriends, isFalse);
      });

      test('should fetch friend IDs for user', () async {
        // Arrange
        const userId = 'user-123';
        await _seedFriendship(fakeFirestore, userId, 'friend-1');
        await _seedFriendship(fakeFirestore, userId, 'friend-2');

        // Act
        final friendIds = await repository.fetchFriendIds(userId);

        // Assert
        expect(friendIds.length, equals(2));
        expect(friendIds, containsAll(['friend-1', 'friend-2']));
      });

      test('should return empty list when user has no friends', () async {
        // Act
        final friendIds = await repository.fetchFriendIds('user-123');

        // Assert
        expect(friendIds, isEmpty);
      });

      test('should fetch friend profiles', () async {
        // Arrange
        await _seedUserProfile(fakeFirestore, 'friend-1', {
          'displayName': 'Friend One',
          'email': 'friend1@example.com',
          'isSearchable': true,
          'allowEmailSearch': false,
          'publicRecipeCount': 5,
          'friendsCount': 10,
          'joinedAt': Timestamp.now(),
          'lastActiveAt': Timestamp.now(),
          'isOnline': false,
        });
        await _seedUserProfile(fakeFirestore, 'friend-2', {
          'displayName': 'Friend Two',
          'email': 'friend2@example.com',
          'isSearchable': true,
          'allowEmailSearch': false,
          'publicRecipeCount': 3,
          'friendsCount': 8,
          'joinedAt': Timestamp.now(),
          'lastActiveAt': Timestamp.now(),
          'isOnline': true,
        });

        // Act
        final profiles =
            await repository.fetchFriendProfiles(['friend-1', 'friend-2']);

        // Assert
        expect(profiles.length, equals(2));
        expect(profiles[0].uid, equals('friend-1'));
        expect(profiles[0].displayName, equals('Friend One'));
        expect(profiles[1].uid, equals('friend-2'));
        expect(profiles[1].displayName, equals('Friend Two'));
      });

      test('should handle empty profile list', () async {
        // Act
        final profiles = await repository.fetchFriendProfiles([]);

        // Assert
        expect(profiles, isEmpty);
      });

      test('should stream friend profiles for real-time updates', () async {
        // Arrange
        const userId = 'user-123';
        await _seedFriendship(fakeFirestore, userId, 'friend-1');
        await _seedUserProfile(fakeFirestore, 'friend-1', {
          'displayName': 'Friend One',
          'email': 'friend1@example.com',
          'isSearchable': true,
          'allowEmailSearch': false,
          'publicRecipeCount': 5,
          'friendsCount': 10,
          'joinedAt': Timestamp.now(),
          'lastActiveAt': Timestamp.now(),
          'isOnline': false,
        });

        // Act
        final stream = repository.friendProfilesStream(userId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<UserProfile>>((profiles) {
            return profiles.length == 1 && profiles.first.uid == 'friend-1';
          })),
        );
      });
    });

    group('Friend Category Operations - Delegation', () {
      // NOTE: These tests verify basic delegation to FriendCategoryRepository.
      // Full category management testing is done in friend_category_repository_test.dart

      test('should fetch user categories', () async {
        // Arrange
        const userId = 'user-123';
        await _seedCategory(fakeFirestore, userId, 'category-1', {
          'ownerId': userId,
          'name': 'Family',
          'description': 'Family members',
          'emoji': '👨‍👩‍👧‍👦',
          'friendUserIds': ['friend-1', 'friend-2'],
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sortOrder': 0,
          'isDefault': false,
        });
        await _seedCategory(fakeFirestore, userId, 'category-2', {
          'ownerId': userId,
          'name': 'Work',
          'description': 'Colleagues',
          'emoji': '💼',
          'friendUserIds': ['friend-3'],
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sortOrder': 1,
          'isDefault': false,
        });

        // Act
        final categories = await repository.fetchCategories(userId);

        // Assert
        expect(categories.length, equals(2));
        expect(categories[0].name, equals('Family'));
        expect(categories[0].friendCount, equals(2));
        expect(categories[1].name, equals('Work'));
        expect(categories[1].friendCount, equals(1));
      });

      test('should return empty list when user has no categories', () async {
        // Act
        final categories = await repository.fetchCategories('user-123');

        // Assert
        expect(categories, isEmpty);
      });

      test('should get category by id', () async {
        // Arrange
        const userId = 'user-123';
        const categoryId = 'category-1';
        await _seedCategory(fakeFirestore, userId, categoryId, {
          'ownerId': userId,
          'name': 'Family',
          'description': 'Family members',
          'emoji': '👨‍👩‍👧‍👦',
          'friendUserIds': ['friend-1'],
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sortOrder': 0,
          'isDefault': false,
        });

        // Act
        final category = await repository.getCategory(userId, categoryId);

        // Assert
        expect(category, isNotNull);
        expect(category!.id, equals(categoryId));
        expect(category.name, equals('Family'));
      });

      test('should return null when category does not exist', () async {
        // Act
        final category =
            await repository.getCategory('user-123', 'nonexistent');

        // Assert
        expect(category, isNull);
      });

      test('should stream categories for real-time updates', () async {
        // Arrange
        const userId = 'user-123';
        await _seedCategory(fakeFirestore, userId, 'category-1', {
          'ownerId': userId,
          'name': 'Family',
          'description': 'Family members',
          'emoji': '👨‍👩‍👧‍👦',
          'friendUserIds': ['friend-1'],
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sortOrder': 0,
          'isDefault': false,
        });

        // Act
        final stream = repository.categoriesStream(userId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendCategory>>((categories) {
            return categories.length == 1 && categories.first.name == 'Family';
          })),
        );
      });
    });

    group('Coordinated Operations - Multi-Repository', () {
      // These tests verify operations that coordinate multiple sub-repositories

      test(
          'acceptFriendRequest should accept request and create mutual friendship',
          () async {
        // Arrange
        const requestId = 'request-1';
        const fromUserId = 'user-456';
        const toUserId = 'user-123'; // Current user

        await _seedFriendRequest(fakeFirestore, requestId, {
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        // Act
        final success = await repository.acceptFriendRequest(requestId);

        // Assert
        expect(success, isTrue);

        // Verify request was updated to accepted
        final requestDoc = await fakeFirestore
            .collection('friend_requests')
            .doc(requestId)
            .get();
        expect(requestDoc.exists, isTrue);
        expect(requestDoc.data()!['status'], equals('accepted'));

        // Verify mutual friendship was created
        final areFriends = await repository.areFriends(fromUserId, toUserId);
        expect(areFriends, isTrue);
      },
          skip:
              'Requires server timestamp support - tested in integration tests');

      test(
          'getComprehensiveFriendStatistics should aggregate stats from all repositories',
          () async {
        // Arrange
        const userId = 'user-123';

        // Seed data for comprehensive statistics
        await _seedFriendship(fakeFirestore, userId, 'friend-1');
        await _seedFriendship(fakeFirestore, userId, 'friend-2');

        await _seedFriendRequest(fakeFirestore, 'request-1', {
          'fromUserId': 'user-456',
          'toUserId': userId,
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });

        await _seedCategory(fakeFirestore, userId, 'category-1', {
          'ownerId': userId,
          'name': 'Family',
          'friendUserIds': ['friend-1'],
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'sortOrder': 0,
          'isDefault': false,
        });

        // Act
        final stats = await repository.getComprehensiveFriendStatistics(userId);

        // Assert
        expect(stats, isNotNull);
        expect(stats.containsKey('friends'), isTrue);
        expect(stats.containsKey('requests'), isTrue);
        expect(stats.containsKey('categories'), isTrue);
        expect(stats.containsKey('invitations'), isTrue);
      });

      test('getFriendsWithProfiles should fetch friends and their profiles',
          () async {
        // Arrange
        const userId = 'user-123';
        await _seedFriendship(fakeFirestore, userId, 'friend-1');

        await _seedUserProfile(fakeFirestore, 'friend-1', {
          'displayName': 'Friend One',
          'email': 'friend1@example.com',
          'isSearchable': true,
          'allowEmailSearch': false,
          'publicRecipeCount': 5,
          'friendsCount': 10,
          'joinedAt': Timestamp.now(),
          'lastActiveAt': Timestamp.now(),
          'isOnline': false,
        });

        // Act
        final profiles = await repository.getFriendsWithProfiles(userId);

        // Assert
        expect(profiles.length, equals(1));
        expect(profiles.first.uid, equals('friend-1'));
        expect(profiles.first.displayName, equals('Friend One'));
      });

      test('getMutualFriends should find common friends between two users',
          () async {
        // Arrange
        const userId1 = 'user-123';
        const userId2 = 'user-456';
        const mutualFriend = 'user-789';

        // User1 and User2 both have mutualFriend as friend
        await _seedFriendship(fakeFirestore, userId1, mutualFriend);
        await _seedFriendship(fakeFirestore, userId2, mutualFriend);

        // Act
        final mutualFriends =
            await repository.getMutualFriends(userId1, userId2);

        // Assert
        expect(mutualFriends, contains(mutualFriend));
      });
    });

    group('Model Integration', () {
      test('should correctly serialize and deserialize UserProfile', () async {
        // Arrange
        final profile = _createUserProfile('user-123');
        const profileId = 'user-123';

        // Act - Seed and fetch
        await _seedUserProfile(fakeFirestore, profileId, profile.toFirestore());
        final doc = await fakeFirestore
            .collection('public_profiles')
            .doc(profileId)
            .get();
        final retrieved = UserProfile.fromMap(doc.id, doc.data()!);

        // Assert
        expect(retrieved.uid, equals(profile.uid));
        expect(retrieved.displayName, equals(profile.displayName));
        expect(retrieved.email, equals(profile.email));
        expect(retrieved.friendsCount, equals(profile.friendsCount));
      });

      test('should correctly serialize and deserialize FriendRequest',
          () async {
        // Arrange
        final request = FriendRequest(
          id: 'request-1',
          fromUserId: 'user-123',
          toUserId: 'user-456',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        // Act - Seed and fetch
        await _seedFriendRequest(
            fakeFirestore, request.id, request.toFirestore());
        final doc = await fakeFirestore
            .collection('friend_requests')
            .doc(request.id)
            .get();
        final retrieved = FriendRequest.fromMap(doc.id, doc.data()!);

        // Assert
        expect(retrieved.id, equals(request.id));
        expect(retrieved.fromUserId, equals(request.fromUserId));
        expect(retrieved.toUserId, equals(request.toUserId));
        expect(retrieved.status, equals(request.status));
      });

      test('should correctly serialize and deserialize FriendCategory',
          () async {
        // Arrange
        final category = FriendCategory(
          id: 'category-1',
          ownerId: 'user-123',
          name: 'Family',
          emoji: '👨‍👩‍👧‍👦',
          friendUserIds: ['friend-1', 'friend-2'],
          sortOrder: 0,
        );

        // Act - Seed and fetch
        await _seedCategory(fakeFirestore, category.ownerId, category.id,
            category.toFirestore());
        final doc = await fakeFirestore
            .collection('users')
            .doc(category.ownerId)
            .collection('friendCategories')
            .doc(category.id)
            .get();
        final retrieved = FriendCategory.fromMap(doc.id, doc.data()!);

        // Assert
        expect(retrieved.id, equals(category.id));
        expect(retrieved.ownerId, equals(category.ownerId));
        expect(retrieved.name, equals(category.name));
        expect(retrieved.friendUserIds, equals(category.friendUserIds));
      });
    });

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, equals('public_profiles'));
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final id = repository.getId(profile);

        // Assert
        expect(id, equals('user-123'));
      });

      test('should convert to/from Firestore correctly', () {
        // Arrange
        final profile = _createUserProfile('user-123');

        // Act
        final firestoreData = repository.toFirestore(profile);

        // Assert
        expect(firestoreData['displayName'], equals(profile.displayName));
        expect(firestoreData['email'], equals(profile.email));
        expect(firestoreData['friendsCount'], equals(profile.friendsCount));
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test user profile
UserProfile _createUserProfile(String uid) {
  return UserProfile(
    uid: uid,
    displayName: 'Test User',
    email: 'test@example.com',
    avatarUrl: 'https://example.com/avatar.jpg',
    isSearchable: true,
    allowEmailSearch: false,
    publicRecipeCount: 5,
    friendsCount: 10,
    joinedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
    isOnline: false,
  );
}

/// Seed friend request into fake Firestore
Future<void> _seedFriendRequest(
  FakeFirebaseFirestore firestore,
  String requestId,
  Map<String, dynamic> data,
) async {
  await firestore.collection('friend_requests').doc(requestId).set(data);
}

/// Seed friendship into fake Firestore
Future<void> _seedFriendship(
  FakeFirebaseFirestore firestore,
  String userId,
  String friendId,
) async {
  // Add friendId to userId's friends list
  await firestore
      .collection('users')
      .doc(userId)
      .collection('friends')
      .doc(friendId)
      .set({'userId': friendId, 'createdAt': Timestamp.now()});

  // Add userId to friendId's friends list (mutual friendship)
  await firestore
      .collection('users')
      .doc(friendId)
      .collection('friends')
      .doc(userId)
      .set({'userId': userId, 'createdAt': Timestamp.now()});
}

/// Seed user profile into fake Firestore
Future<void> _seedUserProfile(
  FakeFirebaseFirestore firestore,
  String userId,
  Map<String, dynamic> data,
) async {
  await firestore.collection('public_profiles').doc(userId).set(data);
}

/// Seed friend category into fake Firestore
Future<void> _seedCategory(
  FakeFirebaseFirestore firestore,
  String userId,
  String categoryId,
  Map<String, dynamic> data,
) async {
  await firestore
      .collection('users')
      .doc(userId)
      .collection('friendCategories')
      .doc(categoryId)
      .set(data);
}
