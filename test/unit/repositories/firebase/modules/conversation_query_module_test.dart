/// Unit tests for ConversationQueryModule (legacy / non-inverse-index paths).
///
/// The module exposes five read paths over the conversations collection.
/// Tests target the legacy arrayContains-based paths that fire when no
/// `ConversationParticipantModule` is wired up (or when the inverse-index
/// returns empty): the user-conversations stream, the single-doc read,
/// the participants accessor, the unread-message count, and the unread-
/// conversations count.
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
}) async {
  await firestore.collection(_convoCollection).doc(id).set({
    'participantIds': participants,
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdAt': Timestamp.fromDate(updatedAt),
    'isGroup': false,
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
    // participantModule deliberately null → all calls fall through to
    // legacy arrayContains paths.
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
      // Absence is the answer, so callers can tell "no such conversation" from
      // "a conversation I cannot see" — the latter throws, it does not answer
      // null (see ChatGroupRepository.getGroup's note on the same distinction).
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

  group('getUnreadConversationsCount (legacy path)', () {
    test('falls back to arrayContains query when no inverse index', () async {
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

      final count = await _module(
        firestore,
      ).getUnreadConversationsCount(_userId);
      expect(count, 2);
    });

    test('returns 0 when no conversations exist', () async {
      final firestore = FakeFirebaseFirestore();
      expect(await _module(firestore).getUnreadConversationsCount(_userId), 0);
    });
  });

  group('getConversationIdsViaInverseIndex', () {
    test('returns empty list when no participantModule is wired', () async {
      final firestore = FakeFirebaseFirestore();
      final ids = await _module(
        firestore,
      ).getConversationIdsViaInverseIndex(_userId);
      expect(ids, isEmpty);
    });
  });
}
