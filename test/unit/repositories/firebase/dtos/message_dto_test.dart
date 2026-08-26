/// Unit tests for MessageDto.
///
/// Round-trip tests for the three conversion entry points: fromFirestore
/// (document-level), fromMap (used for nested lastMessage data on
/// conversations), and toFirestore / toMap (write paths). Also pins
/// enum-safety fallbacks (unknown `type` / `status` strings fall back to
/// text / sent) and that toMap omits the createdAt / updatedAt
/// server-timestamp pair that only the document write path emits.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';

Message _message({
  String id = 'm1',
  String content = 'hej',
  MessageType type = MessageType.text,
  MessageStatus status = MessageStatus.sent,
  DateTime? sentAt,
  DateTime? deliveredAt,
  DateTime? readAt,
  Map<String, dynamic>? metadata,
  String? replyToMessageId,
  bool isEdited = false,
  DateTime? editedAt,
  Map<String, List<String>> reactions = const {},
}) {
  return Message(
    id: id,
    conversationId: 'c1',
    senderId: 'alice',
    senderDisplayName: 'Alice',
    senderAvatarUrl: 'https://avatar/alice',
    content: content,
    type: type,
    status: status,
    sentAt: sentAt ?? DateTime.utc(2026, 1, 2, 9, 30),
    deliveredAt: deliveredAt,
    readAt: readAt,
    metadata: metadata,
    replyToMessageId: replyToMessageId,
    isEdited: isEdited,
    editedAt: editedAt,
    reactions: reactions,
  );
}

void main() {
  group('toFirestore + fromFirestore round-trip', () {
    test('preserves all core fields', () async {
      final firestore = FakeFirebaseFirestore();
      final msg = _message(
        deliveredAt: DateTime.utc(2026, 1, 2, 9, 31),
        readAt: DateTime.utc(2026, 1, 2, 9, 32),
        metadata: const {'k': 'v'},
        replyToMessageId: 'm0',
        isEdited: true,
        editedAt: DateTime.utc(2026, 1, 2, 10),
        reactions: const {
          '👍': ['alice'],
        },
      );

      await firestore
          .collection('messages')
          .doc(msg.id)
          .set(
            MessageDto.toFirestore(
              msg,
              timestampProvider: const TestTimestampProvider(),
            ),
          );
      final doc = await firestore.collection('messages').doc(msg.id).get();
      final restored = MessageDto.fromFirestore(doc);

      expect(restored.id, msg.id);
      expect(restored.conversationId, msg.conversationId);
      expect(restored.senderId, msg.senderId);
      expect(restored.senderDisplayName, msg.senderDisplayName);
      expect(restored.senderAvatarUrl, msg.senderAvatarUrl);
      expect(restored.content, msg.content);
      expect(restored.type, MessageType.text);
      expect(restored.status, MessageStatus.sent);
      expect(restored.sentAt.toUtc(), msg.sentAt);
      expect(restored.deliveredAt!.toUtc(), msg.deliveredAt);
      expect(restored.readAt!.toUtc(), msg.readAt);
      expect(restored.metadata, {'k': 'v'});
      expect(restored.replyToMessageId, 'm0');
      expect(restored.isEdited, isTrue);
      expect(restored.editedAt!.toUtc(), msg.editedAt);
      expect(restored.reactions, {
        '👍': ['alice'],
      });
    });

    test('reactions field absent in write when empty', () {
      final data = MessageDto.toFirestore(
        _message(reactions: const {}),
        timestampProvider: const TestTimestampProvider(),
      );
      expect(data.containsKey('reactions'), isFalse);
    });

    test('createdAt / updatedAt emitted by toFirestore (write metadata)', () {
      final data = MessageDto.toFirestore(
        _message(),
        timestampProvider: const TestTimestampProvider(),
      );
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });
  });

  group('fromMap', () {
    test('uses provided documentId when given', () {
      final map = MessageDto.toMap(_message(id: 'should-be-overridden'));
      final restored = MessageDto.fromMap(map, documentId: 'forced-id');
      expect(restored.id, 'forced-id');
    });

    test('falls back to map[id] when documentId is null', () {
      final map = MessageDto.toMap(_message(id: 'm-orig'));
      final restored = MessageDto.fromMap(map);
      expect(restored.id, 'm-orig');
    });

    test('unknown type string falls back to MessageType.text', () {
      final map = MessageDto.toMap(_message());
      map['type'] = 'totally-unknown-type';
      final restored = MessageDto.fromMap(map);
      expect(restored.type, MessageType.text);
    });

    // BUT-1904. The guard writes this string server-side, through the Admin
    // SDK, so nothing on the Dart side produces it — which is exactly why it
    // needs pinning: the case above proves an unrecognised type is silently
    // read as `text`, so a spelling drift here would land a blocked row in the
    // thread as an empty ordinary bubble with no error anywhere.
    test(
      'the duplicateBlocked string the server writes parses to the enum',
      () {
        final map = MessageDto.toMap(_message());
        map['type'] = 'duplicateBlocked';
        map['content'] = '';
        final restored = MessageDto.fromMap(map);
        expect(restored.type, MessageType.duplicateBlocked);
        expect(restored.content, isEmpty);
      },
    );

    test('unknown status string falls back to MessageStatus.sent', () {
      final map = MessageDto.toMap(_message());
      map['status'] = 'totally-unknown-status';
      final restored = MessageDto.fromMap(map);
      expect(restored.status, MessageStatus.sent);
    });
  });

  group('toMap (nested-message format)', () {
    test('includes id field — distinct from toFirestore output', () {
      final msg = _message(id: 'm-X');
      final map = MessageDto.toMap(msg);
      expect(map['id'], 'm-X');
      // toMap does NOT emit createdAt/updatedAt — those belong only to
      // the standalone document write path.
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('omits reactions when empty, includes when non-empty', () {
      final emptyMap = MessageDto.toMap(_message(reactions: const {}));
      expect(emptyMap.containsKey('reactions'), isFalse);

      final withReactions = MessageDto.toMap(
        _message(
          reactions: const {
            '😂': ['alice', 'bob'],
          },
        ),
      );
      expect(withReactions['reactions'], {
        '😂': ['alice', 'bob'],
      });
    });

    test('null timestamps remain null in serialized map', () {
      final map = MessageDto.toMap(_message());
      expect(map['deliveredAt'], isNull);
      expect(map['readAt'], isNull);
      expect(map['editedAt'], isNull);
    });
  });
}
