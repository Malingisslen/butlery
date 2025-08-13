// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/models/user_profile.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test-specific mocks
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockWriteBatch extends Mock implements WriteBatch {}
class MockAggregateQuerySnapshot extends Mock implements AggregateQuerySnapshot {}
class MockAggregateQuery extends Mock implements AggregateQuery {}

// Fake classes for any() matching
class FakeFieldValue extends Fake implements FieldValue {}
class FakeFieldPath extends Fake implements FieldPath {}
class FakeTimestamp extends Fake implements Timestamp {}

void main() {
  group('FriendRelationshipRepository', () {
    late FriendRelationshipRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockPublicProfilesCollection;
    late MockCollectionReference mockUsersCollection;
    late MockCollectionReference mockFriendsSubcollection;
    late MockDocumentReference mockUserDoc;
    late MockDocumentReference mockProfileDoc;
    late MockDocumentReference mockFriendDoc;
    late MockAuthRepository mockAuthRepository;
    late MockWriteBatch mockBatch;
    late MockQuery mockQuery;
    
    // Test data
    const userId1 = 'user-123';
    const userId2 = 'user-456';
    const userId3 = 'user-789';
    const currentUserId = 'current-user';
    
    late Map<String, dynamic> userProfileData1;
    late Map<String, dynamic> userProfileData2;
    late UserProfile testProfile1;
    
    setUpAll(() {
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(FieldValue.serverTimestamp());
      registerFallbackValue(FieldValue.increment(1));
      registerFallbackValue(FieldValue.increment(-1));
      registerFallbackValue(FakeFieldPath());
      registerFallbackValue(FieldPath.documentId);
      registerFallbackValue(FakeTimestamp());
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockPublicProfilesCollection = MockCollectionReference();
      mockUsersCollection = MockCollectionReference();
      mockFriendsSubcollection = MockCollectionReference();
      mockUserDoc = MockDocumentReference();
      mockProfileDoc = MockDocumentReference();
      mockFriendDoc = MockDocumentReference();
      mockAuthRepository = MockAuthRepository();
      mockBatch = MockWriteBatch();
      mockQuery = MockQuery();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: currentUserId,
        isAuthenticated: true,
      );
      
      // Setup test data
      userProfileData1 = {
        'uid': userId1,
        'displayName': 'Test User 1',
        'email': 'user1@test.com',
        'bio': 'Test bio 1',
        'isSearchable': true,
        'allowEmailSearch': true,
        'publicRecipeCount': 5,
        'friendsCount': 10,
        'joinedAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'lastActiveAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'isOnline': false,
        'notificationsEnabled': true,
      };
      
      userProfileData2 = {
        'uid': userId2,
        'displayName': 'Test User 2',
        'email': 'user2@test.com',
        'bio': 'Test bio 2',
        'isSearchable': true,
        'allowEmailSearch': false,
        'publicRecipeCount': 3,
        'friendsCount': 8,
        'joinedAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'lastActiveAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'isOnline': true,
        'notificationsEnabled': false,
      };
      
      testProfile1 = UserProfile(
        uid: userId1,
        displayName: 'Test User 1',
        email: 'user1@test.com',
        bio: 'Test bio 1',
        isSearchable: true,
        allowEmailSearch: true,
        publicRecipeCount: 5,
        friendsCount: 10,
        joinedAt: DateTime.fromMillisecondsSinceEpoch(1234567890000),
        lastActiveAt: DateTime.fromMillisecondsSinceEpoch(1234567890000),
      );
      
      // Setup Firestore structure
      when(() => mockFirestore.collection('public_profiles')).thenReturn(mockPublicProfilesCollection);
      when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      
      when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);
      when(() => mockUserDoc.collection('friends')).thenReturn(mockFriendsSubcollection);
      
      when(() => mockPublicProfilesCollection.doc(any())).thenReturn(mockProfileDoc);
      when(() => mockPublicProfilesCollection.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      
      when(() => mockFriendsSubcollection.doc(any())).thenReturn(mockFriendDoc);
      when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => MockQuerySnapshot());
      when(() => mockFriendsSubcollection.count()).thenReturn(MockAggregateQuery());
      when(() => mockFriendsSubcollection.snapshots()).thenAnswer(
        (_) => Stream.value(MockQuerySnapshot()),
      );
      when(() => mockFriendsSubcollection.where(any(), isGreaterThan: any(named: 'isGreaterThan')))
          .thenReturn(mockQuery);
      when(() => mockFriendsSubcollection.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => MockQuerySnapshot());
      
      when(() => mockFriendDoc.get()).thenAnswer((_) async => MockDocumentSnapshot());
      when(() => mockFriendDoc.set(any())).thenAnswer((_) async {});
      
      when(() => mockProfileDoc.get()).thenAnswer((_) async => MockDocumentSnapshot());
      
      // WriteBatch methods return void
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository
      repository = FriendRelationshipRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('areFriends', () {
      test('should return true if users are friends', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockFriendDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.areFriends(userId1, userId2);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockUserDoc.collection('friends')).called(1);
        verify(() => mockFriendsSubcollection.doc(userId2)).called(1);
      });
      
      test('should return false if users are not friends', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockFriendDoc.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.areFriends(userId1, userId2);
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('addMutualFriends', () {
      test('should add bidirectional friendship and update counts', () async {
        // Act
        await repository.addMutualFriends(userId1, userId2);
        
        // Assert
        // Verify friendship documents are created for both users
        verify(() => mockBatch.set(any(), any())).called(2);
        
        // Verify friend counts are incremented for both users
        verify(() => mockBatch.update(any(), any())).called(2);
        
        // Verify batch is committed
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should set correct timestamp for friendship', () async {
        // Act
        await repository.addMutualFriends(userId1, userId2);
        
        // Assert
        final captured = verify(() => mockBatch.set(any(), captureAny())).captured;
        expect(captured[0], {'addedAt': isA<FieldValue>()});
        expect(captured[1], {'addedAt': isA<FieldValue>()});
      });
    });
    
    group('removeMutualFriends', () {
      test('should remove bidirectional friendship and update counts', () async {
        // Act
        await repository.removeMutualFriends(userId1, userId2);
        
        // Assert
        // Verify friendship documents are deleted for both users
        verify(() => mockBatch.delete(any())).called(2);
        
        // Verify friend counts are decremented for both users
        verify(() => mockBatch.update(any(), any())).called(2);
        
        // Verify batch is committed
        verify(() => mockBatch.commit()).called(1);
      });
    });
    
    group('removeFriend', () {
      test('should remove friend for current user and return true', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: userId1, isAuthenticated: true);
        
        // Act
        final result = await repository.removeFriend(userId2);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockBatch.delete(any())).called(2);
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should return false on error', () async {
        // Arrange
        when(() => mockBatch.commit()).thenThrow(Exception('Network error'));
        
        // Act
        final result = await repository.removeFriend(userId2);
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('fetchFriendIds', () {
      test('should return list of friend IDs', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        final mockDoc3 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn(userId1);
        when(() => mockDoc2.id).thenReturn(userId2);
        when(() => mockDoc3.id).thenReturn(userId3);
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final friendIds = await repository.fetchFriendIds(currentUserId);
        
        // Assert
        expect(friendIds, equals([userId1, userId2, userId3]));
      });
      
      test('should return empty list if no friends', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final friendIds = await repository.fetchFriendIds(currentUserId);
        
        // Assert
        expect(friendIds, isEmpty);
      });
    });
    
    group('fetchFriendProfiles', () {
      test('should fetch profiles in batches of 10', () async {
        // Arrange
        final userIds = List.generate(25, (i) => 'user-$i');
        
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn(userId1);
        when(() => mockDoc1.data()).thenReturn(userProfileData1);
        when(() => mockDoc2.id).thenReturn(userId2);
        when(() => mockDoc2.data()).thenReturn(userProfileData2);
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        await repository.fetchFriendProfiles(userIds);
        
        // Assert
        // Should make 3 batch queries (10 + 10 + 5)
        verify(() => mockPublicProfilesCollection.where(
          FieldPath.documentId,
          whereIn: any(named: 'whereIn'),
        )).called(3);
      });
      
      test('should return empty list for empty input', () async {
        // Act
        final profiles = await repository.fetchFriendProfiles([]);
        
        // Assert
        expect(profiles, isEmpty);
        verifyNever(() => mockPublicProfilesCollection.where(any(), whereIn: any(named: 'whereIn')));
      });
      
      test('should handle profiles correctly', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn(userId1);
        when(() => mockDoc1.data()).thenReturn(userProfileData1);
        when(() => mockDoc2.id).thenReturn(userId2);
        when(() => mockDoc2.data()).thenReturn(userProfileData2);
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final profiles = await repository.fetchFriendProfiles([userId1, userId2]);
        
        // Assert
        expect(profiles.length, equals(2));
        expect(profiles[0].displayName, equals('Test User 1'));
        expect(profiles[1].displayName, equals('Test User 2'));
      });
    });
    
    group('getFriendsWithProfiles', () {
      test('should get friend IDs and fetch their profiles', () async {
        // Arrange
        final mockFriendDoc1 = MockQueryDocumentSnapshot();
        final mockFriendDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockFriendDoc1.id).thenReturn(userId1);
        when(() => mockFriendDoc2.id).thenReturn(userId2);
        
        final mockFriendsSnapshot = MockQuerySnapshot();
        when(() => mockFriendsSnapshot.docs).thenReturn([mockFriendDoc1, mockFriendDoc2]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockFriendsSnapshot);
        
        final mockProfileDoc1 = MockQueryDocumentSnapshot();
        final mockProfileDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockProfileDoc1.id).thenReturn(userId1);
        when(() => mockProfileDoc1.data()).thenReturn(userProfileData1);
        when(() => mockProfileDoc2.id).thenReturn(userId2);
        when(() => mockProfileDoc2.data()).thenReturn(userProfileData2);
        
        final mockProfilesSnapshot = MockQuerySnapshot();
        when(() => mockProfilesSnapshot.docs).thenReturn([mockProfileDoc1, mockProfileDoc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockProfilesSnapshot);
        
        // Act
        final friends = await repository.getFriendsWithProfiles(currentUserId);
        
        // Assert
        expect(friends.length, equals(2));
        expect(friends[0].uid, equals(userId1));
        expect(friends[1].uid, equals(userId2));
      });
    });
    
    group('getMutualFriends', () {
      test('should return mutual friend IDs', () async {
        // Arrange
        // User1's friends
        final mockUser1Friends = [userId2, userId3, 'user-4', 'user-5'];
        final user1Docs = mockUser1Friends.map((id) {
          final doc = MockQueryDocumentSnapshot();
          when(() => doc.id).thenReturn(id);
          return doc;
        }).toList();
        
        // User2's friends
        final mockUser2Friends = [userId1, userId3, 'user-5', 'user-6'];
        final user2Docs = mockUser2Friends.map((id) {
          final doc = MockQueryDocumentSnapshot();
          when(() => doc.id).thenReturn(id);
          return doc;
        }).toList();
        
        final mockSnapshot1 = MockQuerySnapshot();
        final mockSnapshot2 = MockQuerySnapshot();
        when(() => mockSnapshot1.docs).thenReturn(user1Docs);
        when(() => mockSnapshot2.docs).thenReturn(user2Docs);
        
        // Setup different responses for different users
        var callCount = 0;
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? mockSnapshot1 : mockSnapshot2;
        });
        
        // Act
        final mutualFriends = await repository.getMutualFriends(userId1, userId2);
        
        // Assert
        expect(mutualFriends, unorderedEquals([userId3, 'user-5'])); // Common friends
      });
      
      test('should return empty list if no mutual friends', () async {
        // Arrange
        final mockSnapshot1 = MockQuerySnapshot();
        final mockSnapshot2 = MockQuerySnapshot();
        
        final user1Doc = MockQueryDocumentSnapshot();
        when(() => user1Doc.id).thenReturn('user-A');
        
        final user2Doc = MockQueryDocumentSnapshot();
        when(() => user2Doc.id).thenReturn('user-B');
        
        when(() => mockSnapshot1.docs).thenReturn([user1Doc]);
        when(() => mockSnapshot2.docs).thenReturn([user2Doc]);
        
        var callCount = 0;
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? mockSnapshot1 : mockSnapshot2;
        });
        
        // Act
        final mutualFriends = await repository.getMutualFriends(userId1, userId2);
        
        // Assert
        expect(mutualFriends, isEmpty);
      });
    });
    
    group('getMutualFriendsCount', () {
      test('should return count of mutual friends', () async {
        // Arrange
        final mockSnapshot1 = MockQuerySnapshot();
        final mockSnapshot2 = MockQuerySnapshot();
        
        final commonIds = [userId3, 'user-5'];
        final user1Docs = [...commonIds, 'user-4'].map((id) {
          final doc = MockQueryDocumentSnapshot();
          when(() => doc.id).thenReturn(id);
          return doc;
        }).toList();
        
        final user2Docs = [...commonIds, 'user-6'].map((id) {
          final doc = MockQueryDocumentSnapshot();
          when(() => doc.id).thenReturn(id);
          return doc;
        }).toList();
        
        when(() => mockSnapshot1.docs).thenReturn(user1Docs);
        when(() => mockSnapshot2.docs).thenReturn(user2Docs);
        
        var callCount = 0;
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? mockSnapshot1 : mockSnapshot2;
        });
        
        // Act
        final count = await repository.getMutualFriendsCount(userId1, userId2);
        
        // Assert
        expect(count, equals(2));
      });
    });
    
    group('getFriendCount', () {
      test('should return friend count from aggregate query', () async {
        // Arrange
        final mockAggregateQuery = MockAggregateQuery();
        final mockAggregateSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockAggregateSnapshot.count).thenReturn(15);
        when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
        when(() => mockFriendsSubcollection.count()).thenReturn(mockAggregateQuery);
        
        // Act
        final count = await repository.getFriendCount(userId1);
        
        // Assert
        expect(count, equals(15));
      });
      
      test('should return 0 if count is null', () async {
        // Arrange
        final mockAggregateQuery = MockAggregateQuery();
        final mockAggregateSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockAggregateSnapshot.count).thenReturn(null);
        when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
        when(() => mockFriendsSubcollection.count()).thenReturn(mockAggregateQuery);
        
        // Act
        final count = await repository.getFriendCount(userId1);
        
        // Assert
        expect(count, equals(0));
      });
    });
    
    group('friendIdsStream', () {
      test('should stream friend IDs', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn(userId1);
        when(() => mockDoc2.id).thenReturn(userId2);
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockFriendsSubcollection.snapshots()).thenAnswer(
          (_) => Stream.value(mockSnapshot),
        );
        
        // Act
        final stream = repository.friendIdsStream(currentUserId);
        final friendIds = await stream.first;
        
        // Assert
        expect(friendIds, equals([userId1, userId2]));
      });
    });
    
    group('hasFriends', () {
      test('should return true if user has friends', () async {
        // Arrange
        final mockAggregateQuery = MockAggregateQuery();
        final mockAggregateSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockAggregateSnapshot.count).thenReturn(5);
        when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
        when(() => mockFriendsSubcollection.count()).thenReturn(mockAggregateQuery);
        
        // Act
        final hasFriends = await repository.hasFriends(userId1);
        
        // Assert
        expect(hasFriends, isTrue);
      });
      
      test('should return false if user has no friends', () async {
        // Arrange
        final mockAggregateQuery = MockAggregateQuery();
        final mockAggregateSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockAggregateSnapshot.count).thenReturn(0);
        when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
        when(() => mockFriendsSubcollection.count()).thenReturn(mockAggregateQuery);
        
        // Act
        final hasFriends = await repository.hasFriends(userId1);
        
        // Assert
        expect(hasFriends, isFalse);
      });
    });
    
    group('getRecentFriends', () {
      test('should get friends added within specified days', () async {
        // Arrange
        
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn(userId1);
        when(() => mockDoc2.id).thenReturn(userId2);
        
        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockQuery.orderBy('addedAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockFriendsSubcollection.where(
          'addedAt',
          isGreaterThan: any(named: 'isGreaterThan'),
        )).thenReturn(mockQuery);
        
        final mockProfileDoc1 = MockQueryDocumentSnapshot();
        final mockProfileDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockProfileDoc1.id).thenReturn(userId1);
        when(() => mockProfileDoc1.data()).thenReturn(userProfileData1);
        when(() => mockProfileDoc2.id).thenReturn(userId2);
        when(() => mockProfileDoc2.data()).thenReturn(userProfileData2);
        
        final mockProfilesSnapshot = MockQuerySnapshot();
        when(() => mockProfilesSnapshot.docs).thenReturn([mockProfileDoc1, mockProfileDoc2]);
        when(() => mockPublicProfilesCollection.where(
          FieldPath.documentId,
          whereIn: any(named: 'whereIn'),
        )).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockProfilesSnapshot);
        
        // Act
        final recentFriends = await repository.getRecentFriends(userId1, days: 7);
        
        // Assert
        expect(recentFriends.length, equals(2));
        verify(() => mockFriendsSubcollection.where(
          'addedAt',
          isGreaterThan: any(named: 'isGreaterThan'),
        )).called(1);
      });
    });
    
    group('getFriendStatistics', () {
      test('should return comprehensive friend statistics', () async {
        // Arrange
        final mockFriendDoc1 = MockQueryDocumentSnapshot();
        final mockFriendDoc2 = MockQueryDocumentSnapshot();
        final mockFriendDoc3 = MockQueryDocumentSnapshot();
        
        when(() => mockFriendDoc1.id).thenReturn(userId1);
        when(() => mockFriendDoc2.id).thenReturn(userId2);
        when(() => mockFriendDoc3.id).thenReturn(userId3);
        
        final mockFriendsSnapshot = MockQuerySnapshot();
        when(() => mockFriendsSnapshot.docs).thenReturn([mockFriendDoc1, mockFriendDoc2, mockFriendDoc3]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockFriendsSnapshot);
        
        // Setup recent friends query
        final mockRecentDoc = MockQueryDocumentSnapshot();
        when(() => mockRecentDoc.id).thenReturn(userId3);
        
        final mockRecentSnapshot = MockQuerySnapshot();
        when(() => mockRecentSnapshot.docs).thenReturn([mockRecentDoc]);
        
        when(() => mockQuery.orderBy('addedAt', descending: true)).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockRecentSnapshot);
        when(() => mockFriendsSubcollection.where(
          'addedAt',
          isGreaterThan: any(named: 'isGreaterThan'),
        )).thenReturn(mockQuery);
        
        // Setup profile fetch
        final mockProfileDoc = MockQueryDocumentSnapshot();
        when(() => mockProfileDoc.id).thenReturn(userId3);
        when(() => mockProfileDoc.data()).thenReturn(userProfileData1);
        
        final mockProfileSnapshot = MockQuerySnapshot();
        when(() => mockProfileSnapshot.docs).thenReturn([mockProfileDoc]);
        when(() => mockPublicProfilesCollection.where(
          FieldPath.documentId,
          whereIn: any(named: 'whereIn'),
        )).thenReturn(mockQuery);
        when(() => mockQuery.get()).thenAnswer((_) async => mockProfileSnapshot);
        
        // Act
        final stats = await repository.getFriendStatistics(userId1);
        
        // Assert
        expect(stats['totalFriends'], equals(3));
        expect(stats['recentFriends'], equals(1));
        expect(stats['hasActiveFriends'], isTrue);
      });
    });
    
    group('searchFriends', () {
      test('should search friends by display name', () async {
        // Arrange
        final mockFriendDoc1 = MockQueryDocumentSnapshot();
        final mockFriendDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockFriendDoc1.id).thenReturn(userId1);
        when(() => mockFriendDoc2.id).thenReturn(userId2);
        
        final mockFriendsSnapshot = MockQuerySnapshot();
        when(() => mockFriendsSnapshot.docs).thenReturn([mockFriendDoc1, mockFriendDoc2]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockFriendsSnapshot);
        
        final searchProfileData1 = {
          ...userProfileData1,
          'displayName': 'John Smith',
        };
        final searchProfileData2 = {
          ...userProfileData2,
          'displayName': 'Jane Doe',
        };
        
        final mockProfileDoc1 = MockQueryDocumentSnapshot();
        final mockProfileDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockProfileDoc1.id).thenReturn(userId1);
        when(() => mockProfileDoc1.data()).thenReturn(searchProfileData1);
        when(() => mockProfileDoc2.id).thenReturn(userId2);
        when(() => mockProfileDoc2.data()).thenReturn(searchProfileData2);
        
        final mockProfilesSnapshot = MockQuerySnapshot();
        when(() => mockProfilesSnapshot.docs).thenReturn([mockProfileDoc1, mockProfileDoc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockProfilesSnapshot);
        
        // Act
        final results = await repository.searchFriends(currentUserId, 'john');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].displayName, equals('John Smith'));
      });
      
      test('should search friends by email if allowed', () async {
        // Arrange
        final mockFriendDoc1 = MockQueryDocumentSnapshot();
        final mockFriendDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockFriendDoc1.id).thenReturn(userId1);
        when(() => mockFriendDoc2.id).thenReturn(userId2);
        
        final mockFriendsSnapshot = MockQuerySnapshot();
        when(() => mockFriendsSnapshot.docs).thenReturn([mockFriendDoc1, mockFriendDoc2]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockFriendsSnapshot);
        
        final mockProfileDoc1 = MockQueryDocumentSnapshot();
        final mockProfileDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockProfileDoc1.id).thenReturn(userId1);
        when(() => mockProfileDoc1.data()).thenReturn(userProfileData1); // allowEmailSearch: true
        when(() => mockProfileDoc2.id).thenReturn(userId2);
        when(() => mockProfileDoc2.data()).thenReturn(userProfileData2); // allowEmailSearch: false
        
        final mockProfilesSnapshot = MockQuerySnapshot();
        when(() => mockProfilesSnapshot.docs).thenReturn([mockProfileDoc1, mockProfileDoc2]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockProfilesSnapshot);
        
        // Act
        final results = await repository.searchFriends(currentUserId, 'user1@test');
        
        // Assert
        expect(results.length, equals(1));
        expect(results[0].email, equals('user1@test.com'));
      });
    });
    
    group('inherited from BaseFirebaseRepository', () {
      test('should use correct collection name', () {
        // Assert
        expect(repository.collectionName, equals('public_profiles'));
      });
      
      test('should convert from Firestore correctly', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.id).thenReturn(userId1);
        when(() => mockSnapshot.data()).thenReturn(userProfileData1);
        
        // Act
        final result = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(result.uid, equals(userId1));
        expect(result.displayName, equals('Test User 1'));
        expect(result.email, equals('user1@test.com'));
      });
      
      test('should convert to Firestore correctly', () {
        // Act
        final result = repository.toFirestore(testProfile1);
        
        // Assert
        expect(result['uid'], equals(userId1));
        expect(result['displayName'], equals('Test User 1'));
        expect(result['email'], equals('user1@test.com'));
      });
      
      test('should extract ID correctly', () {
        // Act
        final id = repository.getId(testProfile1);
        
        // Assert
        expect(id, equals(userId1));
      });
    });
  });
}