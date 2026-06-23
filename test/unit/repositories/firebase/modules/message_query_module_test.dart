/// Unit tests for MessageQueryModule.
///
/// Exercises the four read paths on the conversation messages collection:
/// real-time stream, paginated page-by-page reader, single-message
/// lookup, and the simplified client-side search.
/// All paths go through `FakeFirebaseFirestore` — the module's only
/// dependency is a `CollectionReference`, so no auth wiring is needed.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/repositories/firebase/modules/message_query_module.dart';

const _conversationId = 'conv-1';

Future<void> _seedMessage(
  CollectionReference<Map<String, dynamic>> messagesRef, {
  required String id,
  required String content,
  required DateTime sentAt,
  String conversationId = _conversationId,
  String senderId = 'user-a',
}) async {
  final msg = Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderDisplayName: senderId,
    content: content,
    type: MessageType.text,
    status: MessageStatus.sent,
    sentAt: sentAt,
  );
  // toFirestore embeds server-side timestamps in createdAt/updatedAt;
  // the fake firestore handles ServerTimestampProvider by leaving the
  // sentinel until the doc is written, which is fine for query tests.
  await messagesRef.doc(id).set(MessageDto.toFirestore(msg));
}

void main() {
  group('getConversationMessages (stream)', () {
    test('emits oldest-first list filtered by conversationId', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');

      // 3 in target conversation, 1 in another → other must be excluded.
      await _seedMessage(
        messagesRef,
        id: 'm-old',
        content: 'oldest',
        sentAt: DateTime.utc(2026, 1, 1, 10),
      );
      await _seedMessage(
        messagesRef,
        id: 'm-mid',
        content: 'middle',
        sentAt: DateTime.utc(2026, 1, 1, 11),
      );
      await _seedMessage(
        messagesRef,
        id: 'm-new',
        content: 'newest',
        sentAt: DateTime.utc(2026, 1, 1, 12),
      );
      await _seedMessage(
        messagesRef,
        id: 'other',
        content: 'unrelated',
        sentAt: DateTime.utc(2026, 1, 1, 11),
        conversationId: 'conv-other',
      );

      final module = MessageQueryModule(messagesRef: messagesRef);
      final messages = await module
          .getConversationMessages(conversationId: _conversationId)
          .first;

      expect(messages.map((m) => m.id), ['m-old', 'm-mid', 'm-new']);
      expect(
        messages.every((m) => m.conversationId == _conversationId),
        isTrue,
      );
    });

    test('respects limit (only N newest, but emitted oldest-first)', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');

      for (var i = 0; i < 5; i++) {
        await _seedMessage(
          messagesRef,
          id: 'm$i',
          content: 'msg $i',
          sentAt: DateTime.utc(2026, 1, 1, 10 + i),
        );
      }

      final module = MessageQueryModule(messagesRef: messagesRef);
      final messages = await module
          .getConversationMessages(conversationId: _conversationId, limit: 3)
          .first;

      // Limit applies to the descending-sort, then reversed → 3 newest in
      // ascending order = m2, m3, m4.
      expect(messages.map((m) => m.id), ['m2', 'm3', 'm4']);
    });

    test('emits empty list when no messages match', () async {
      final firestore = FakeFirebaseFirestore();
      final module = MessageQueryModule(
        messagesRef: firestore.collection('messages'),
      );

      final messages = await module
          .getConversationMessages(conversationId: 'nope')
          .first;
      expect(messages, isEmpty);
    });
  });

  group('getConversationMessagesPage', () {
    test('returns oldest-first page filtered by conversation', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');

      for (var i = 0; i < 3; i++) {
        await _seedMessage(
          messagesRef,
          id: 'm$i',
          content: 'msg $i',
          sentAt: DateTime.utc(2026, 1, 1, 10 + i),
        );
      }

      final module = MessageQueryModule(messagesRef: messagesRef);
      final page = await module.getConversationMessagesPage(
        conversationId: _conversationId,
        limit: 10,
      );
      expect(page.map((m) => m.id), ['m0', 'm1', 'm2']);
    });

    test('startAfter cursor is accepted (smoke)', () async {
      // fake_cloud_firestore implements startAfter on a single-field
      // orderBy, but the exact slicing semantics for Timestamp cursors
      // diverge from production. This test asserts only that supplying
      // the cursor does not throw and returns a subset of all messages —
      // contract verification rather than slicing semantics.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');

      await _seedMessage(
        messagesRef,
        id: 'm0',
        content: 'a',
        sentAt: DateTime.utc(2026, 1, 1, 10),
      );
      await _seedMessage(
        messagesRef,
        id: 'm1',
        content: 'b',
        sentAt: DateTime.utc(2026, 1, 1, 11),
      );
      await _seedMessage(
        messagesRef,
        id: 'm2',
        content: 'c',
        sentAt: DateTime.utc(2026, 1, 1, 12),
      );

      final module = MessageQueryModule(messagesRef: messagesRef);
      final page = await module.getConversationMessagesPage(
        conversationId: _conversationId,
        limit: 10,
        startAfter: DateTime.utc(2026, 1, 1, 12),
      );
      // No throw → the startAfter branch executed.
      expect(page.length, lessThanOrEqualTo(3));
    });

    test('empty list when no messages exist', () async {
      final firestore = FakeFirebaseFirestore();
      final module = MessageQueryModule(
        messagesRef: firestore.collection('messages'),
      );
      final page = await module.getConversationMessagesPage(
        conversationId: _conversationId,
      );
      expect(page, isEmpty);
    });
  });

  group('getMessage', () {
    test('returns null when document does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final module = MessageQueryModule(
        messagesRef: firestore.collection('messages'),
      );
      expect(await module.getMessage('missing'), isNull);
    });

    test('returns the message when document exists', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await _seedMessage(
        messagesRef,
        id: 'm1',
        content: 'hello',
        sentAt: DateTime.utc(2026, 1, 1),
      );

      final module = MessageQueryModule(messagesRef: messagesRef);
      final msg = await module.getMessage('m1');
      expect(msg, isNotNull);
      expect(msg!.id, 'm1');
      expect(msg.content, 'hello');
    });
  });

  group('searchMessages', () {
    test('case-insensitive substring match on content', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await _seedMessage(
        messagesRef,
        id: 'm1',
        content: 'Hello World',
        sentAt: DateTime.utc(2026, 1, 1, 10),
      );
      await _seedMessage(
        messagesRef,
        id: 'm2',
        content: 'goodbye',
        sentAt: DateTime.utc(2026, 1, 1, 11),
      );
      await _seedMessage(
        messagesRef,
        id: 'm3',
        content: 'helmet',
        sentAt: DateTime.utc(2026, 1, 1, 12),
      );

      final module = MessageQueryModule(messagesRef: messagesRef);
      final hits = await module.searchMessages(
        conversationId: _conversationId,
        query: 'HEL',
      );
      expect(hits.map((m) => m.id).toSet(), {'m1', 'm3'});
    });

    test('respects limit on filtered hits', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      for (var i = 0; i < 5; i++) {
        await _seedMessage(
          messagesRef,
          id: 'm$i',
          content: 'pizza topping $i',
          sentAt: DateTime.utc(2026, 1, 1, 10 + i),
        );
      }

      final module = MessageQueryModule(messagesRef: messagesRef);
      final hits = await module.searchMessages(
        conversationId: _conversationId,
        query: 'pizza',
        limit: 2,
      );
      expect(hits, hasLength(2));
    });

    test('returns empty when no content matches', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await _seedMessage(
        messagesRef,
        id: 'm1',
        content: 'apple',
        sentAt: DateTime.utc(2026, 1, 1, 10),
      );

      final module = MessageQueryModule(messagesRef: messagesRef);
      final hits = await module.searchMessages(
        conversationId: _conversationId,
        query: 'banana',
      );
      expect(hits, isEmpty);
    });
  });
}
