/// Emulator-lane integration tests for [FirebaseMessagingRepository].
///
/// Sending a message is a batched write of the message plus the conversation's
/// `lastMessage`, followed by a deferred status flip to `sent`; the listeners
/// and queries on top of it need real snapshot semantics. The emulator runs
/// without security rules, so the participant checks asserted here are the
/// repository's own client-side ones.
@Tags(['integration', 'firebase'])
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/emulator_lane.dart';

void main() {
  group('Firebase Messaging Repository Integration Tests', () {
    late FirebaseMessagingRepository repository;
    late FirebaseFirestore firestore;

    const testUserId = 'test_user_123';
    const friendUserId = 'friend_456';
    const server = GetOptions(source: Source.server);
    const wait = Duration(seconds: 15);

    Message textFrom(
      String conversationId,
      String senderId,
      String content, {
      DateTime? at,
    }) {
      Message build() => Message.text(
        conversationId: conversationId,
        senderId: senderId,
        senderDisplayName: senderId,
        content: content,
      );
      return at == null ? build() : withClock(Clock.fixed(at), build);
    }

    Future<String> createConversation({
      String other = friendUserId,
      DateTime? at,
    }) {
      Future<String> create() => repository.createDirectConversation(
        user1Id: testUserId,
        user1DisplayName: 'Test User',
        user2Id: other,
        user2DisplayName: 'Friend User',
      );
      return at == null ? create() : withClock(Clock.fixed(at), create);
    }

    DocumentReference<Map<String, dynamic>> conversationDoc(String id) =>
        firestore.collection('conversations').doc(id);

    DocumentReference<Map<String, dynamic>> messageDoc(String id) =>
        firestore.collection('messages').doc(id);

    // sendMessage flips the message, then the conversation's lastMessage, to
    // `sent` on a deferred write. Waiting for both keeps that write from
    // landing in a later test, which reuses the same deterministic ids.
    Future<void> sendSettled(Message message) async {
      await repository.sendMessage(message);
      await messageDoc(message.id)
          .snapshots()
          .firstWhere((s) => s.data()?['status'] == 'sent')
          .timeout(wait);
      await conversationDoc(message.conversationId)
          .snapshots()
          .firstWhere((s) => s.data()?['lastMessage']?['status'] == 'sent')
          .timeout(wait);
    }

    Future<void> seedMessage(Message message) =>
        messageDoc(message.id).set(MessageDto.toFirestore(message));

    setUp(() async {
      firestore = await firestoreForLane();
      await clearLane();

      repository = FirebaseMessagingRepository(
        firestore: firestore,
        authRepository: FakeAuthRepository()
          ..setAuthState(userId: testUserId, isAuthenticated: true),
      );
    });

    group('Direct conversations', () {
      test('the id is the same whichever side opens it, and reopening does '
          'not create a second one', () async {
        final first = await createConversation();
        final reversed = await repository.createDirectConversation(
          user1Id: friendUserId,
          user1DisplayName: 'Friend User',
          user2Id: testUserId,
          user2DisplayName: 'Test User',
        );

        expect(reversed, first);
        expect(first, 'direct_${friendUserId}_$testUserId');
        final all = await firestore.collection('conversations').get(server);
        expect(all.docs, hasLength(1));
        final stored = await repository.getConversation(first);
        expect(stored!.isGroup, isFalse);
        expect(
          stored.participantIds,
          unorderedEquals([testUserId, friendUserId]),
        );
        expect(stored.metadata?['creatorId'], testUserId);
      });

      test('getConversationParticipants lists the two participants and '
          'nobody for an unknown id', () async {
        final id = await createConversation();

        expect(
          await repository.getConversationParticipants(id),
          unorderedEquals([testUserId, friendUserId]),
        );
        expect(await repository.getConversationParticipants('nope'), isEmpty);
      });

      test('updateConversation sets title and metadata', () async {
        final id = await createConversation();

        await repository.updateConversation(
          conversationId: id,
          title: 'Updated Title',
          metadata: {'description': 'A test conversation'},
        );

        final data = (await conversationDoc(id).get(server)).data()!;
        expect(data['title'], 'Updated Title');
        expect(data['metadata']['description'], 'A test conversation');
        expect(
          data['participantIds'],
          unorderedEquals([testUserId, friendUserId]),
        );
      });

      test('updateConversation on a missing conversation throws and creates '
          'nothing', () async {
        await expectLater(
          repository.updateConversation(
            conversationId: 'direct_a_b',
            title: 'x',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
        expect(
          (await conversationDoc('direct_a_b').get(server)).exists,
          isFalse,
        );
      });

      test('renaming a group conversation changes nothing visible when the '
          'group record cannot be written', () async {
        await conversationDoc('conv_group').set({
          'participantIds': [testUserId, friendUserId],
          'isGroup': true,
          'title': 'Old name',
          'groupId': 'missing_group',
          'updatedAt': Timestamp.now(),
        });

        await expectLater(
          repository.updateConversation(
            conversationId: 'conv_group',
            title: 'New name',
          ),
          throwsA(anything),
        );

        expect(
          (await conversationDoc('conv_group').get(server)).data()?['title'],
          'Old name',
        );
      });

      test(
        'renaming a group conversation also renames its chat group',
        () async {
          await firestore.collection('chat_groups').doc('g1').set({
            'name': 'Old name',
          });
          await conversationDoc('conv_group').set({
            'participantIds': [testUserId, friendUserId],
            'isGroup': true,
            'title': 'Old name',
            'groupId': 'g1',
            'updatedAt': Timestamp.now(),
          });

          await repository.updateConversation(
            conversationId: 'conv_group',
            title: 'New name',
          );

          expect(
            (await conversationDoc('conv_group').get(server)).data()?['title'],
            'New name',
          );
          expect(
            (await firestore.collection('chat_groups').doc('g1').get(server))
                .data()?['name'],
            'New name',
          );
        },
      );
    });

    group('Sending', () {
      test('stores the message and mirrors it into the conversation\'s '
          'lastMessage', () async {
        final id = await createConversation();
        final message = textFrom(id, testUserId, 'Hello!');

        await sendSettled(message);

        final stored = (await messageDoc(message.id).get(server)).data()!;
        expect(stored['content'], 'Hello!');
        expect(stored['senderId'], testUserId);
        expect(stored['conversationId'], id);
        expect(stored['createdAt'], isA<Timestamp>());
        final conversation = await repository.getConversation(id);
        expect(conversation!.lastMessage!.id, message.id);
        expect(conversation.lastMessage!.content, 'Hello!');
      });

      test('a sender who is not in the conversation is refused and nothing '
          'is written', () async {
        final id = await createConversation();
        final intruder = textFrom(id, 'intruder', 'Let me in');

        await expectLater(
          repository.sendMessage(intruder),
          throwsA(isA<PermissionDeniedException>()),
        );

        expect((await messageDoc(intruder.id).get(server)).exists, isFalse);
        expect((await repository.getConversation(id))!.lastMessage, isNull);
      });

      test('sending into a conversation that does not exist throws and '
          'invents no conversation', () async {
        final message = textFrom('direct_a_b', testUserId, 'Hello?');

        await expectLater(
          repository.sendMessage(message),
          throwsA(isA<ResourceNotFoundException>()),
        );

        expect((await messageDoc(message.id).get(server)).exists, isFalse);
        expect(
          (await conversationDoc('direct_a_b').get(server)).exists,
          isFalse,
        );
      });

      test(
        'batchMarkAsDelivered marks every given message delivered',
        () async {
          final id = await createConversation();
          final messages = [
            for (var i = 0; i < 3; i++) textFrom(id, testUserId, 'Message $i'),
          ];
          for (final m in messages) {
            await seedMessage(m);
          }

          await repository.batchMarkAsDelivered(
            messageIds: [for (final m in messages) m.id],
            userId: friendUserId,
          );

          for (final m in messages) {
            final data = (await messageDoc(m.id).get(server)).data()!;
            expect(data['status'], 'delivered');
            expect(data['deliveredAt'], isA<Timestamp>());
          }
        },
      );
    });

    group('Reading', () {
      test('a recipient has an unread conversation until it is marked '
          'read', () async {
        final id = await createConversation(
          at: DateTime.now().subtract(const Duration(minutes: 1)),
        );
        await sendSettled(textFrom(id, testUserId, 'Are you there?'));

        expect(await repository.getUnreadConversationsCount(friendUserId), 1);

        await repository.markConversationAsRead(
          conversationId: id,
          userId: friendUserId,
        );

        expect(await repository.getUnreadConversationsCount(friendUserId), 0);
        final stored = (await conversationDoc(id).get(server)).data()!;
        expect(stored['lastReadTimestamps'][friendUserId], isA<Timestamp>());
      });

      test('only a participant can mark a conversation read', () async {
        final id = await createConversation();

        await expectLater(
          repository.markConversationAsRead(
            conversationId: id,
            userId: 'intruder',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        final stored = (await conversationDoc(id).get(server)).data()!;
        expect(
          (stored['lastReadTimestamps'] as Map).containsKey('intruder'),
          isFalse,
        );
      });
    });

    group('Real-time streaming', () {
      test('the message stream delivers messages oldest first as they are '
          'sent', () async {
        final id = await createConversation();
        final base = DateTime.now().subtract(const Duration(minutes: 5));

        final stream = repository.getConversationMessages(conversationId: id);
        final bothArrived = stream
            .firstWhere((messages) => messages.length == 2)
            .timeout(wait);

        await sendSettled(textFrom(id, testUserId, 'First message', at: base));
        await sendSettled(
          textFrom(
            id,
            friendUserId,
            'Second message',
            at: base.add(const Duration(seconds: 1)),
          ),
        );

        final messages = await bothArrived;
        expect(messages.map((m) => m.content), [
          'First message',
          'Second message',
        ]);
      });

      test('the conversation list stream picks up conversations as they are '
          'created', () async {
        final stream = repository.getUserConversations(testUserId);
        final both = stream
            .firstWhere((conversations) => conversations.length == 2)
            .timeout(wait);

        final first = await createConversation(other: 'friend_1');
        final second = await createConversation(other: 'friend_2');

        final conversations = await both;
        expect(
          conversations.map((Conversation c) => c.id),
          unorderedEquals([first, second]),
        );
      });
    });

    group('Queries', () {
      test('searchMessages finds matches case-insensitively, newest first, '
          'and only in the given conversation', () async {
        final id = await createConversation();
        final other = await createConversation(other: 'friend_other');
        final base = DateTime.now().subtract(const Duration(minutes: 5));
        for (final (i, entry) in [
          (id, 'Let\'s cook pasta tonight'),
          (id, 'I prefer pizza'),
          (id, 'How about pasta with pizza toppings?'),
          (other, 'Pasta in another chat'),
        ].indexed) {
          await seedMessage(
            textFrom(
              entry.$1,
              testUserId,
              entry.$2,
              at: base.add(Duration(seconds: i)),
            ),
          );
        }

        final results = await repository.searchMessages(
          conversationId: id,
          query: 'PASTA',
        );

        expect(results.map((m) => m.content), [
          'How about pasta with pizza toppings?',
          'Let\'s cook pasta tonight',
        ]);
      });

      test('paging walks back through the history without overlap', () async {
        final id = await createConversation();
        final base = DateTime.now().subtract(const Duration(minutes: 5));
        for (var i = 0; i < 10; i++) {
          await seedMessage(
            textFrom(
              id,
              i.isEven ? testUserId : friendUserId,
              'Message $i',
              at: base.add(Duration(seconds: i)),
            ),
          );
        }

        final firstPage = await repository.getConversationMessagesPage(
          conversationId: id,
          limit: 5,
        );
        final secondPage = await repository.getConversationMessagesPage(
          conversationId: id,
          limit: 5,
          startAfter: firstPage.first.sentAt,
        );

        expect(firstPage.map((m) => m.content), [
          for (var i = 5; i < 10; i++) 'Message $i',
        ]);
        expect(secondPage.map((m) => m.content), [
          for (var i = 0; i < 5; i++) 'Message $i',
        ]);
      });

      test(
        'historyStart hides messages from before the member joined',
        () async {
          final id = await createConversation();
          final base = DateTime.now().subtract(const Duration(minutes: 5));
          for (var i = 0; i < 4; i++) {
            await seedMessage(
              textFrom(
                id,
                testUserId,
                'Message $i',
                at: base.add(Duration(seconds: i)),
              ),
            );
          }

          final page = await repository.getConversationMessagesPage(
            conversationId: id,
            historyStart: base.add(const Duration(seconds: 2)),
          );

          expect(page.map((m) => m.content), ['Message 2', 'Message 3']);
        },
      );
    });
  }, skip: emulatorOnlySkip);
}
