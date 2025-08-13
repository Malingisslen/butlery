/// Unit tests for FirebaseMessagingRepository
/// 
/// Tests the messaging repository that provides real-time messaging and
/// conversation management functionality for the application.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseMessagingRepository', () {
    late FirebaseMessagingRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(Conversation.direct(
        user1Id: 'fallback1',
        user1DisplayName: 'Fallback User 1',
        user2Id: 'fallback2',
        user2DisplayName: 'Fallback User 2',
      ));
      registerFallbackValue(Message.text(
        conversationId: 'fallback_conv',
        senderId: 'fallback_sender',
        senderDisplayName: 'Fallback User',
        content: 'Fallback message',
      ));
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Setup fake Firestore and mock auth
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      
      // Create repository with dependency injection
      repository = FirebaseMessagingRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );
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
        
        // Act
        final conversationId = await repository.createDirectConversation(
          user1Id: user1Id,
          user1DisplayName: user1Name,
          user2Id: user2Id,
          user2DisplayName: user2Name,
        );
        
        // Assert
        expect(conversationId, isNotEmpty);
        
        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('conversations')
            .doc(conversationId)
            .get();
        expect(doc.exists, isTrue);
        
        final data = doc.data()!;
        expect(data['participantIds'], containsAll([user1Id, user2Id]));
        expect(data['isGroup'], isFalse);
        expect(data['participantDisplayNames'][user1Id], equals(user1Name));
        expect(data['participantDisplayNames'][user2Id], equals(user2Name));
      });
      
      test('should return existing direct conversation if already exists', () async {
        // Arrange
        const user1Id = 'user_1';
        const user2Id = 'user_2';
        
        // Create first conversation
        final firstId = await repository.createDirectConversation(
          user1Id: user1Id,
          user1DisplayName: 'Alice',
          user2Id: user2Id,
          user2DisplayName: 'Bob',
        );
        
        // Act - Try to create again
        final secondId = await repository.createDirectConversation(
          user1Id: user1Id,
          user1DisplayName: 'Alice',
          user2Id: user2Id,
          user2DisplayName: 'Bob',
        );
        
        // Assert - Should return same conversation
        expect(secondId, equals(firstId));
      });
      
      test('should create group conversation with multiple participants', () async {
        // Arrange
        final participantIds = ['user_1', 'user_2', 'user_3'];
        final displayNames = {
          'user_1': 'Alice',
          'user_2': 'Bob',
          'user_3': 'Charlie',
        };
        final avatarUrls = {
          'user_1': 'avatar1.jpg',
          'user_2': null,
          'user_3': 'avatar3.jpg',
        };
        const groupTitle = 'Recipe Exchange Group';
        const creatorId = 'user_1';
        
        // Act
        final conversationId = await repository.createGroupConversation(
          participantIds: participantIds,
          participantDisplayNames: displayNames,
          participantAvatarUrls: avatarUrls,
          title: groupTitle,
          creatorId: creatorId,
        );
        
        // Assert
        expect(conversationId, isNotEmpty);
        
        // Verify in Firestore
        final doc = await fakeFirestore
            .collection('conversations')
            .doc(conversationId)
            .get();
        expect(doc.exists, isTrue);
        
        final data = doc.data()!;
        expect(data['participantIds'], equals(participantIds));
        expect(data['isGroup'], isTrue);
        expect(data['title'], equals(groupTitle));
        expect(data['creatorId'], equals(creatorId));
        
        // Verify system message was sent
        final messages = await fakeFirestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .get();
        expect(messages.docs.length, equals(1));
        expect(messages.docs.first.data()['type'], equals('system'));
      });
      
      test('should find existing direct conversation', () async {
        // Arrange
        const user1Id = 'user_1';
        const user2Id = 'user_2';
        
        final conversationId = await repository.createDirectConversation(
          user1Id: user1Id,
          user1DisplayName: 'Alice',
          user2Id: user2Id,
          user2DisplayName: 'Bob',
        );
        
        // Act
        final foundId = await repository.findDirectConversation(
          user1Id: user1Id,
          user2Id: user2Id,
        );
        
        // Assert
        expect(foundId, equals(conversationId));
      });
      
      test('should return null when direct conversation does not exist', () async {
        // Act
        final foundId = await repository.findDirectConversation(
          user1Id: 'non_existent_1',
          user2Id: 'non_existent_2',
        );
        
        // Assert
        expect(foundId, isNull);
      });
      
      test('should update conversation metadata', () async {
        // Arrange
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'Alice', 'user_2': 'Bob'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          title: 'Original Title',
          creatorId: 'user_1',
        );
        
        await fakeFirestore
            .collection('conversations')
            .doc(conversation.id)
            .set(ConversationDto.toFirestore(conversation));
        
        // Act
        await repository.updateConversation(
          conversationId: conversation.id,
          title: 'Updated Title',
          metadata: {'theme': 'dark'},
        );
        
        // Assert
        final doc = await fakeFirestore
            .collection('conversations')
            .doc(conversation.id)
            .get();
        expect(doc.data()?['title'], equals('Updated Title'));
        expect(doc.data()?['metadata']?['theme'], equals('dark'));
      });
    });
    
    group('Message Operations', () {
      test('should send text message', () async {
        // Arrange
        const conversationId = 'test_conversation';
        const senderId = 'sender_123';
        const senderName = 'Test Sender';
        const content = 'Hello, this is a test message!';
        
        final message = Message.text(
          conversationId: conversationId,
          senderId: senderId,
          senderDisplayName: senderName,
          content: content,
        );
        
        // Act
        await repository.sendMessage(message);
        
        // Assert - Message should be saved in Firestore
        final messages = await fakeFirestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .get();
        
        expect(messages.docs.length, equals(1));
        final savedMessage = messages.docs.first.data();
        expect(savedMessage['content'], equals(content));
        expect(savedMessage['senderId'], equals(senderId));
        expect(savedMessage['senderDisplayName'], equals(senderName));
      });
      
      test('should send recipe share message', () async {
        // Arrange
        const conversationId = 'test_conversation';
        const senderId = 'sender_123';
        const senderName = 'Recipe Sharer';
        const recipeId = 'recipe_456';
        const recipeTitle = 'Swedish Meatballs';
        
        final message = Message.recipeShare(
          conversationId: conversationId,
          senderId: senderId,
          senderDisplayName: senderName,
          recipeId: recipeId,
          recipeTitle: recipeTitle,
        );
        
        // Act
        await repository.sendMessage(message);
        
        // Assert
        final messages = await fakeFirestore
            .collection('messages')
            .where('conversationId', isEqualTo: conversationId)
            .get();
        
        expect(messages.docs.length, equals(1));
        final savedMessage = messages.docs.first.data();
        expect(savedMessage['type'], equals('recipe_share'));
        expect(savedMessage['metadata']?['recipeId'], equals(recipeId));
        expect(savedMessage['metadata']?['recipeTitle'], equals(recipeTitle));
      });
      
      test('should delete message', () async {
        // Arrange
        const conversationId = 'test_conversation';
        const senderId = 'sender_123';
        const messageId = 'message_to_delete';
        
        final message = Message.text(
          conversationId: conversationId,
          senderId: senderId,
          senderDisplayName: 'Test User',
          content: 'Message to delete',
        );
        
        // Save message to Firestore
        await fakeFirestore
            .collection('messages')
            .doc(messageId)
            .set(MessageDto.toFirestore(message));
        
        // Act
        await repository.deleteMessage(messageId);
        
        // Assert
        final doc = await fakeFirestore
            .collection('messages')
            .doc(messageId)
            .get();
        expect(doc.exists, isFalse);
      });
    });
    
    group('Stream Operations', () {
      test('should stream user conversations', () async {
        // Arrange
        const userId = 'test_user';
        
        // Create test conversations
        final conv1 = Conversation.direct(
          user1Id: userId,
          user1DisplayName: 'Test User',
          user2Id: 'other_user_1',
          user2DisplayName: 'Other User 1',
        );
        
        final conv2 = Conversation.direct(
          user1Id: userId,
          user1DisplayName: 'Test User',
          user2Id: 'other_user_2',
          user2DisplayName: 'Other User 2',
        );
        
        await fakeFirestore.collection('conversations').doc(conv1.id).set(ConversationDto.toFirestore(conv1));
        await fakeFirestore.collection('conversations').doc(conv2.id).set(ConversationDto.toFirestore(conv2));
        
        // Act
        final stream = repository.getUserConversations(userId);
        
        // Assert
        final conversations = await stream.first;
        expect(conversations.length, equals(2));
        expect(conversations.every((c) => c.participantIds.contains(userId)), isTrue);
      });
      
      test('should stream conversation messages', () async {
        // Arrange
        const conversationId = 'test_conversation';
        
        // Create test messages
        final messages = [
          Message.text(
            conversationId: conversationId,
            senderId: 'user_1',
            senderDisplayName: 'User One',
            content: 'First message',
          ),
          Message.text(
            conversationId: conversationId,
            senderId: 'user_2',
            senderDisplayName: 'User Two',
            content: 'Second message',
          ),
        ];
        
        for (final msg in messages) {
          await fakeFirestore.collection('messages').doc(msg.id).set(MessageDto.toFirestore(msg));
        }
        
        // Act
        final stream = repository.getConversationMessages(
          conversationId: conversationId,
        );
        
        // Assert
        final streamedMessages = await stream.first;
        expect(streamedMessages.length, equals(2));
        expect(streamedMessages.map((m) => m.content), 
            containsAll(['First message', 'Second message']));
      });
    });
    
    group('Participant Management', () {
      test('should add participants to group conversation', () async {
        // Arrange
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2'],
          participantDisplayNames: {'user_1': 'Alice', 'user_2': 'Bob'},
          participantAvatarUrls: {'user_1': null, 'user_2': null},
          title: 'Test Group',
          creatorId: 'user_1',
        );
        
        await fakeFirestore
            .collection('conversations')
            .doc(conversation.id)
            .set(ConversationDto.toFirestore(conversation));
        
        // Act
        await repository.addParticipants(
          conversationId: conversation.id,
          participantIds: ['user_3'],
          participantDisplayNames: {'user_3': 'Charlie'},
          participantAvatarUrls: {'user_3': null},
        );
        
        // Assert
        final doc = await fakeFirestore
            .collection('conversations')
            .doc(conversation.id)
            .get();
        final participantIds = List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participantIds, containsAll(['user_1', 'user_2', 'user_3']));
      });
      
      test('should remove participant from group conversation', () async {
        // Arrange
        final conversation = Conversation.group(
          participantIds: ['user_1', 'user_2', 'user_3'],
          participantDisplayNames: {
            'user_1': 'Alice',
            'user_2': 'Bob',
            'user_3': 'Charlie',
          },
          participantAvatarUrls: {
            'user_1': null,
            'user_2': null,
            'user_3': null,
          },
          title: 'Test Group',
          creatorId: 'user_1',
        );
        
        await fakeFirestore
            .collection('conversations')
            .doc(conversation.id)
            .set(ConversationDto.toFirestore(conversation));
        
        // Act
        await repository.removeParticipant(
          conversationId: conversation.id,
          participantId: 'user_3',
        );
        
        // Assert
        final doc = await fakeFirestore
            .collection('conversations')
            .doc(conversation.id)
            .get();
        final participantIds = List<String>.from(doc.data()?['participantIds'] ?? []);
        expect(participantIds, equals(['user_1', 'user_2']));
        expect(participantIds, isNot(contains('user_3')));
      });
    });
    
    group('Message Status', () {
      test('should mark message as read', () async {
        // Arrange
        const conversationId = 'test_conversation';
        const messageId = 'test_message';
        
        final message = Message.text(
          conversationId: conversationId,
          senderId: 'sender',
          senderDisplayName: 'Sender Name',
          content: 'Test message',
        );
        
        await fakeFirestore
            .collection('messages')
            .doc(messageId)
            .set(MessageDto.toFirestore(message));
        
        // Act
        await repository.markMessageAsRead(
          messageId: messageId,
          userId: 'reader',
        );
        
        // Assert
        final doc = await fakeFirestore
            .collection('messages')
            .doc(messageId)
            .get();
        expect(doc.data()?['readBy'], contains('reader'));
      });
    });
    
    group('Error Handling', () {
      test('should handle conversation not found error', () async {
        // Act & Assert
        expect(
          () async => await repository.updateConversation(
            conversationId: 'non_existent',
            title: 'New Title',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
      
      test('should require authentication for message operations', () async {
        // Arrange
        mockAuthRepository.setAuthState(userId: null);
        final message = Message.text(
          conversationId: 'test',
          senderId: 'test',
          senderDisplayName: 'Test User',
          content: 'Test',
        );
        
        // Act & Assert
        expect(
          () async => await repository.sendMessage(message),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}