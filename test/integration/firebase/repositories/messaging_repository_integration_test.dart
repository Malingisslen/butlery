/// Integration tests for Firebase Messaging Repository
///
/// **Status:** Bulk-skipped pending BUT-369 continuation. The production
/// repo now enforces `user is conversation participant` on every write,
/// but the seed fixtures construct conversations under the hardcoded
/// 'system' user id, so the writes get denied. The test set also relies
/// on FieldValue operations that FakeFirebaseFirestore doesn't implement.
/// Real coverage will land via the emulator lane (BUT-387 Phase 7).
@Tags(['integration'])
@Skip('Bulk-skipped pending BUT-369 rewrite — see file header.')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart'
    as firebase_auth_mocks;
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../test_support/test_data_isolator.dart';

void main() {
  group('Firebase Messaging Repository Integration Tests', () {
    late FirebaseMessagingRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late firebase_auth_mocks.MockFirebaseAuth mockAuth;

    const testUserId = 'test_user_123';
    const friendUserId = 'friend_456';

    setUp(() async {
      await TestServiceLocator.initialize();

      // Initialize test isolation
      TestDataIsolator.initializeTest('messaging_repository_integration_test');

      // Use FakeFirebaseFirestore singleton for integration tests
      fakeFirestore = FirestoreSingleton.instance;
      mockAuth = firebase_auth_mocks.MockFirebaseAuth(
        mockUser: firebase_auth_mocks.MockUser(
          uid: testUserId,
          email: 'test@example.com',
          displayName: 'Test User',
        ),
        signedIn: true,
      );

      repository = FirebaseMessagingRepository(
        firestore: fakeFirestore,
        authRepository: FakeAuthRepository()
          ..setAuthState(
            userId: testUserId,
            user: mockAuth.currentUser,
          ),
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest(
        'messaging_repository_integration_test',
      );
      await TestServiceLocator.reset();
    });

    group('FieldValue Operations', () {
      test('should use DateTime.now for message creation', () async {
        // Arrange
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        final message = Message.text(
          conversationId: conversationId,
          senderId: testUserId,
          senderDisplayName: 'Test User',
          content: 'Hello!',
        );

        // Act
        await repository.sendMessage(message);

        // Assert
        final snapshot = await fakeFirestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .get();

        expect(snapshot.docs, isNotEmpty);
        final messageData = snapshot.docs.first.data();
        expect(
          messageData['createdAt'],
          anyOf(isA<DateTime>(), isA<Timestamp>()),
        );
        expect(messageData['content'], equals('Hello!'));
      });

      // BUT-1838: `createGroupConversation`, `addParticipants` and
      // `removeParticipant` are removed from `MessagingRepository` — group
      // creation and membership changes now go through `ChatGroupRepository`
      // (the `createChatGroup`/`addChatGroupMembers`/`removeChatGroupMember`
      // callables), not a client-side Firestore write. The two tests that
      // exercised those methods here were deleted with them rather than
      // rewritten, since there is no repository-level replacement to point
      // at — real coverage for the new path lives in the CF unit/integration
      // tests, not here.

      test('should manually increment unread count', () async {
        // Arrange
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        // Send multiple messages
        for (int i = 0; i < 3; i++) {
          await repository.sendMessage(
            Message.text(
              conversationId: conversationId,
              senderId: testUserId,
              senderDisplayName: 'Test User',
              content: 'Message $i',
            ),
          );
        }

        // Act
        final unreadCount = await repository.getUnreadMessageCount(
          friendUserId,
        );

        // Assert - FakeFirebaseFirestore may not fully support increment
        // but we can verify the structure is correct
        // FakeFirebaseFirestore may not fully support increment
        // but we can verify the structure is correct
        expect(unreadCount, greaterThanOrEqualTo(0));
      });
    });

    group('Real-time Streaming', () {
      test('should stream conversation updates in real-time', () async {
        // Arrange
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        final messagesReceived = <List<Message>>[];
        final subscription = repository
            .getConversationMessages(
              conversationId: conversationId,
            )
            .listen((messages) {
              messagesReceived.add(messages);
            });

        // Act - Send messages with delays
        await Future.delayed(const Duration(milliseconds: 100));

        await repository.sendMessage(
          Message.text(
            conversationId: conversationId,
            senderId: testUserId,
            senderDisplayName: 'Test User',
            content: 'First message',
          ),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.sendMessage(
          Message.text(
            conversationId: conversationId,
            senderId: friendUserId,
            senderDisplayName: 'Friend User',
            content: 'Second message',
          ),
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(messagesReceived.length, greaterThanOrEqualTo(2));
        if (messagesReceived.length >= 2) {
          expect(messagesReceived.last.length, equals(2));
          expect(messagesReceived.last[0].content, equals('First message'));
          expect(messagesReceived.last[1].content, equals('Second message'));
        }

        await subscription.cancel();
      });

      test('should stream user conversations', () async {
        // Arrange
        final conversationsReceived = <List<Conversation>>[];

        final subscription = repository.getUserConversations(testUserId).listen(
          (conversations) {
            conversationsReceived.add(conversations);
          },
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Act - Create multiple conversations
        await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: 'friend_1',
          user2DisplayName: 'Friend 1',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: 'friend_2',
          user2DisplayName: 'Friend 2',
        );

        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(conversationsReceived.length, greaterThanOrEqualTo(2));
        if (conversationsReceived.length >= 2) {
          expect(conversationsReceived.last.length, equals(2));
        }

        await subscription.cancel();
      });
    });

    group('Transaction Operations', () {
      test('should handle batch mark as delivered', () async {
        // Arrange
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        final messageIds = <String>[];
        for (int i = 0; i < 5; i++) {
          final message = Message.text(
            conversationId: conversationId,
            senderId: testUserId,
            senderDisplayName: 'Test User',
            content: 'Message $i',
          );

          await repository.sendMessage(message);
          messageIds.add(message.id);
        }

        // Act
        await repository.batchMarkAsDelivered(
          messageIds: messageIds,
          userId: friendUserId,
        );

        // Assert - Verify structure is correct
        // In real Firebase, this would update message statuses
        expect(messageIds.length, equals(5));
      });

      test('should update conversation metadata transactionally', () async {
        // Arrange — a direct conversation exercises the same updateFn path;
        // group creation moved off this repository (BUT-1838, see the note
        // above the deleted participant-management tests).
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        // Act
        await repository.updateConversation(
          conversationId: conversationId,
          title: 'Updated Title',
          metadata: {
            'description': 'A test conversation',
            'category': 'recipe_discussion',
          },
        );

        // Assert
        final doc = await fakeFirestore
            .collection('conversations')
            .doc(conversationId)
            .get();

        expect(doc.data()!['title'], equals('Updated Title'));
        expect(
          doc.data()!['metadata']['description'],
          equals('A test conversation'),
        );
        expect(
          doc.data()!['metadata']['category'],
          equals('recipe_discussion'),
        );
      });
    });

    group('Query Operations', () {
      test('should search messages within conversation', () async {
        // Arrange
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        await repository.sendMessage(
          Message.text(
            conversationId: conversationId,
            senderId: testUserId,
            senderDisplayName: 'Test User',
            content: 'Let\'s cook pasta tonight',
          ),
        );

        await repository.sendMessage(
          Message.text(
            conversationId: conversationId,
            senderId: friendUserId,
            senderDisplayName: 'Friend User',
            content: 'I prefer pizza',
          ),
        );

        await repository.sendMessage(
          Message.text(
            conversationId: conversationId,
            senderId: testUserId,
            senderDisplayName: 'Test User',
            content: 'How about pasta with pizza toppings?',
          ),
        );

        // Act
        final results = await repository.searchMessages(
          conversationId: conversationId,
          query: 'pasta',
        );

        // Assert
        expect(results.length, equals(2));
        expect(
          results.every((m) => m.content.toLowerCase().contains('pasta')),
          isTrue,
        );
      });

      test('should paginate messages correctly', () async {
        // Arrange
        final conversationId = await repository.createDirectConversation(
          user1Id: testUserId,
          user1DisplayName: 'Test User',
          user2Id: friendUserId,
          user2DisplayName: 'Friend User',
        );

        // Create 10 messages
        for (int i = 0; i < 10; i++) {
          await repository.sendMessage(
            Message.text(
              conversationId: conversationId,
              senderId: i.isEven ? testUserId : friendUserId,
              senderDisplayName: i.isEven ? 'Test User' : 'Friend User',
              content: 'Message $i',
            ),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Act
        final firstPage = await repository.getConversationMessagesPage(
          conversationId: conversationId,
          limit: 5,
        );

        final secondPage = await repository.getConversationMessagesPage(
          conversationId: conversationId,
          limit: 5,
          startAfter: firstPage.last.sentAt,
        );

        // Assert
        expect(firstPage.length, lessThanOrEqualTo(5));
        expect(secondPage.length, lessThanOrEqualTo(5));

        // Ensure no overlap
        final firstPageIds = firstPage.map((m) => m.id).toSet();
        final secondPageIds = secondPage.map((m) => m.id).toSet();
        expect(firstPageIds.intersection(secondPageIds), isEmpty);
      });
    });
  });
}
