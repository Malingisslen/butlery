/// Comprehensive unit tests for GroupInvitationRepository.
///
/// Tests group invitation lifecycle including create, accept, reject, cancel operations,
/// permission validation, cleanup, and real-time streams.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/group_invitation_repository.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('GroupInvitationRepository - Group Invitation Management', () {
    late GroupInvitationRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test data
    const testUserId = 'user-123';
    const testFriendId = 'friend-456';
    const testOtherUserId = 'other-789';
    const testGroupId = 'group-1';
    const testInvitationId = 'invitation-1';

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
      repository = GroupInvitationRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    // ===== HELPER METHODS =====

    GroupInvitation createTestInvitation({
      String? id,
      String? fromUserId,
      String? fromUserName,
      String? toUserId,
      String? groupId,
      String? groupName,
      String? groupEmoji,
      String? personalMessage,
      GroupInvitationStatus? status,
      DateTime? sentAt,
      DateTime? respondedAt,
    }) {
      return GroupInvitation(
        id: id ?? testInvitationId,
        groupId: groupId ?? testGroupId,
        groupName: groupName ?? 'Matgrupp',
        groupEmoji: groupEmoji ?? '👨‍🍳',
        fromUserId: fromUserId ?? testUserId,
        fromUserName: fromUserName ?? 'Test User',
        toUserId: toUserId ?? testFriendId,
        status: status ?? GroupInvitationStatus.pending,
        sentAt: sentAt,
        respondedAt: respondedAt,
        personalMessage: personalMessage,
      );
    }

    Future<void> seedInvitation(GroupInvitation invitation) async {
      await fakeFirestore
          .collection('group_invitations')
          .doc(invitation.id)
          .set(invitation.toFirestore());
    }

    // ===== PERMISSION VALIDATION TESTS =====

    group('Permission Validation', () {
      test('should allow user to create invitation as sender', () async {
        // Arrange
        final invitation = createTestInvitation(fromUserId: testUserId);

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, invitation);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject user from creating invitation as another user',
          () async {
        // Arrange
        final invitation = createTestInvitation(fromUserId: testOtherUserId);

        // Act
        final hasPermission =
            await repository.validateCreatePermission(testUserId, invitation);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should allow sender to read their own invitation', () async {
        // Arrange
        final invitation = createTestInvitation(fromUserId: testUserId);

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testInvitationId, invitation);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow recipient to read invitation sent to them', () async {
        // Arrange
        final invitation = createTestInvitation(toUserId: testUserId);

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testInvitationId, invitation);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should reject third party from reading invitation', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testFriendId,
          toUserId: testOtherUserId,
        );

        // Act
        final hasPermission = await repository.validateReadPermission(
            testUserId, testInvitationId, invitation);

        // Assert
        expect(hasPermission, isFalse);
      });

      test('should allow sender to update their own invitation', () async {
        // Arrange
        final invitation = createTestInvitation(fromUserId: testUserId);

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testInvitationId, invitation);

        // Assert
        expect(hasPermission, isTrue);
      });

      test('should allow recipient to update invitation sent to them',
          () async {
        // Arrange
        final invitation = createTestInvitation(toUserId: testUserId);

        // Act
        final hasPermission = await repository.validateUpdatePermission(
            testUserId, testInvitationId, invitation);

        // Assert
        expect(hasPermission, isTrue);
      });
    });

    // ===== INVITATION OPERATIONS =====

    group('Invitation Operations', () {
      test('should save invitation successfully', () async {
        // Arrange
        final invitation = createTestInvitation();

        // Act
        await repository.saveInvitation(invitation);

        // Assert
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(testInvitationId)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.data()?['groupId'], testGroupId);
      });

      test('should reject saving invitation from another user', () async {
        // Arrange
        final invitation = createTestInvitation(fromUserId: testOtherUserId);

        // Act & Assert
        expect(
          () => repository.saveInvitation(invitation),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject saving invitation with non-pending status', () async {
        // Arrange
        final invitation =
            createTestInvitation(status: GroupInvitationStatus.accepted);

        // Act & Assert
        expect(
          () => repository.saveInvitation(invitation),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should get invitation by ID', () async {
        // Arrange
        final invitation = createTestInvitation();
        await seedInvitation(invitation);

        // Act
        final result = await repository.getInvitation(testInvitationId);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testInvitationId);
        expect(result.groupId, testGroupId);
      });

      test('should return null for non-existent invitation', () async {
        // Act
        final result = await repository.getInvitation('non-existent');

        // Assert
        expect(result, isNull);
      });

      test('should check if pending invitation exists', () async {
        // Arrange
        final invitation = createTestInvitation();
        await seedInvitation(invitation);

        // Act
        final exists =
            await repository.hasPendingInvitation(testGroupId, testFriendId);

        // Assert
        expect(exists, isTrue);
      });

      test('should return false if no pending invitation exists', () async {
        // Act
        final exists =
            await repository.hasPendingInvitation(testGroupId, testFriendId);

        // Assert
        expect(exists, isFalse);
      });
    });

    // ===== INVITATION STATUS MANAGEMENT =====

    group('Invitation Status Management', () {
      test('should accept invitation as recipient', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testFriendId,
          toUserId: testUserId, // Current user is recipient
        );
        await seedInvitation(invitation);

        // Act
        final success = await repository.acceptInvitation(testInvitationId);

        // Assert
        expect(success, isTrue);

        // Verify status was updated (skip server timestamp check)
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(testInvitationId)
            .get();
        expect(doc.data()?['status'], 'accepted');
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should reject invitation as recipient', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testFriendId,
          toUserId: testUserId, // Current user is recipient
        );
        await seedInvitation(invitation);

        // Act
        final success = await repository.rejectInvitation(testInvitationId);

        // Assert
        expect(success, isTrue);

        // Verify status was updated (skip server timestamp check)
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(testInvitationId)
            .get();
        expect(doc.data()?['status'], 'rejected');
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should cancel invitation as sender', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testUserId, // Current user is sender
          toUserId: testFriendId,
        );
        await seedInvitation(invitation);

        // Act
        final success = await repository.cancelInvitation(testInvitationId);

        // Assert
        expect(success, isTrue);

        // Verify status was updated (skip server timestamp check)
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(testInvitationId)
            .get();
        expect(doc.data()?['status'], 'cancelled');
      }, skip: 'Requires FieldValue.serverTimestamp support');

      test('should reject non-recipient from accepting invitation', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testFriendId,
          toUserId: testOtherUserId, // Current user is NOT recipient
        );
        await seedInvitation(invitation);

        // Act
        final success = await repository.acceptInvitation(testInvitationId);

        // Assert
        expect(success, isFalse);
      });

      test('should return false when accepting non-existent invitation',
          () async {
        // Act
        final success = await repository.acceptInvitation('non-existent');

        // Assert
        expect(success, isFalse);
      });
    });

    // ===== QUERY OPERATIONS =====

    group('Query Operations', () {
      test('should get received invitations for user', () async {
        // Arrange
        final invitation1 = createTestInvitation(
          id: 'inv-1',
          fromUserId: testFriendId,
          toUserId: testUserId, // To current user
        );
        final invitation2 = createTestInvitation(
          id: 'inv-2',
          fromUserId: testOtherUserId,
          toUserId: testUserId, // To current user
        );
        await seedInvitation(invitation1);
        await seedInvitation(invitation2);

        // Act
        final invitations = await repository.getReceivedInvitations();

        // Assert
        expect(invitations.length, 2);
        expect(invitations.every((inv) => inv.toUserId == testUserId), isTrue);
      });

      test('should get sent invitations for user', () async {
        // Arrange
        final invitation1 = createTestInvitation(
          id: 'inv-1',
          fromUserId: testUserId, // From current user
          toUserId: testFriendId,
        );
        final invitation2 = createTestInvitation(
          id: 'inv-2',
          fromUserId: testUserId, // From current user
          toUserId: testOtherUserId,
        );
        await seedInvitation(invitation1);
        await seedInvitation(invitation2);

        // Act
        final invitations = await repository.getSentInvitations();

        // Assert
        expect(invitations.length, 2);
        expect(
            invitations.every((inv) => inv.fromUserId == testUserId), isTrue);
      });

      test('should get invitations for specific group', () async {
        // Arrange
        final invitation1 = createTestInvitation(
          id: 'inv-1',
          groupId: testGroupId,
        );
        final invitation2 = createTestInvitation(
          id: 'inv-2',
          groupId: testGroupId,
        );
        final invitation3 = createTestInvitation(
          id: 'inv-3',
          groupId: 'other-group',
        );
        await seedInvitation(invitation1);
        await seedInvitation(invitation2);
        await seedInvitation(invitation3);

        // Act
        final invitations = await repository.getGroupInvitations(testGroupId);

        // Assert
        expect(invitations.length, 2);
        expect(invitations.every((inv) => inv.groupId == testGroupId), isTrue);
      });

      test('should get invitation statistics for user', () async {
        // Arrange - Create pending invitations
        final received1 = createTestInvitation(
          id: 'recv-1',
          fromUserId: testFriendId,
          toUserId: testUserId,
        );
        final received2 = createTestInvitation(
          id: 'recv-2',
          fromUserId: testOtherUserId,
          toUserId: testUserId,
        );
        final sent1 = createTestInvitation(
          id: 'sent-1',
          fromUserId: testUserId,
          toUserId: testFriendId,
        );
        await seedInvitation(received1);
        await seedInvitation(received2);
        await seedInvitation(sent1);

        // Act
        final stats = await repository.getInvitationStatistics(testUserId);

        // Assert
        expect(stats['pendingReceived'], 2);
        expect(stats['pendingSent'], 1);
      });
    });

    // ===== REAL-TIME STREAMS =====

    group('Real-time Streams', () {
      test('should stream received invitations', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testFriendId,
          toUserId: testUserId,
        );
        await seedInvitation(invitation);

        // Act
        final stream = repository.receivedInvitationsStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<GroupInvitation>>((invitations) {
            return invitations.length == 1 &&
                invitations.first.toUserId == testUserId;
          })),
        );
      });

      test('should stream sent invitations', () async {
        // Arrange
        final invitation = createTestInvitation(
          fromUserId: testUserId,
          toUserId: testFriendId,
        );
        await seedInvitation(invitation);

        // Act
        final stream = repository.sentInvitationsStream(testUserId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<GroupInvitation>>((invitations) {
            return invitations.length == 1 &&
                invitations.first.fromUserId == testUserId;
          })),
        );
      });
    });

    // ===== CLEANUP OPERATIONS =====

    group('Cleanup Operations', () {
      test('should find expired invitations', () async {
        // Arrange - Create invitation that expires in the past
        final expiredInvitation = GroupInvitation(
          id: 'expired-inv',
          groupId: testGroupId,
          groupName: 'Matgrupp',
          groupEmoji: '👨‍🍳',
          fromUserId: testUserId,
          fromUserName: 'Test User',
          toUserId: testFriendId,
          status: GroupInvitationStatus.pending,
          expiresAt:
              DateTime.now().subtract(const Duration(days: 1)), // Expired
        );
        await seedInvitation(expiredInvitation);

        // Act
        final expiredRefs = await repository.expiredInvitations(DateTime.now());

        // Assert
        expect(expiredRefs.length, 1);
      });

      test('should find old invitations for cleanup', () async {
        // Arrange - Create old invitation
        final oldInvitation = GroupInvitation(
          id: 'old-inv',
          groupId: testGroupId,
          groupName: 'Matgrupp',
          groupEmoji: '👨‍🍳',
          fromUserId: testFriendId,
          fromUserName: 'Friend',
          toUserId: testUserId,
          status: GroupInvitationStatus.pending,
          sentAt:
              DateTime.now().subtract(const Duration(days: 30)), // 30 days ago
        );
        await seedInvitation(oldInvitation);

        // Act
        final oldInvitations = await repository.oldInvitations(
          testUserId,
          DateTime.now()
              .subtract(const Duration(days: 7)), // Cutoff: 7 days ago
        );

        // Assert
        expect(oldInvitations.length, 1);
      });

      test('should cleanup expired invitations', () async {
        // Arrange - Create expired invitation
        final expiredInvitation = GroupInvitation(
          id: 'expired-inv',
          groupId: testGroupId,
          groupName: 'Matgrupp',
          groupEmoji: '👨‍🍳',
          fromUserId: testUserId,
          fromUserName: 'Test User',
          toUserId: testFriendId,
          status: GroupInvitationStatus.pending,
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        );
        await seedInvitation(expiredInvitation);

        // Act
        final cleanedCount = await repository.cleanupExpiredInvitations();

        // Assert - At least one invitation should be marked as expired
        expect(cleanedCount, greaterThanOrEqualTo(1));
      }, skip: 'Requires FieldValue.serverTimestamp support');
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

        final invitation = createTestInvitation();

        // Act & Assert
        expect(
          () => repository.saveInvitation(invitation),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle empty received invitations', () async {
        // Act
        final invitations = await repository.getReceivedInvitations();

        // Assert
        expect(invitations, isEmpty);
      });

      test('should handle empty sent invitations', () async {
        // Act
        final invitations = await repository.getSentInvitations();

        // Assert
        expect(invitations, isEmpty);
      });

      test('should throw when updating non-existent invitation', () async {
        // Act & Assert
        expect(
          () => repository
              .updateInvitation('non-existent', {'status': 'accepted'}),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should handle invitation with personal message', () async {
        // Arrange
        final invitation = createTestInvitation(
          personalMessage: 'Kom och laga mat med oss!',
        );

        // Act
        await repository.saveInvitation(invitation);

        // Assert
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(testInvitationId)
            .get();
        expect(doc.data()?['personalMessage'], 'Kom och laga mat med oss!');
      });
    });

    // ===== BASE REPOSITORY IMPLEMENTATION =====

    group('Base Repository Implementation', () {
      test('should use correct collection name', () {
        expect(repository.collectionName, 'group_invitations');
      });

      test('should convert entity to ID correctly', () {
        // Arrange
        final invitation = createTestInvitation();

        // Act
        final id = repository.getId(invitation);

        // Assert
        expect(id, testInvitationId);
      });

      test('should serialize to Firestore correctly', () {
        // Arrange
        final invitation = createTestInvitation();

        // Act
        final data = repository.toFirestore(invitation);

        // Assert
        expect(data['groupId'], testGroupId);
        expect(data['fromUserId'], testUserId);
        expect(data['toUserId'], testFriendId);
        expect(data['status'], 'pending');
      });

      test('should deserialize from Firestore correctly', () async {
        // Arrange
        final invitation = createTestInvitation();
        await seedInvitation(invitation);

        // Act
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(testInvitationId)
            .get();
        final result = repository.fromFirestore(doc);

        // Assert
        expect(result.id, testInvitationId);
        expect(result.groupId, testGroupId);
        expect(result.fromUserId, testUserId);
        expect(result.toUserId, testFriendId);
      });
    });
  });
}
