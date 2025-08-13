// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/friend_request_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
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
class MockAggregateQuery extends Mock implements AggregateQuery {}
class MockAggregateQuerySnapshot extends Mock implements AggregateQuerySnapshot {}

void main() {
  group('FriendRequestRepository', () {
    late FriendRequestRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocRef;
    late MockAuthRepository mockAuthRepository;
    late MockQuery mockQuery;
    late MockQuerySnapshot mockQuerySnapshot;
    
    // Test data
    const currentUserId = 'current-user-123';
    const otherUserId = 'other-user-456';
    const requestId = 'request-123';
    const fromUserId = 'sender-789';
    const toUserId = 'recipient-012';
    
    late FriendRequest testRequest;
    late Map<String, dynamic> testRequestMap;
    
    setUpAll(() {
      // Register fallback values for any() matchers
      registerFallbackValue(FriendRequestStatus.pending);
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference();
      mockDocRef = MockDocumentReference();
      mockAuthRepository = MockAuthRepository();
      mockQuery = MockQuery();
      mockQuerySnapshot = MockQuerySnapshot();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: currentUserId,
        isAuthenticated: true,
      );
      
      // Setup test request
      testRequest = FriendRequest(
        id: requestId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        status: FriendRequestStatus.pending,
        sentAt: DateTime.now(),
        message: 'Would love to connect!',
      );
      
      testRequestMap = {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'sentAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'message': 'Would love to connect!',
        'respondedAt': null,
      };
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection('friend_requests')).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.get()).thenAnswer((_) async => MockDocumentSnapshot());
      
      when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.count()).thenReturn(MockAggregateQuery());
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuery.snapshots()).thenAnswer(
        (_) => Stream.value(mockQuerySnapshot),
      );
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      
      // Create repository
      repository = FriendRequestRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('sendRequest', () {
      test('should send friend request with validation', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final request = FriendRequest.create(
          fromUserId: fromUserId,
          toUserId: toUserId,
          message: 'Hi there!',
        );
        
        // Act
        await repository.sendRequest(request);
        
        // Assert
        final captured = verify(() => mockDocRef.set(captureAny())).captured.single;
        expect(captured['fromUserId'], equals(fromUserId));
        expect(captured['toUserId'], equals(toUserId));
        expect(captured['status'], equals('pending'));
      });
      
      test('should prevent sending request from another user account', () async {
        // Arrange
        final maliciousRequest = FriendRequest.create(
          fromUserId: otherUserId, // Trying to send from someone else's account
          toUserId: toUserId,
        );
        
        // Act & Assert
        expect(
          () => repository.sendRequest(maliciousRequest),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only send friend request'))),
        );
      });
      
      test('should reject non-pending status for new requests', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final acceptedRequest = FriendRequest(
          id: 'new-request',
          fromUserId: fromUserId,
          toUserId: toUserId,
          status: FriendRequestStatus.accepted, // Invalid for new request
        );
        
        // Act & Assert
        expect(
          () => repository.sendRequest(acceptedRequest),
          throwsA(isA<SecurityViolationException>()
            .having((e) => e.message, 'message', contains('must have pending status'))),
        );
      });
      
      test('should validate required fields', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final invalidRequest = FriendRequest(
          id: 'test',
          fromUserId: fromUserId,
          toUserId: '', // Invalid - empty toUserId
          status: FriendRequestStatus.pending,
        );
        
        // Act
        await repository.sendRequest(invalidRequest);
        
        // Assert - should still attempt to set with empty toUserId
        final captured = verify(() => mockDocRef.set(captureAny())).captured.single;
        expect(captured['toUserId'], equals(''));
      });
    });
    
    group('sendFriendRequest', () {
      test('should send friend request successfully', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        when(() => mockQuerySnapshot.docs).thenReturn([]); // No existing request
        
        // Act
        final result = await repository.sendFriendRequest(toUserId, message: 'Hello!');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockDocRef.set(any())).called(1);
      });
      
      test('should prevent sending request to yourself', () async {
        // Act
        final result = await repository.sendFriendRequest(currentUserId);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockDocRef.set(any()));
      });
      
      test('should return false if request already exists', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final existingDoc = MockQueryDocumentSnapshot();
        when(() => existingDoc.id).thenReturn('existing-request');
        when(() => mockQuerySnapshot.docs).thenReturn([existingDoc]);
        
        // Act
        final result = await repository.sendFriendRequest(toUserId);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockDocRef.set(any()));
      });
    });
    
    group('updateRequest', () {
      test('should allow sender to cancel their request', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final cancelledRequest = testRequest.cancel();
        
        // Act
        await repository.updateRequest(cancelledRequest);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should prevent non-sender from cancelling request', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: otherUserId, isAuthenticated: true);
        final cancelledRequest = testRequest.cancel();
        
        // Act & Assert
        expect(
          () => repository.updateRequest(cancelledRequest),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('Only the sender can cancel'))),
        );
      });
      
      test('should allow recipient to accept request', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        final acceptedRequest = testRequest.accept();
        
        // Act
        await repository.updateRequest(acceptedRequest);
        
        // Assert
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['status'], equals('accepted'));
      });
      
      test('should allow recipient to reject request', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        final rejectedRequest = testRequest.reject();
        
        // Act
        await repository.updateRequest(rejectedRequest);
        
        // Assert
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['status'], equals('rejected'));
      });
      
      test('should prevent non-recipient from accepting request', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: otherUserId, isAuthenticated: true);
        final acceptedRequest = testRequest.accept();
        
        // Act & Assert
        expect(
          () => repository.updateRequest(acceptedRequest),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('Only the recipient can accept'))),
        );
      });
    });
    
    group('acceptFriendRequest', () {
      test('should accept request when user is recipient', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(requestId);
        when(() => mockSnapshot.data()).thenReturn(testRequestMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.acceptFriendRequest(requestId);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should return false when user is not recipient', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: otherUserId, isAuthenticated: true);
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(requestId);
        when(() => mockSnapshot.data()).thenReturn(testRequestMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.acceptFriendRequest(requestId);
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockDocRef.update(any()));
      });
      
      test('should throw ResourceNotFoundException when request not found', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.acceptFriendRequest(requestId),
          throwsA(isA<ResourceNotFoundException>()
            .having((e) => e.message, 'message', contains('not found'))),
        );
      });
    });
    
    group('fetchRequest', () {
      test('should return request when it exists', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(requestId);
        when(() => mockSnapshot.data()).thenReturn(testRequestMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final request = await repository.fetchRequest(requestId);
        
        // Assert
        expect(request, isNotNull);
        expect(request!.id, equals(requestId));
        expect(request.fromUserId, equals(fromUserId));
        expect(request.toUserId, equals(toUserId));
      });
      
      test('should return null when request does not exist', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final request = await repository.fetchRequest(requestId);
        
        // Assert
        expect(request, isNull);
      });
    });
    
    group('requestExists', () {
      test('should return true when pending request exists', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(requestId);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final exists = await repository.requestExists(fromUserId, toUserId);
        
        // Assert
        expect(exists, isTrue);
        verify(() => mockQuery.where('status', isEqualTo: 'pending')).called(1);
      });
      
      test('should return false when no pending request exists', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        
        // Act
        final exists = await repository.requestExists(fromUserId, toUserId);
        
        // Assert
        expect(exists, isFalse);
      });
    });
    
    group('getIncomingRequests', () {
      test('should return incoming pending requests for current user', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('req1');
        when(() => mockDoc1.data()).thenReturn({
          ...testRequestMap,
          'toUserId': currentUserId,
        });
        
        when(() => mockDoc2.id).thenReturn('req2');
        when(() => mockDoc2.data()).thenReturn({
          ...testRequestMap,
          'toUserId': currentUserId,
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        // Act
        final requests = await repository.getIncomingRequests();
        
        // Assert
        expect(requests.length, equals(2));
        verify(() => mockCollection.where('toUserId', isEqualTo: currentUserId)).called(1);
        verify(() => mockQuery.where('status', isEqualTo: 'pending')).called(1);
      });
      
      test('should return empty list on error', () async {
        // Arrange
        when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
            .thenThrow(Exception('Network error'));
        
        // Act
        final requests = await repository.getIncomingRequests();
        
        // Assert
        expect(requests, isEmpty);
      });
    });
    
    group('getSentRequests', () {
      test('should return sent pending requests for current user', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn('sent-req');
        when(() => mockDoc.data()).thenReturn({
          ...testRequestMap,
          'fromUserId': currentUserId,
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final requests = await repository.getSentRequests();
        
        // Assert
        expect(requests.length, equals(1));
        verify(() => mockCollection.where('fromUserId', isEqualTo: currentUserId)).called(1);
        verify(() => mockQuery.where('status', isEqualTo: 'pending')).called(1);
      });
    });
    
    group('incomingRequestsStream', () {
      test('should stream incoming pending requests', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(requestId);
        when(() => mockDoc.data()).thenReturn(testRequestMap);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final stream = repository.incomingRequestsStream(toUserId);
        final requests = await stream.first;
        
        // Assert
        expect(requests.length, equals(1));
        expect(requests[0].id, equals(requestId));
        verify(() => mockCollection.where('toUserId', isEqualTo: toUserId)).called(1);
        verify(() => mockQuery.where('status', isEqualTo: 'pending')).called(1);
      });
      
      test('should handle real-time updates', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        when(() => mockDoc1.id).thenReturn('req1');
        when(() => mockDoc1.data()).thenReturn(testRequestMap);
        
        final mockDoc2 = MockQueryDocumentSnapshot();
        when(() => mockDoc2.id).thenReturn('req2');
        when(() => mockDoc2.data()).thenReturn(testRequestMap);
        
        final snapshot1 = MockQuerySnapshot();
        final snapshot2 = MockQuerySnapshot();
        final snapshot3 = MockQuerySnapshot();
        
        when(() => snapshot1.docs).thenReturn([]);
        when(() => snapshot2.docs).thenReturn([mockDoc1]);
        when(() => snapshot3.docs).thenReturn([mockDoc1, mockDoc2]);
        
        when(() => mockQuery.snapshots()).thenAnswer(
          (_) => Stream.fromIterable([snapshot1, snapshot2, snapshot3]),
        );
        
        // Act
        final stream = repository.incomingRequestsStream(toUserId);
        final results = await stream.take(3).toList();
        
        // Assert
        expect(results[0].length, equals(0));
        expect(results[1].length, equals(1));
        expect(results[2].length, equals(2));
      });
    });
    
    group('sentRequestsStream', () {
      test('should stream sent pending requests', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(requestId);
        when(() => mockDoc.data()).thenReturn(testRequestMap);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final stream = repository.sentRequestsStream(fromUserId);
        final requests = await stream.first;
        
        // Assert
        expect(requests.length, equals(1));
        verify(() => mockCollection.where('fromUserId', isEqualTo: fromUserId)).called(1);
      });
    });
    
    group('getRequestStatistics', () {
      test('should return correct request statistics', () async {
        // Arrange
        final mockIncomingQuery = MockAggregateQuery();
        final mockIncomingSnapshot = MockAggregateQuerySnapshot();
        final mockSentQuery = MockAggregateQuery();
        final mockSentSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockIncomingSnapshot.count).thenReturn(5);
        when(() => mockSentSnapshot.count).thenReturn(3);
        
        when(() => mockIncomingQuery.get()).thenAnswer((_) async => mockIncomingSnapshot);
        when(() => mockSentQuery.get()).thenAnswer((_) async => mockSentSnapshot);
        
        when(() => mockQuery.count()).thenReturn(mockIncomingQuery);
        
        // Setup incoming query chain
        final mockIncomingQuery1 = MockQuery();
        final mockIncomingQuery2 = MockQuery();
        when(() => mockCollection.where('toUserId', isEqualTo: currentUserId))
            .thenReturn(mockIncomingQuery1);
        when(() => mockIncomingQuery1.where('status', isEqualTo: 'pending'))
            .thenReturn(mockIncomingQuery2);
        when(() => mockIncomingQuery2.count()).thenReturn(mockIncomingQuery);
        
        // Setup sent query chain
        final mockSentQuery1 = MockQuery();
        final mockSentQuery2 = MockQuery();
        when(() => mockCollection.where('fromUserId', isEqualTo: currentUserId))
            .thenReturn(mockSentQuery1);
        when(() => mockSentQuery1.where('status', isEqualTo: 'pending'))
            .thenReturn(mockSentQuery2);
        when(() => mockSentQuery2.count()).thenReturn(mockSentQuery);
        
        // Act
        final stats = await repository.getRequestStatistics(currentUserId);
        
        // Assert
        expect(stats['incoming'], equals(5));
        expect(stats['sent'], equals(3));
      });
      
      test('should handle null counts', () async {
        // Arrange
        final mockAggQuery = MockAggregateQuery();
        final mockAggSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockAggSnapshot.count).thenReturn(null);
        when(() => mockAggQuery.get()).thenAnswer((_) async => mockAggSnapshot);
        when(() => mockQuery.count()).thenReturn(mockAggQuery);
        
        // Act
        final stats = await repository.getRequestStatistics(currentUserId);
        
        // Assert
        expect(stats['incoming'], equals(0));
        expect(stats['sent'], equals(0));
      });
    });
    
    group('hasPendingRequestBetween', () {
      test('should return true if pending request exists in either direction', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(requestId);
        
        // First query returns empty, second query returns a result
        var queryCount = 0;
        when(() => mockQuery.get()).thenAnswer((_) async {
          queryCount++;
          final snapshot = MockQuerySnapshot();
          when(() => snapshot.docs).thenReturn(queryCount == 1 ? [] : [mockDoc]);
          return snapshot;
        });
        
        // Act
        final hasPending = await repository.hasPendingRequestBetween(fromUserId, toUserId);
        
        // Assert
        expect(hasPending, isTrue);
      });
      
      test('should return false if no pending request exists', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        final hasPending = await repository.hasPendingRequestBetween(fromUserId, toUserId);
        
        // Assert
        expect(hasPending, isFalse);
      });
    });
    
    group('inherited from BaseFirebaseRepository', () {
      test('should use correct collection name', () {
        // Assert
        expect(repository.collectionName, equals('friend_requests'));
      });
      
      test('should convert from Firestore correctly', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.id).thenReturn(requestId);
        when(() => mockSnapshot.data()).thenReturn(testRequestMap);
        
        // Act
        final result = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(result.id, equals(requestId));
        expect(result.fromUserId, equals(fromUserId));
        expect(result.toUserId, equals(toUserId));
        expect(result.status, equals(FriendRequestStatus.pending));
      });
      
      test('should convert to Firestore correctly', () {
        // Act
        final result = repository.toFirestore(testRequest);
        
        // Assert
        expect(result['fromUserId'], equals(fromUserId));
        expect(result['toUserId'], equals(toUserId));
        expect(result['status'], equals('pending'));
        expect(result['message'], equals('Would love to connect!'));
      });
      
      test('should extract ID correctly', () {
        // Act
        final id = repository.getId(testRequest);
        
        // Assert
        expect(id, equals(requestId));
      });
    });
  });
}