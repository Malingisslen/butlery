/// Unit tests for ConversationQueryModule, one group per public read path.
///
/// Five of them: the user-conversations stream, the single-doc read, the
/// participants accessor, the unread-message count, and the unread-conversations
/// count.
///
/// No read path consults a `ConversationParticipantModule`.
/// The unread-conversations count reads the conversations themselves, which is
/// what the last two tests in that group hold in place — one where a READ
/// conversation must not be counted, one where a GROUP must be.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/modules/conversation_query_module.dart';

const _convoCollection = 'conversations';
const _userId = 'alice';

/// Test-only fromFirestore that pulls every Conversation field we care
/// about from a flat doc map.
Conversation _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Conversation(
    id: doc.id,
    participantIds: List<String>.from(data['participantIds'] ?? const []),
    participantDisplayNames: const {},
    participantAvatarUrls: const {},
    lastMessage: data['lastMessage'] is Map
        ? Message(
            id: 'msg',
            conversationId: doc.id,
            senderId: (data['lastMessage'] as Map)['senderId'] as String? ?? '',
            senderDisplayName: '',
            content: '',
            type: MessageType.text,
            status: MessageStatus.sent,
            sentAt: ((data['lastMessage'] as Map)['sentAt'] as Timestamp)
                .toDate(),
          )
        : null,
    lastReadTimestamps: ((data['lastReadTimestamps'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, (v as Timestamp).toDate()),
    ),
    isGroup: data['isGroup'] as bool? ?? false,
    createdAt:
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.utc(2026, 1, 1),
    updatedAt:
        (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.utc(2026, 1, 1),
  );
}

Future<void> _seedConvo(
  FakeFirebaseFirestore firestore, {
  required String id,
  required List<String> participants,
  required DateTime updatedAt,
  DateTime? lastMessageAt,
  String? lastMessageSender,
  Map<String, DateTime>? lastReads,
  bool isGroup = false,
}) async {
  await firestore.collection(_convoCollection).doc(id).set({
    'participantIds': participants,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdAt': Timestamp.fromDate(updatedAt),
    'isGroup': isGroup,
    if (lastMessageAt != null)
      'lastMessage': {
        'senderId': lastMessageSender ?? participants.first,
        'sentAt': Timestamp.fromDate(lastMessageAt),
      },
    if (lastReads != null)
      'lastReadTimestamps': lastReads.map(
        (k, v) => MapEntry(k, Timestamp.fromDate(v)),
      ),
  });
}

ConversationQueryModule _module(FakeFirebaseFirestore firestore) {
  return ConversationQueryModule(
    firestore: firestore,
    collectionName: _convoCollection,
    fromFirestore: _fromFirestore,
  );
}

void main() {
  group('getUserConversations (stream)', () {
    test('emits only conversations the user participates in', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedConvo(
        firestore,
        id: 'c1',
        participants: [_userId, 'bob'],
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await _seedConvo(
        firestore,
        id: 'c2',
        participants: ['carol', 'bob'],
        updatedAt: DateTime.utc(2026, 1, 3),
      );

      final list = await _module(firestore).getUserConversations(_userId).first;
      expect(list.map((c) => c.id), ['c1']);
    });

    test('emits empty list when user has no conversations', () async {
      final firestore = FakeFirebaseFirestore();
      final list = await _module(firestore).getUserConversations(_userId).first;
      expect(list, isEmpty);
    });

    test('sorted by updatedAt descending', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedConvo(
        firestore,
        id: 'old',
        participants: [_userId],
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await _seedConvo(
        firestore,
        id: 'new',
        participants: [_userId],
        updatedAt: DateTime.utc(2026, 1, 5),
      );
      await _seedConvo(
        firestore,
        id: 'mid',
        participants: [_userId],
        updatedAt: DateTime.utc(2026, 1, 3),
      );

      final list = await _module(firestore).getUserConversations(_userId).first;
      expect(list.map((c) => c.id), ['new', 'mid', 'old']);
    });
  });

  // BUT-1838/BUT-1795. Both accessors below used to delegate to `readFn` and
  // were tested through it. `readFn` is `BaseFirebaseRepository.read`, and
  // `FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`,
  // which rewrites every path to `users/{uid}/conversations/{id}` — while a
  // chat group's conversation is written ONLY at the top level, by
  // `createChatGroup` under the Admin SDK. So `readFn` answered null for every
  // group, for everyone, and a null conversation means a null `memberSince`
  // cut-off, an unfiltered message query, and a query `firestore.rules`
  // refuses IN FULL for anyone who joined late. A group chat rendered an
  // error instead of its history.
  //
  // The retired `readFn` parameter is GONE from the signature, so the seam
  // cannot be consulted at all — the compiler enforces what a decoy fixture
  // used to. What remains worth asserting is that these read the TOP-LEVEL
  // document, which is the half that broke every group chat.
  group('getConversation', () {
    test(
      'reads the TOP-LEVEL document — the one the group callables write, and '
      'the read whose absence broke every group chat',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seedConvo(
          firestore,
          id: 'c1',
          participants: const [_userId, 'bob'],
          updatedAt: DateTime.utc(2026, 1, 1),
        );

        final result = await _module(
          firestore,
        ).getConversation('c1');

        expect(result, isNotNull);
        expect(result!.id, 'c1');
        expect(result.participantIds, [_userId, 'bob']);
      },
    );

    test(
      'the top-level document WINS over one at the user-scoped path',
      () async {
        // The seam this test used to stage is gone from the signature, so an
        // in-memory decoy `Conversation` could no longer reach the module at all
        // and asserting the result differed from it had become unfailable. What
        // CAN still fail is the path: seed the RETIRED location as a trap, in
        // the same run, so a revert to a user-scoped read — the shape of the bug
        // — returns the wrong participants instead of quietly returning the
        // right ones for the wrong reason.
        final firestore = FakeFirebaseFirestore();
        await _seedConvo(
          firestore,
          id: 'c1',
          participants: const [_userId, 'bob'],
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        await firestore
            .collection('users')
            .doc(_userId)
            .collection(_convoCollection)
            .doc('c1')
            .set({
              'participantIds': const ['someone-else-entirely'],
              'updatedAt': Timestamp.fromDate(DateTime.utc(2020, 1, 1)),
              'createdAt': Timestamp.fromDate(DateTime.utc(2020, 1, 1)),
              'isGroup': false,
            });

        final result = await _module(
          firestore,
        ).getConversation('c1');

        expect(result!.participantIds, [_userId, 'bob']);
        expect(result.participantIds, isNot(contains('someone-else-entirely')));
      },
    );

    // A "readFn is never invoked" case stood here. The parameter is DELETED
    // now, so the compiler enforces it — strictly stronger than a counter.

    test('returns null when the top-level document does not exist', () async {
      // Absence answers null. So does a DENIED read: the catch below logs and
      // returns null too, so this method deliberately flattens both to the same
      // answer and a caller cannot tell them apart. That is the opposite of
      // `ChatGroupRepository.getGroup`, which rethrows a denial on purpose —
      // do not import that contract here by reading this test's name as one.
      final firestore = FakeFirebaseFirestore();

      final result = await _module(
        firestore,
      ).getConversation('missing');

      expect(result, isNull);
    });
  });

  group('getConversationParticipants', () {
    test('returns participantIds from the TOP-LEVEL document', () async {
      // Same repoint: this delegates to getConversation, so it inherits the
      // top-level read. Previously it seeded ONLY the retired `readFn` seam,
      // so it measured that seam and returned [] the moment production
      // stopped calling it.
      final firestore = FakeFirebaseFirestore();
      await _seedConvo(
        firestore,
        id: 'c1',
        participants: const ['alice', 'bob', 'carol'],
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final ids = await _module(
        firestore,
      ).getConversationParticipants('c1');

      expect(ids, ['alice', 'bob', 'carol']);
    });

    test('returns empty list when the conversation does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final ids = await _module(
        firestore,
      ).getConversationParticipants('missing');
      expect(ids, isEmpty);
    });

    // A "a throwing readFn is inert" case stood here. It is gone because the
    // PARAMETER is gone (BUT-1838): the compiler now enforces what that test
    // asserted, which is strictly stronger than a fixture. Recorded rather than
    // deleted silently, so nobody re-adds the seam to "restore coverage".
  });

  group('getUnreadMessageCount', () {
    test('counts only conversations with unread messages', () async {
      final firestore = FakeFirebaseFirestore();
      // c1: has a newer message than user's lastReadTimestamps → unread
      await _seedConvo(
        firestore,
        id: 'c1',
        participants: [_userId, 'bob'],
        updatedAt: DateTime.utc(2026, 1, 5),
        lastMessageAt: DateTime.utc(2026, 1, 5),
        lastReads: {_userId: DateTime.utc(2026, 1, 1)},
      );
      // c2: lastRead is after lastMessage → read
      await _seedConvo(
        firestore,
        id: 'c2',
        participants: [_userId, 'bob'],
        updatedAt: DateTime.utc(2026, 1, 4),
        lastMessageAt: DateTime.utc(2026, 1, 2),
        lastReads: {_userId: DateTime.utc(2026, 1, 3)},
      );
      // c3: no lastMessage → not unread
      await _seedConvo(
        firestore,
        id: 'c3',
        participants: [_userId, 'bob'],
        updatedAt: DateTime.utc(2026, 1, 3),
      );

      final count = await _module(firestore).getUnreadMessageCount(_userId);
      expect(count, 1);
    });

    test('returns 0 when user has no conversations', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _module(firestore).getUnreadMessageCount(_userId), 0);
    });
  });

  group('getUnreadConversationsCount', () {
    test(
      'counts unread conversations when no participant module is wired',
      () async {
        final firestore = FakeFirebaseFirestore();
        await _seedConvo(
          firestore,
          id: 'c1',
          participants: [_userId, 'bob'],
          updatedAt: DateTime.utc(2026, 1, 5),
          lastMessageAt: DateTime.utc(2026, 1, 5),
          lastReads: {_userId: DateTime.utc(2026, 1, 1)},
        );
        await _seedConvo(
          firestore,
          id: 'c2',
          participants: [_userId, 'bob'],
          updatedAt: DateTime.utc(2026, 1, 4),
          lastMessageAt: DateTime.utc(2026, 1, 4),
          lastReads: {_userId: DateTime.utc(2026, 1, 1)},
        );
        await _seedConvo(
          firestore,
          id: 'c3',
          participants: [_userId, 'bob'],
          updatedAt: DateTime.utc(2026, 1, 3),
        );
        // Somebody else's unread conversation. Without it every fixture in this
        // file sits in ONE scope, and deleting the
        // `where('participantIds', arrayContains: userId)` clause is green
        // across the whole suite — `hasUnreadMessages` asks nothing about
        // membership, and a stranger's chat has no `lastReadTimestamps` entry
        // for this user, which that method reads as UNREAD. Measured: dropping
        // the clause returns 3 here and the correct answer in every other
        // fixture in this group.
        await _seedConvo(
          firestore,
          id: 'not-mine',
          participants: ['bob', 'carol'],
          updatedAt: DateTime.utc(2026, 1, 6),
          lastMessageAt: DateTime.utc(2026, 1, 6),
          lastReads: {'bob': DateTime.utc(2026, 1, 1)},
        );

        final count = await _module(
          firestore,
        ).getUnreadConversationsCount(_userId);
        expect(count, 2);
      },
    );

    test('returns 0 when no conversations exist', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _module(firestore).getUnreadConversationsCount(_userId), 0);
    });

    test('a conversation the user has already read is not counted', () async {
      // Two unread conversations and one READ one. The read conversation is
      // what makes the assertion discriminating: without it the answer equals
      // the number of conversations, so a count that ignores lastReadTimestamps
      // passes.
      final firestore = FakeFirebaseFirestore();

      for (final id in ['c1', 'c2']) {
        await _seedConvo(
          firestore,
          id: id,
          participants: [_userId, 'bob'],
          updatedAt: DateTime.utc(2026, 1, 5),
          lastMessageAt: DateTime.utc(2026, 1, 5),
          lastReads: {_userId: DateTime.utc(2026, 1, 1)},
        );
      }
      await _seedConvo(
        firestore,
        id: 'c3',
        participants: [_userId, 'bob'],
        updatedAt: DateTime.utc(2026, 1, 4),
        lastMessageAt: DateTime.utc(2026, 1, 2),
        lastReads: {_userId: DateTime.utc(2026, 1, 3)},
      );

      expect(await _module(firestore).getUnreadConversationsCount(_userId), 2);
    });

    test('a group conversation is counted like any other', () async {
      // BUT-1838 writes a group conversation without any per-user index row,
      // so a counter keyed on anything but the conversation itself answers 0
      // for a user whose only unread chat is a group.
      //
      // `isGroup: true` makes the fixture the thing its name claims. The
      // counter reads neither `isGroup` nor `groupId`, so the flag is
      // documentation, not a kill — a future branch keyed on group-ness would
      // need its own test.
      final firestore = FakeFirebaseFirestore();

      await _seedConvo(
        firestore,
        id: 'direct',
        participants: [_userId, 'bob'],
        updatedAt: DateTime.utc(2026, 1, 2),
        lastMessageAt: DateTime.utc(2026, 1, 2),
        lastReads: {_userId: DateTime.utc(2026, 1, 3)},
      );
      await _seedConvo(
        firestore,
        id: 'group',
        participants: [_userId, 'bob', 'cecilia'],
        updatedAt: DateTime.utc(2026, 1, 5),
        lastMessageAt: DateTime.utc(2026, 1, 5),
        lastReads: {_userId: DateTime.utc(2026, 1, 1)},
        isGroup: true,
      );

      expect(await _module(firestore).getUnreadConversationsCount(_userId), 1);
    });
  });
}
