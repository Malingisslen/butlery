import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/bootstrap/handlers/error_handler.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockMessagingRepository extends Mock implements MessagingRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockBootstrapErrorHandler extends Mock implements BootstrapErrorHandler {}

void main() {
  late MessagingService sut;
  late MockMessagingRepository mockRepository;
  late MockAuthRepository mockAuthRepository;

  setUpAll(() async {
    // TestServiceLocator initialization moved to setUp
    registerFallbackValue(MessageFactory.empty());
    registerFallbackValue(ConversationFactory.empty());
    registerFallbackValue(MessageType.text);
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockRepository = MockMessagingRepository();
    mockAuthRepository = MockAuthRepository();

    // Setup default auth
    when(() => mockAuthRepository.currentUserId).thenReturn('test_user_id');
    when(() => mockAuthRepository.currentUser)
        .thenReturn(null); // Mock Firebase User

    sut = MessagingService(
      messagingRepository: mockRepository,
      authRepository: mockAuthRepository,
    );
  });

  group('MessagingService - Conversation Management', () {
    test('should get conversations stream', () async {
      // Given
      final conversations = [
        ConversationFactory.build(id: 'conv1'),
        ConversationFactory.build(id: 'conv2'),
      ];
      when(() => mockRepository.getUserConversations('test_user_id'))
          .thenAnswer((_) => Stream.value(conversations));

      // When
      final result = sut.getMyConversations();

      // Then
      await expectLater(result, emits(conversations));
      verify(() => mockRepository.getUserConversations('test_user_id')).called(1);
    });

    test('should get single conversation', () async {
      // Given
      final conversation = ConversationFactory.build(id: 'conv1');
      when(() => mockRepository.getConversation(any()))
          .thenAnswer((_) async => conversation);

      // When
      final result = await sut.getConversation('conv1');

      // Then
      expect(result, equals(conversation));
      verify(() => mockRepository.getConversation('conv1')).called(1);
    });

    test('should create direct conversation', () async {
      // Given
      const recipientId = 'recipient_user';
      const conversationId = 'conv_123';
      when(() => mockRepository.createDirectConversation(
        user1Id: any(named: 'user1Id'),
        user1DisplayName: any(named: 'user1DisplayName'),
        user2Id: any(named: 'user2Id'),
        user2DisplayName: any(named: 'user2DisplayName'),
        user1AvatarUrl: any(named: 'user1AvatarUrl'),
        user2AvatarUrl: any(named: 'user2AvatarUrl'),
      ))
          .thenAnswer((_) async => conversationId);
      
      when(() => mockRepository.findDirectConversation(
        user1Id: any(named: 'user1Id'),
        user2Id: any(named: 'user2Id'),
      )).thenAnswer((_) async => null);

      // When
      final result = await sut.startDirectConversation(
        otherUserId: recipientId,
        otherUserDisplayName: 'Recipient User',
      );

      // Then
      expect(result, equals(conversationId));

      verify(() => mockRepository.createDirectConversation(
        user1Id: 'test_user_id',
        user1DisplayName: any(named: 'user1DisplayName'),
        user2Id: recipientId,
        user2DisplayName: 'Recipient User',
        user1AvatarUrl: any(named: 'user1AvatarUrl'),
        user2AvatarUrl: any(named: 'user2AvatarUrl'),
      )).called(1);
    });

    test('should create group conversation', () async {
      // Given
      const name = 'Test Group';
      final participantIds = ['user1', 'user2', 'user3'];
      const conversationId = 'group_123';
      when(() => mockRepository.createGroupConversation(
        participantIds: any(named: 'participantIds'),
        participantDisplayNames: any(named: 'participantDisplayNames'),
        participantAvatarUrls: any(named: 'participantAvatarUrls'),
        title: any(named: 'title'),
        creatorId: any(named: 'creatorId'),
      ))
          .thenAnswer((_) async => conversationId);

      // When
      final result = await sut.createGroupConversation(
        title: name,
        participantIds: participantIds,
        participantDisplayNames: {'user1': 'User 1', 'user2': 'User 2', 'user3': 'User 3'},
        participantAvatarUrls: {'user1': null, 'user2': null, 'user3': null},
      );

      // Then
      expect(result, equals(conversationId));
    });

    test('should delete conversation', () async {
      // Given
      const conversationId = 'conv_to_delete';
      when(() => mockRepository.deleteConversation(any()))
          .thenAnswer((_) async {});

      // When
      await sut.deleteConversation(conversationId);

      // Then
      verify(() => mockRepository.deleteConversation(conversationId)).called(1);
    });

    test('should handle conversation creation errors', () async {
      // Given
      when(() => mockRepository.findDirectConversation(
        user1Id: any(named: 'user1Id'),
        user2Id: any(named: 'user2Id'),
      )).thenAnswer((_) async => null);
      
      when(() => mockRepository.createDirectConversation(
        user1Id: any(named: 'user1Id'),
        user1DisplayName: any(named: 'user1DisplayName'),
        user2Id: any(named: 'user2Id'),
        user2DisplayName: any(named: 'user2DisplayName'),
        user1AvatarUrl: any(named: 'user1AvatarUrl'),
        user2AvatarUrl: any(named: 'user2AvatarUrl'),
      ))
          .thenThrow(Exception('Network error'));
      // When & Then
      await expectLater(
        () => sut.startDirectConversation(
          otherUserId: 'recipient',
          otherUserDisplayName: 'Recipient User',
        ),
        throwsException,
      );
    });
  });

  group('MessagingService - Message Operations', () {
    test('should send text message', () async {
      // Given
      const conversationId = 'conv1';
      const text = 'Hello, test message!';

      when(() => mockRepository.sendMessage(any()))
          .thenAnswer((_) async {});

      // When
      await sut.sendTextMessage(
        conversationId: conversationId,
        content: text,
      );

      // Then
      final capturedMessage = verify(() => mockRepository.sendMessage(
            captureAny(),
          )).captured.first as Message;
      
      expect(capturedMessage.type, equals(MessageType.text));
      expect(capturedMessage.content, equals(text));
      expect(capturedMessage.conversationId, equals(conversationId));
    });

    test('should send recipe share message', () async {
      // Given
      const conversationId = 'conv1';
      const recipeId = 'recipe123';
      const recipeTitle = 'Test Recipe';
      const message = 'Check out this recipe!';

      when(() => mockRepository.sendMessage(any()))
          .thenAnswer((_) async {});

      // When
      await sut.sendRecipeShare(
        conversationId: conversationId,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        message: message,
      );

      // Then
      final capturedMessage = verify(() => mockRepository.sendMessage(
            captureAny(),
          )).captured.first as Message;

      expect(capturedMessage.type, equals(MessageType.recipeShare));
      expect(capturedMessage.metadata?['recipeId'], equals(recipeId));
      expect(capturedMessage.metadata?['recipeTitle'], equals(recipeTitle));
      expect(capturedMessage.content, equals(message));
    });

    test('should send menu share message', () async {
      // Given
      const conversationId = 'conv1';
      const menuId = 'menu1';
      const menuTitle = 'Weekly Menu';
      const message = 'Here is my weekly menu';

      when(() => mockRepository.sendMessage(any()))
          .thenAnswer((_) async {});

      // When
      await sut.sendMenuShare(
        conversationId: conversationId,
        menuId: menuId,
        menuTitle: menuTitle,
        message: message,
      );

      // Then
      final capturedMessage = verify(() => mockRepository.sendMessage(
            captureAny(),
          )).captured.first as Message;

      expect(capturedMessage.type, equals(MessageType.menuShare));
      expect(capturedMessage.metadata?['menuId'], equals(menuId));
      expect(capturedMessage.metadata?['menuTitle'], equals(menuTitle));
      expect(capturedMessage.content, equals(message));
    });

    test('should mark conversation as read', () async {
      // Given
      const conversationId = 'conv1';
      when(() => mockRepository.markConversationAsRead(
        conversationId: any(named: 'conversationId'),
        userId: any(named: 'userId'),
      )).thenAnswer((_) async {});

      // When
      await sut.markConversationAsRead(conversationId);

      // Then
      verify(() => mockRepository.markConversationAsRead(
        conversationId: conversationId,
        userId: 'test_user_id',
      )).called(1);
    });

    test('should delete message', () async {
      // Given
      const messageId = 'msg123';
      const conversationId = 'conv1';
      final message = MessageFactory.build(
        id: messageId,
        senderId: 'test_user_id',
        conversationId: conversationId,
      );
      
      when(() => mockRepository.getMessage(any()))
          .thenAnswer((_) async => message);
      when(() => mockRepository.deleteMessage(any()))
          .thenAnswer((_) async {});

      // When
      await sut.deleteMessage(messageId);

      // Then
      verify(() => mockRepository.deleteMessage(messageId)).called(1);
    });

    test('should handle message editing', () async {
      // Given
      const messageId = 'msg123';
      const newContent = 'Updated message content';
      final originalMessage = MessageFactory.build(
        id: messageId,
        senderId: 'test_user_id',
        text: 'Original content',
      );

      when(() => mockRepository.getMessage(any()))
          .thenAnswer((_) async => originalMessage);
      when(() => mockRepository.updateMessageContent(
        messageId: any(named: 'messageId'),
        newContent: any(named: 'newContent'),
      )).thenAnswer((_) async {});

      // When
      await sut.editMessage(
        messageId: messageId,
        newContent: newContent,
      );

      // Then
      verify(() => mockRepository.updateMessageContent(
        messageId: messageId,
        newContent: newContent,
      )).called(1);
    });

    test('should send text message with reply', () async {
      // Given
      const conversationId = 'conv1';
      const text = 'This is a reply';
      const replyToMessageId = 'msg_original';

      when(() => mockRepository.sendMessage(any()))
          .thenAnswer((_) async {});

      // When
      await sut.sendTextMessage(
        conversationId: conversationId,
        content: text,
        replyToMessageId: replyToMessageId,
      );

      // Then
      final capturedMessage = verify(() => mockRepository.sendMessage(
            captureAny(),
          )).captured.first as Message;

      expect(capturedMessage.type, equals(MessageType.text));
      expect(capturedMessage.content, equals(text));
      expect(capturedMessage.replyToMessageId, equals(replyToMessageId));
    });
  });

  group('MessagingService - Typing Status', () {
    test('should get typing users', () {
      // Given
      const conversationId = 'conv1';
      
      // When
      final typingUsers = sut.getTypingUsers(conversationId);

      // Then
      expect(typingUsers, isA<List<String>>());
      expect(typingUsers, isEmpty); // No typing users initially
    });
  });

  group('MessagingService - Search', () {
    test('should search messages', () async {
      // Given
      const conversationId = 'conv1';
      const query = 'test search';
      final searchResults = [
        MessageFactory.build(text: 'test search result 1'),
        MessageFactory.build(text: 'test search result 2'),
      ];
      when(() => mockRepository.searchMessages(
        conversationId: any(named: 'conversationId'),
        query: any(named: 'query'),
        limit: any(named: 'limit'),
      )).thenAnswer((_) async => searchResults);

      // When
      final results = await sut.searchMessages(
        conversationId: conversationId,
        query: query,
      );

      // Then
      expect(results, equals(searchResults));
      verify(() => mockRepository.searchMessages(
        conversationId: conversationId,
        query: query,
        limit: 20, // default limit
      )).called(1);
    });
  });

  group('MessagingService - Error Handling', () {
    test('should handle send message errors', () async {
      // Given
      when(() => mockRepository.sendMessage(any()))
          .thenThrow(Exception('Failed to send'));

      // When & Then
      await expectLater(
        () => sut.sendTextMessage(
          conversationId: 'conv1',
          content: 'Test message',
        ),
        throwsException,
      );
    });

    test('should validate empty message content', () async {
      // When & Then
      await expectLater(
        () => sut.sendTextMessage(
          conversationId: 'conv1',
          content: '   ',
        ),
        throwsException,
      );
    });

    test('should handle permission errors when editing message', () async {
      // Given
      const messageId = 'msg123';
      final message = MessageFactory.build(
        id: messageId,
        senderId: 'other_user_id', // Different from current user
      );

      when(() => mockRepository.getMessage(any()))
          .thenAnswer((_) async => message);

      // When & Then
      await expectLater(
        () => sut.editMessage(
          messageId: messageId,
          newContent: 'New content',
        ),
        throwsException,
      );
    });
  });
}