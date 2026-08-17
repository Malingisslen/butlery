/// Unit tests for MessageMutationModule.
///
/// Targets the sendMessage write module that handles its atomic
/// 3-doc batch + poll mutation. Tests focus on the documented contracts
/// (atomic write, fallback conversation construction, permission gates,
/// poll vote toggling) rather than method-call presence.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';

const _convoCollection = 'conversations';
const _messagesPath = 'messages';

MessageMutationModule _newModule(
  FakeFirebaseFirestore firestore, {
  Future<Conversation?> Function(String)? readConversation,
}) {
  return MessageMutationModule(
    firestore: firestore,
    collectionName: _convoCollection,
    messagesRef: firestore.collection(_messagesPath),
    readConversation: readConversation ?? ((_) async => null),
  );
}

Conversation _twoPersonConvo({
  String id = 'conv-1',
  String userA = 'user-a',
  String userB = 'user-b',
}) {
  return Conversation(
    id: id,
    participantIds: [userA, userB],
    participantDisplayNames: {userA: 'A', userB: 'B'},
    participantAvatarUrls: const {},
    lastReadTimestamps: const {},
    isGroup: false,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Message _textMessage({
  String conversationId = 'conv-1',
  String senderId = 'user-a',
}) {
  return Message.text(
    conversationId: conversationId,
    senderId: senderId,
    senderDisplayName: 'A',
    content: 'hello',
  );
}

void main() {
  group('MessageMutationModule.sendMessage', () {
    test(
      'atomically writes message + conversation update + sender rate-limit doc',
      () async {
        final firestore = FakeFirebaseFirestore();
        final convo = _twoPersonConvo();
        final module = _newModule(
          firestore,
          readConversation: (id) async => id == convo.id ? convo : null,
        );

        final msg = _textMessage();

        await module.sendMessage(msg);

        // 1. Message written
        final msgDoc = await firestore
            .collection(_messagesPath)
            .doc(msg.id)
            .get();
        expect(msgDoc.exists, isTrue);
        expect(msgDoc.data()?['content'], equals('hello'));

        // 2. Conversation lastMessage updated (via merge set)
        final convoDoc = await firestore
            .collection(_convoCollection)
            .doc(convo.id)
            .get();
        expect(convoDoc.exists, isTrue);
        expect(convoDoc.data()?['lastMessage'], isA<Map<String, dynamic>>());

        // 3. Sender rate-limit doc written under users/<sender>/rate_limits/messages
        final rateDoc = await firestore
            .collection('users')
            .doc(msg.senderId)
            .collection('rate_limits')
            .doc('messages')
            .get();
        expect(rateDoc.exists, isTrue);
        expect(rateDoc.data()?['expireAt'], isNotNull);
      },
    );

    test('rejects non-participants with PermissionDeniedException', () async {
      final firestore = FakeFirebaseFirestore();
      final convo = _twoPersonConvo(userA: 'user-a', userB: 'user-b');
      final module = _newModule(
        firestore,
        readConversation: (id) async => convo,
      );

      final outsiderMsg = _textMessage(senderId: 'user-c');

      await expectLater(
        module.sendMessage(outsiderMsg),
        throwsA(isA<PermissionDeniedException>()),
      );

      final msgDoc = await firestore
          .collection(_messagesPath)
          .doc(outsiderMsg.id)
          .get();
      expect(
        msgDoc.exists,
        isFalse,
        reason: 'No message should land when permission is denied',
      );
    });

    test(
      'falls back to constructed conversation when readConversation returns null '
      '— for ANY id; the direct_ check lives only in the catch, so a null RETURN '
      'reaches the fallback whatever the id looks like. This case uses a direct_ '
      'id because it also exercises the other-participant profile fetch',
      () async {
        final firestore = FakeFirebaseFirestore();
        // Pre-seed the other user's public profile doc.
        await firestore.collection('users').doc('user-b').set({
          'displayName': 'B from profile',
          'avatarUrl': 'https://x/b.png',
        });

        final module = _newModule(
          firestore,
          readConversation: (_) async => null, // simulate missing conversation
        );

        final msg = _textMessage(
          conversationId: 'direct_user-a_user-b',
          senderId: 'user-a',
        );

        await module.sendMessage(msg);

        // The fallback conversation should have been merged in with both
        // participants' display names populated.
        final convoDoc = await firestore
            .collection(_convoCollection)
            .doc('direct_user-a_user-b')
            .get();
        expect(convoDoc.exists, isTrue);
        final participantNames = Map<String, dynamic>.from(
          convoDoc.data()?['participantDisplayNames'] as Map,
        );
        expect(participantNames['user-a'], equals('A'));
        expect(participantNames['user-b'], equals('B from profile'));

        // The fallback must write `metadata` PRESENT and NULL. Both halves are
        // load-bearing, and neither is obvious, which is why this is a test and
        // not only a comment.
        //
        // WHY, restated for BUT-1838 — the old reason is retired and repeating
        // it would mislead. It used to be that the conversations CREATE rule
        // read `'creatorId' in request.resource.data.metadata`, that an `in` on
        // a null was an evaluation error, and that this error was the only
        // thing stopping a non-creator from materialising a group's top-level
        // document and thereby disarming an `onDocumentCreated` child-safety
        // trigger. The rule is now a bare
        // `request.resource.data.metadata.creatorId == request.auth.uid`, a
        // client cannot create a group conversation at all, and the safety gate
        // runs before the write in the `chat_groups` callables.
        //
        // What still holds, and what these two assertions pin:
        //   1. stamping `metadata: {'creatorId': senderId}` here would claim a
        //      creator this caller is not — the second assertion catches it,
        //      because the VALUE stops being null;
        //   2. making `ConversationDto.toFirestore` skip a null metadata (the
        //      standard "don't write nulls" cleanup) changes a write path the
        //      rules govern — the first assertion catches it, because the KEY
        //      disappears.
        // That way round, and it is worth stating because getting it backwards
        // is how the load-bearing one gets deleted: under (1) the key is still
        // present so `containsKey` does not fire; under (2) the key is absent
        // and `data()['metadata']` returns null, so `isNull` passes VACUOUSLY.
        // Measured, not reasoned: each mutant reddens exactly one of them.
        //
        // AND: green here is the FAKE, not production. This payload is still
        // refused against the real rules, now by the bare equality on create
        // and by the update rule's `createdAt` pin when the document exists
        // (BUT-1831). Do not read this passing test as proof the fallback
        // works.
        expect(
          convoDoc.data()!.containsKey('metadata'),
          isTrue,
          reason:
              'the metadata KEY must be written even when null — omitting it '
              "satisfies the rule's !(metadata in data) disjunct and lets a "
              "non-creator's conversation create land",
        );
        expect(
          convoDoc.data()!['metadata'],
          isNull,
          reason:
              'the fallback conversation must record NO creator — a creatorId '
              'here makes the create land and disarms the minor-eviction '
              'trigger for that group',
        );
      },
    );

    // The SAME invariant on a GROUP-shaped id, and it is not redundant.
    //
    // The test above reaches the fallback through a `direct_` id, so its payload
    // has two participants. The payload the invariant is actually about is the
    // one-participant shape a group id produces — `otherUserId` is parsed only
    // from a `direct_` id, so it stays null. Without this fixture a
    // BRANCH-CONDITIONAL disarming edit survives the whole suite: stamping a
    // creatorId only when the id does NOT start with `direct_` is mutant (1)
    // applied exactly where it matters, and every other test stays green.
    test(
      'the fallback records no creator and keeps the metadata key for a '
      'GROUP-shaped id too — the one-participant payload the squat is about',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          readConversation: (_) async => null,
        );

        await module.sendMessage(
          _textMessage(conversationId: 'group-abc', senderId: 'user-a'),
        );

        final convoDoc = await firestore
            .collection(_convoCollection)
            .doc('group-abc')
            .get();
        expect(convoDoc.exists, isTrue);
        expect(
          convoDoc.data()!['participantIds'],
          equals(['user-a']),
          reason:
              'a group id yields no otherUserId, so the fallback builds a '
              'ONE-participant conversation — the exact shape that makes '
              'enforceGroupMinorMembership return early',
        );
        expect(convoDoc.data()!['isGroup'], isFalse);
        expect(
          convoDoc.data()!.containsKey('metadata'),
          isTrue,
          reason:
              'same invariant as the direct_ case, on the shape it matters for',
        );
        expect(convoDoc.data()!['metadata'], isNull);
      },
    );

    test(
      'throws ResourceNotFoundException when conversation missing AND id is '
      'not a deterministic direct_ id',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          // Throwing read short-circuits to the not-found branch since the id
          // doesn't start with `direct_`.
          readConversation: (_) async => throw StateError('not found'),
        );

        final msg = _textMessage(conversationId: 'random-uuid-not-direct');

        await expectLater(
          module.sendMessage(msg),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );
  });

  group('MessageMutationModule.updateMessageStatus', () {
    test('sets status field and deliveredAt for delivered status', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      // Seed a message doc.
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'status': MessageStatus.sending.name,
      });

      await module.updateMessageStatus(
        messageId: 'msg-1',
        status: MessageStatus.delivered,
      );

      final doc = await firestore.collection(_messagesPath).doc('msg-1').get();
      expect(doc.data()?['status'], equals(MessageStatus.delivered.name));
      expect(doc.data()?['deliveredAt'], isNotNull);
    });

    test('sets readAt for read status with explicit timestamp', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'status': MessageStatus.delivered.name,
      });

      final readAt = DateTime.utc(2026, 5, 19, 12, 0);
      await module.updateMessageStatus(
        messageId: 'msg-1',
        status: MessageStatus.read,
        timestamp: readAt,
      );

      final doc = await firestore.collection(_messagesPath).doc('msg-1').get();
      expect(doc.data()?['status'], equals(MessageStatus.read.name));
      expect(doc.data()?['readAt'], isNotNull);
    });

    test(
      'markMessageAsRead is a thin wrapper around updateMessageStatus',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await firestore.collection(_messagesPath).doc('msg-1').set({
          'status': MessageStatus.delivered.name,
        });

        await module.markMessageAsRead(
          messageId: 'msg-1',
          userId: 'user-a',
        );

        final doc = await firestore
            .collection(_messagesPath)
            .doc('msg-1')
            .get();
        expect(doc.data()?['status'], equals(MessageStatus.read.name));
      },
    );
  });

  group('MessageMutationModule.markConversationAsRead', () {
    // BUT-1838: the contract CHANGED. It used to hand the whole updated
    // conversation to an injected callback, which resolved to
    // `users/{uid}/conversations/{id}` — a document that exists for no chat
    // group, so a group read receipt landed nowhere and the failure was
    // swallowed. It now writes ONE dotted field to the top-level document,
    // which is also what keeps it clear of the conversations update rule's
    // deny-list (`participantIds`, `createdAt`).
    test(
      'writes the reader stamp to the TOP-LEVEL document, not through the callback',
      () async {
        final firestore = FakeFirebaseFirestore();
        final convo = _twoPersonConvo();

        await firestore.collection('conversations').doc(convo.id).set({
          'participantIds': convo.participantIds,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        });

        final module = _newModule(
          firestore,
          readConversation: (_) async => convo,
        );

        await module.markConversationAsRead(
          conversationId: convo.id,
          userId: 'user-a',
        );

        final stored = await firestore
            .collection('conversations')
            .doc(convo.id)
            .get();
        expect(
          (stored.data()!['lastReadTimestamps'] as Map)['user-a'],
          isNotNull,
          reason: 'lastReadTimestamps must record the reader',
        );
        // The retired user-scoped write seam is not merely unused here — the
        // parameter no longer EXISTS on this method (BUT-1838), so the
        // compiler enforces what this assertion used to.
        // Not merely unchanged in value: the write must not TOUCH the two keys
        // the update rule denies, or it only works while they round-trip
        // byte-identically (BUT-1831).
        expect(
          (stored.data()!['createdAt'] as Timestamp).toDate().isAtSameMomentAs(
            DateTime.utc(2026, 1, 1),
          ),
          isTrue,
        );
      },
    );

    test(
      'throws ResourceNotFoundException when conversation missing',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          readConversation: (_) async => null,
        );

        await expectLater(
          module.markConversationAsRead(
            conversationId: 'missing',
            userId: 'user-a',
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );

    test('throws PermissionDeniedException for non-participants', () async {
      final firestore = FakeFirebaseFirestore();
      final convo = _twoPersonConvo();
      final module = _newModule(
        firestore,
        readConversation: (_) async => convo,
      );

      await expectLater(
        module.markConversationAsRead(
          conversationId: convo.id,
          userId: 'outsider',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('MessageMutationModule.updateMessageContent', () {
    test('flips isEdited and writes new content + editedAt', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'content': 'old',
        'isEdited': false,
      });

      await module.updateMessageContent(
        messageId: 'msg-1',
        newContent: 'new',
      );

      final doc = await firestore.collection(_messagesPath).doc('msg-1').get();
      expect(doc.data()?['content'], equals('new'));
      expect(doc.data()?['isEdited'], isTrue);
      expect(doc.data()?['editedAt'], isNotNull);
    });
  });

  group('MessageMutationModule.deleteMessage', () {
    test('removes the message doc from the messages collection', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({'x': 1});

      await module.deleteMessage('msg-1');

      final doc = await firestore.collection(_messagesPath).doc('msg-1').get();
      expect(doc.exists, isFalse);
    });
  });

  group('MessageMutationModule.batchMarkAsDelivered', () {
    test('flips status + deliveredAt for every supplied message id', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);

      for (final id in ['m-1', 'm-2', 'm-3']) {
        await firestore.collection(_messagesPath).doc(id).set({
          'status': MessageStatus.sending.name,
        });
      }

      await module.batchMarkAsDelivered(
        messageIds: ['m-1', 'm-2', 'm-3'],
        userId: 'user-a',
      );

      for (final id in ['m-1', 'm-2', 'm-3']) {
        final doc = await firestore.collection(_messagesPath).doc(id).get();
        expect(
          doc.data()?['status'],
          equals(MessageStatus.delivered.name),
          reason: 'message $id should be marked delivered',
        );
        expect(doc.data()?['deliveredAt'], isNotNull);
      }
    });
  });

  group('MessageMutationModule.votePoll (BUT-1832)', () {
    // Votes live at `messages/{messageId}/poll_votes/{voterUid}` — one row per
    // voter, doc id == voter — because only a message's SENDER may update the
    // message, so the inline `metadata.poll.options[].voterIds` write was
    // denied for everyone except the poll's own author. The message document is
    // now NEVER touched by a vote, which is what these tests assert first.
    //
    // `FakeFirebaseFirestore.runTransaction` is a no-op passthrough with no
    // isolation and no retry, so nothing here says anything about concurrency;
    // it exercises the read-modify-write shape only.

    Future<Map<String, dynamic>?> voteRow(
      FakeFirebaseFirestore firestore,
      String messageId,
      String voterId,
    ) async {
      final doc = await firestore
          .collection(_messagesPath)
          .doc(messageId)
          .collection('poll_votes')
          .doc(voterId)
          .get();
      return doc.exists ? doc.data() : null;
    }

    Future<void> seedPoll(FakeFirebaseFirestore firestore) =>
        firestore.collection(_messagesPath).doc('msg-1').set({
          'senderId': 'author-uid',
          'metadata': {
            'poll': {
              'options': [
                {'id': 'opt-a', 'voterIds': <String>[]},
                {'id': 'opt-b', 'voterIds': <String>[]},
              ],
            },
          },
        });

    test('writes the voter row and leaves the message untouched', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await seedPoll(firestore);
      final before =
          (await firestore.collection(_messagesPath).doc('msg-1').get()).data();

      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-a',
        voterId: 'user-1',
        allowMultiple: false,
      );

      expect(await voteRow(firestore, 'msg-1', 'user-1'), {
        'voterId': 'user-1',
        'optionIds': ['opt-a'],
        'votedAt': anything,
      });
      // The whole point of the ticket: a vote is not a message update.
      final after =
          (await firestore.collection(_messagesPath).doc('msg-1').get()).data();
      expect(after, equals(before));
    });

    test('the row carries voterId as a FIELD, not only as the doc id', () async {
      // The Art. 17 sweep is `collectionGroup('poll_votes').where('voterId',
      // '==', uid)`. A document id is invisible to any query, so dropping this
      // field would leave the erasure cascade matching nothing — silently.
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await seedPoll(firestore);

      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-a',
        voterId: 'user-1',
        allowMultiple: false,
      );

      final swept = await firestore
          .collection(_messagesPath)
          .doc('msg-1')
          .collection('poll_votes')
          .where('voterId', isEqualTo: 'user-1')
          .get();
      expect(swept.docs.map((d) => d.id), ['user-1']);
    });

    test('each vote lands in its OWN row, keyed by the voter', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await seedPoll(firestore);

      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-a',
        voterId: 'user-1',
        allowMultiple: false,
      );
      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-b',
        voterId: 'user-2',
        allowMultiple: false,
      );

      expect((await voteRow(firestore, 'msg-1', 'user-1'))?['optionIds'], [
        'opt-a',
      ]);
      expect((await voteRow(firestore, 'msg-1', 'user-2'))?['optionIds'], [
        'opt-b',
      ]);
    });

    test('single-choice: a new pick REPLACES the previous one', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await seedPoll(firestore);

      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-a',
        voterId: 'user-1',
        allowMultiple: false,
      );
      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-b',
        voterId: 'user-1',
        allowMultiple: false,
      );

      expect((await voteRow(firestore, 'msg-1', 'user-1'))?['optionIds'], [
        'opt-b',
      ]);
    });

    test(
      'single-choice: re-picking the current option leaves it selected',
      () async {
        // Preserved from the inline implementation, which stripped every option
        // then added back, netting to "stays voted". Not a toggle — asserted
        // here so that making it one is a deliberate act with a red test first.
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await seedPoll(firestore);

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: false,
        );
        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: false,
        );

        expect((await voteRow(firestore, 'msg-1', 'user-1'))?['optionIds'], [
          'opt-a',
        ]);
      },
    );

    test('multi-choice: a second option is added, not replaced', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await seedPoll(firestore);

      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-a',
        voterId: 'user-1',
        allowMultiple: true,
      );
      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-b',
        voterId: 'user-1',
        allowMultiple: true,
      );

      expect((await voteRow(firestore, 'msg-1', 'user-1'))?['optionIds'], [
        'opt-a',
        'opt-b',
      ]);
    });

    test(
      'multi-choice: re-tapping toggles off, and the last one deletes the row',
      () async {
        // An empty row is still a uid on a document every participant reads, so
        // "no selection" must leave nothing behind rather than an empty list.
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await seedPoll(firestore);

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: true,
        );
        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-b',
          voterId: 'user-1',
          allowMultiple: true,
        );
        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: true,
        );

        expect((await voteRow(firestore, 'msg-1', 'user-1'))?['optionIds'], [
          'opt-b',
        ]);

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-b',
          voterId: 'user-1',
          allowMultiple: true,
        );

        expect(await voteRow(firestore, 'msg-1', 'user-1'), isNull);
      },
    );

    test(
      'multi-choice: toggling off a vote that was never cast writes nothing',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await seedPoll(firestore);

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: true,
        );
        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: true,
        );

        expect(await voteRow(firestore, 'msg-1', 'user-1'), isNull);
      },
    );
  });

  group('MessageMutationModule.closePoll', () {
    test(
      'creator can close the poll → isClosed flips, sibling keys survive',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await firestore.collection(_messagesPath).doc('msg-1').set({
          'metadata': {
            'poll': {
              'creatorId': 'user-1',
              'isClosed': false,
              'question': 'Which one?',
            },
          },
        });

        await module.closePoll(messageId: 'msg-1', closerId: 'user-1');

        final doc = await firestore
            .collection(_messagesPath)
            .doc('msg-1')
            .get();
        expect(doc.data()?['metadata']['poll']['isClosed'], isTrue);
        // Sibling keys MUST survive — closePoll is a partial mutation.
        expect(doc.data()?['metadata']['poll']['creatorId'], equals('user-1'));
        expect(
          doc.data()?['metadata']['poll']['question'],
          equals('Which one?'),
        );
      },
    );

    test('non-creator request is a no-op — isClosed stays false', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'metadata': {
          'poll': {
            'creatorId': 'user-1',
            'isClosed': false,
          },
        },
      });

      await module.closePoll(messageId: 'msg-1', closerId: 'user-2');

      final doc = await firestore.collection(_messagesPath).doc('msg-1').get();
      expect(doc.data()?['metadata']['poll']['isClosed'], isFalse);
    });

    test('missing message is a silent no-op', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);

      await expectLater(
        module.closePoll(messageId: 'missing', closerId: 'user-1'),
        completes,
      );
    });
  });
}
