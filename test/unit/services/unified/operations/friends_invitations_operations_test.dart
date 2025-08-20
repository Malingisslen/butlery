import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

// Mock for UnifiedFriendsService
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {
  final List<GroupInvitation> _sentInvitations = [];
  final List<GroupInvitation> _receivedInvitations = [];
  String? _currentUserId;
  String? _currentUserDisplayName;
  
  @override
  String? get currentUserId => _currentUserId;
  
  @override
  String? get currentUserDisplayName => _currentUserDisplayName;
  
  List<GroupInvitation> get sentInvitationsList => _sentInvitations;
  
  List<GroupInvitation> get receivedInvitationsList => _receivedInvitations;
  
  void setServiceState({
    String? currentUserId,
    String? currentUserDisplayName,
    List<GroupInvitation>? sentInvitations,
    List<GroupInvitation>? receivedInvitations,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (currentUserDisplayName != null) _currentUserDisplayName = currentUserDisplayName;
    if (sentInvitations != null) {
      _sentInvitations.clear();
      _sentInvitations.addAll(sentInvitations);
    }
    if (receivedInvitations != null) {
      _receivedInvitations.clear();
      _receivedInvitations.addAll(receivedInvitations);
    }
  }
  
  @override
  void addSentInvitationInternal(GroupInvitation invitation) {
    _sentInvitations.add(invitation);
  }
  
  @override
  void updateSentInvitationInternal(String invitationId, GroupInvitation updatedInvitation) {
    final index = _sentInvitations.indexWhere((inv) => inv.id == invitationId);
    if (index != -1) {
      _sentInvitations[index] = updatedInvitation;
    }
  }
  
  @override
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) {
    return _sentInvitations.firstWhere(
      (inv) => inv.id == invitationId,
      orElse: () => GroupInvitation(
        id: '',
        groupId: '',
        groupName: '',
        groupEmoji: '👥',
        fromUserId: '',
        fromUserName: '',
        toUserId: '',
        sentAt: DateTime.now(),
      ),
    );
  }
  
  @override
  void notifyListenersInternal() {
    // Mock implementation - no-op
  }
  
  @override
  Future<bool> sendEmailInvitationInternal({
    required String email,
    required GroupInvitation invitation,
  }) async {
    // Mock implementation - return true for valid emails
    return email.contains('@');
  }
  
  @override
  Future<bool> sendSMSInvitationInternal({
    required String phoneNumber,
    required GroupInvitation invitation,
  }) async {
    // Mock implementation - return true for valid phone numbers
    return phoneNumber.startsWith('+');
  }
  
  @override
  String createInvitationLinkInternal(String invitationId) {
    return 'https://butlery.app/invite/$invitationId';
  }
  
  @override
  Future<void> updateInvitationStatusInternal(String invitationId, GroupInvitationStatus status) async {
    // Mock implementation - just update local state
    final invitation = getSentInvitationByIdInternal(invitationId);
    if (invitation != null && invitation.id.isNotEmpty) {
      final updatedInvitation = invitation.copyWith(status: status);
      updateSentInvitationInternal(invitationId, updatedInvitation);
    }
  }
  
  @override
  List<GroupInvitation> getAllSentInvitationsInternal() => _sentInvitations;
}

void main() {
  group('FriendsInvitationsOperations', () {
    late FriendsInvitationsOperations operations;
    late MockUnifiedFriendsService mockParentService;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(GroupInvitation(
        id: 'test',
        groupId: '',
        groupName: '',
        groupEmoji: '👥',
        fromUserId: 'test',
        fromUserName: 'Test',
        toUserId: 'test',
        sentAt: DateTime.now(),
      ));
      registerFallbackValue(GroupInvitationStatus.pending);
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mock parent service
      mockParentService = MockUnifiedFriendsService();
      mockParentService.setServiceState(
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
        sentInvitations: [],
        receivedInvitations: [],
      );
      
      // Create operations instance
      operations = FriendsInvitationsOperations(mockParentService);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Email Invitations', () {
      test('should send email invitation successfully', () async {
        // Act
        final result = await operations.sendEmailInvitation(
          email: 'friend@example.com',
          customMessage: 'Join me on Butlery!',
          senderName: 'Test Sender',
        );
        
        // Assert
        expect(result, isTrue);
        expect(mockParentService.sentInvitationsList.length, equals(1));
        
        final invitation = mockParentService.sentInvitationsList.first;
        expect(invitation.toUserId, equals('friend@example.com'));
        expect(invitation.personalMessage, equals('Join me on Butlery!'));
        expect(invitation.fromUserName, equals('Test Sender'));
      });
      
      test('should reject invalid email address', () async {
        // Act
        final result = await operations.sendEmailInvitation(
          email: 'invalid-email',
          customMessage: 'Join me!',
        );
        
        // Assert
        expect(result, isFalse);
        expect(mockParentService.sentInvitationsList.length, equals(0));
      });
      
      test('should not send duplicate email invitation', () async {
        // Arrange - Add existing invitation
        mockParentService.addSentInvitationInternal(GroupInvitation(
          id: 'existing-1',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: 'friend@example.com',
          sentAt: DateTime.now(),
        ));
        
        // Act
        final result = await operations.sendEmailInvitation(
          email: 'friend@example.com',
          customMessage: 'Join again!',
        );
        
        // Assert
        expect(result, isFalse);
        expect(mockParentService.sentInvitationsList.length, equals(1)); // Still just 1
      });
      
      test('should use default sender name if not provided', () async {
        // Act
        final result = await operations.sendEmailInvitation(
          email: 'new@example.com',
          customMessage: 'Welcome!',
        );
        
        // Assert
        expect(result, isTrue);
        
        final invitation = mockParentService.sentInvitationsList.last;
        expect(invitation.fromUserName, equals('Test User'));
      });
    });
    
    group('SMS Invitations', () {
      test('should send SMS invitation successfully', () async {
        // Act
        final result = await operations.sendSMSInvitation(
          phoneNumber: '+46701234567',
          customMessage: 'Join me on Butlery!',
          senderName: 'Test Sender',
        );
        
        // Assert
        expect(result, isTrue);
        expect(mockParentService.sentInvitationsList.length, equals(1));
        
        final invitation = mockParentService.sentInvitationsList.first;
        expect(invitation.toUserId, equals('+46701234567'));
        expect(invitation.personalMessage, equals('Join me on Butlery!'));
      });
      
      test('should reject invalid phone number', () async {
        // Act
        final result = await operations.sendSMSInvitation(
          phoneNumber: '123',
          customMessage: 'Join me!',
        );
        
        // Assert
        expect(result, isFalse);
        expect(mockParentService.sentInvitationsList.length, equals(0));
      });
      
      test('should not send duplicate SMS invitation', () async {
        // Arrange - Add existing invitation
        mockParentService.addSentInvitationInternal(GroupInvitation(
          id: 'existing-1',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: '+46701234567',
          sentAt: DateTime.now(),
        ));
        
        // Act
        final result = await operations.sendSMSInvitation(
          phoneNumber: '+46701234567',
          customMessage: 'Join again!',
        );
        
        // Assert
        expect(result, isFalse);
        expect(mockParentService.sentInvitationsList.length, equals(1));
      });
    });
    
    group('Invitation Links', () {
      test('should create invitation link successfully', () async {
        // Act
        final link = await operations.createInvitationLink(
          customMessage: 'Join my cooking community!',
          expiresAt: DateTime.now().add(const Duration(days: 14)),
        );
        
        // Assert
        expect(link, isNotNull);
        expect(link, contains('https://butlery.app/invite/'));
        expect(mockParentService.sentInvitationsList.length, equals(1));
        
        final invitation = mockParentService.sentInvitationsList.first;
        expect(invitation.personalMessage, equals('Join my cooking community!'));
        expect(invitation.expiresAt, isNotNull);
      });
      
      test('should use default expiration if not provided', () async {
        // Act
        final link = await operations.createInvitationLink(
          customMessage: 'Welcome!',
        );
        
        // Assert
        expect(link, isNotNull);
        
        final invitation = mockParentService.sentInvitationsList.first;
        final expiresAt = invitation.expiresAt;
        expect(expiresAt, isNotNull);
        
        // Check that expiration is roughly 7 days from now  
        final daysDiff = expiresAt.difference(DateTime.now()).inDays;
        expect(daysDiff, greaterThanOrEqualTo(6));
        expect(daysDiff, lessThanOrEqualTo(7));
      });
    });
    
    group('Bulk Invitations', () {
      test('should send bulk invitations to mixed contacts', () async {
        // Arrange
        final contacts = [
          {'email': 'friend1@example.com'},
          {'phoneNumber': '+46701234567'},
          {'email': 'friend2@example.com'},
        ];
        
        // Act
        final results = await operations.sendBulkInvitations(
          contacts: contacts,
          customMessage: 'Join us!',
          senderName: 'Bulk Sender',
        );
        
        // Assert
        expect(results.length, equals(3));
        expect(results['friend1@example.com'], isTrue);
        expect(results['+46701234567'], isTrue);
        expect(results['friend2@example.com'], isTrue);
        expect(mockParentService.sentInvitationsList.length, equals(3));
      });
      
      test('should handle invalid contacts in bulk send', () async {
        // Arrange
        final contacts = [
          {'email': 'valid@example.com'},
          {'email': 'invalid-email'},
          {'phoneNumber': '123'}, // Invalid phone
        ];
        
        // Act
        final results = await operations.sendBulkInvitations(
          contacts: contacts,
          customMessage: 'Join!',
        );
        
        // Assert
        expect(results['valid@example.com'], isTrue);
        expect(results['invalid-email'], isFalse);
        expect(results['123'], isFalse);
        expect(mockParentService.sentInvitationsList.length, equals(1));
      });
    });
    
    group('Invitation Management', () {
      test('should cancel pending invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'inv-123',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: 'friend@example.com',
          sentAt: DateTime.now(),
          status: GroupInvitationStatus.pending,
        );
        mockParentService.addSentInvitationInternal(invitation);
        
        // Act
        final result = await operations.cancelInvitation('inv-123');
        
        // Assert
        expect(result, isTrue);
        
        final cancelled = mockParentService.getSentInvitationByIdInternal('inv-123');
        expect(cancelled!.status, equals(GroupInvitationStatus.cancelled));
      });
      
      test('should not cancel accepted invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'inv-123',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: 'friend@example.com',
          sentAt: DateTime.now(),
          status: GroupInvitationStatus.accepted,
        );
        mockParentService.addSentInvitationInternal(invitation);
        
        // Act
        final result = await operations.cancelInvitation('inv-123');
        
        // Assert
        expect(result, isFalse);
        
        final invitation2 = mockParentService.getSentInvitationByIdInternal('inv-123');
        expect(invitation2!.status, equals(GroupInvitationStatus.accepted));
      });
      
      test('should resend invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'inv-123',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: 'friend@example.com',
          sentAt: DateTime.now().subtract(const Duration(days: 7)),
          status: GroupInvitationStatus.expired,
        );
        mockParentService.addSentInvitationInternal(invitation);
        
        // Act
        final result = await operations.resendInvitation('inv-123');
        
        // Assert
        expect(result, isTrue);
        
        final resent = mockParentService.getSentInvitationByIdInternal('inv-123');
        expect(resent!.status, equals(GroupInvitationStatus.pending));
      });
      
      test('should not resend accepted invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'inv-123',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: 'friend@example.com',
          sentAt: DateTime.now(),
          status: GroupInvitationStatus.accepted,
        );
        mockParentService.addSentInvitationInternal(invitation);
        
        // Act
        final result = await operations.resendInvitation('inv-123');
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should mark invitation as viewed', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'inv-123',
          groupId: '',
          groupName: '',
          groupEmoji: '👥',
          fromUserId: 'test-user-123',
          fromUserName: 'Test User',
          toUserId: 'friend@example.com',
          sentAt: DateTime.now(),
          status: GroupInvitationStatus.pending,
        );
        mockParentService.addSentInvitationInternal(invitation);
        
        // Act
        final result = await operations.markInvitationAsViewed('inv-123');
        
        // Assert
        expect(result, isTrue);
        
        final viewed = mockParentService.getSentInvitationByIdInternal('inv-123');
        expect(viewed?.respondedAt, isNotNull);
      });
    });
    
    group('Invitation Queries', () {
      test('should get pending invitations', () {
        // Arrange
        mockParentService.setServiceState(
          sentInvitations: [
            GroupInvitation(
              id: '1',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user1',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.pending,
            ),
            GroupInvitation(
              id: '2',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user2',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.accepted,
            ),
          ],
        );
        
        // Act
        final pending = operations.getPendingInvitations();
        
        // Assert
        expect(pending.length, equals(1));
        expect(pending.first.id, equals('1'));
      });
      
      test('should get invitations by status', () {
        // Arrange
        mockParentService.setServiceState(
          sentInvitations: [
            GroupInvitation(
              id: '1',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user1',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.pending,
            ),
            GroupInvitation(
              id: '2',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user2',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.accepted,
            ),
          ],
        );
        
        // Act
        final accepted = operations.getInvitationsByStatus(GroupInvitationStatus.accepted);
        
        // Assert
        expect(accepted.length, equals(1));
        expect(accepted.first.id, equals('2'));
      });
      
      test('should check if invitation exists', () {
        // Arrange
        mockParentService.setServiceState(
          sentInvitations: [
            GroupInvitation(
              id: '1',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'test@example.com',
              sentAt: DateTime.now(),
            ),
          ],
        );
        
        // Act & Assert
        expect(operations.hasInvitation(email: 'test@example.com'), isTrue);
        expect(operations.hasInvitation(email: 'other@example.com'), isFalse);
      });
      
      test('should get invitation statistics', () {
        // Arrange
        mockParentService.setServiceState(
          sentInvitations: [
            GroupInvitation(
              id: '1',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user1',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.pending,
            ),
            GroupInvitation(
              id: '2',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user2',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.accepted,
            ),
            GroupInvitation(
              id: '3',
              groupId: '',
              groupName: '',
          groupEmoji: '👥',
              fromUserId: 'test-user-123',
              fromUserName: 'Test',
              toUserId: 'user3',
              sentAt: DateTime.now(),
              status: GroupInvitationStatus.rejected,
            ),
          ],
        );
        
        // Act
        final stats = operations.getInvitationStats();
        
        // Assert
        expect(stats['total'], equals(3));
        expect(stats['pending'], equals(1));
        expect(stats['accepted'], equals(1));
        expect(stats['rejected'], equals(1));
        expect(stats['acceptanceRate'], closeTo(33, 1));
      });
    });
  });
}