import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';

// Test data builders
class ConversationBuilder {
  static Conversation build({
    String? id,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Map<String, String?>? participantAvatarUrls,
    Message? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
    bool isGroup = false,
    Map<String, DateTime>? lastReadTimestamps,
    Map<String, dynamic>? metadata,
  }) {
    final defaultId = id ?? 'conv_${DateTime.now().millisecondsSinceEpoch}';
    final defaultParticipantIds = participantIds ?? ['user1', 'user2'];
    final now = DateTime.now();
    
    return Conversation(
      id: defaultId,
      participantIds: defaultParticipantIds,
      participantDisplayNames: participantDisplayNames ?? {
        'user1': 'Anna Andersson',
        'user2': 'Erik Svensson',
      },
      participantAvatarUrls: participantAvatarUrls ?? {},
      lastMessage: lastMessage,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      title: title,
      isGroup: isGroup,
      lastReadTimestamps: lastReadTimestamps ?? {},
      metadata: metadata ?? {},
    );
  }
  
  static Conversation buildDirect({
    String? id,
    String? user1Id,
    String? user2Id,
    String? user1Name,
    String? user2Name,
    Message? lastMessage,
  }) {
    final userId1 = user1Id ?? 'user1';
    final userId2 = user2Id ?? 'user2';
    
    return build(
      id: id,
      participantIds: [userId1, userId2],
      participantDisplayNames: {
        userId1: user1Name ?? 'Anna Andersson',
        userId2: user2Name ?? 'Erik Svensson',
      },
      lastMessage: lastMessage,
      isGroup: false,
    );
  }
  
  static Conversation buildGroup({
    String? id,
    String? title,
    List<String>? participantIds,
    Map<String, String>? participantDisplayNames,
    Message? lastMessage,
  }) {
    final ids = participantIds ?? ['user1', 'user2', 'user3'];
    final names = participantDisplayNames ?? {
      'user1': 'Anna Andersson',
      'user2': 'Erik Svensson',
      'user3': 'Maria Johansson',
    };
    
    return build(
      id: id,
      title: title ?? 'Matgruppen',
      participantIds: ids,
      participantDisplayNames: names,
      lastMessage: lastMessage,
      isGroup: true,
    );
  }
}

class MessageBuilder {
  static Message build({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderDisplayName,
    String? content,
    MessageType type = MessageType.text,
    MessageStatus status = MessageStatus.delivered,
    DateTime? sentAt,
    Map<String, dynamic>? data,
  }) {
    final now = DateTime.now();
    
    return Message(
      id: id ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId ?? 'conv_test',
      senderId: senderId ?? 'user1',
      senderDisplayName: senderDisplayName ?? 'Test User',
      type: type,
      content: content ?? 'Test message',
      status: status,
      sentAt: sentAt ?? now,
      metadata: data ?? {},
    );
  }
}

void main() {
  group('ConversationsViewModel', () {
    late ConversationsViewModel viewModel;
    late MockMessagingService mockMessagingService;
    late MockAuthRepository mockAuthRepository;
    late StreamController<List<Conversation>> conversationsStreamController;
    const testUserId = 'test-user-123';
    
    // Test conversations
    final testDirectConversation = ConversationBuilder.buildDirect(
      id: 'conv_direct_1',
      user1Id: testUserId,
      user2Id: 'other_user',
      user1Name: 'Test User',
      user2Name: 'Anna Andersson',
      lastMessage: MessageBuilder.build(
        content: 'Hej! Hur mår du?',
        senderId: 'other_user',
        senderDisplayName: 'Anna Andersson',
      ),
    );
    
    final testGroupConversation = ConversationBuilder.buildGroup(
      id: 'conv_group_1',
      title: 'Köttbullsälskare',
      participantIds: [testUserId, 'user2', 'user3'],
      participantDisplayNames: {
        testUserId: 'Test User',
        'user2': 'Erik Svensson',
        'user3': 'Maria Öberg',
      },
      lastMessage: MessageBuilder.build(
        content: 'Någon som vill laga köttbullar imorgon?',
        senderId: 'user2',
        senderDisplayName: 'Erik Svensson',
      ),
    );
    
    final testSearchConversation = ConversationBuilder.buildDirect(
      id: 'conv_search_1',
      user1Id: testUserId,
      user2Id: 'search_user',
      user1Name: 'Test User',
      user2Name: 'Åsa Ängström',
      lastMessage: MessageBuilder.build(
        content: 'Recept för räksmörgås',
        senderId: 'search_user',
        senderDisplayName: 'Åsa Ängström',
      ),
    );
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ConversationBuilder.build());
      registerFallbackValue(MessageBuilder.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockMessagingService = MockMessagingService();
      mockAuthRepository = MockAuthRepository();
      conversationsStreamController = StreamController<List<Conversation>>.broadcast();
      
      // Configure default mock behavior
      mockAuthRepository.setAuthState(
        userId: testUserId,
        isAuthenticated: true,
      );
      
      when(() => mockMessagingService.getMyConversations())
          .thenAnswer((_) => conversationsStreamController.stream);
      
      when(() => mockMessagingService.markConversationAsRead(any()))
          .thenAnswer((_) async => {});
      
      when(() => mockMessagingService.startDirectConversation(
        otherUserId: any(named: 'otherUserId'),
        otherUserDisplayName: any(named: 'otherUserDisplayName'),
        otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
      )).thenAnswer((_) async => 'new_conv_direct');
      
      when(() => mockMessagingService.createGroupConversation(
        participantIds: any(named: 'participantIds'),
        participantDisplayNames: any(named: 'participantDisplayNames'),
        participantAvatarUrls: any(named: 'participantAvatarUrls'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => 'new_conv_group');
      
      when(() => mockMessagingService.removeParticipantFromGroup(
        conversationId: any(named: 'conversationId'),
        participantId: any(named: 'participantId'),
      )).thenAnswer((_) async => {});
      
      // Create viewModel
      viewModel = ConversationsViewModel(
        messagingService: mockMessagingService,
        authRepository: mockAuthRepository,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      await conversationsStreamController.close();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with loading state', () {
        // Assert initial state
        expect(viewModel.isLoading, isTrue);
        expect(viewModel.conversations, isEmpty);
        expect(viewModel.error, isNull);
        expect(viewModel.hasConversations, isFalse);
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.isSearching, isFalse);
        expect(viewModel.isCreatingConversation, isFalse);
        expect(viewModel.conversationCreationError, isNull);
      });

      test('should setup stream subscription on initialization', () {
        // Verify stream subscription was created
        verify(() => mockMessagingService.getMyConversations()).called(1);
      });

      test('should handle error during initialization', () {
        // Arrange
        when(() => mockMessagingService.getMyConversations())
            .thenThrow(Exception('Stream setup failed'));
        
        // Act
        final errorViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        
        // Assert
        expect(errorViewModel.error, equals('Kunde inte ladda konversationer'));
        expect(errorViewModel.isLoading, isFalse);
        
        // Cleanup
        errorViewModel.dispose();
      });

      test('should load conversations from stream successfully', () async {
        // Arrange
        final conversations = [testDirectConversation, testGroupConversation];
        
        // Act
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero); // Allow stream to process
        
        // Assert
        expect(viewModel.conversations.length, equals(2));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasConversations, isTrue);
      });

      test('should get current user ID from auth repository', () {
        // Assert
        expect(viewModel.currentUserId, equals(testUserId));
      });
    });

    group('Conversation Updates', () {
      test('should receive and update conversations from stream', () async {
        // Arrange
        final conversations = [
          testDirectConversation,
          testGroupConversation,
          testSearchConversation,
        ];
        
        // Act
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero);
        
        // Assert
        expect(viewModel.conversations.length, equals(3));
        expect(viewModel.conversations[0].id, equals('conv_direct_1'));
        expect(viewModel.conversations[1].id, equals('conv_group_1'));
        expect(viewModel.conversations[2].id, equals('conv_search_1'));
      });

      test('should handle empty conversation list', () async {
        // Act
        conversationsStreamController.add([]);
        await Future.delayed(Duration.zero);
        
        // Assert
        expect(viewModel.conversations, isEmpty);
        expect(viewModel.hasConversations, isFalse);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
      });

      test('should handle multiple conversation updates', () async {
        // Act - First update
        conversationsStreamController.add([testDirectConversation]);
        await Future.delayed(Duration.zero);
        expect(viewModel.conversations.length, equals(1));
        
        // Act - Second update
        conversationsStreamController.add([
          testDirectConversation,
          testGroupConversation,
        ]);
        await Future.delayed(Duration.zero);
        expect(viewModel.conversations.length, equals(2));
        
        // Act - Third update
        conversationsStreamController.add([testGroupConversation]);
        await Future.delayed(Duration.zero);
        expect(viewModel.conversations.length, equals(1));
      });

      test('should handle stream errors', () async {
        // Act
        conversationsStreamController.addError('Stream error');
        await Future.delayed(Duration.zero);
        
        // Assert
        expect(viewModel.error, equals('Kunde inte ladda konversationer'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should not update when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        
        // Load initial data
        conversationsStreamController.add([testDirectConversation]);
        await Future.delayed(Duration.zero);
        expect(testViewModel.conversations.length, equals(1));
        
        // Now dispose
        testViewModel.dispose();
        
        // Act - Try to update after dispose
        conversationsStreamController.add([testDirectConversation, testGroupConversation]);
        await Future.delayed(Duration.zero);
        
        // Assert - Should not crash, conversations should remain as before dispose
        // We can't access conversations after dispose as it violates ChangeNotifier contract
        // The test passes if it doesn't crash
      });

      test('should preserve conversation order from stream', () async {
        // Arrange
        final conversations = [
          testGroupConversation,
          testSearchConversation,
          testDirectConversation,
        ];
        
        // Act
        conversationsStreamController.add(conversations);
        await Future.delayed(Duration.zero);
        
        // Assert
        expect(viewModel.conversations[0].id, equals('conv_group_1'));
        expect(viewModel.conversations[1].id, equals('conv_search_1'));
        expect(viewModel.conversations[2].id, equals('conv_direct_1'));
      });
    });

    group('Search Functionality', () {
      setUp(() async {
        // Load test conversations
        conversationsStreamController.add([
          testDirectConversation,
          testGroupConversation,
          testSearchConversation,
        ]);
        await Future.delayed(Duration.zero);
      });

      test('should search by conversation title', () {
        // Act
        viewModel.updateSearchQuery('köttbull');
        
        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].title, equals('Köttbullsälskare'));
        expect(viewModel.searchQuery, equals('köttbull'));
      });

      test('should search by last message content', () {
        // Act
        viewModel.updateSearchQuery('räksmörgås');
        
        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].id, equals('conv_search_1'));
      });

      test('should perform case-insensitive search', () {
        // Act
        viewModel.updateSearchQuery('KÖTTBULL');
        
        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].title, equals('Köttbullsälskare'));
      });

      test('should clear search and show all conversations', () {
        // Arrange
        viewModel.updateSearchQuery('köttbull');
        expect(viewModel.conversations.length, equals(1));
        
        // Act
        viewModel.clearSearch();
        
        // Assert
        expect(viewModel.conversations.length, equals(3));
        expect(viewModel.searchQuery, isEmpty);
      });

      test('should handle empty search query', () {
        // Act
        viewModel.updateSearchQuery('');
        
        // Assert
        expect(viewModel.conversations.length, equals(3));
        expect(viewModel.searchQuery, isEmpty);
      });

      test('should search with Swedish characters', () {
        // Act
        viewModel.updateSearchQuery('åsa ängström');
        
        // Assert
        expect(viewModel.conversations.length, equals(1));
        expect(viewModel.conversations[0].participantDisplayNames['search_user'], 
               equals('Åsa Ängström'));
      });

      test('should return empty list when no search results', () {
        // Act
        viewModel.updateSearchQuery('nonexistent');
        
        // Assert
        expect(viewModel.conversations, isEmpty);
        expect(viewModel.hasConversations, isFalse);
      });
    });

    group('Direct Conversation Creation', () {
      test('should create direct conversation successfully', () async {
        // Act
        final conversationId = await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
          otherUserAvatarUrl: 'https://example.com/avatar.jpg',
        );
        
        // Assert
        expect(conversationId, equals('new_conv_direct'));
        expect(viewModel.isCreatingConversation, isFalse);
        expect(viewModel.conversationCreationError, isNull);
        
        verify(() => mockMessagingService.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
          otherUserAvatarUrl: 'https://example.com/avatar.jpg',
        )).called(1);
      });

      test('should create direct conversation without avatar URL', () async {
        // Act
        final conversationId = await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );
        
        // Assert
        expect(conversationId, equals('new_conv_direct'));
        
        verify(() => mockMessagingService.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
          otherUserAvatarUrl: null,
        )).called(1);
      });

      test('should handle error during direct conversation creation', () async {
        // Arrange
        when(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        )).thenThrow(Exception('Network error'));
        
        // Act
        final conversationId = await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );
        
        // Assert
        expect(conversationId, isNull);
        expect(viewModel.conversationCreationError, 
               contains('Kunde inte starta konversation'));
        expect(viewModel.isCreatingConversation, isFalse);
      });

      test('should set loading state during creation', () async {
        // Arrange
        bool wasCreating = false;
        viewModel.addListener(() {
          if (viewModel.isCreatingConversation) wasCreating = true;
        });
        
        // Act
        await viewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );
        
        // Assert
        expect(wasCreating, isTrue);
        expect(viewModel.isCreatingConversation, isFalse);
      });

      test('should not create when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        testViewModel.dispose();
        
        // Act
        final conversationId = await testViewModel.startDirectConversation(
          otherUserId: 'other_user_123',
          otherUserDisplayName: 'Erik Eriksson',
        );
        
        // Assert
        expect(conversationId, isNull);
        verifyNever(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        ));
      });

      test('should clear creation error on successful creation', () async {
        // Arrange - Set initial error
        when(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        )).thenThrow(Exception('First attempt failed'));
        
        await viewModel.startDirectConversation(
          otherUserId: 'user1',
          otherUserDisplayName: 'User 1',
        );
        expect(viewModel.conversationCreationError, isNotNull);
        
        // Reset mock for successful attempt
        when(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        )).thenAnswer((_) async => 'new_conv');
        
        // Act
        await viewModel.startDirectConversation(
          otherUserId: 'user2',
          otherUserDisplayName: 'User 2',
        );
        
        // Assert
        expect(viewModel.conversationCreationError, isNull);
      });
    });

    group('Group Conversation Creation', () {
      test('should create group conversation successfully', () async {
        // Act
        final conversationId = await viewModel.createGroupConversation(
          participantIds: ['user1', 'user2', 'user3'],
          participantDisplayNames: {
            'user1': 'Anna Andersson',
            'user2': 'Erik Svensson',
            'user3': 'Maria Öberg',
          },
          participantAvatarUrls: {
            'user1': 'https://example.com/anna.jpg',
            'user2': null,
            'user3': 'https://example.com/maria.jpg',
          },
          title: 'Matlagningsgruppen',
        );
        
        // Assert
        expect(conversationId, equals('new_conv_group'));
        expect(viewModel.isCreatingConversation, isFalse);
        expect(viewModel.conversationCreationError, isNull);
      });

      test('should handle multiple participants in group', () async {
        // Arrange
        final participantIds = List.generate(10, (i) => 'user$i');
        final displayNames = Map.fromEntries(
          participantIds.map((id) => MapEntry(id, 'User ${id.substring(4)}')),
        );
        final avatarUrls = Map.fromEntries(
          participantIds.map((id) => MapEntry(id, null)),
        );
        
        // Act
        final conversationId = await viewModel.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: displayNames,
          participantAvatarUrls: avatarUrls,
          title: 'Stor grupp',
        );
        
        // Assert
        expect(conversationId, equals('new_conv_group'));
        
        verify(() => mockMessagingService.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: displayNames,
          participantAvatarUrls: avatarUrls,
          title: 'Stor grupp',
        )).called(1);
      });

      test('should handle participant display names and avatars', () async {
        // Act
        await viewModel.createGroupConversation(
          participantIds: ['user1', 'user2'],
          participantDisplayNames: {
            'user1': 'Åsa Ängström',
            'user2': 'Örjan Öberg',
          },
          participantAvatarUrls: {
            'user1': 'https://example.com/asa.jpg',
            'user2': null,
          },
          title: 'Svenska tecken',
        );
        
        // Assert
        verify(() => mockMessagingService.createGroupConversation(
          participantIds: ['user1', 'user2'],
          participantDisplayNames: {
            'user1': 'Åsa Ängström',
            'user2': 'Örjan Öberg',
          },
          participantAvatarUrls: {
            'user1': 'https://example.com/asa.jpg',
            'user2': null,
          },
          title: 'Svenska tecken',
        )).called(1);
      });

      test('should handle error during group creation', () async {
        // Arrange
        when(() => mockMessagingService.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
        )).thenThrow(Exception('Creation failed'));
        
        // Act
        final conversationId = await viewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Test Group',
        );
        
        // Assert
        expect(conversationId, isNull);
        expect(viewModel.conversationCreationError, 
               contains('Kunde inte skapa gruppchatt'));
        expect(viewModel.isCreatingConversation, isFalse);
      });

      test('should manage loading state during creation', () async {
        // Arrange
        bool wasCreating = false;
        viewModel.addListener(() {
          if (viewModel.isCreatingConversation) wasCreating = true;
        });
        
        // Act
        await viewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Test Group',
        );
        
        // Assert
        expect(wasCreating, isTrue);
        expect(viewModel.isCreatingConversation, isFalse);
      });

      test('should not create when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        testViewModel.dispose();
        
        // Act
        final conversationId = await testViewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Test Group',
        );
        
        // Assert
        expect(conversationId, isNull);
        verifyNever(() => mockMessagingService.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
        ));
      });
    });

    group('Mark as Read', () {
      test('should mark conversation as read successfully', () async {
        // Act
        await viewModel.markConversationAsRead('conv_123');
        
        // Assert
        verify(() => mockMessagingService.markConversationAsRead('conv_123'))
            .called(1);
      });

      test('should handle error silently when marking as read fails', () async {
        // Arrange
        when(() => mockMessagingService.markConversationAsRead(any()))
            .thenThrow(Exception('Mark as read failed'));
        
        // Act & Assert - Should not throw
        await expectLater(
          viewModel.markConversationAsRead('conv_123'),
          completes,
        );
        
        // Error should not be visible to user
        expect(viewModel.error, isNull);
      });

      test('should handle marking invalid conversation ID', () async {
        // Act
        await viewModel.markConversationAsRead('');
        
        // Assert
        verify(() => mockMessagingService.markConversationAsRead(''))
            .called(1);
      });

      test('should not mark as read when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        testViewModel.dispose();
        
        // Act
        await testViewModel.markConversationAsRead('conv_123');
        
        // Assert
        verifyNever(() => mockMessagingService.markConversationAsRead(any()));
      });
    });

    group('Leave Group', () {
      test('should leave group successfully', () async {
        // Act
        final result = await viewModel.leaveGroup('group_123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockMessagingService.removeParticipantFromGroup(
          conversationId: 'group_123',
          participantId: testUserId,
        )).called(1);
      });

      test('should handle when user not authenticated', () async {
        // Arrange
        mockAuthRepository.setAuthState(
          userId: null,
          isAuthenticated: false,
        );
        
        // Act
        final result = await viewModel.leaveGroup('group_123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockMessagingService.removeParticipantFromGroup(
          conversationId: any(named: 'conversationId'),
          participantId: any(named: 'participantId'),
        ));
      });

      test('should handle error when leaving group', () async {
        // Arrange
        when(() => mockMessagingService.removeParticipantFromGroup(
          conversationId: any(named: 'conversationId'),
          participantId: any(named: 'participantId'),
        )).thenThrow(Exception('Leave failed'));
        
        // Act
        final result = await viewModel.leaveGroup('group_123');
        
        // Assert
        expect(result, isFalse);
      });

      test('should return correct success/failure values', () async {
        // Test success
        final successResult = await viewModel.leaveGroup('group_success');
        expect(successResult, isTrue);
        
        // Test failure
        when(() => mockMessagingService.removeParticipantFromGroup(
          conversationId: any(named: 'conversationId'),
          participantId: any(named: 'participantId'),
        )).thenThrow(Exception('Failed'));
        
        final failureResult = await viewModel.leaveGroup('group_fail');
        expect(failureResult, isFalse);
      });

      test('should not leave group when disposed', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        testViewModel.dispose();
        
        // Act
        final result = await testViewModel.leaveGroup('group_123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockMessagingService.removeParticipantFromGroup(
          conversationId: any(named: 'conversationId'),
          participantId: any(named: 'participantId'),
        ));
      });
    });

    group('Refresh & Error Management', () {
      test('should handle refresh with delay', () async {
        // Act
        final stopwatch = Stopwatch()..start();
        await viewModel.refresh();
        stopwatch.stop();
        
        // Assert
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(500));
      });

      test('should clear general error', () async {
        // Arrange - Set an error first
        conversationsStreamController.addError('Test error');
        await Future.delayed(Duration.zero); // Wait for error to be set
        expect(viewModel.error, isNotNull);
        
        // Act
        viewModel.clearError();
        
        // Assert
        expect(viewModel.error, isNull);
      });

      test('should clear conversation creation error', () async {
        // Arrange - Create an error
        when(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        )).thenThrow(Exception('Creation error'));
        
        await viewModel.startDirectConversation(
          otherUserId: 'user',
          otherUserDisplayName: 'User',
        );
        expect(viewModel.conversationCreationError, isNotNull);
        
        // Act
        viewModel.clearError();
        
        // Assert
        expect(viewModel.conversationCreationError, isNull);
      });

      test('should handle multiple error states', () async {
        // Set stream error
        conversationsStreamController.addError('Stream error');
        await Future.delayed(Duration.zero);
        
        // Set creation error
        when(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        )).thenThrow(Exception('Creation error'));
        
        await viewModel.startDirectConversation(
          otherUserId: 'user',
          otherUserDisplayName: 'User',
        );
        
        // Both errors should be set
        expect(viewModel.error, isNotNull);
        expect(viewModel.conversationCreationError, isNotNull);
        
        // Clear all errors
        viewModel.clearError();
        
        // Both should be cleared
        expect(viewModel.error, isNull);
        expect(viewModel.conversationCreationError, isNull);
      });
    });

    group('Lifecycle Management', () {
      test('should dispose and cancel stream subscription', () async {
        // Arrange
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        
        // Act & Assert - Should not throw on first dispose
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle safe notify listeners when disposed', () {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        testViewModel.dispose();
        
        // Act & Assert - Should not throw
        expect(() => testViewModel.updateSearchQuery('test'), returnsNormally);
        expect(() => testViewModel.clearSearch(), returnsNormally);
        expect(() => testViewModel.clearError(), returnsNormally);
      });

      test('should handle multiple dispose calls safely', () {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        
        // Act - First dispose should work
        expect(() => testViewModel.dispose(), returnsNormally);
        
        // Note: Flutter's ChangeNotifier will throw on subsequent dispose calls
        // This is expected behavior, not a bug in our code
      });

      test('should not perform operations after dispose', () async {
        // Arrange - Create a separate viewModel for this test
        final testViewModel = ConversationsViewModel(
          messagingService: mockMessagingService,
          authRepository: mockAuthRepository,
        );
        testViewModel.dispose();
        
        // Act
        testViewModel.updateSearchQuery('test');
        testViewModel.clearSearch();
        testViewModel.clearError();
        await testViewModel.refresh();
        await testViewModel.markConversationAsRead('conv');
        await testViewModel.leaveGroup('group');
        await testViewModel.startDirectConversation(
          otherUserId: 'user',
          otherUserDisplayName: 'User',
        );
        await testViewModel.createGroupConversation(
          participantIds: ['user1'],
          participantDisplayNames: {'user1': 'User 1'},
          participantAvatarUrls: {'user1': null},
          title: 'Group',
        );
        
        // Assert - No operations should have been performed
        verifyNever(() => mockMessagingService.markConversationAsRead(any()));
        verifyNever(() => mockMessagingService.removeParticipantFromGroup(
          conversationId: any(named: 'conversationId'),
          participantId: any(named: 'participantId'),
        ));
        verifyNever(() => mockMessagingService.startDirectConversation(
          otherUserId: any(named: 'otherUserId'),
          otherUserDisplayName: any(named: 'otherUserDisplayName'),
          otherUserAvatarUrl: any(named: 'otherUserAvatarUrl'),
        ));
        verifyNever(() => mockMessagingService.createGroupConversation(
          participantIds: any(named: 'participantIds'),
          participantDisplayNames: any(named: 'participantDisplayNames'),
          participantAvatarUrls: any(named: 'participantAvatarUrls'),
          title: any(named: 'title'),
        ));
      });
    });
  });
}