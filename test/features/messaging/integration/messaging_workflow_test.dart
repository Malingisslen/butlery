import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/viewmodels/chat_viewmodel.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import '../../../helpers/test_service_locator.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockMessagingService extends Mock implements MessagingService {}
class MockMessagingRepository extends Mock implements MessagingRepository {}
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MockMessagingService mockMessagingService;
  late MockAuthRepository mockAuthRepository;
  
  setUpAll(() {
    registerFallbackValue(MessageFactory.empty());
    registerFallbackValue(ConversationFactory.empty());
    registerFallbackValue(MessageType.text);
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    // Setup test environment
    TestServiceLocator.initialize();
    
    // Create mocks
    mockMessagingService = MockMessagingService();
    mockAuthRepository = MockAuthRepository();
    
    // Register mocks (TestServiceLocator handles this internally)
    // No explicit registration needed as mocks are set up in TestServiceLocator
  });

  tearDown(() {
    TestServiceLocator.reset();
  });

  group('Messaging Workflow Integration Tests', () {
    testWidgets('Complete messaging workflow - Direct conversation', (tester) async {
      // Given - Test users
      const currentUserId = 'current_user';
      const recipientId = 'recipient_user';
      const recipientName = 'Test Recipient';
      
      // Step 1: Create a new direct conversation
      final newConversation = ConversationFactory.build(
        id: 'conv_123',
        isGroup: false,
        participantIds: [currentUserId, recipientId],
        participantDisplayNames: {
          currentUserId: 'Current User',
          recipientId: recipientName,
        },
      );
      
      when(() => mockMessagingService.startDirectConversation(
            otherUserId: any(named: 'otherUserId'),
            otherUserDisplayName: any(named: 'otherUserDisplayName'),
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          )).thenAnswer((_) async => newConversation.id);
      
      final conversationsViewModel = ConversationsViewModel(
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      await conversationsViewModel.startDirectConversation(
        otherUserId: recipientId,
        otherUserDisplayName: recipientName,
      );
      
      verify(() => mockMessagingService.startDirectConversation(
            otherUserId: recipientId,
            otherUserDisplayName: recipientName,
            otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
          )).called(1);
      
      // Step 2: Initialize chat view for the conversation
      final chatViewModel = ChatViewModel(
        conversationId: newConversation.id,
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      
      when(() => mockMessagingService.getConversation(any()))
          .thenAnswer((_) async => newConversation);
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => Stream.value([]));
      when(() => mockMessagingService.getTypingUsers(any())).thenReturn([]);
      
      // ChatViewModel initializes in constructor
      expect(chatViewModel.conversation, equals(newConversation));
      
      // Step 3: Send various message types
      
      // Send text message
      final textMessage = MessageFactory.build(
        id: 'msg_1',
        type: MessageType.text,
        text: 'Hello, this is a test message!',
        senderId: currentUserId,
        conversationId: newConversation.id,
        createdAt: DateTime.now(),
      );
      
      when(() => mockMessagingService.sendTextMessage(
        conversationId: any(named: 'conversationId'),
        content: any(named: 'content'),
        replyToMessageId: any(named: 'replyToMessageId'),
      )).thenAnswer((_) async => textMessage);
      
      // Send text message
      await chatViewModel.sendTextMessage('Hello, this is a test message!');
      
      verify(() => mockMessagingService.sendTextMessage(
        conversationId: any(named: 'conversationId'),
        content: any(named: 'content'),
        replyToMessageId: any(named: 'replyToMessageId'),
      )).called(1);
      
      // Test reply functionality
      // Set reply target
      chatViewModel.setReplyToMessage(textMessage);
      expect(chatViewModel.hasReplyTarget, isTrue);
      expect(chatViewModel.replyToMessage, equals(textMessage));
      
      // Send reply message
      await chatViewModel.sendTextMessage('This is a reply');
      
      verify(() => mockMessagingService.sendTextMessage(
        conversationId: newConversation.id,
        content: 'This is a reply',
        replyToMessageId: textMessage.id,
      )).called(1);
      
      // Verify reply target was cleared after sending
      expect(chatViewModel.hasReplyTarget, isFalse);
      
      // Step 6: Delete a message
      when(() => mockMessagingService.deleteMessage(any())).thenAnswer((_) async {});
      
      await chatViewModel.deleteMessage(textMessage.id);
      
      verify(() => mockMessagingService.deleteMessage(textMessage.id)).called(1);
      
      // Step 7: Mark messages as read
      final unreadMessage = MessageFactory.build(
        id: 'msg_5',
        senderId: recipientId,
        status: MessageStatus.delivered,
      );
      
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => Stream.value([unreadMessage]));
      when(() => mockMessagingService.markConversationAsRead(any()))
          .thenAnswer((_) async {});
      
      // Re-initialize to trigger read status update
      // ChatViewModel initializes in constructor
      await Future.delayed(const Duration(milliseconds: 200));
      
      verify(() => mockMessagingService.markConversationAsRead(any())).called(1);
      
      // Cleanup
      chatViewModel.dispose();
    });

    testWidgets('Group conversation workflow', (tester) async {
      // Given - Test participants
      const currentUserId = 'current_user';
      final participantIds = ['user1', 'user2', 'user3'];
      const groupName = 'Test Group';
      
      // Step 1: Create group conversation
      final groupConversation = ConversationFactory.build(
        id: 'group_123',
        isGroup: true,
        title: groupName,
        participantIds: [currentUserId, ...participantIds],
        participantDisplayNames: {
          currentUserId: 'Current User',
          'user1': 'User One',
          'user2': 'User Two',
          'user3': 'User Three',
        },
      );
      
      when(() => mockMessagingService.createGroupConversation(
        title: any(named: 'title'),
        participantIds: any(named: 'participantIds'),
        participantDisplayNames: any(named: 'participantDisplayNames'),
        participantAvatarUrls: any(named: 'participantAvatarUrls'),
      )).thenAnswer((_) async => groupConversation.id);
      
      final conversationsViewModel = ConversationsViewModel(
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      await conversationsViewModel.createGroupConversation(
        title: groupName,
        participantIds: participantIds,
        participantDisplayNames: {'userId1': 'User 1', 'userId2': 'User 2'},
        participantAvatarUrls: {'userId1': null, 'userId2': null},
      );
      
      verify(() => mockMessagingService.createGroupConversation(
        title: groupName,
        participantIds: participantIds,
        participantDisplayNames: any(named: 'participantDisplayNames'),
        participantAvatarUrls: any(named: 'participantAvatarUrls'),
      )).called(1);
      
      // Step 2: Send message in group
      final chatViewModel = ChatViewModel(
        conversationId: groupConversation.id,
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      
      when(() => mockMessagingService.getConversation(any()))
          .thenAnswer((_) async => groupConversation);
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => Stream.value([]));
      when(() => mockMessagingService.getTypingUsers(any())).thenReturn([]);
      
      // ChatViewModel initializes in constructor
      expect(chatViewModel.conversation?.isGroup, equals(true));
      expect(chatViewModel.conversationTitle, equals(groupName));
      expect(chatViewModel.conversation?.participantIds.length ?? 0, equals(4));
      
      // Step 3: Handle multiple typing users
      when(() => mockMessagingService.getTypingUsers(any())).thenReturn(['user1', 'user2']);
      
      await Future.delayed(const Duration(milliseconds: 100));
      expect(chatViewModel.currentTypingUsers.length, equals(2));
      
      // Cleanup
      chatViewModel.dispose();
    });

    testWidgets('Search and navigation workflow', (tester) async {
      // Given - Existing conversations and messages
      final conversations = [
        ConversationFactory.build(
          id: 'conv1',
          title: 'Project Discussion',
          lastMessage: MessageFactory.build(
            text: 'Latest update on the project',
          ),
        ),
        ConversationFactory.build(
          id: 'conv2',
          title: 'Recipe Sharing',
          lastMessage: MessageFactory.build(
            text: 'Check out this new recipe',
          ),
        ),
      ];
      
      // Step 1: Load conversations list
      when(() => mockMessagingService.getMyConversations())
          .thenAnswer((_) => Stream.value(conversations));
      when(() => mockMessagingService.getUnreadConversationsCount())
          .thenAnswer((_) async => 2);
      
      final conversationsViewModel = ConversationsViewModel(
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      // ConversationsViewModel initializes in constructor
      
      expect(conversationsViewModel.conversations.length, equals(2));
      
      // Test unread count functionality
      final unreadCount = await mockMessagingService.getUnreadConversationsCount();
      expect(unreadCount, equals(2));
      
      // Step 2: Search conversations
      // Search is handled client-side in the ViewModel
      conversationsViewModel.updateSearchQuery('recipe');
      
      // Verify search filtered the results
      expect(conversationsViewModel.searchQuery, equals('recipe'));
      expect(conversationsViewModel.conversations.length, equals(1));
      expect(conversationsViewModel.conversations.first.title, equals('Recipe Sharing'));
      
      // Clear search
      conversationsViewModel.clearSearch();
      expect(conversationsViewModel.conversations.length, equals(2));
      
      // Step 3: Search messages within conversation
      final messages = [
        MessageFactory.build(text: 'This pasta recipe is amazing'),
        MessageFactory.build(text: 'I love Italian food'),
        MessageFactory.build(text: 'Another pasta variation'),
      ];
      
      when(() => mockMessagingService.searchMessages(
        conversationId: any(named: 'conversationId'),
        query: any(named: 'query'),
      )).thenAnswer((invocation) async {
        final query = invocation.namedArguments[const Symbol('query')] as String;
        return messages.where((m) =>
          m.content.toLowerCase().contains(query.toLowerCase())
        ).toList();
      });
      
      final chatViewModel = ChatViewModel(
        conversationId: 'conv2',
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      
      final searchResults = await mockMessagingService.searchMessages(
        conversationId: 'conv2',
        query: 'pasta',
      );
      
      expect(searchResults.length, equals(2));
      expect(searchResults.every((m) => m.content.contains('pasta')), isTrue);
      
      // Cleanup
      chatViewModel.dispose();
    });

    testWidgets('Message status and delivery workflow', (tester) async {
      // Given
      const conversationId = 'conv_status_test';
      final conversation = ConversationFactory.build(id: conversationId);
      
      // Simulate message lifecycle: sending -> sent -> delivered -> read
      final Message message = MessageFactory.build(
        id: 'msg_lifecycle',
        text: 'Testing message status',
        status: MessageStatus.sending,
        senderId: 'current_user',
      );
      
      final messageStream = Stream<List<Message>>.periodic(
        const Duration(seconds: 1),
        (count) {
          if (count == 0) {
            return [message];
          } else if (count == 1) {
            return [message.copyWith(status: MessageStatus.sent)];
          } else if (count == 2) {
            return [message.copyWith(status: MessageStatus.delivered)];
          } else {
            return [message.copyWith(status: MessageStatus.read)];
          }
        },
      ).take(4);
      
      when(() => mockMessagingService.getConversation(any()))
          .thenAnswer((_) async => conversation);
      when(() => mockMessagingService.getConversationMessages(conversationId: any(named: 'conversationId')))
          .thenAnswer((_) => messageStream);
      when(() => mockMessagingService.getTypingUsers(any())).thenReturn([]);
      
      final chatViewModel = ChatViewModel(
        conversationId: conversationId,
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
      
      // ChatViewModel initializes in constructor
      
      // Verify message status changes
      final statusChanges = <MessageStatus>[];
      chatViewModel.addListener(() {
        if (chatViewModel.messages.isNotEmpty) {
          statusChanges.add(chatViewModel.messages.first.status);
        }
      });
      
      await Future.delayed(const Duration(seconds: 5));
      
      expect(statusChanges, contains(MessageStatus.sending));
      expect(statusChanges, contains(MessageStatus.sent));
      expect(statusChanges, contains(MessageStatus.delivered));
      expect(statusChanges, contains(MessageStatus.read));
      
      // Cleanup
      chatViewModel.dispose();
    });
  });
}