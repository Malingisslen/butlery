import 'package:flutter_test/flutter_test.dart';
import '../../../test_configuration.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message_type.dart';
import 'package:flutter/material.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockMessagingService extends Mock implements MessagingService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTextEditingController extends Mock implements TextEditingController {}

void main() {
  // Configure tests to ensure ServiceLocator is properly initialized
  configureTests();

  late ChatViewModel sut;
  late MockMessagingService mockMessagingService;
  late MockAuthRepository mockAuthRepository;
  late String conversationId;
  late Conversation testConversation;

  setUpAll(() async {
    // ServiceLocator is already initialized by configureTests()
    registerFallbackValue(MessageFactory.empty());
    registerFallbackValue(MessageType.text);
  });

  setUp(() {
    mockMessagingService = MockMessagingService();
    mockAuthRepository = MockAuthRepository();
    conversationId = 'test_conversation_id';

    testConversation = ConversationFactory.build(
      id: conversationId,
      participantIds: ['current_user', 'other_user'],
    );

    // Setup default auth
    when(() => mockAuthRepository.currentUserId).thenReturn('current_user');

    // Setup default conversation
    when(() => mockMessagingService.getConversation(any()))
        .thenAnswer((_) async => testConversation);

    // Setup default streams
    when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
        .thenAnswer((_) => Stream.value([]));
    when(() => mockMessagingService.getTypingUsers(any())).thenReturn([]);

    sut = ChatViewModel(
      conversationId: conversationId,
      messagingService: mockMessagingService,
      authRepository: mockAuthRepository,
    );
  });

  tearDown(() {
    sut.dispose();
  });

  group('ChatViewModel - Initialization', () {
    test('should initialize with conversation data', () async {
      // When
      // ChatViewModel initializes automatically in constructor

      // Then
      expect(sut.conversation, equals(testConversation));
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
      verify(() => mockMessagingService.getConversation(conversationId))
          .called(1);
    });

    test('should setup message stream on initialization', () async {
      // Given
      final messages = [
        MessageFactory.build(id: 'msg1', senderId: 'current_user'),
        MessageFactory.build(id: 'msg2', senderId: 'other_user'),
      ];
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => Stream.value(messages));

      // When
      // ChatViewModel initializes automatically in constructor
      await Future.delayed(
          const Duration(milliseconds: 100)); // Let stream emit

      // Then
      expect(sut.messages, equals(messages));
      verify(() => mockMessagingService.getConversationMessages(conversationId: conversationId)).called(1);
    });

    // Note: Typing users are managed internally by ChatViewModel

    test('should handle initialization errors', () async {
      // Given
      when(() => mockMessagingService.getConversation(any()))
          .thenThrow(Exception('Failed to load'));

      // When
      // ChatViewModel initializes automatically in constructor

      // Then
      expect(sut.isLoading, isFalse);
      expect(sut.error, contains('kunde inte laddas'));
      expect(sut.conversation, isNull);
    });
  });

  group('ChatViewModel - Message Sending', () {
    test('should send text message', () async {
      // Given
      // ChatViewModel initializes automatically in constructor
      const messageText = 'Hello, test!';

      when(() => mockMessagingService.sendTextMessage(
        conversationId: any(named: 'conversationId'),
        content: any(named: 'content'),
      )).thenAnswer((_) async => true);

      // When
      final result = await sut.sendTextMessage(messageText);

      // Then
      expect(result, isTrue);
      verify(() => mockMessagingService.sendTextMessage(
        conversationId: conversationId,
        content: messageText,
      )).called(1);
    });

    test('should send recipe share', () async {
      // Given
      // ChatViewModel initializes automatically in constructor
      final recipe = RecipeFactory.build(
        id: 'recipe1',
        title: 'Test Recipe',
        description: 'Test description',
        ingredients: ['ingredient'],
        instructions: ['instruction'],
        category: 'Middag',
        portions: 4,
        userId: 'current_user',
      );


      when(() => mockMessagingService.sendRecipeShare(
            conversationId: any(named: 'conversationId'),
            recipeId: any(named: 'recipeId'),
            recipeTitle: any(named: 'recipeTitle'),
            message: any(named: 'message'),
          )).thenAnswer((_) async => true);

      // When
      final result = await sut.sendRecipeShare(
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        message: 'Try this!',
      );

      // Then
      expect(result, isTrue);
      verify(() => mockMessagingService.sendRecipeShare(
            conversationId: conversationId,
            recipeId: recipe.id,
            recipeTitle: recipe.title,
            message: 'Try this!',
          )).called(1);
    });

    // Note: Menu sharing is not implemented in ChatViewModel

    test('should handle send message errors', () async {
      // Given
      // ChatViewModel initializes automatically in constructor
      const messageText = 'Test message';

      when(() => mockMessagingService.sendTextMessage(
        conversationId: any(named: 'conversationId'),
        content: any(named: 'content'),
      )).thenThrow(Exception('Send failed'));

      // When
      final result = await sut.sendTextMessage(messageText);

      // Then
      expect(result, isFalse);
      expect(sut.sendError, contains('Kunde inte skicka meddelandet'));
    });
  });

  group('ChatViewModel - Message Actions', () {
    test('should delete message', () async {
      // Given
      // ChatViewModel initializes automatically in constructor
      const messageId = 'msg_to_delete';

      when(() => mockMessagingService.deleteMessage(any()))
          .thenAnswer((_) async {});

      // When
      final result = await sut.deleteMessage(messageId);

      // Then
      expect(result, isTrue);
      verify(() => mockMessagingService.deleteMessage(messageId)).called(1);
    });

    test('should handle reply functionality', () async {
      // Given
      final originalMessage = MessageFactory.build(
        id: 'original_msg',
        text: 'Original message',
      );

      when(() => mockMessagingService.sendTextMessage(
        conversationId: any(named: 'conversationId'),
        content: any(named: 'content'),
        replyToMessageId: any(named: 'replyToMessageId'),
      )).thenAnswer((_) async => MessageFactory.build());

      // When - Set reply target
      sut.setReplyToMessage(originalMessage);

      // Then - Verify reply state
      expect(sut.hasReplyTarget, isTrue);
      expect(sut.replyToMessage, equals(originalMessage));

      // When - Send reply
      await sut.sendTextMessage('This is a reply');

      // Then - Verify reply was sent and state cleared
      verify(() => mockMessagingService.sendTextMessage(
        conversationId: conversationId,
        content: 'This is a reply',
        replyToMessageId: originalMessage.id,
      )).called(1);
      expect(sut.hasReplyTarget, isFalse);
    });

    test('should clear reply target', () {
      // Given
      final originalMessage = MessageFactory.build();
      sut.setReplyToMessage(originalMessage);
      expect(sut.hasReplyTarget, isTrue);

      // When
      sut.clearReplyToMessage();

      // Then
      expect(sut.hasReplyTarget, isFalse);
      expect(sut.replyToMessage, isNull);
    });

  });

  group('ChatViewModel - Typing Indicators', () {
    test('should update typing status when text changes', () async {
      // Given
      when(() => mockMessagingService.setTypingIndicator(any()))
          .thenAnswer((_) async {});

      // When
      sut.setTyping();

      // Then
      verify(() => mockMessagingService.setTypingIndicator(conversationId))
          .called(1);
    });

    test('should clear typing indicator', () {
      // Given
      when(() => mockMessagingService.clearTypingIndicator(any()))
          .thenAnswer((_) async {});

      // When
      sut.clearTyping();

      // Then
      verify(() => mockMessagingService.clearTypingIndicator(conversationId))
          .called(1);
    });

    test('should handle typing users display', () {
      // Given - Mock typing users from service
      when(() => mockMessagingService.getTypingUsers(any()))
          .thenReturn(['user1', 'user2']);

      // When
      final typingUsers = sut.currentTypingUsers;

      // Then
      expect(typingUsers, contains('user1'));
      expect(typingUsers, contains('user2'));
      expect(typingUsers.length, equals(2));
    });
  });

  group('ChatViewModel - Read Status', () {
    test('should mark messages as read on view', () async {
      // Given
      final messages = [
        MessageFactory.build(
          id: 'msg1',
          senderId: 'other_user',
          status: MessageStatus.delivered,
        ),
      ];
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => Stream.value(messages));
      when(() => mockMessagingService.markConversationAsRead(any()))
          .thenAnswer((_) async {});

      // When
      // ChatViewModel initializes automatically in constructor
      await Future.delayed(const Duration(milliseconds: 200));

      // Then
      verify(() => mockMessagingService.markConversationAsRead(any())).called(1);
    });

    test('should not mark own messages as read', () async {
      // Given
      final messages = [
        MessageFactory.build(
          id: 'msg1',
          senderId: 'current_user',
          status: MessageStatus.delivered,
        ),
      ];
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => Stream.value(messages));

      // When
      // ChatViewModel initializes automatically in constructor
      await Future.delayed(const Duration(milliseconds: 200));

      // Then
      verifyNever(() => mockMessagingService.markConversationAsRead(any()));
    });
  });

  group('ChatViewModel - State Management', () {
    test('should notify listeners on state changes', () async {
      // Given
      var notificationCount = 0;
      sut.addListener(() => notificationCount++);

      // When
      // ChatViewModel initializes automatically in constructor
      await sut.sendTextMessage('Test message');

      // Then
      expect(notificationCount, greaterThan(0));
    });

    test('should properly dispose resources', () {
      // When
      sut.dispose();

      // Then
      // Cannot test internal state - just verify disposal doesn't throw
      expect(() => sut.dispose(), returnsNormally);
    });
  });

  group('ChatViewModel - Group Conversations', () {
    test('should handle group conversation display', () async {
      // Given
      final groupConversation = ConversationFactory.build(
        id: conversationId,
        isGroup: true,
        title: 'Test Group',
        participantIds: ['current_user', 'user1', 'user2', 'user3'],
      );
      when(() => mockMessagingService.getConversation(any()))
          .thenAnswer((_) async => groupConversation);

      // When
      // ChatViewModel initializes automatically in constructor

      // Then
      expect(sut.conversation?.isGroup, equals(true));
      expect(sut.conversation?.title, equals('Test Group'));
      expect(sut.conversationTitle, equals('Test Group'));
    });

    test('should show participant count for groups', () async {
      // Given
      final groupConversation = ConversationFactory.build(
        isGroup: true,
        participantIds: ['current_user', 'user1', 'user2'],
      );
      when(() => mockMessagingService.getConversation(any()))
          .thenAnswer((_) async => groupConversation);

      // When
      // ChatViewModel initializes automatically in constructor

      // Then
      expect(sut.conversation?.participantIds.length, equals(3));
      expect(sut.conversation?.isGroup, isTrue);
    });
  });
}
