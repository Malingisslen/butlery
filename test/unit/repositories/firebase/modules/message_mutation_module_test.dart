/// Unit tests for MessageMutationModule.
///
/// Targets the sendMessage write module that handles its atomic
/// batch. Tests focus on the documented contracts rather than
/// method-call presence. The poll writes reached here delegate to
/// [MessagePollMutationModule]; exercising them through this seam is
/// deliberate, because that delegation is what the callers see.
// ignore_for_file: subtype_of_sealed_class
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/pending_image_status.dart';
import 'package:butlery/repositories/firebase/modules/message_mutation_module.dart';

class _MockMessages extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockMessageRef extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshotMetadata extends Mock implements SnapshotMetadata {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

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
      'atomically writes message + conversation update, with no rate-limit stamp',
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

        // 3. No rate-limit stamp: messages carry no burst guard, because
        //    queued offline sends replay back to back and a guard refuses all
        //    but the first.
        final rateLimits = await firestore
            .collection('users')
            .doc(msg.senderId)
            .collection('rate_limits')
            .get();
        expect(rateLimits.docs, isEmpty);
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
        // Two different masks meet on these objects, and the assertions are
        // split to match. Since BUT-1897 the exception CLASS masks inside its
        // own `toString()`, so every rendered-string assertion below holds
        // whether or not the throw site masks — that half pins what leaves the
        // device, not what the throw site did. The FIELDS are deliberately left
        // unmasked by the class, keeping whatever the caller passed, so a
        // hashed `resource` and a truncated `userId` can only come from the
        // throw site's own `.maskedConversationId` / `.maskedUserId`. Those are
        // the discriminating assertions, and they discriminate on the live
        // `direct_<uidA>_<uidB>` shape (BUT-1913).
        const uidA = 'aBcDeFgHiJkLmNoPqRsTuVwXyZ12';
        const uidB = 'zZyYxXwWvVuUtTsSrRqQpPoO3456';
        const directId = 'direct_${uidA}_$uidB';
        const outsider = 'qQwWeErRtTyYuUiIoOpP12345678';

        Future<Object> throwFrom(Future<void> Function() op) async {
          try {
            await op();
          } catch (e) {
            return e;
          }
          throw StateError('expected a throw');
        }

        final missing = await throwFrom(
          () =>
              _newModule(
                FakeFirebaseFirestore(),
                readConversation: (_) async => null,
              ).markConversationAsRead(
                conversationId: directId,
                userId: outsider,
              ),
        );
        final missingRendered = missing.toString();
        expect(missingRendered, isNot(contains(uidA)));
        expect(missingRendered, isNot(contains(uidB)));
        expect(missingRendered, contains('direct_#'));
        expect(
          (missing as ResourceNotFoundException).resourceId,
          contains('direct_#'),
          reason:
              'the field survives the class mask untouched, so a hashed '
              'resourceId is what proves this throw site still masks',
        );

        final convo = _twoPersonConvo();
        final denied = await throwFrom(
          () =>
              _newModule(
                FakeFirebaseFirestore(),
                readConversation: (_) async => convo,
              ).markConversationAsRead(
                conversationId: directId,
                userId: outsider,
              ),
        );
        final deniedRendered = denied.toString();
        expect(deniedRendered, isNot(contains(uidA)));
        expect(deniedRendered, isNot(contains(uidB)));
        expect(
          deniedRendered,
          isNot(contains(outsider)),
          reason:
              'the CALLER uid too — it rode in on `userId:` for a week '
              'after the conversation id beside it was masked',
        );
        expect(deniedRendered, contains('direct_#'));

        // The discriminating half: the raw fields, which no class-level
        // `toString()` mask can reach.
        final deniedException = denied as PermissionDeniedException;
        expect(deniedException.resource, isNot(contains(uidA)));
        expect(deniedException.resource, isNot(contains(uidB)));
        expect(
          deniedException.resource,
          contains('direct_#'),
          reason:
              'a hashed field can only come from the throw site, so this is '
              'what proves the per-site call is still there',
        );
        expect(
          deniedException.userId,
          isNotNull,
          reason:
              'the negative assertion below is vacuous on a null field, and '
              'this throw site does populate it',
        );
        expect(
          deniedException.userId,
          isNot(contains(outsider)),
          reason:
              'the uid field is untouched by the class mask, so this is what '
              'reddens if `.maskedUserId` leaves the throw site',
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

    // BUT-1925. The answer is what `MessagingService.closePoll` writes the
    // weekly plan on, so each of these four is a branch of the plan write too.
    //
    // What these CANNOT show: that two concurrent closers serialise.
    // `fake_cloud_firestore.runTransaction` is a passthrough with no
    // isolation, so the second close here is sequential — it reads the flag
    // the first one wrote, which is the branch under test.
    test('the creator closing an OPEN poll is told it was this call', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'metadata': {
          'poll': {'creatorId': 'user-1', 'isClosed': false},
        },
      });

      expect(
        await module.closePoll(messageId: 'msg-1', closerId: 'user-1'),
        isTrue,
      );
    });

    test('a second close of the same poll answers false', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'metadata': {
          'poll': {'creatorId': 'user-1', 'isClosed': false},
        },
      });

      await module.closePoll(messageId: 'msg-1', closerId: 'user-1');

      expect(
        await module.closePoll(messageId: 'msg-1', closerId: 'user-1'),
        isFalse,
      );
    });

    test('a non-creator is told it was not this call', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'metadata': {
          'poll': {'creatorId': 'user-1', 'isClosed': false},
        },
      });

      expect(
        await module.closePoll(messageId: 'msg-1', closerId: 'user-2'),
        isFalse,
      );
    });

    test('a missing message answers false', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);

      expect(
        await module.closePoll(messageId: 'missing', closerId: 'user-1'),
        isFalse,
      );
    });
  });

  group('chat image placeholder (BUT-2294)', () {
    Future<MessageMutationModule> withPlaceholder(
      FakeFirebaseFirestore firestore, {
      String senderId = 'user-a',
      Map<String, dynamic> metadata = const {'pendingImage': true},
    }) async {
      await firestore.collection(_messagesPath).doc('msg-1').set({
        'senderId': senderId,
        'type': 'image',
        'content': '',
        'metadata': metadata,
      });
      return _newModule(firestore);
    }

    test('an empty placeholder of the sender is waiting', () async {
      final module = await withPlaceholder(FakeFirebaseFirestore());

      final status = await module.pendingImageStatus(
        conversationId: 'conv-1',
        messageId: 'msg-1',
        userId: 'user-a',
      );

      expect(status.state, PendingImageState.waiting);
    });

    test('a placeholder with a picture is filled and names it', () async {
      final module = await withPlaceholder(
        FakeFirebaseFirestore(),
        metadata: {'imageUrl': 'https://img/1.jpg'},
      );

      final status = await module.pendingImageStatus(
        conversationId: 'conv-1',
        messageId: 'msg-1',
        userId: 'user-a',
      );

      expect(status.state, PendingImageState.filled);
      expect(status.imageUrl, 'https://img/1.jpg');
    });

    test('an empty picture address still counts as waiting', () async {
      final module = await withPlaceholder(
        FakeFirebaseFirestore(),
        metadata: {'imageUrl': ''},
      );

      final status = await module.pendingImageStatus(
        conversationId: 'conv-1',
        messageId: 'msg-1',
        userId: 'user-a',
      );

      expect(status.state, PendingImageState.waiting);
    });

    test('another sender\'s message is not the caller\'s to fill', () async {
      final module = await withPlaceholder(
        FakeFirebaseFirestore(),
        senderId: 'user-b',
      );

      final status = await module.pendingImageStatus(
        conversationId: 'conv-1',
        messageId: 'msg-1',
        userId: 'user-a',
      );

      expect(status.state, PendingImageState.notMine);
    });

    test(
      'a message neither on the server nor in the cache is absent',
      () async {
        final module = _newModule(FakeFirebaseFirestore());

        final status = await module.pendingImageStatus(
          conversationId: 'conv-1',
          messageId: 'missing',
          userId: 'user-a',
        );

        expect(status.state, PendingImageState.absent);
      },
    );

    test('attaching sets the picture, clears the mark and leaves the rest '
        'of the message', () async {
      final firestore = FakeFirebaseFirestore();
      final module = await withPlaceholder(firestore);

      await module.attachPendingImage(
        messageId: 'msg-1',
        imageUrl: 'https://img/1.jpg',
      );

      final data =
          (await firestore.collection(_messagesPath).doc('msg-1').get())
              .data()!;
      expect(data['metadata'], {'imageUrl': 'https://img/1.jpg'});
      expect(data['senderId'], 'user-a');
      expect(data['type'], 'image');
    });

    test('attaching to a message that is gone fails instead of creating '
        'one', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _newModule(firestore);

      await expectLater(
        module.attachPendingImage(
          messageId: 'missing',
          imageUrl: 'https://img/1.jpg',
        ),
        throwsA(isA<FirebaseException>()),
      );
      expect(
        (await firestore.collection(_messagesPath).doc('missing').get()).exists,
        isFalse,
      );
    });
  });

  group('chat image placeholder the server will not let the caller read '
      '(BUT-2294)', () {
    // The messages read rule dereferences the stored message, so for a message
    // the server does not have, the server answers permission-denied.
    MessageMutationModule moduleWhereServerRefuses({
      String serverCode = 'permission-denied',
      bool pendingInCache = false,
      bool cached = false,
      required Future<Conversation?> Function(String) readConversation,
    }) {
      final messages = _MockMessages();
      final ref = _MockMessageRef();
      when(() => messages.doc('msg-1')).thenReturn(ref);
      when(() => ref.get(any())).thenAnswer((invocation) async {
        final options = invocation.positionalArguments.single as GetOptions;
        if (options.source == Source.server) {
          throw FirebaseException(plugin: 'cloud_firestore', code: serverCode);
        }
        if (!cached) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        final snapshot = _MockSnapshot();
        when(() => snapshot.exists).thenReturn(true);
        final metadata = _MockSnapshotMetadata();
        when(() => metadata.hasPendingWrites).thenReturn(pendingInCache);
        when(() => snapshot.metadata).thenReturn(metadata);
        return snapshot;
      });
      return MessageMutationModule(
        firestore: FakeFirebaseFirestore(),
        collectionName: _convoCollection,
        messagesRef: messages,
        readConversation: readConversation,
      );
    }

    Future<PendingImageStatus> ask(MessageMutationModule module) =>
        module.pendingImageStatus(
          messageId: 'msg-1',
          userId: 'user-a',
          conversationId: 'conv-1',
        );

    test('a placeholder still in Firestore\'s own queue is writePending, '
        'without asking the conversation', () async {
      var asked = false;
      final module = moduleWhereServerRefuses(
        cached: true,
        pendingInCache: true,
        readConversation: (_) async {
          asked = true;
          return _twoPersonConvo();
        },
      );

      expect((await ask(module)).state, PendingImageState.writePending);
      expect(asked, isFalse);
    });

    test('a member of the conversation whose message never arrived is '
        'absent', () async {
      final module = moduleWhereServerRefuses(
        readConversation: (_) async => _twoPersonConvo(),
      );

      expect((await ask(module)).state, PendingImageState.absent);
    });

    test('a conversation that is gone leaves the message absent', () async {
      final module = moduleWhereServerRefuses(
        readConversation: (_) async => null,
      );

      expect((await ask(module)).state, PendingImageState.absent);
    });

    test('a caller no longer in the conversation gets the refusal', () async {
      final module = moduleWhereServerRefuses(
        readConversation: (_) async => _twoPersonConvo(userA: 'user-x'),
      );

      await expectLater(
        ask(module),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    });

    test('a server that cannot be reached is not mistaken for a missing '
        'message', () async {
      final module = moduleWhereServerRefuses(
        serverCode: 'unavailable',
        readConversation: (_) async => _twoPersonConvo(),
      );

      await expectLater(
        ask(module),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
    });

    test('a conversation that cannot be read is not mistaken for a '
        'missing message', () async {
      final module = moduleWhereServerRefuses(
        readConversation: (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );

      await expectLater(ask(module), throwsA(isA<FirebaseException>()));
    });
  });
}
