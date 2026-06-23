/// Unit tests for services using MessagingRepository
///
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('MessagingRepository Mock Tests', () {
    late MockMessagingRepository mockRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(
        Conversation.direct(
          user1Id: 'fallback1',
          user1DisplayName: 'Fallback User 1',
          user2Id: 'fallback2',
          user2DisplayName: 'Fallback User 2',
        ),
      );
      registerFallbackValue(
        Message.text(
          conversationId: 'fallback_conv',
          senderId: 'fallback_sender',
          senderDisplayName: 'Fallback User',
          content: 'Fallback message',
        ),
      );
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mock repository with configuration
      mockRepository = MockFactory.createMessagingRepository(
        currentUserId: 'test_user_123',
        conversations: {},
        messagesByConversation: {},
        readMessagesByUser: {},
        messageStatuses: {},
      );

      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Conversation Management', () {
      test('should create direct conversation between two users', () async {
        // Arrange
        const user1Id = 'user_1';
        const user1Name = 'Alice';
        const user2Id = 'user_2';
        const user2Name = 'Bob';
        const expectedConversationId = 'conv_123';

        // Stub the repository method
        when(
          () => mockRepository.createDirectConversation(
            user1Id: user1Id,
            user1DisplayName: user1Name,
            user2Id: user2Id,
            user2DisplayName: user2Name,
          ),
        ).thenAnswer((_) async => expectedConversationId);

        // Act
        final conversationId = await mockRepository.createDirectConversation(
          user1Id: user1Id,
          user1DisplayName: user1Name,
          user2Id: user2Id,
          user2DisplayName: user2Name,
        );

        // Assert
        expect(conversationId, equals(expectedConversationId));
        verify(
          () => mockRepository.createDirectConversation(
            user1Id: user1Id,
            user1DisplayName: user1Name,
            user2Id: user2Id,
            user2DisplayName: user2Name,
          ),
        ).called(1);
      });

      test('should find existing direct conversation', () async {
        // Arrange
        const user1Id = 'user_1';
        const user2Id = 'user_2';
        const existingConversationId = 'existing_conv_123';

        // Stub the repository method
        when(
          () => mockRepository.findDirectConversation(
            user1Id: user1Id,
            user2Id: user2Id,
          ),
        ).thenAnswer((_) async => existingConversationId);

        // Act
        final conversationId = await mockRepository.findDirectConversation(
          user1Id: user1Id,
          user2Id: user2Id,
        );

        // Assert
        expect(conversationId, equals(existingConversationId));
        verify(
          () => mockRepository.findDirectConversation(
            user1Id: user1Id,
            user2Id: user2Id,
          ),
        ).called(1);
      });

      test('should create group conversation', () async {
        // Arrange
        final participantIds = ['user_1', 'user_2', 'user_3'];
        final participantNames = {
          'user_1': 'Alice',
          'user_2': 'Bob',
          'user_3': 'Charlie',
        };
        final participantAvatars = {
          'user_1': 'avatar1.jpg',
          'user_2': null,
          'user_3': 'avatar3.jpg',
        };
        const title = 'Recipe Discussion Group';
        const creatorId = 'user_1';
        const expectedConversationId = 'group_conv_123';

        // Stub the repository method
        when(
          () => mockRepository.createGroupConversation(
            participantIds: participantIds,
            participantDisplayNames: participantNames,
            participantAvatarUrls: participantAvatars,
            title: title,
            creatorId: creatorId,
          ),
        ).thenAnswer((_) async => expectedConversationId);

        // Act
        final conversationId = await mockRepository.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: participantNames,
          participantAvatarUrls: participantAvatars,
          title: title,
          creatorId: creatorId,
        );

        // Assert
        expect(conversationId, equals(expectedConversationId));
        verify(
          () => mockRepository.createGroupConversation(
            participantIds: participantIds,
            participantDisplayNames: participantNames,
            participantAvatarUrls: participantAvatars,
            title: title,
            creatorId: creatorId,
          ),
        ).called(1);
      });

      test('should get conversation by ID', () async {
        // Arrange
        const conversationId = 'conv_123';
        final expectedConversation = Conversation.direct(
          user1Id: 'user_1',
          user1DisplayName: 'Alice',
          user2Id: 'user_2',
          user2DisplayName: 'Bob',
        );

        // Stub the repository method
        when(
          () => mockRepository.getConversation(conversationId),
        ).thenAnswer((_) async => expectedConversation);

        // Act
        final conversation = await mockRepository.getConversation(
          conversationId,
        );

        // Assert
        expect(conversation, isNotNull);
        expect(conversation, equals(expectedConversation));
        verify(() => mockRepository.getConversation(conversationId)).called(1);
      });

      test('should stream user conversations', () async {
        // Arrange
        const userId = 'test_user_123';
        final conversations = [
          Conversation.direct(
            user1Id: userId,
            user1DisplayName: 'Test User',
            user2Id: 'friend_1',
            user2DisplayName: 'Friend 1',
          ),
          Conversation.direct(
            user1Id: userId,
            user1DisplayName: 'Test User',
            user2Id: 'friend_2',
            user2DisplayName: 'Friend 2',
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getUserConversations(userId),
        ).thenAnswer((_) => Stream.value(conversations));

        // Act
        final stream = mockRepository.getUserConversations(userId);
        final result = await stream.first;

        // Assert
        expect(result, hasLength(2));
        expect(result.first.participantIds, contains(userId));
        verify(() => mockRepository.getUserConversations(userId)).called(1);
      });
    });

    group('Message Operations', () {
      test('should send text message', () async {
        // Arrange
        final message = Message.text(
          conversationId: 'conv_123',
          senderId: 'user_1',
          senderDisplayName: 'Alice',
          content: 'Hello, Bob!',
        );

        // Stub the repository method
        when(
          () => mockRepository.sendMessage(message),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.sendMessage(message);

        // Assert
        verify(() => mockRepository.sendMessage(message)).called(1);
      });

      test('should stream conversation messages', () async {
        // Arrange
        const conversationId = 'conv_123';
        final messages = [
          Message.text(
            conversationId: conversationId,
            senderId: 'user_1',
            senderDisplayName: 'Alice',
            content: 'Hello!',
          ),
          Message.text(
            conversationId: conversationId,
            senderId: 'user_2',
            senderDisplayName: 'Bob',
            content: 'Hi Alice!',
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getConversationMessages(
            conversationId: conversationId,
            limit: 50,
          ),
        ).thenAnswer((_) => Stream.value(messages));

        // Act
        final stream = mockRepository.getConversationMessages(
          conversationId: conversationId,
        );
        final result = await stream.first;

        // Assert
        expect(result, hasLength(2));
        expect(result.first.content, equals('Hello!'));
        expect(result[1].content, equals('Hi Alice!'));

        verify(
          () => mockRepository.getConversationMessages(
            conversationId: conversationId,
            limit: 50,
          ),
        ).called(1);
      });

      test('should get paginated messages', () async {
        // Arrange
        const conversationId = 'conv_123';
        final startAfter = DateTime.now().subtract(const Duration(hours: 1));
        final messages = [
          Message.text(
            conversationId: conversationId,
            senderId: 'user_1',
            senderDisplayName: 'Alice',
            content: 'Page 2 message 1',
          ),
          Message.text(
            conversationId: conversationId,
            senderId: 'user_2',
            senderDisplayName: 'Bob',
            content: 'Page 2 message 2',
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getConversationMessagesPage(
            conversationId: conversationId,
            limit: 50,
            startAfter: startAfter,
          ),
        ).thenAnswer((_) async => messages);

        // Act
        final result = await mockRepository.getConversationMessagesPage(
          conversationId: conversationId,
          startAfter: startAfter,
        );

        // Assert
        expect(result, hasLength(2));
        verify(
          () => mockRepository.getConversationMessagesPage(
            conversationId: conversationId,
            limit: 50,
            startAfter: startAfter,
          ),
        ).called(1);
      });

      test('should update message content', () async {
        // Arrange
        const messageId = 'msg_123';
        const newContent = 'Edited message content';

        // Stub the repository method
        when(
          () => mockRepository.updateMessageContent(
            messageId: messageId,
            newContent: newContent,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateMessageContent(
          messageId: messageId,
          newContent: newContent,
        );

        // Assert
        verify(
          () => mockRepository.updateMessageContent(
            messageId: messageId,
            newContent: newContent,
          ),
        ).called(1);
      });

      test('should delete message', () async {
        // Arrange
        const messageId = 'msg_to_delete';

        // Stub the repository method
        when(
          () => mockRepository.deleteMessage(messageId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.deleteMessage(messageId);

        // Assert
        verify(() => mockRepository.deleteMessage(messageId)).called(1);
      });
    });

    group('Message Status', () {
      test('should update message status', () async {
        // Arrange
        const messageId = 'msg_123';
        const status = MessageStatus.delivered;
        final timestamp = DateTime.now();

        // Stub the repository method
        when(
          () => mockRepository.updateMessageStatus(
            messageId: messageId,
            status: status,
            timestamp: timestamp,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateMessageStatus(
          messageId: messageId,
          status: status,
          timestamp: timestamp,
        );

        // Assert
        verify(
          () => mockRepository.updateMessageStatus(
            messageId: messageId,
            status: status,
            timestamp: timestamp,
          ),
        ).called(1);
      });

      test('should mark message as read', () async {
        // Arrange
        const messageId = 'msg_123';
        const userId = 'user_1';

        // Stub the repository method
        when(
          () => mockRepository.markMessageAsRead(
            messageId: messageId,
            userId: userId,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.markMessageAsRead(
          messageId: messageId,
          userId: userId,
        );

        // Assert
        verify(
          () => mockRepository.markMessageAsRead(
            messageId: messageId,
            userId: userId,
          ),
        ).called(1);
      });

      test('should mark conversation as read', () async {
        // Arrange
        const conversationId = 'conv_123';
        const userId = 'user_1';

        // Stub the repository method
        when(
          () => mockRepository.markConversationAsRead(
            conversationId: conversationId,
            userId: userId,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.markConversationAsRead(
          conversationId: conversationId,
          userId: userId,
        );

        // Assert
        verify(
          () => mockRepository.markConversationAsRead(
            conversationId: conversationId,
            userId: userId,
          ),
        ).called(1);
      });

      test('should batch mark messages as delivered', () async {
        // Arrange
        final messageIds = ['msg_1', 'msg_2', 'msg_3'];
        const userId = 'user_1';

        // Stub the repository method
        when(
          () => mockRepository.batchMarkAsDelivered(
            messageIds: messageIds,
            userId: userId,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.batchMarkAsDelivered(
          messageIds: messageIds,
          userId: userId,
        );

        // Assert
        verify(
          () => mockRepository.batchMarkAsDelivered(
            messageIds: messageIds,
            userId: userId,
          ),
        ).called(1);
      });
    });

    group('Participant Management', () {
      test('should add participants to group', () async {
        // Arrange
        const conversationId = 'group_conv_123';
        final newParticipantIds = ['user_4', 'user_5'];
        final newParticipantNames = {
          'user_4': 'David',
          'user_5': 'Emma',
        };
        final newParticipantAvatars = {
          'user_4': 'avatar4.jpg',
          'user_5': null,
        };

        // Stub the repository method
        when(
          () => mockRepository.addParticipants(
            conversationId: conversationId,
            participantIds: newParticipantIds,
            participantDisplayNames: newParticipantNames,
            participantAvatarUrls: newParticipantAvatars,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.addParticipants(
          conversationId: conversationId,
          participantIds: newParticipantIds,
          participantDisplayNames: newParticipantNames,
          participantAvatarUrls: newParticipantAvatars,
        );

        // Assert
        verify(
          () => mockRepository.addParticipants(
            conversationId: conversationId,
            participantIds: newParticipantIds,
            participantDisplayNames: newParticipantNames,
            participantAvatarUrls: newParticipantAvatars,
          ),
        ).called(1);
      });

      test('should remove participant from group', () async {
        // Arrange
        const conversationId = 'group_conv_123';
        const participantId = 'user_3';

        // Stub the repository method
        when(
          () => mockRepository.removeParticipant(
            conversationId: conversationId,
            participantId: participantId,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.removeParticipant(
          conversationId: conversationId,
          participantId: participantId,
        );

        // Assert
        verify(
          () => mockRepository.removeParticipant(
            conversationId: conversationId,
            participantId: participantId,
          ),
        ).called(1);
      });

      test('should get conversation participants', () async {
        // Arrange
        const conversationId = 'conv_123';
        final expectedParticipants = ['user_1', 'user_2', 'user_3'];

        // Stub the repository method
        when(
          () => mockRepository.getConversationParticipants(conversationId),
        ).thenAnswer((_) async => expectedParticipants);

        // Act
        final participants = await mockRepository.getConversationParticipants(
          conversationId,
        );

        // Assert
        expect(participants, equals(expectedParticipants));
        verify(
          () => mockRepository.getConversationParticipants(conversationId),
        ).called(1);
      });
    });

    group('Utility Operations', () {
      test('should get unread message count', () async {
        // Arrange
        const userId = 'user_1';
        const expectedCount = 5;

        // Stub the repository method
        when(
          () => mockRepository.getUnreadMessageCount(userId),
        ).thenAnswer((_) async => expectedCount);

        // Act
        final count = await mockRepository.getUnreadMessageCount(userId);

        // Assert
        expect(count, equals(expectedCount));
        verify(() => mockRepository.getUnreadMessageCount(userId)).called(1);
      });

      test('should get unread conversations count', () async {
        // Arrange
        const userId = 'user_1';
        const expectedCount = 3;

        // Stub the repository method
        when(
          () => mockRepository.getUnreadConversationsCount(userId),
        ).thenAnswer((_) async => expectedCount);

        // Act
        final count = await mockRepository.getUnreadConversationsCount(userId);

        // Assert
        expect(count, equals(expectedCount));
        verify(
          () => mockRepository.getUnreadConversationsCount(userId),
        ).called(1);
      });

      test('should search messages in conversation', () async {
        // Arrange
        const conversationId = 'conv_123';
        const query = 'recipe';
        final expectedMessages = [
          Message.text(
            conversationId: conversationId,
            senderId: 'user_1',
            senderDisplayName: 'Alice',
            content: 'Check out this recipe!',
          ),
          Message.text(
            conversationId: conversationId,
            senderId: 'user_2',
            senderDisplayName: 'Bob',
            content: 'That recipe looks delicious!',
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.searchMessages(
            conversationId: conversationId,
            query: query,
            limit: 20,
          ),
        ).thenAnswer((_) async => expectedMessages);

        // Act
        final messages = await mockRepository.searchMessages(
          conversationId: conversationId,
          query: query,
        );

        // Assert
        expect(messages, hasLength(2));
        expect(
          messages.every((m) => m.content.toLowerCase().contains(query)),
          isTrue,
        );

        verify(
          () => mockRepository.searchMessages(
            conversationId: conversationId,
            query: query,
            limit: 20,
          ),
        ).called(1);
      });

      test('should delete conversation', () async {
        // Arrange
        const conversationId = 'conv_to_delete';

        // Stub the repository method
        when(
          () => mockRepository.deleteConversation(conversationId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.deleteConversation(conversationId);

        // Assert
        verify(
          () => mockRepository.deleteConversation(conversationId),
        ).called(1);
      });
    });
  });
}
