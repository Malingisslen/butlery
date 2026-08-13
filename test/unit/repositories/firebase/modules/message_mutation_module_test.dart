/// Unit tests for MessageMutationModule.
///
/// Targets the sendMessage write module that handles its atomic
/// 3-doc batch + poll mutation. Tests focus on the documented contracts
/// (atomic write, fallback conversation construction, permission gates,
/// poll vote toggling) rather than method-call presence.
library;

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
        // `firestore.rules`' conversations CREATE rule reads
        // `'creatorId' in request.resource.data.metadata`. An `in` on a null is
        // an evaluation error, which denies — and that denial is the only thing
        // stopping a NON-CREATOR from materialising a group's top-level
        // conversation document by sending its first message. If it landed,
        // `enforceGroupMinorMembership` would return early on it — this payload
        // trips BOTH halves of its guard (`isGroup: false` AND at most two
        // participants — the squat payload this is about carries one);
        // a false flag alone does NOT return early when there are more than two
        // — and `onDocumentCreated` cannot fire twice, so the child-safety cut
        // that evicts a minor added by a non-friend would never run for that
        // group at all.
        //
        // Two well-intentioned edits would each disarm that, and the rules-side
        // test (C7B in conversations-rules.test.ts) stays green through both:
        //   1. stamping `metadata: {'creatorId': senderId}` here — the key stops
        //      being null, so the `in` succeeds and the create is ALLOWED;
        //   2. making `ConversationDto.toFirestore` skip a null metadata (the
        //      standard "don't write nulls" cleanup) — the key disappears, the
        //      rule's `!('metadata' in ...)` disjunct becomes true, and the
        //      create is ALLOWED.
        // The first assertion below catches (2); the second catches (1) — that
        // way round, and it is worth stating because getting it backwards is
        // how the load-bearing one gets deleted. Under (1) the KEY is still
        // present, so `containsKey` does not fire; under (2) the key is absent
        // and `data()['metadata']` returns null, so `isNull` passes VACUOUSLY.
        // Neither assertion covers for the other. Measured, not reasoned: each
        // mutant reddens exactly one of them.
        //
        // NOTE this is not a security bound — it binds our own client, not a
        // tampered one (BUT-1830). It is the invariant our writer must keep.
        //
        // AND: green here is the FAKE, not production. This exact payload is
        // refused twice over against the real rules — as a create (the `in` on
        // null above) when the document is absent, and as an update when it
        // exists, because the DTO re-stamps `createdAt` and the update rule
        // pins that key. So a DM send fails today (BUT-1831). Do not read this
        // passing test as proof the fallback works, and do not "fix" BUT-1831
        // by stamping a creatorId here — that is mutant (1).
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
    test(
      'updates lastReadTimestamps for the participant via updateConversation cb',
      () async {
        final firestore = FakeFirebaseFirestore();
        final convo = _twoPersonConvo();
        Conversation? captured;

        final module = _newModule(
          firestore,
          readConversation: (_) async => convo,
        );

        await module.markConversationAsRead(
          conversationId: convo.id,
          userId: 'user-a',
          updateConversation: (updated) async {
            captured = updated;
          },
        );

        expect(captured, isNotNull);
        expect(
          captured!.lastReadTimestamps.containsKey('user-a'),
          isTrue,
          reason: 'lastReadTimestamps must record the reader',
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
            updateConversation: (_) async {},
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
          updateConversation: (_) async {},
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

  group('MessageMutationModule.votePoll', () {
    test('adds a voter to the target option (single-choice)', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'metadata': {
          'poll': {
            'options': [
              {'id': 'opt-a', 'voterIds': <String>[]},
              {'id': 'opt-b', 'voterIds': <String>[]},
            ],
          },
        },
      });

      await module.votePoll(
        messageId: 'msg-1',
        optionId: 'opt-a',
        voterId: 'user-1',
        allowMultiple: false,
      );

      final doc = await firestore.collection(_messagesPath).doc('msg-1').get();
      final opts = (doc.data()?['metadata']['poll']['options'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        opts.firstWhere((o) => o['id'] == 'opt-a')['voterIds'],
        equals(['user-1']),
      );
      expect(opts.firstWhere((o) => o['id'] == 'opt-b')['voterIds'], isEmpty);
    });

    test(
      'multi-choice: second vote on the SAME option toggles the vote off',
      () async {
        // Single-choice runs strip-then-add and net-zeros to "user stays
        // voted" on a same-option re-vote (see the strip-all-options branch
        // in votePoll). The honest toggle-off contract lives on the
        // multi-choice path, which skips the strip.
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await firestore.collection(_messagesPath).doc('msg-1').set({
          'metadata': {
            'poll': {
              'options': [
                {
                  'id': 'opt-a',
                  'voterIds': <String>['user-1'],
                },
              ],
            },
          },
        });

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: true,
        );

        final doc = await firestore
            .collection(_messagesPath)
            .doc('msg-1')
            .get();
        final opts = (doc.data()?['metadata']['poll']['options'] as List)
            .cast<Map<String, dynamic>>();
        expect(opts.first['voterIds'], isEmpty);
      },
    );

    test(
      'single-choice: re-vote on already-selected option is a no-op '
      '(strip-then-add nets to staying voted)',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await firestore.collection(_messagesPath).doc('msg-1').set({
          'metadata': {
            'poll': {
              'options': [
                {
                  'id': 'opt-a',
                  'voterIds': <String>['user-1'],
                },
              ],
            },
          },
        });

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: false,
        );

        final doc = await firestore
            .collection(_messagesPath)
            .doc('msg-1')
            .get();
        final opts = (doc.data()?['metadata']['poll']['options'] as List)
            .cast<Map<String, dynamic>>();
        expect(opts.first['voterIds'], equals(['user-1']));
      },
    );

    test(
      'single-choice vote removes user from previous option before adding new',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await firestore.collection(_messagesPath).doc('msg-1').set({
          'metadata': {
            'poll': {
              'options': [
                {
                  'id': 'opt-a',
                  'voterIds': <String>['user-1'],
                },
                {'id': 'opt-b', 'voterIds': <String>[]},
              ],
            },
          },
        });

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-b',
          voterId: 'user-1',
          allowMultiple: false,
        );

        final doc = await firestore
            .collection(_messagesPath)
            .doc('msg-1')
            .get();
        final opts = (doc.data()?['metadata']['poll']['options'] as List)
            .cast<Map<String, dynamic>>();
        expect(opts.firstWhere((o) => o['id'] == 'opt-a')['voterIds'], isEmpty);
        expect(
          opts.firstWhere((o) => o['id'] == 'opt-b')['voterIds'],
          equals(['user-1']),
        );
      },
    );

    test(
      'multi-choice vote leaves the previous option intact',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(firestore);
        await firestore.collection(_messagesPath).doc('msg-1').set({
          'metadata': {
            'poll': {
              'options': [
                {
                  'id': 'opt-a',
                  'voterIds': <String>['user-1'],
                },
                {'id': 'opt-b', 'voterIds': <String>[]},
              ],
            },
          },
        });

        await module.votePoll(
          messageId: 'msg-1',
          optionId: 'opt-b',
          voterId: 'user-1',
          allowMultiple: true,
        );

        final doc = await firestore
            .collection(_messagesPath)
            .doc('msg-1')
            .get();
        final opts = (doc.data()?['metadata']['poll']['options'] as List)
            .cast<Map<String, dynamic>>();
        expect(
          opts.firstWhere((o) => o['id'] == 'opt-a')['voterIds'],
          equals(['user-1']),
        );
        expect(
          opts.firstWhere((o) => o['id'] == 'opt-b')['voterIds'],
          equals(['user-1']),
        );
      },
    );

    test('silently no-ops when message does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);

      // The transaction returns early without writing; just assert no throw.
      await expectLater(
        module.votePoll(
          messageId: 'missing',
          optionId: 'opt-a',
          voterId: 'user-1',
          allowMultiple: false,
        ),
        completes,
      );
    });
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
