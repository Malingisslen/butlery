/// Comprehensive unit tests for FriendRequestRepository.
///
/// Tests friend request lifecycle operations including send, accept, reject, cancel,
/// permission validation, and real-time streams.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/friend_request_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendRequestRepository - Friend Request Lifecycle', () {
    late FriendRequestRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testFriendId = 'friend-456';
    const testOtherUserId = 'other-789';
    const testRequestId = 'request-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: testUserId, displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: testUserId,
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FriendRequestRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    FriendRequest createTestRequest({
      String? id,
      String? fromUserId,
      String? toUserId,
      String? message,
      FriendRequestStatus? status,
      DateTime? sentAt,
    }) {
      return FriendRequest(
        id: id ?? testRequestId,
        fromUserId: fromUserId ?? testUserId,
        toUserId: toUserId ?? testFriendId,
        message: message,
        status: status ?? FriendRequestStatus.pending,
        sentAt: sentAt ?? DateTime(2025, 1, 15),
      );
    }

    Future<void> seedFriendRequest(FriendRequest request) async {
      await fakeFirestore
          .collection('friend_requests')
          .doc(request.id)
          .set(request.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create friend request as sender', () async {
        // Arrange
        final request = createTestRequest(fromUserId: testUserId);

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, request);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject user from creating friend request as another user',
          () async {
        // Arrange
        final request = createTestRequest(fromUserId: testOtherUserId);

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, request);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should allow sender to read their own request', () async {
        // Arrange
        final request = createTestRequest(fromUserId: testUserId);

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testRequestId, request);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow recipient to read request sent to them', () async {
        // Arrange
        final request = createTestRequest(toUserId: testUserId);

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testRequestId, request);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject third party from reading request', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testFriendId,
          toUserId: testOtherUserId,
        );

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testRequestId, request);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should allow sender to update their own request', () async {
        // Arrange
        final request = createTestRequest(fromUserId: testUserId);

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testRequestId, request);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow recipient to update request sent to them', () async {
        // Arrange
        final request = createTestRequest(toUserId: testUserId);

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testRequestId, request);

        // Assert
        expect(hasPermission, isTrue);
      });
    });

    // ===== FRIEND REQUEST OPERATIONS =====

    group('Friend Request Operations', () {
      test('should send friend request successfully', () async {
        // Act
        final success = await repository.sendFriendRequest(testFriendId,
            message: 'Let\'s be friends!');

        // Assert
        expect(success, isTrue);

        // Verify request was created in Firestore
        final requests = await fakeFirestore
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: testUserId)
            .where('toUserId', isEqualTo: testFriendId)
            .get();
        expect(requests.docs.isNotEmpty, isTrue);
      });

      test('should reject sending friend request to yourself', () async {
        // Act
        final success = await repository.sendFriendRequest(testUserId,
            message: 'To myself?');

        // Assert
        expect(success, isFalse);
      });

      test('should reject duplicate friend request', () async {
        // Arrange
        final existingRequest = createTestRequest();
        await seedFriendRequest(existingRequest);

        // Act
        final success = await repository.sendFriendRequest(testFriendId,
            message: 'Another request?');

        // Assert
        expect(success, isFalse);
      });

      test('should check if request exists', () async {
        // Arrange
        final request = createTestRequest();
        await seedFriendRequest(request);

        // Act
        final exists = await repository.requestExists(testUserId, testFriendId);

        // Assert
        expect(exists, isTrue);
      });

      test('should return false if request does not exist', () async {
        // Act
        final exists = await repository.requestExists(testUserId, testFriendId);

        // Assert
        expect(exists, isFalse);
      });

      test('should fetch request by ID', () async {
        // Arrange
        final request = createTestRequest();
        await seedFriendRequest(request);

        // Act
        final result = await repository.fetchRequest(testRequestId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testRequestId);
        expect(result.fromUserId, testUserId);
        expect(result.toUserId, testFriendId);
      });

      test('should return null for non-existent request', () async {
        // Act
        final result = await repository.fetchRequest('non-existent');

        // Assert
        expect(result, isNull);
      });
    });

    // ===== REQUEST STATUS MANAGEMENT =====

    group('Request Status Management', () {
      test('should accept friend request as recipient', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testFriendId,
          toUserId: testUserId, // Current user is recipient
        );
        await seedFriendRequest(request);

        // Act
        final success = await repository.acceptFriendRequest(testRequestId);

        // Assert
        expect(success, isTrue);

        // Verify status was updated
        final doc = await fakeFirestore
            .collection('friend_requests')
            .doc(testRequestId)
            .get();
        expect(doc.data()?['status'], 'accepted');
      });

      test('should reject non-recipient from accepting request', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testFriendId,
          toUserId: testOtherUserId, // Current user is NOT recipient
        );
        await seedFriendRequest(request);

        // Act
        final success = await repository.acceptFriendRequest(testRequestId);

        // Assert
        expect(success, isFalse);
      });

      test('should reject friend request as recipient', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testFriendId,
          toUserId: testUserId, // Current user is recipient
        );
        await seedFriendRequest(request);

        // Act
        final success = await repository.rejectFriendRequest(testRequestId);

        // Assert
        expect(success, isTrue);

        // Verify status was updated
        final doc = await fakeFirestore
            .collection('friend_requests')
            .doc(testRequestId)
            .get();
        expect(doc.data()?['status'], 'rejected');
      });

      test('should cancel friend request as sender', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testUserId, // Current user is sender
          toUserId: testFriendId,
        );
        await seedFriendRequest(request);

        // Act
        final success = await repository.cancelFriendRequest(testRequestId);

        // Assert
        expect(success, isTrue);

        // Verify status was updated
        final doc = await fakeFirestore
            .collection('friend_requests')
            .doc(testRequestId)
            .get();
        expect(doc.data()?['status'], 'cancelled');
      });

      test('should return false when cancelling non-existent request',
          () async {
        // Act
        final success = await repository.cancelFriendRequest('non-existent');

        // Assert
        expect(success, isFalse);
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get incoming requests for user', () async {
        // Arrange
        final request1 = createTestRequest(
          id: 'req-1',
          fromUserId: testFriendId,
          toUserId: testUserId, // To current user
        );
        final request2 = createTestRequest(
          id: 'req-2',
          fromUserId: testOtherUserId,
          toUserId: testUserId, // To current user
        );
        await seedFriendRequest(request1);
        await seedFriendRequest(request2);

        // Act
        final requests = await repository.getIncomingRequests();

        // Assert
        expect(requests.length, 2);
        expect(requests.every((r) => r.toUserId == testUserId), isTrue);
      });

      test('should get sent requests for user', () async {
        // Arrange
        final request1 = createTestRequest(
          id: 'req-1',
          fromUserId: testUserId, // From current user
          toUserId: testFriendId,
        );
        final request2 = createTestRequest(
          id: 'req-2',
          fromUserId: testUserId, // From current user
          toUserId: testOtherUserId,
        );
        await seedFriendRequest(request1);
        await seedFriendRequest(request2);

        // Act
        final requests = await repository.getSentRequests();

        // Assert
        expect(requests.length, 2);
        expect(requests.every((r) => r.fromUserId == testUserId), isTrue);
      });

      test('should stream incoming requests', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testFriendId,
          toUserId: testUserId,
        );
        await seedFriendRequest(request);

        // Act
        final stream = repository.incomingRequestsStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendRequest>>((requests) {
            return requests.length == 1 &&
                requests.first.toUserId == testUserId;
          })),
        );
      });

      test('should stream sent requests', () async {
        // Arrange
        final request = createTestRequest(
          fromUserId: testUserId,
          toUserId: testFriendId,
        );
        await seedFriendRequest(request);

        // Act
        final stream = repository.sentRequestsStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<FriendRequest>>((requests) {
            return requests.length == 1 &&
                requests.first.fromUserId == testUserId;
          })),
        );
      });
    });

    // ===== EDGE CASES =====

    group('Edge Cases', () {
      test('should handle user not authenticated', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        // Act
        final success = await repository.sendFriendRequest(testFriendId);

        // Assert - Method returns false instead of throwing
        expect(success, isFalse);
      });

      test('should handle empty incoming requests', () async {
        // Act
        final requests = await repository.getIncomingRequests();

        // Assert
        expect(requests, isEmpty);
      });

      test('should handle empty sent requests', () async {
        // Act
        final requests = await repository.getSentRequests();

        // Assert
        expect(requests, isEmpty);
      });

      test('should throw when accepting non-existent request', () async {
        // Act & Assert
        expect(
          () => repository.acceptFriendRequest('non-existent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    // ===== BASE REPOSITORY IMPLEMENTATION =====

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, 'friend_requests');
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final request = createTestRequest();

        // Act
        final id = repository.getId(request);

        // Assert
        expect(id, testRequestId);
      });

      test('should serialize to Firestore correctly', () {
        // Arrange
        final request = createTestRequest();

        // Act
        final data = repository.toFirestore(request);

        // Assert
        expect(data['fromUserId'], testUserId);
        expect(data['toUserId'], testFriendId);
        expect(data['status'], 'pending');
      });

      test('should deserialize from Firestore correctly', () async {
        // Arrange
        final request = createTestRequest();
        await seedFriendRequest(request);

        // Act
        final doc = await fakeFirestore
            .collection('friend_requests')
            .doc(testRequestId)
            .get();
        final result = repository.fromFirestore(doc);

        // Assert
        expect(result.id, testRequestId);
        expect(result.fromUserId, testUserId);
        expect(result.toUserId, testFriendId);
      });
    });
  });
}
