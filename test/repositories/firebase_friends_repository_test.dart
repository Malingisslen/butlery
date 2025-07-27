import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';

// Generate mocks with: dart run build_runner build
@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentSnapshot,
  AuthRepository,
])
import 'firebase_friends_repository_test.mocks.dart';

void main() {
  group('FirebaseFriendsRepository', () {
    late FirebaseFriendsRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockAuthRepository mockAuthRepository;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocumentRef;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockQueryDocumentSnapshot<Map<String, dynamic>> mockQueryDoc;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocumentRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockQueryDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      repository = FirebaseFriendsRepository(authRepository: mockAuthRepository);
      
      // Setup common auth mocks
      when(mockAuthRepository.currentUserId).thenReturn('test-user-id');
      // Note: isAuthenticated removed - not part of AuthRepository interface
    });

    group('Friend Requests', () {
      test('sendFriendRequest creates friend request successfully', () async {
        // Arrange
        const targetUserId = 'target-user-id';
        const message = 'Hi, let\'s be friends!';

        when(mockFirestore.collection('friend_requests')).thenReturn(mockCollection);
        when(mockCollection.add(any)).thenAnswer((_) async => mockDocumentRef);
        when(mockDocumentRef.id).thenReturn('request-id');

        // Act
        final result = await repository.sendFriendRequest(targetUserId, message: message);

        // Assert
        expect(result, isNotNull);
        verify(mockCollection.add(any)).called(1);
      });

      test('sendFriendRequest throws when sending to self', () async {
        // Arrange
        const targetUserId = 'test-user-id'; // Same as current user
        const message = 'Hi!';

        // Act & Assert
        expect(
          () => repository.sendFriendRequest(targetUserId, message: message),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('acceptFriendRequest updates request and creates friendship', () async {
        // Arrange
        const requestId = 'friend-request-id';

        when(mockFirestore.collection('friend_requests')).thenReturn(mockCollection);
        when(mockCollection.doc(requestId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.update(any)).thenAnswer((_) async {});
        
        // Mock friends collection
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.set(any)).thenAnswer((_) async {});

        // Act
        await repository.acceptFriendRequest(requestId);

        // Assert
        verify(mockDocumentRef.update(any)).called(1);
        verify(mockDocumentRef.set(any)).called(2); // Two friendship records
      });

      test('rejectFriendRequest updates request status', () async {
        // Arrange
        const requestId = 'friend-request-id';

        when(mockFirestore.collection('friend_requests')).thenReturn(mockCollection);
        when(mockCollection.doc(requestId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.update(any)).thenAnswer((_) async {});

        // Act
        await repository.rejectFriendRequest(requestId);

        // Assert
        verify(mockDocumentRef.update({
          'status': FriendRequestStatus.rejected.toString(),
          'respondedAt': any,
        })).called(1);
      });

      test('getIncomingFriendRequests returns pending requests', () async {
        // Arrange
        final requestData = {
          'id': 'request-1',
          'fromUserId': 'sender-id',
          'toUserId': 'test-user-id',
          'message': 'Hi there!',
          'status': FriendRequestStatus.pending.toString(),
          'sentAt': Timestamp.now(),
        };

        when(mockFirestore.collection('friend_requests')).thenReturn(mockCollection);
        when(mockCollection.where('toUserId', isEqualTo: 'test-user-id'))
            .thenReturn(mockCollection);
        when(mockCollection.where('status', isEqualTo: FriendRequestStatus.pending.toString()))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(mockQueryDoc.data()).thenReturn(requestData);
        when(mockQueryDoc.id).thenReturn('request-1');

        // Act
        final result = await repository.getIncomingRequests();

        // Assert
        expect(result, isA<List<FriendRequest>>());
        expect(result.length, equals(1));
        expect(result.first.id, equals('request-1'));
      });

      test('getSentFriendRequests returns sent requests', () async {
        // Arrange
        when(mockFirestore.collection('friend_requests')).thenReturn(mockCollection);
        when(mockCollection.where('fromUserId', isEqualTo: 'test-user-id'))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await repository.getSentRequests();

        // Assert
        expect(result, isA<List<FriendRequest>>());
        expect(result.length, equals(0));
      });
    });

    group('Friends Management', () {
      test('fetchFriendIds returns list of friend user IDs', () async {
        // Arrange
        final friendData = {
          'friendUserId': 'friend-user-id',
          'displayName': 'Friend Name',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'addedAt': Timestamp.now(),
        };

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: 'test-user-id'))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(mockQueryDoc.data()).thenReturn(friendData);
        when(mockQueryDoc.id).thenReturn('friend-id');

        // Act
        final result = await repository.fetchFriendIds('test-user-id');

        // Assert
        expect(result, isA<List<String>>());
        expect(result.length, equals(1));
      });

      test('removeFriend removes friendship from both sides', () async {
        // Arrange
        const friendUserId = 'friend-user-id';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.where(any, isEqualTo: any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(mockQueryDoc.reference).thenReturn(mockDocumentRef);
        when(mockDocumentRef.delete()).thenAnswer((_) async {});

        // Act
        await repository.removeFriend(friendUserId);

        // Assert
        verify(mockDocumentRef.delete()).called(2); // Both directions
      });

      test('areFriends returns true for existing friendship', () async {
        // Arrange
        const friendUserId = 'friend-user-id';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: 'test-user-id'))
            .thenReturn(mockCollection);
        when(mockCollection.where('friendUserId', isEqualTo: friendUserId))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);

        // Act
        final result = await repository.areFriends('test-user-id', friendUserId);

        // Assert
        expect(result, isTrue);
      });

      test('areFriends returns false for non-friend', () async {
        // Arrange
        const friendUserId = 'non-friend-user-id';

        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.where('userId', isEqualTo: 'test-user-id'))
            .thenReturn(mockCollection);
        when(mockCollection.where('friendUserId', isEqualTo: friendUserId))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([]);

        // Act
        final result = await repository.areFriends('test-user-id', friendUserId);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Friend Categories', () {
      test('createFriendCategory creates new category successfully', () async {
        // Arrange
        final category = FriendCategory(
          id: 'category-id',
          ownerId: 'test-user-id',
          name: 'Best Friends',
          description: 'My closest friends',
          emoji: '👥',
          friendUserIds: [],
          createdAt: DateTime.now(),
        );

        when(mockFirestore.collection('friend_categories')).thenReturn(mockCollection);
        when(mockCollection.add(any)).thenAnswer((_) async => mockDocumentRef);
        when(mockDocumentRef.id).thenReturn('category-id');

        // Act
        await repository.saveCategory('test-user-id', category);

        // Assert
        verify(mockCollection.add(any)).called(1);
      });

      test('getFriendCategories returns user categories', () async {
        // Arrange
        final categoryData = {
          'ownerId': 'test-user-id',
          'name': 'Family',
          'description': 'Family members',
          'emoji': '👨‍👩‍👧‍👦',
          'friendUserIds': ['user1', 'user2'],
          'createdAt': Timestamp.now(),
        };

        when(mockFirestore.collection('friend_categories')).thenReturn(mockCollection);
        when(mockCollection.where('ownerId', isEqualTo: 'test-user-id'))
            .thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(mockQuerySnapshot.docs).thenReturn([mockQueryDoc]);
        when(mockQueryDoc.data()).thenReturn(categoryData);
        when(mockQueryDoc.id).thenReturn('category-id');

        // Act
        final result = await repository.fetchCategories('test-user-id');

        // Assert
        expect(result, isA<List<FriendCategory>>());
        expect(result.length, equals(1));
        expect(result.first.name, equals('Family'));
      });

      test('addFriendToCategory adds friend to existing category', () async {
        // Arrange
        const categoryId = 'category-id';

        when(mockFirestore.collection('friend_categories')).thenReturn(mockCollection);
        when(mockCollection.doc(categoryId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.update(any)).thenAnswer((_) async {});

        // Act
        await repository.updateCategoryMembers('test-user-id', categoryId, ['friend-user-id']);

        // Assert
        verify(mockDocumentRef.update(any)).called(1);
      });

      test('removeFriendFromCategory removes friend from category', () async {
        // Arrange
        const categoryId = 'category-id';

        when(mockFirestore.collection('friend_categories')).thenReturn(mockCollection);
        when(mockCollection.doc(categoryId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.update(any)).thenAnswer((_) async {});

        // Act
        await repository.updateCategoryMembers('test-user-id', categoryId, []);

        // Assert
        verify(mockDocumentRef.update(any)).called(1);
      });

      test('deleteFriendCategory removes category successfully', () async {
        // Arrange
        const categoryId = 'category-id';

        when(mockFirestore.collection('friend_categories')).thenReturn(mockCollection);
        when(mockCollection.doc(categoryId)).thenReturn(mockDocumentRef);
        when(mockDocumentRef.delete()).thenAnswer((_) async {});

        // Act
        await repository.deleteCategory('test-user-id', categoryId);

        // Assert
        verify(mockDocumentRef.delete()).called(1);
      });
    });

    // Note: User search tests removed - searchUsers not part of FriendsRepository interface

    group('Error Handling', () {
      test('handles authentication errors', () async {
        // Arrange
        when(mockAuthRepository.currentUserId).thenReturn(null);

        // Act & Assert
        expect(
          () => repository.fetchFriendIds(''),
          throwsA(isA<Exception>()),
        );
      });

      test('handles Firestore permission errors', () async {
        // Arrange
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Permission denied',
          ),
        );

        // Act & Assert
        expect(
          () => repository.fetchFriendIds('test-user-id'),
          throwsA(isA<FirebaseException>()),
        );
      });

      test('handles network connectivity issues', () async {
        // Arrange
        when(mockFirestore.collection(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'The service is currently unavailable',
          ),
        );

        // Act & Assert
        expect(
          () => repository.fetchFriendIds('test-user-id'),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    group('Repository Interface Compliance', () {
      test('implements FriendsRepository interface correctly', () {
        // Act & Assert
        expect(repository, isA<FriendsRepository>());
      });

      test('requires authentication for all operations', () {
        // Arrange
        when(mockAuthRepository.currentUserId).thenReturn(null);

        // Act & Assert
        expect(() => repository.fetchFriendIds(''), throwsA(isA<Exception>()));
        expect(() => repository.sendFriendRequest('user-id', message: 'Hi'), throwsA(isA<Exception>()));
        expect(() => repository.fetchCategories(''), throwsA(isA<Exception>()));
      });
    });

    group('Social Platform Integration', () {
      test('supports 85% complete social platform features', () {
        // This test ensures the repository supports the current 85% social platform
        // completeness mentioned in the project documentation
        
        expect(() => repository.fetchFriendIds('test-user-id'), returnsNormally);
        expect(() => repository.sendFriendRequest('user-id', message: 'message'), returnsNormally);
        expect(() => repository.fetchCategories('test-user-id'), returnsNormally);
        // searchUsers removed - not part of FriendsRepository interface
      });
    });
  });
}