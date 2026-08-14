/// Unit tests for ConversationDto.
///
/// Round-trip + edge-case coverage for the conversations serializer.
/// Tests pin: defaults for missing fields, per-user settings extraction
/// (perUserSettings is keyed by currentUserId and only that user's flags
/// are surfaced), lastMessage nesting via MessageDto, and timestamp
/// round-tripping.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/dtos/conversation_dto.dart';

Conversation _conv({
  String id = 'c1',
  List<String> participants = const ['alice', 'bob'],
  Message? lastMessage,
  bool isGroup = false,
  String? title,
  Map<String, DateTime>? lastReads,
}) {
  return Conversation(
    id: id,
    participantIds: participants,
    participantDisplayNames: {for (final p in participants) p: p.toUpperCase()},
    participantAvatarUrls: {
      for (final p in participants) p: 'https://avatar/$p',
    },
    lastReadTimestamps: lastReads ?? const {},
    isGroup: isGroup,
    title: title,
    lastMessage: lastMessage,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

Future<DocumentSnapshot<Map<String, dynamic>>> _writeAndRead(
  FakeFirebaseFirestore firestore,
  Map<String, dynamic> data, {
  String id = 'c1',
}) async {
  await firestore.collection('conversations').doc(id).set(data);
  return firestore.collection('conversations').doc(id).get();
}

void main() {
  group('toFirestore + fromFirestore round-trip', () {
    test('preserves basic conversation fields', () async {
      final firestore = FakeFirebaseFirestore();
      final original = _conv(isGroup: true, title: 'Squad');

      final data = ConversationDto.toFirestore(original);
      final doc = await _writeAndRead(firestore, data);
      final restored = ConversationDto.fromFirestore(doc);

      expect(restored.id, 'c1');
      expect(restored.participantIds, ['alice', 'bob']);
      expect(restored.participantDisplayNames, {
        'alice': 'ALICE',
        'bob': 'BOB',
      });
      expect(restored.participantAvatarUrls, {
        'alice': 'https://avatar/alice',
        'bob': 'https://avatar/bob',
      });
      expect(restored.isGroup, isTrue);
      expect(restored.title, 'Squad');
      expect(restored.createdAt.toUtc(), DateTime.utc(2026, 1, 1));
      expect(restored.updatedAt.toUtc(), DateTime.utc(2026, 1, 2));
    });

    test('lastMessage nests through MessageDto', () async {
      final firestore = FakeFirebaseFirestore();
      final msg = Message(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'alice',
        senderDisplayName: 'Alice',
        content: 'hej',
        type: MessageType.text,
        status: MessageStatus.sent,
        sentAt: DateTime.utc(2026, 1, 2, 9, 30),
      );
      final original = _conv(lastMessage: msg);

      final data = ConversationDto.toFirestore(original);
      final doc = await _writeAndRead(firestore, data);
      final restored = ConversationDto.fromFirestore(doc);

      expect(restored.lastMessage, isNotNull);
      expect(restored.lastMessage!.id, 'm1');
      expect(restored.lastMessage!.content, 'hej');
      expect(
        restored.lastMessage!.sentAt.toUtc(),
        DateTime.utc(2026, 1, 2, 9, 30),
      );
    });

    test('lastReadTimestamps round-trips per-user dates', () async {
      final firestore = FakeFirebaseFirestore();
      final reads = {
        'alice': DateTime.utc(2026, 1, 2, 10),
        'bob': DateTime.utc(2026, 1, 2, 11),
      };
      final original = _conv(lastReads: reads);

      final data = ConversationDto.toFirestore(original);
      final doc = await _writeAndRead(firestore, data);
      final restored = ConversationDto.fromFirestore(doc);

      // Timestamp.toDate() returns local-zone DateTime; compare on the
      // UTC instant to ignore the round-trip zone shift.
      expect(restored.lastReadTimestamps['alice']!.toUtc(), reads['alice']);
      expect(restored.lastReadTimestamps['bob']!.toUtc(), reads['bob']);
    });
  });

  group('fromFirestore defaults & null-safety', () {
    test('missing participantIds defaults to empty list', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await _writeAndRead(firestore, <String, dynamic>{
        'isGroup': false,
      });
      final restored = ConversationDto.fromFirestore(doc);
      expect(restored.participantIds, isEmpty);
      expect(restored.lastReadTimestamps, isEmpty);
      expect(restored.lastMessage, isNull);
    });

    test('missing isGroup defaults to false', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await _writeAndRead(firestore, <String, dynamic>{});
      final restored = ConversationDto.fromFirestore(doc);
      expect(restored.isGroup, isFalse);
    });

    test('metadata preserved when present, null when absent', () async {
      final firestore = FakeFirebaseFirestore();
      final docA = await _writeAndRead(firestore, {
        'metadata': {'key': 'value'},
      }, id: 'a');
      expect(ConversationDto.fromFirestore(docA).metadata, {'key': 'value'});

      final docB = await _writeAndRead(firestore, <String, dynamic>{}, id: 'b');
      expect(ConversationDto.fromFirestore(docB).metadata, isNull);
    });
  });

  // BUT-1838. `groupId` and `memberSince` are written ONLY by the group
  // callables under the Admin SDK. The DTO therefore has to be asymmetric —
  // it reads both and writes neither — and both halves need pinning:
  //
  //  * drop the READ and a group conversation loses its history cut-off, so
  //    the client's message query returns rows firestore.rules refuses and
  //    the whole query fails;
  //  * add the WRITE and every ordinary conversation update (a read receipt,
  //    a pin) starts carrying a server-owned key, which the conversations
  //    UPDATE rule's deny-list refuses — silently, in the way only a rules
  //    test can see (the BUT-1482 shape).
  group('groupId + memberSince are read but never written', () {
    test('fromFirestore reads groupId and per-member join stamps', () async {
      final firestore = FakeFirebaseFirestore();
      final joinedAt = DateTime.utc(2026, 3, 4, 5, 6);
      final doc = await _writeAndRead(firestore, <String, dynamic>{
        'participantIds': ['alice', 'bob'],
        'isGroup': true,
        'groupId': 'chat-group-1',
        'memberSince': {'bob': Timestamp.fromDate(joinedAt)},
      });

      final restored = ConversationDto.fromFirestore(doc);

      expect(restored.groupId, 'chat-group-1');
      expect(restored.memberSince['bob']?.toUtc(), joinedAt);
      expect(restored.historyQueryStartFor('bob')?.toUtc(), joinedAt);
      // alice is a founding member — present in the group, absent from the
      // stamp map, so no cut-off applies to her.
      expect(restored.historyQueryStartFor('alice'), isNull);
    });

    test('both default safely when the document predates BUT-1838', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await _writeAndRead(firestore, <String, dynamic>{
        'participantIds': ['alice', 'bob'],
        'isGroup': true,
      });

      final restored = ConversationDto.fromFirestore(doc);

      expect(restored.groupId, isNull);
      expect(restored.memberSince, isEmpty);
      expect(restored.historyQueryStartFor('bob'), isNull);
    });

    test('toFirestore omits both KEYS, not merely their values', () {
      // Asserted as key ABSENCE. `containsKey` is the load-bearing check:
      // fake_cloud_firestore stores a null-valued key faithfully, and so does
      // production, so a payload carrying `'groupId': null` would still put
      // the key in the update diff and still be denied.
      final conversation = Conversation(
        id: 'c-group',
        participantIds: const ['alice', 'bob'],
        participantDisplayNames: const {'alice': 'A', 'bob': 'B'},
        participantAvatarUrls: const {'alice': null, 'bob': null},
        lastReadTimestamps: const {},
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        isGroup: true,
        groupId: 'chat-group-1',
        memberSince: {'bob': DateTime.utc(2026, 3, 4)},
      );

      final data = ConversationDto.toFirestore(conversation);

      // Premise: the model really is carrying both, so the absence below is
      // the serializer's decision and not an empty fixture.
      expect(conversation.groupId, isNotNull);
      expect(conversation.memberSince, isNotEmpty);

      expect(data.containsKey('groupId'), isFalse);
      expect(data.containsKey('memberSince'), isFalse);

      // Positive control: the client-owned keys ARE still written, so this
      // is a scoped omission rather than a broken serializer.
      expect(data.containsKey('participantIds'), isTrue);
      expect(data.containsKey('isGroup'), isTrue);
      expect(data.containsKey('metadata'), isTrue);
    });

    test(
      'a write-then-read round trip drops the server-owned fields',
      () async {
        // End to end: what the client persists cannot resurrect a groupId,
        // so nothing the app writes can make a direct chat look like a group.
        final firestore = FakeFirebaseFirestore();
        final conversation = Conversation(
          id: 'c-round',
          participantIds: const ['alice', 'bob'],
          participantDisplayNames: const {'alice': 'A', 'bob': 'B'},
          participantAvatarUrls: const {'alice': null, 'bob': null},
          lastReadTimestamps: const {},
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
          isGroup: true,
          groupId: 'chat-group-1',
          memberSince: {'bob': DateTime.utc(2026, 3, 4)},
        );

        final doc = await _writeAndRead(
          firestore,
          ConversationDto.toFirestore(conversation),
          id: 'c-round',
        );
        final restored = ConversationDto.fromFirestore(doc);

        expect(restored.groupId, isNull);
        expect(restored.memberSince, isEmpty);
        expect(restored.isGroup, isTrue); // positive control
      },
    );
  });

  group('perUserSettings extraction', () {
    test('flags default to false when no perUserSettings present', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await _writeAndRead(firestore, <String, dynamic>{});
      final restored = ConversationDto.fromFirestore(
        doc,
        currentUserId: 'alice',
      );
      expect(restored.isArchived, isFalse);
      expect(restored.isPinned, isFalse);
      expect(restored.isMuted, isFalse);
      expect(restored.archivedAt, isNull);
      expect(restored.pinnedAt, isNull);
    });

    test(
      'only surfaces the calling user\'s flags from denormalized map',
      () async {
        final firestore = FakeFirebaseFirestore();
        final doc = await _writeAndRead(firestore, {
          'perUserSettings': {
            'alice': {
              'isArchived': true,
              'isPinned': true,
              'isMuted': false,
              'archivedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 5)),
              'pinnedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 4)),
            },
            'bob': {
              'isArchived': false,
              'isPinned': false,
              'isMuted': true,
            },
          },
        });

        final asAlice = ConversationDto.fromFirestore(
          doc,
          currentUserId: 'alice',
        );
        expect(asAlice.isArchived, isTrue);
        expect(asAlice.isPinned, isTrue);
        expect(asAlice.isMuted, isFalse);
        expect(asAlice.archivedAt!.toUtc(), DateTime.utc(2026, 1, 5));
        expect(asAlice.pinnedAt!.toUtc(), DateTime.utc(2026, 1, 4));

        final asBob = ConversationDto.fromFirestore(doc, currentUserId: 'bob');
        expect(asBob.isArchived, isFalse);
        expect(asBob.isPinned, isFalse);
        expect(asBob.isMuted, isTrue);
      },
    );

    test('flags ignored when currentUserId is null', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await _writeAndRead(firestore, {
        'perUserSettings': {
          'alice': {'isArchived': true, 'isPinned': true},
        },
      });
      final restored = ConversationDto.fromFirestore(doc);
      expect(restored.isArchived, isFalse);
      expect(restored.isPinned, isFalse);
    });
  });
}
