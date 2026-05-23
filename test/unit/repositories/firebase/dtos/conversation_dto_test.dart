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
      for (final p in participants) p: 'https://avatar/$p'
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
      expect(
          restored.participantDisplayNames, {'alice': 'ALICE', 'bob': 'BOB'});
      expect(restored.participantAvatarUrls,
          {'alice': 'https://avatar/alice', 'bob': 'https://avatar/bob'});
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
      expect(restored.lastMessage!.sentAt.toUtc(),
          DateTime.utc(2026, 1, 2, 9, 30));
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
      final docA = await _writeAndRead(
          firestore,
          {
            'metadata': {'key': 'value'},
          },
          id: 'a');
      expect(ConversationDto.fromFirestore(docA).metadata, {'key': 'value'});

      final docB = await _writeAndRead(firestore, <String, dynamic>{}, id: 'b');
      expect(ConversationDto.fromFirestore(docB).metadata, isNull);
    });
  });

  group('perUserSettings extraction', () {
    test('flags default to false when no perUserSettings present', () async {
      final firestore = FakeFirebaseFirestore();
      final doc = await _writeAndRead(firestore, <String, dynamic>{});
      final restored =
          ConversationDto.fromFirestore(doc, currentUserId: 'alice');
      expect(restored.isArchived, isFalse);
      expect(restored.isPinned, isFalse);
      expect(restored.isMuted, isFalse);
      expect(restored.archivedAt, isNull);
      expect(restored.pinnedAt, isNull);
    });

    test('only surfaces the calling user\'s flags from denormalized map',
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

      final asAlice =
          ConversationDto.fromFirestore(doc, currentUserId: 'alice');
      expect(asAlice.isArchived, isTrue);
      expect(asAlice.isPinned, isTrue);
      expect(asAlice.isMuted, isFalse);
      expect(asAlice.archivedAt!.toUtc(), DateTime.utc(2026, 1, 5));
      expect(asAlice.pinnedAt!.toUtc(), DateTime.utc(2026, 1, 4));

      final asBob = ConversationDto.fromFirestore(doc, currentUserId: 'bob');
      expect(asBob.isArchived, isFalse);
      expect(asBob.isPinned, isFalse);
      expect(asBob.isMuted, isTrue);
    });

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
