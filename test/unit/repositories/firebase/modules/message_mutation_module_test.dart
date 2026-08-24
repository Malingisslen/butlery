/// Unit tests for MessageMutationModule.
///
/// Targets the sendMessage write module that handles its atomic
/// 3-doc batch + poll mutation. Tests focus on the documented contracts
/// (atomic write, a missing or unreadable conversation, permission gates,
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

    // The SURVIVING happy path, and the assertion that guards the whole
    // feature. The conversations update rule deny-lists `participantIds`,
    // `createdAt`, `memberSince` and `groupId` on any diff, and separately
    // requires `metadata.creatorId` to compare equal before and after. This
    // send stages the conversation as a merge-set carrying
    // `ConversationDto.toFirestore`, so every key that DTO emits is re-sent on
    // every message. They must round-trip byte-identically or the rules refuse
    // the batch — and because the batch is atomic, that takes the message with
    // it.
    //
    // `memberSince` and `groupId` are absent from the assertions below because
    // that DTO does not write them at all; the omission is pinned in
    // `conversation_dto_test.dart`, through the same function this module
    // calls, so re-asserting it here would be a second copy of one decision.
    //
    // No fake can rule on any of this (rules are not modelled here), so this
    // test pins the INPUT half — that the module hands the rules back exactly
    // what it was given. The rules half is pinned on the emulator in
    // `conversations-rules.test.ts`.
    test(
      'the conversation merge-set round-trips createdAt, participantIds and '
      'metadata.creatorId unchanged',
      () async {
        final firestore = FakeFirebaseFirestore();
        final convo = Conversation(
          id: 'direct_user-a_user-b',
          participantIds: const ['user-a', 'user-b'],
          participantDisplayNames: const {'user-a': 'A', 'user-b': 'B'},
          participantAvatarUrls: const {},
          lastReadTimestamps: const {},
          isGroup: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          metadata: const {'creatorId': 'user-a'},
        );
        final module = _newModule(
          firestore,
          readConversation: (id) async => id == convo.id ? convo : null,
        );

        // Sent by the RECIPIENT, because that is the direction the deleted
        // fallback got wrong: it rebuilt the array as [sender, other], the
        // opposite of the stored order, and the deny-list refuses that.
        await module.sendMessage(
          _textMessage(conversationId: convo.id, senderId: 'user-b'),
        );

        final data =
            (await firestore.collection(_convoCollection).doc(convo.id).get())
                .data()!;

        expect(
          data['participantIds'],
          equals(['user-a', 'user-b']),
          reason: 'the STORED creation order, not the sender-first order',
        );
        expect(
          (data['createdAt'] as Timestamp).toDate().toUtc(),
          equals(DateTime.utc(2026, 1, 1)),
          reason: 'a re-stamp here denies every send in this conversation',
        );
        expect(
          (data['metadata'] as Map)['creatorId'],
          equals('user-a'),
          reason:
              'the update rule compares creatorId before and after; the sender '
              'is not the creator and must not become one',
        );
      },
    );

    // BUT-1831 replaced three tests here that pinned a fabricate-a-conversation
    // fallback. They were sound descriptions of what the code did and are gone
    // with it, not weakened: `firestore.rules` refuses that write on both
    // horns, so what they certified is a shape the server declines. The
    // `metadata` invariant they carried has two halves and two homes — the
    // RULES half is C6B (key absent) and C7B (key present, null) in
    // `conversations-rules.test.ts`, which a fake Firestore cannot rule on;
    // the DTO half, that the key is emitted even when the value is null, is
    // `conversation_dto_test.dart`.
    test(
      'throws ResourceNotFoundException when the conversation is ABSENT, and '
      'for a direct_ id too — the id no longer selects a softer path',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          readConversation: (_) async => null,
        );

        await expectLater(
          module.sendMessage(
            _textMessage(
              conversationId: 'direct_user-a_user-b',
              senderId: 'user-a',
            ),
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      },
    );

    test(
      'writes NOTHING when the conversation is absent — the batch is atomic, so '
      'a message must not survive a send that could not name its conversation',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          readConversation: (_) async => null,
        );
        final msg = _textMessage(
          conversationId: 'direct_user-a_user-b',
          senderId: 'user-a',
        );

        await expectLater(
          module.sendMessage(msg),
          throwsA(isA<ResourceNotFoundException>()),
        );

        final convoDoc = await firestore
            .collection(_convoCollection)
            .doc('direct_user-a_user-b')
            .get();
        expect(
          convoDoc.exists,
          isFalse,
          reason: 'no conversation may be materialised by a send',
        );
        expect(
          (await firestore.collection(_messagesPath).doc(msg.id).get()).exists,
          isFalse,
          reason: 'the message must not outlive the refusal that killed it',
        );
      },
    );

    // The other half of the BUT-1831 split, and the one that was the live
    // defect: a read that FAILS is not a read that found nothing.
    test(
      'propagates a FAILING read unchanged, for a direct_ id too — a momentary '
      'failure must not be laundered into "this conversation does not exist"',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          readConversation: (_) async => throw StateError('transient'),
        );

        // `isA<StateError>()`, not merely "it threw": the error must arrive
        // WRAPPED IN NOTHING. `MessageSendErrorMapper.classify` reads the
        // concrete `FirebaseException` to tell a clock-skew denial from
        // anything else, so a repackaging here would silently downgrade every
        // failed send to the generic message.
        await expectLater(
          module.sendMessage(
            _textMessage(
              conversationId: 'direct_user-a_user-b',
              senderId: 'user-a',
            ),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'a failing read on a NON-direct id propagates too — the surviving '
      'ResourceNotFoundException is now the absence signal only',
      () async {
        final firestore = FakeFirebaseFirestore();
        final module = _newModule(
          firestore,
          readConversation: (_) async => throw StateError('transient'),
        );

        await expectLater(
          module.sendMessage(
            _textMessage(conversationId: 'random-uuid-not-direct'),
          ),
          throwsA(isA<StateError>()),
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

    test(
      'BUT-1872: neither thrown exception carries a raw id',
      () async {
        // The exception OBJECT is the one channel AppLogger cannot sanitize —
        // `recordError(error, ...)` masks only the reason string, while
        // `PermissionDeniedException.toString()` prints both `Resource:` and
        // `User:`, and `ResourceNotFoundException.toString()` prints `ID:`.
        // Both throws below are caught by this method's own handler, which
        // logs the exception object at error level.
        //
        // Two assertions per throw, because the two fields were masked in
        // separate passes: the conversation id was caught by one reviewer and
        // the uid by another, a line apart, in the same hunk.
        //
        // Since BUT-1897 the exception CLASS masks inside its own `toString()`,
        // so the id assertions below no longer discriminate the throw site's
        // `.maskedConversationId` on their own — the class rule would hold them
        // up anyway. Nor does the `outsider` assertion — a bare uid passed as
        // `userId:` is masked by the class rule too, measured: deleting
        // `.maskedUserId` from the throw site leaves this suite green.
        //
        // The one-segment check at the end of this test is the ONLY assertion
        // here that pins a per-site call, because the class rule's composite
        // pattern needs TWO segments and cannot hash `direct_abc`.
        const uidA = 'aBcDeFgHiJkLmNoPqRsTuVwXyZ12';
        const uidB = 'zZyYxXwWvVuUtTsSrRqQpPoO3456';
        const directId = 'direct_${uidA}_$uidB';
        const outsider = 'qQwWeErRtTyYuUiIoOpP12345678';

        Future<String> renderedThrowFrom(Future<void> Function() op) async {
          try {
            await op();
          } catch (e) {
            return e.toString();
          }
          throw StateError('expected a throw');
        }

        final missing = await renderedThrowFrom(
          () =>
              _newModule(
                FakeFirebaseFirestore(),
                readConversation: (_) async => null,
              ).markConversationAsRead(
                conversationId: directId,
                userId: outsider,
              ),
        );
        expect(missing, isNot(contains(uidA)));
        expect(missing, isNot(contains(uidB)));
        expect(missing, contains('direct_#'));

        final convo = _twoPersonConvo();
        final denied = await renderedThrowFrom(
          () =>
              _newModule(
                FakeFirebaseFirestore(),
                readConversation: (_) async => convo,
              ).markConversationAsRead(
                conversationId: directId,
                userId: outsider,
              ),
        );
        expect(denied, isNot(contains(uidA)));
        expect(denied, isNot(contains(uidB)));
        expect(
          denied,
          isNot(contains(outsider)),
          reason:
              'the CALLER uid too — it rode in on `userId:` for a week '
              'after the conversation id beside it was masked',
        );
        expect(denied, contains('direct_#'));

        // The discriminating half. A one-segment `direct_` id is hashed by
        // `maskConversationId` at the throw site and NOT by the class-level
        // rule, which matches two segments — so this is what reddens if the
        // per-site masking is removed.
        final shortId = await renderedThrowFrom(
          () =>
              _newModule(
                FakeFirebaseFirestore(),
                readConversation: (_) async => null,
              ).markConversationAsRead(
                conversationId: 'direct_abc',
                userId: outsider,
              ),
        );
        expect(
          shortId,
          contains('direct_#'),
          reason:
              'a one-segment id is masked only by the throw site, so this is '
              'what proves the per-site call is still there',
        );
      },
    );
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
