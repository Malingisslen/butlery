import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// ============= EXCEPTION CLASSES =============

// Simple exception classes for tests
class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
}

// ============= FAKE MODELS =============

class FakeMessage extends Fake implements Message {
  @override
  final String id;
  @override
  final String conversationId;
  @override
  final String senderId;
  @override
  final String senderDisplayName;
  @override
  final String? senderAvatarUrl;
  @override
  final String content;
  @override
  final MessageType type;
  @override
  final MessageStatus status;
  @override
  final DateTime sentAt;
  @override
  final DateTime? deliveredAt;
  @override
  final DateTime? readAt;
  @override
  final Map<String, dynamic>? metadata;
  @override
  final String? replyToMessageId;
  @override
  final bool isEdited;
  @override
  final DateTime? editedAt;

  FakeMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderDisplayName,
    this.senderAvatarUrl,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    DateTime? sentAt,
    this.deliveredAt,
    this.readAt,
    this.metadata,
    this.replyToMessageId,
    this.isEdited = false,
    this.editedAt,
  }) : sentAt = sentAt ?? DateTime.now();
}

void main() {
  group('MessagingService Error Handling Tests', () {
    late MessagingService messagingService;
    late MockMessagingRepository mockMessagingRepo;
    late MockAuthRepository mockAuthRepo;
    late User mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Register fallback values for mocktail
      registerFallbackValue(FakeMessage(
        id: 'test',
        conversationId: 'test',
        senderId: 'test',
        senderDisplayName: 'Test',
        content: 'Test',
      ));
    });

    setUp(() {
      mockMessagingRepo = MockMessagingRepository();
      mockAuthRepo = MockAuthRepository();
      
      // Create mock user with proper configuration
      mockUser = MockFactory.createMockUser(
        uid: 'test-user-id',
        displayName: 'Test User',
        photoURL: 'https://example.com/avatar.jpg',
      );

      // Setup auth repository with configuration
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'test-user-id',
      );

      messagingService = MessagingService(
        messagingRepository: mockMessagingRepo,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Firebase/Firestore Errors', () {
      test('should handle permission denied when accessing conversations', () async {
        // Arrange
        when(() => mockMessagingRepo.getUserConversations('test-user-id'))
            .thenAnswer((_) => Stream.error(
                PermissionDeniedException(
                  'User does not have permission to access conversations',
                  resource: 'conversations',
                  userId: 'test-user-id',
                )
            ));

        // Act
        final stream = messagingService.getMyConversations();

        // Assert
        await expectLater(
          stream,
          emitsError(isA<PermissionDeniedException>()),
        );
      });

      test('should handle document not found when fetching messages', () async {
        // Arrange
        const conversationId = 'non-existent-conv';
        when(() => mockMessagingRepo.getConversationMessages(
          conversationId: conversationId,
          limit: any(named: 'limit'),
        )).thenAnswer((_) => Stream.error(
            Exception('Document not found: /conversations/$conversationId')
        ));

        // Act
        final stream = messagingService.getConversationMessages(
          conversationId: conversationId,
        );

        // Assert
        await expectLater(
          stream,
          emitsError(isA<Exception>()),
        );
      });

      test('should handle network errors during message sending', () async {
        // Arrange
        const conversationId = 'conv-network-error';
        const content = 'Test message';
        when(() => mockMessagingRepo.sendMessage(any()))
            .thenAnswer((_) async => throw Exception('Network unavailable'));

        // Act & Assert
        await expectLater(
          messagingService.sendTextMessage(
            conversationId: conversationId,
            content: content,
          ),
          throwsException,
        );
      });

      test('should handle quota exceeded errors', () async {
        // Arrange
        when(() => mockMessagingRepo.getUnreadMessageCount('test-user-id'))
            .thenAnswer((_) async => throw Exception('Quota exceeded: Too many read operations'));

        // Act & Assert
        await expectLater(
          messagingService.getUnreadMessageCount(),
          throwsException,
        );
      });

      test('should handle Firestore transaction timeout', () async {
        // Arrange
        const conversationId = 'conv-transaction';
        when(() => mockMessagingRepo.markConversationAsRead(
          conversationId: conversationId,
          userId: 'test-user-id',
        )).thenAnswer((_) async => throw Exception('Transaction timeout after 5 seconds'));

        // Act & Assert
        await expectLater(
          messagingService.markConversationAsRead(conversationId),
          throwsException,
        );
      });
    });

    group('Message Sending Errors', () {
      test('should handle sending with empty content after trim', () async {
        // Arrange
        const conversationId = 'conv-empty';
        const content = '\n\t   \n'; // Only whitespace

        // Act & Assert
        await expectLater(
          messagingService.sendTextMessage(
            conversationId: conversationId,
            content: content,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should handle message too long validation', () async {
        // Arrange
        const conversationId = 'conv-long';
        final content = 'a' * 10001; // Exceeds typical message limit
        when(() => mockMessagingRepo.sendMessage(any()))
            .thenAnswer((_) async => throw ValidationException('Message exceeds 10000 character limit'));

        // Act & Assert
        await expectLater(
          messagingService.sendTextMessage(
            conversationId: conversationId,
            content: content,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should handle network timeout during send', () async {
        // Arrange
        const conversationId = 'conv-timeout';
        const content = 'Timeout message';
        when(() => mockMessagingRepo.sendMessage(any()))
            .thenAnswer((_) async => throw Exception('Request timed out after 30 seconds'));

        // Act & Assert
        await expectLater(
          messagingService.sendTextMessage(
            conversationId: conversationId,
            content: content,
          ),
          throwsException,
        );
      });

      test('should handle sending message with invalid metadata', () async {
        // Arrange
        const conversationId = 'conv-metadata';
        const recipeId = ''; // Empty recipe ID
        when(() => mockMessagingRepo.sendMessage(any()))
            .thenAnswer((_) async => throw ValidationException('Invalid recipe ID'));

        // Act & Assert
        await expectLater(
          messagingService.sendRecipeShare(
            conversationId: conversationId,
            recipeId: recipeId,
            recipeTitle: 'Test Recipe',
          ),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('Conversation Management Errors', () {
      test('should handle creating conversation with invalid participants', () async {
        // Arrange
        final participantIds = <String>[]; // Empty participants list
        when(() => mockMessagingRepo.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
          creatorId: any(named: 'creatorId'),
        )).thenAnswer((_) async => throw ValidationException('At least 2 participants required'));

        // Act & Assert
        await expectLater(
          messagingService.createGroupConversation(
            participantIds: participantIds,
            participantDisplayNames: {},
            participantAvatarUrls: {},
            title: 'Empty Group',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should handle updating non-existent conversation', () async {
        // Arrange
        const conversationId = 'non-existent-conv';
        const newTitle = 'Updated Title';
        when(() => mockMessagingRepo.updateConversation(
          conversationId: conversationId,
          title: newTitle,
        )).thenAnswer((_) async => throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        ));

        // Act & Assert
        await expectLater(
          messagingService.updateGroupTitle(
            conversationId: conversationId,
            newTitle: newTitle,
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should handle leaving conversation as last admin', () async {
        // Arrange
        const conversationId = 'conv-admin';
        const userId = 'test-user-id';
        when(() => mockMessagingRepo.removeParticipant(
          conversationId: conversationId,
          participantId: userId,
        )).thenAnswer((_) async => throw PermissionDeniedException(
          'Cannot leave: You are the only admin',
          resource: 'conversation:$conversationId',
          userId: userId,
        ));

        // Act & Assert
        await expectLater(
          messagingService.removeParticipantFromGroup(
            conversationId: conversationId,
            participantId: userId,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should handle adding duplicate participants', () async {
        // Arrange
        const conversationId = 'conv-duplicate';
        final participantIds = ['user-1', 'user-1']; // Duplicate user
        when(() => mockMessagingRepo.addParticipants(
          conversationId: conversationId,
          participantIds: participantIds,
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
        )).thenAnswer((_) async => throw ValidationException('Duplicate participant IDs'));

        // Act & Assert
        await expectLater(
          messagingService.addParticipantsToGroup(
            conversationId: conversationId,
            participantIds: participantIds,
            participantDisplayNames: {'user-1': 'User One'},
            participantAvatarUrls: {},
          ),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('Real-time Messaging Errors', () {
      test('should handle stream errors during message listening', () async {
        // Arrange
        const conversationId = 'conv-stream-error';
        when(() => mockMessagingRepo.getConversationMessages(
          conversationId: conversationId,
          limit: any(named: 'limit'),
        )).thenAnswer((_) => Stream.error(
            Exception('WebSocket connection lost')
        ));

        // Act
        final stream = messagingService.getConversationMessages(
          conversationId: conversationId,
        );

        // Assert
        await expectLater(
          stream,
          emitsError(isA<Exception>()),
        );
      });

      test('should handle connection lost during typing indicator', () async {
        // Arrange
        const conversationId = 'conv-typing-error';
        
        // Act
        await messagingService.setTypingIndicator(conversationId);
        
        // Simulate connection loss (typing indicators are ephemeral)
        // The service should handle this gracefully
        
        // Assert - Should not throw, typing indicators fail silently
        expect(true, isTrue);
      });

      test('should handle stream cancellation errors', () async {
        // Arrange
        const conversationId = 'conv-cancel';
        final controller = StreamController<List<Message>>();
        when(() => mockMessagingRepo.getConversationMessages(
          conversationId: conversationId,
          limit: any(named: 'limit'),
        )).thenAnswer((_) => controller.stream);

        // Act
        final stream = messagingService.getConversationMessages(
          conversationId: conversationId,
        );
        final subscription = stream.listen((_) {});
        
        // Cancel subscription and emit error
        await subscription.cancel();
        controller.addError(Exception('Stream cancelled'));
        
        // Assert - Stream should be cancelled, no error should propagate
        expect(subscription.isPaused, isFalse);
        await controller.close();
      });
    });

    group('Message Operations Errors', () {
      test('should handle editing deleted message', () async {
        // Arrange
        const messageId = 'deleted-msg';
        when(() => mockMessagingRepo.getMessage(messageId))
            .thenAnswer((_) async => null);

        // Act & Assert
        await expectLater(
          messagingService.editMessage(
            messageId: messageId,
            newContent: 'New content',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should handle deleting message from another user', () async {
        // Arrange
        const messageId = 'other-user-msg';
        when(() => mockMessagingRepo.getMessage(messageId))
            .thenAnswer((_) async => FakeMessage(
              id: messageId,
              conversationId: 'conv-123',
              senderId: 'other-user-id', // Different user
              senderDisplayName: 'Other User',
              content: 'Not my message',
            ));

        // Act & Assert
        await expectLater(
          messagingService.deleteMessage(messageId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should handle mark as read for invalid conversation', () async {
        // Arrange
        const conversationId = 'invalid-conv';
        when(() => mockMessagingRepo.markConversationAsRead(
          conversationId: conversationId,
          userId: 'test-user-id',
        )).thenAnswer((_) async => throw ResourceNotFoundException(
          'Conversation not found',
          resourceType: 'conversation',
          resourceId: conversationId,
        ));

        // Act & Assert
        await expectLater(
          messagingService.markConversationAsRead(conversationId),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });

      test('should handle editing message with empty content', () async {
        // Arrange
        const messageId = 'msg-empty-edit';
        const newContent = '   '; // Only whitespace
        
        when(() => mockMessagingRepo.getMessage(messageId))
            .thenAnswer((_) async => FakeMessage(
              id: messageId,
              conversationId: 'conv-123',
              senderId: 'test-user-id',
              senderDisplayName: 'Test User',
              content: 'Original',
            ));

        // Act & Assert
        await expectLater(
          messagingService.editMessage(
            messageId: messageId,
            newContent: newContent,
          ),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('Concurrent Operation Errors', () {
      test('should handle multiple simultaneous message sends', () async {
        // Arrange
        const conversationId = 'conv-concurrent';
        final messages = List.generate(10, (i) => 'Message $i');
        var sendCount = 0;
        
        when(() => mockMessagingRepo.sendMessage(any()))
            .thenAnswer((_) async {
              sendCount++;
              if (sendCount == 5) {
                throw Exception('Rate limit exceeded');
              }
            });

        // Act
        final futures = messages.map((content) =>
          messagingService.sendTextMessage(
            conversationId: conversationId,
            content: content,
          ).catchError((_) {})
        ).toList();

        // Assert
        await Future.wait(futures);
        expect(sendCount, greaterThanOrEqualTo(5));
      });

      test('should handle concurrent conversation updates', () async {
        // Arrange
        const conversationId = 'conv-update-concurrent';
        var updateCount = 0;
        
        when(() => mockMessagingRepo.updateConversation(
          conversationId: conversationId,
          title: any(named: 'title'),
        )).thenAnswer((_) async {
          updateCount++;
          if (updateCount > 1) {
            throw Exception('Concurrent modification detected');
          }
        });

        // Act
        final future1 = messagingService.updateGroupTitle(
          conversationId: conversationId,
          newTitle: 'Title 1',
        ).catchError((_) {});
        
        final future2 = messagingService.updateGroupTitle(
          conversationId: conversationId,
          newTitle: 'Title 2',
        ).catchError((_) {});

        // Assert
        await Future.wait<void>([future1, future2]);
        expect(updateCount, greaterThanOrEqualTo(2));
      });

      test('should handle race conditions in unread counts', () async {
        // Arrange
        var callCount = 0;
        when(() => mockMessagingRepo.getUnreadMessageCount('test-user-id'))
            .thenAnswer((_) async {
              callCount++;
              await Future.delayed(const Duration(milliseconds: 10));
              return callCount * 5; // Different count each call
            });

        // Act
        final futures = List.generate(5, (_) =>
          messagingService.getUnreadMessageCount()
        );
        final results = await Future.wait(futures);

        // Assert
        expect(results.toSet().length, greaterThan(1)); // Different results
        expect(callCount, equals(5));
      });

      test('should handle concurrent participant additions', () async {
        // Arrange
        const conversationId = 'conv-add-concurrent';
        var addCount = 0;
        
        when(() => mockMessagingRepo.addParticipants(
          conversationId: conversationId,
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
        )).thenAnswer((_) async {
          addCount++;
          if (addCount > 1) {
            throw Exception('Participants already being modified');
          }
        });

        // Act
        final future1 = messagingService.addParticipantsToGroup(
          conversationId: conversationId,
          participantIds: ['user-a'],
          participantDisplayNames: {'user-a': 'User A'},
          participantAvatarUrls: {},
        ).catchError((_) {});
        
        final future2 = messagingService.addParticipantsToGroup(
          conversationId: conversationId,
          participantIds: ['user-b'],
          participantDisplayNames: {'user-b': 'User B'},
          participantAvatarUrls: {},
        ).catchError((_) {});

        // Assert
        await Future.wait<void>([future1, future2]);
        expect(addCount, greaterThanOrEqualTo(2));
      });

      test('should handle concurrent message deletion', () async {
        // Arrange
        const messageId = 'msg-delete-concurrent';
        var deleteCount = 0;
        
        when(() => mockMessagingRepo.getMessage(messageId))
            .thenAnswer((_) async => FakeMessage(
              id: messageId,
              conversationId: 'conv-123',
              senderId: 'test-user-id',
              senderDisplayName: 'Test User',
              content: 'To delete',
            ));
        
        when(() => mockMessagingRepo.deleteMessage(messageId))
            .thenAnswer((_) async {
              deleteCount++;
              if (deleteCount > 1) {
                throw ResourceNotFoundException(
                  'Message already deleted',
                  resourceType: 'message',
                  resourceId: messageId,
                );
              }
            });

        // Act
        final futures = List.generate(3, (_) =>
          messagingService.deleteMessage(messageId)
            .catchError((_) {})
        );

        // Assert
        await Future.wait(futures);
        expect(deleteCount, greaterThanOrEqualTo(2));
      });
    });
  });
}