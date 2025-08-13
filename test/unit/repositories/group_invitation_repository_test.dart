// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/friends/group_invitation_repository.dart';
import 'package:butlery/models/group_invitation.dart';
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
class MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  group('GroupInvitationRepository', () {
    late GroupInvitationRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocRef;
    late MockAuthRepository mockAuthRepository;
    late MockQuery mockQuery;
    late MockQuerySnapshot mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    
    // Test data
    const currentUserId = 'current-user-123';
    const otherUserId = 'other-user-456';
    const invitationId = 'invitation-123';
    const groupId = 'group-456';
    const groupName = 'Matlagningsgruppen';
    const groupEmoji = '👨‍🍳';
    const fromUserId = 'sender-789';
    const fromUserName = 'Anna Andersson';
    const toUserId = 'recipient-012';
    
    late GroupInvitation testInvitation;
    late Map<String, dynamic> testInvitationMap;
    
    setUpAll(() {
      // Register fallback values for any() matchers
      registerFallbackValue(GroupInvitationStatus.pending);
      registerFallbackValue(FieldValue.serverTimestamp());
      registerFallbackValue(<String, dynamic>{});
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
      mockBatch = MockWriteBatch();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: currentUserId,
        isAuthenticated: true,
      );
      
      // Setup test invitation
      testInvitation = GroupInvitation(
        id: invitationId,
        groupId: groupId,
        groupName: groupName,
        groupEmoji: groupEmoji,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        toUserId: toUserId,
        status: GroupInvitationStatus.pending,
        sentAt: DateTime.now(),
        personalMessage: 'Vill du vara med i vår matlagningsgrupp?',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      
      testInvitationMap = {
        'groupId': groupId,
        'groupName': groupName,
        'groupEmoji': groupEmoji,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'status': 'pending',
        'sentAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'personalMessage': 'Vill du vara med i vår matlagningsgrupp?',
        'expiresAt': {'seconds': 1234567890, 'nanoseconds': 0},
        'respondedAt': null,
      };
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection('group_invitations')).thenReturn(mockCollection);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.get()).thenAnswer((_) async => MockDocumentSnapshot());
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      
      // WriteBatch methods don't have return values
      // Just mock them as callable without thenReturn
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockCollection.where(any(), isLessThan: any(named: 'isLessThan')))
          .thenReturn(mockQuery);
      when(() => mockCollection.where(any(), isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isLessThan: any(named: 'isLessThan')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.count()).thenReturn(MockAggregateQuery());
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuery.snapshots()).thenAnswer(
        (_) => Stream.value(mockQuerySnapshot),
      );
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      
      // Create repository
      repository = GroupInvitationRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('saveInvitation', () {
      test('should save invitation with validation', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final invitation = GroupInvitation.create(
          groupId: groupId,
          groupName: groupName,
          groupEmoji: groupEmoji,
          fromUserId: fromUserId,
          fromUserName: fromUserName,
          toUserId: toUserId,
          personalMessage: 'Join us!',
        );
        
        // Act
        await repository.saveInvitation(invitation);
        
        // Assert
        final captured = verify(() => mockDocRef.set(captureAny())).captured.single;
        expect(captured['fromUserId'], equals(fromUserId));
        expect(captured['toUserId'], equals(toUserId));
        expect(captured['groupId'], equals(groupId));
        expect(captured['status'], equals('pending'));
      });
      
      test('should prevent saving invitation from another user account', () async {
        // Arrange
        final maliciousInvitation = GroupInvitation.create(
          groupId: groupId,
          groupName: groupName,
          groupEmoji: groupEmoji,
          fromUserId: otherUserId, // Trying to send from someone else's account
          fromUserName: 'Fake Name',
          toUserId: toUserId,
        );
        
        // Act & Assert
        expect(
          () => repository.saveInvitation(maliciousInvitation),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('can only send group invitation'))),
        );
      });
      
      test('should reject non-pending status for new invitations', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: fromUserId, isAuthenticated: true);
        final acceptedInvitation = GroupInvitation(
          id: 'new-id',
          groupId: groupId,
          groupName: groupName,
          groupEmoji: groupEmoji,
          fromUserId: fromUserId,
          fromUserName: fromUserName,
          toUserId: toUserId,
          status: GroupInvitationStatus.accepted, // Invalid for new invitations
        );
        
        // Act & Assert
        expect(
          () => repository.saveInvitation(acceptedInvitation),
          throwsA(isA<SecurityViolationException>()
            .having((e) => e.message, 'message', contains('pending status'))),
        );
      });
    });
    
    group('updateInvitation', () {
      test('should update invitation when user is recipient', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(invitationId);
        when(() => mockSnapshot.data()).thenReturn(testInvitationMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        final updateData = {
          'status': GroupInvitationStatus.accepted.name,
          'respondedAt': FieldValue.serverTimestamp(),
        };
        
        // Act
        await repository.updateInvitation(invitationId, updateData);
        
        // Assert
        verify(() => mockDocRef.update(updateData)).called(1);
      });
      
      test('should prevent updating invitation by non-recipient', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: otherUserId, isAuthenticated: true);
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(invitationId);
        when(() => mockSnapshot.data()).thenReturn(testInvitationMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.updateInvitation(invitationId, {'status': 'accepted'}),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('Only the recipient'))),
        );
      });
      
      test('should throw error when invitation not found', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act & Assert
        expect(
          () => repository.updateInvitation('non-existent', {}),
          throwsA(isA<ResourceNotFoundException>()
            .having((e) => e.message, 'message', contains('not found'))),
        );
      });
    });
    
    group('Stream operations', () {
      test('receivedInvitationsStream should stream invitations for user', () async {
        // Arrange
        final mockDoc1 = MockQueryDocumentSnapshot();
        final mockDoc2 = MockQueryDocumentSnapshot();
        
        when(() => mockDoc1.id).thenReturn('inv-1');
        when(() => mockDoc1.data()).thenReturn({
          ...testInvitationMap,
          'toUserId': currentUserId,
        });
        
        when(() => mockDoc2.id).thenReturn('inv-2');
        when(() => mockDoc2.data()).thenReturn({
          ...testInvitationMap,
          'toUserId': currentUserId,
        });
        
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2]);
        
        // Act
        final stream = repository.receivedInvitationsStream(currentUserId);
        final invitations = await stream.first;
        
        // Assert
        expect(invitations.length, equals(2));
        expect(invitations[0].toUserId, equals(currentUserId));
        expect(invitations[1].toUserId, equals(currentUserId));
      });
      
      test('sentInvitationsStream should stream sent invitations', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(invitationId);
        when(() => mockDoc.data()).thenReturn({
          ...testInvitationMap,
          'fromUserId': currentUserId,
        });
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final stream = repository.sentInvitationsStream(currentUserId);
        final invitations = await stream.first;
        
        // Assert
        expect(invitations.length, equals(1));
        expect(invitations[0].fromUserId, equals(currentUserId));
      });
    });
    
    group('Invitation response methods', () {
      setUp(() {
        // Setup for response methods
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(invitationId);
        when(() => mockSnapshot.data()).thenReturn(testInvitationMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
      });
      
      test('acceptInvitation should update status to accepted', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        
        // Act
        final result = await repository.acceptInvitation(invitationId);
        
        // Assert
        expect(result, isTrue);
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['status'], equals('accepted'));
        expect(captured['respondedAt'], isA<FieldValue>());
      });
      
      test('rejectInvitation should update status to rejected', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        
        // Act
        final result = await repository.rejectInvitation(invitationId);
        
        // Assert
        expect(result, isTrue);
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['status'], equals('rejected'));
        expect(captured['respondedAt'], isA<FieldValue>());
      });
      
      test('cancelInvitation should update status to cancelled', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        
        // Act
        final result = await repository.cancelInvitation(invitationId);
        
        // Assert
        expect(result, isTrue);
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['status'], equals('cancelled'));
        expect(captured['respondedAt'], isA<FieldValue>());
      });
      
      test('should return false when update fails', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: toUserId, isAuthenticated: true);
        when(() => mockDocRef.update(any())).thenThrow(Exception('Update failed'));
        
        // Act
        final result = await repository.acceptInvitation(invitationId);
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('hasPendingInvitation', () {
      test('should return true when pending invitation exists', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(invitationId);
        when(() => mockDoc.data()).thenReturn(testInvitationMap);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final hasPending = await repository.hasPendingInvitation(groupId, toUserId);
        
        // Assert
        expect(hasPending, isTrue);
      });
      
      test('should return false when no pending invitation exists', () async {
        // Arrange
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        
        // Act
        final hasPending = await repository.hasPendingInvitation(groupId, toUserId);
        
        // Assert
        expect(hasPending, isFalse);
      });
    });
    
    group('getReceivedInvitations', () {
      test('should return pending invitations for current user', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(invitationId);
        when(() => mockDoc.data()).thenReturn({
          ...testInvitationMap,
          'toUserId': currentUserId,
        });
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final invitations = await repository.getReceivedInvitations();
        
        // Assert
        expect(invitations.length, equals(1));
        expect(invitations[0].toUserId, equals(currentUserId));
        expect(invitations[0].status, equals(GroupInvitationStatus.pending));
      });
      
      test('should return empty list on error', () async {
        // Arrange
        when(() => mockQuery.get()).thenThrow(Exception('Query failed'));
        
        // Act
        final invitations = await repository.getReceivedInvitations();
        
        // Assert
        expect(invitations, isEmpty);
      });
    });
    
    group('getSentInvitations', () {
      test('should return pending sent invitations', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(invitationId);
        when(() => mockDoc.data()).thenReturn({
          ...testInvitationMap,
          'fromUserId': currentUserId,
        });
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final invitations = await repository.getSentInvitations();
        
        // Assert
        expect(invitations.length, equals(1));
        expect(invitations[0].fromUserId, equals(currentUserId));
        expect(invitations[0].status, equals(GroupInvitationStatus.pending));
      });
    });
    
    group('getInvitation', () {
      test('should return invitation when exists', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.id).thenReturn(invitationId);
        when(() => mockSnapshot.data()).thenReturn(testInvitationMap);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final invitation = await repository.getInvitation(invitationId);
        
        // Assert
        expect(invitation, isNotNull);
        expect(invitation!.id, equals(invitationId));
        expect(invitation.groupId, equals(groupId));
      });
      
      test('should return null when invitation does not exist', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final invitation = await repository.getInvitation('non-existent');
        
        // Assert
        expect(invitation, isNull);
      });
    });
    
    group('Cleanup operations', () {
      test('expiredInvitations should return expired invitation references', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        final mockRef = MockDocumentReference();
        when(() => mockDoc.reference).thenReturn(mockRef);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        final now = DateTime.now();
        
        // Act
        final expiredRefs = await repository.expiredInvitations(now);
        
        // Assert
        expect(expiredRefs.length, equals(1));
        verify(() => mockCollection.where('status', isEqualTo: 'pending')).called(1);
      });
      
      test('oldInvitations should return old invitations for user', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
        
        // Act
        final oldDocs = await repository.oldInvitations(currentUserId, cutoffDate);
        
        // Assert
        expect(oldDocs.length, equals(1));
        verify(() => mockCollection.where('toUserId', isEqualTo: currentUserId)).called(1);
      });
      
      test('deleteDocuments should batch delete with permission check', () async {
        // Arrange
        final mockRef1 = MockDocumentReference();
        final mockRef2 = MockDocumentReference();
        final mockSnapshot1 = MockDocumentSnapshot();
        final mockSnapshot2 = MockDocumentSnapshot();
        
        when(() => mockRef1.get()).thenAnswer((_) async => mockSnapshot1);
        when(() => mockRef2.get()).thenAnswer((_) async => mockSnapshot2);
        when(() => mockSnapshot1.exists).thenReturn(true);
        when(() => mockSnapshot2.exists).thenReturn(true);
        when(() => mockSnapshot1.data()).thenReturn({'fromUserId': currentUserId});
        when(() => mockSnapshot2.data()).thenReturn({'toUserId': currentUserId});
        
        // Act
        await repository.deleteDocuments([mockRef1, mockRef2]);
        
        // Assert
        verifyInOrder([
          () => mockBatch.delete(mockRef1),
          () => mockBatch.delete(mockRef2),
          () => mockBatch.commit(),
        ]);
      });
      
      test('deleteDocuments should throw error for unauthorized deletion', () async {
        // Arrange
        final mockRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();
        
        when(() => mockRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockRef.path).thenReturn('group_invitations/123');
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({'fromUserId': otherUserId});
        
        // Act & Assert
        expect(
          () => repository.deleteDocuments([mockRef]),
          throwsA(isA<PermissionDeniedException>()
            .having((e) => e.message, 'message', contains('Cannot delete document'))),
        );
      });
      
      test('updateDocuments should batch update with permission check', () async {
        // Arrange
        final mockRef = MockDocumentReference();
        final mockSnapshot = MockDocumentSnapshot();
        
        when(() => mockRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({'fromUserId': currentUserId});
        
        final updateData = {'status': 'expired'};
        
        // Act
        await repository.updateDocuments([mockRef], updateData);
        
        // Assert
        verify(() => mockBatch.update(mockRef, updateData)).called(1);
        verify(() => mockBatch.commit()).called(1);
      });
    });
    
    group('Statistics and group operations', () {
      test('getInvitationStatistics should return correct counts', () async {
        // Arrange
        final mockAggregateQuery = MockAggregateQuery();
        final mockAggregateSnapshot = MockAggregateQuerySnapshot();
        
        when(() => mockQuery.count()).thenReturn(mockAggregateQuery);
        when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
        // Return different values for each call
        var callCount = 0;
        when(() => mockAggregateSnapshot.count).thenAnswer((_) {
          callCount++;
          return callCount == 1 ? 3 : 2;
        });
        
        // Act
        final stats = await repository.getInvitationStatistics(currentUserId);
        
        // Assert
        expect(stats['pendingReceived'], equals(3));
        expect(stats['pendingSent'], equals(2));
      });
      
      test('getGroupInvitations should return invitations for group', () async {
        // Arrange
        final mockDoc = MockQueryDocumentSnapshot();
        when(() => mockDoc.id).thenReturn(invitationId);
        when(() => mockDoc.data()).thenReturn(testInvitationMap);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final invitations = await repository.getGroupInvitations(
          groupId, 
          status: GroupInvitationStatus.pending,
        );
        
        // Assert
        expect(invitations.length, equals(1));
        expect(invitations[0].groupId, equals(groupId));
        verify(() => mockCollection.where('groupId', isEqualTo: groupId)).called(1);
        verify(() => mockQuery.where('status', isEqualTo: 'pending')).called(1);
      });
      
      test('cleanupExpiredInvitations should update expired invitations', () async {
        // Arrange
        final mockRef = MockDocumentReference();
        final mockDoc = MockQueryDocumentSnapshot();
        
        when(() => mockDoc.reference).thenReturn(mockRef);
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Mock for permission check
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockRef.get()).thenAnswer((_) async => mockSnapshot);
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({'fromUserId': currentUserId});
        
        // Act
        final count = await repository.cleanupExpiredInvitations();
        
        // Assert
        expect(count, equals(1));
        final captured = verify(() => mockBatch.update(mockRef, captureAny())).captured.single;
        expect(captured['status'], equals('expired'));
        expect(captured['expiredAt'], isA<FieldValue>());
      });
    });
    
    group('Base repository implementation', () {
      test('should correctly implement fromFirestore', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot();
        when(() => mockSnapshot.id).thenReturn(invitationId);
        when(() => mockSnapshot.data()).thenReturn(testInvitationMap);
        
        // Act
        final invitation = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(invitation.id, equals(invitationId));
        expect(invitation.groupId, equals(groupId));
        expect(invitation.fromUserId, equals(fromUserId));
      });
      
      test('should correctly implement toFirestore', () {
        // Act
        final firestoreData = repository.toFirestore(testInvitation);
        
        // Assert
        expect(firestoreData['groupId'], equals(groupId));
        expect(firestoreData['fromUserId'], equals(fromUserId));
        expect(firestoreData['toUserId'], equals(toUserId));
        expect(firestoreData['status'], equals('pending'));
      });
      
      test('should correctly implement getId', () {
        // Act
        final id = repository.getId(testInvitation);
        
        // Assert
        expect(id, equals(invitationId));
      });
      
      test('should have correct collection name', () {
        // Assert
        expect(repository.collectionName, equals('group_invitations'));
      });
    });
  });
}