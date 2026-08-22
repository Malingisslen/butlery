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

  // BUT-1838. `historyStart` is the caller's `memberSince` stamp, mirrored
  // here as a `sentAt >=` filter. It is NOT a display filter: firestore.rules
  // refuses any message sent before a member joined a group conversation, and
  // a query that returns even ONE refused document fails entirely, so a
  // missing filter turns the chat into a permission error rather than a
  // slightly-too-long history. The boundary matters in its own right — the
  // stamp is the instant of joining, and the join system-message is written
  // AT it, so `>` instead of `>=` would drop the row that explains the cut.
  group('historyStart cut-off', () {
    // Deliberately distinct instants; the middle one is the boundary.
    final before = DateTime.utc(2026, 1, 1, 9);
    final atJoin = DateTime.utc(2026, 1, 1, 10);
    final after = DateTime.utc(2026, 1, 1, 11);

    Future<CollectionReference<Map<String, dynamic>>> seedThree(
      FakeFirebaseFirestore firestore,
    ) async {
      final messagesRef = firestore.collection('messages');
      await _seedMessage(
        messagesRef,
        id: 'm-before',
        content: 'said before you joined',
        sentAt: before,
      );
      await _seedMessage(
        messagesRef,
        id: 'm-at-join',
        content: 'the moment you joined',
        sentAt: atJoin,
      );
      await _seedMessage(
        messagesRef,
        id: 'm-after',
        content: 'said after you joined',
        sentAt: after,
      );
      return messagesRef;
    }

    test('stream excludes messages sent before the stamp, inclusive at '
        'the boundary', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = await seedThree(firestore);
      final module = MessageQueryModule(messagesRef: messagesRef);

      final messages = await module
          .getConversationMessages(
            conversationId: _conversationId,
            historyStart: atJoin,
          )
          .first;

      // 'm-at-join' present pins `>=` against `>`; 'm-before' absent pins
      // that a filter was applied at all.
      expect(messages.map((m) => m.id), ['m-at-join', 'm-after']);
    });

    test('stream returns the full history when historyStart is null', () async {
      // The recall control: a direct chat, or a founding member, must not be
      // filtered. Without this, "always return nothing" would satisfy the
      // test above.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = await seedThree(firestore);
      final module = MessageQueryModule(messagesRef: messagesRef);

      final messages = await module
          .getConversationMessages(
            conversationId: _conversationId,
            historyStart: null,
          )
          .first;

      expect(messages.map((m) => m.id), ['m-before', 'm-at-join', 'm-after']);
    });

    test('the page reader applies the same cut-off', () async {
      // The two methods build their queries separately, so the stream's
      // filter proves nothing about the page reader — which is the one the
      // chat view calls first, on open.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = await seedThree(firestore);
      final module = MessageQueryModule(messagesRef: messagesRef);

      final filtered = await module.getConversationMessagesPage(
        conversationId: _conversationId,
        historyStart: atJoin,
      );
      final unfiltered = await module.getConversationMessagesPage(
        conversationId: _conversationId,
      );

      expect(filtered.map((m) => m.id), ['m-at-join', 'm-after']);
      expect(unfiltered.map((m) => m.id), [
        'm-before',
        'm-at-join',
        'm-after',
      ]);
    });

    test('the cut-off does not widen past the conversation filter', () async {
      // A message in ANOTHER conversation sent after the stamp must still be
      // excluded — the two `where` clauses have to compose, not replace.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = await seedThree(firestore);
      await _seedMessage(
        messagesRef,
        id: 'm-other-convo',
        content: 'someone else entirely',
        sentAt: after,
        conversationId: 'conv-other',
      );
      final module = MessageQueryModule(messagesRef: messagesRef);

      final messages = await module
          .getConversationMessages(
            conversationId: _conversationId,
            historyStart: atJoin,
          )
          .first;

      expect(messages.map((m) => m.id), ['m-at-join', 'm-after']);
      expect(messages.map((m) => m.id), isNot(contains('m-other-convo')));
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

  group('poll-vote hydration (BUT-1832)', () {
    // Votes are stored at `messages/{messageId}/poll_votes/{voterUid}`, because
    // only a message's SENDER may update the message — which denied a vote to
    // everyone except the poll's own author. Nothing ABOVE the repository was
    // changed to suit that: the poll widget, `Poll.totalVotes` and
    // `closePoll`'s winner resolution all still read
    // `metadata.poll.options[].voterIds`, so this module folds the
    // subcollection back into that shape on the way out. An unhydrated poll is
    // not a rendering nit — it reads "0 röster" over real votes.
    //
    // The harm is a DISPLAY harm, and this comment stated it wrongly for days,
    // in the same words the module itself did: an unhydrated poll does NOT make
    // `closePoll` resolve to the first option. `_resolveWinner` returns null
    // once every option reads zero votes, so it writes no plan at all. What
    // really happens is that the close button is drawn on a poll showing
    // "0 röster", the close re-reads the message on its own uncapped path and
    // resolves the REAL winner, and a recipe lands in the week's plan the
    // creator was never shown a vote for (BUT-1883, measured 2026-08-20).

    Future<void> seedPollMessage(
      CollectionReference<Map<String, dynamic>> messagesRef, {
      String id = 'poll-1',
      DateTime? sentAt,
    }) async {
      await messagesRef.doc(id).set({
        'id': id,
        'conversationId': _conversationId,
        'senderId': 'user-a',
        'senderDisplayName': 'user-a',
        'content': 'Vad ska vi äta?',
        'type': MessageType.poll.name,
        'status': MessageStatus.sent.name,
        'sentAt': Timestamp.fromDate(sentAt ?? DateTime.utc(2026, 1, 1, 10)),
        'metadata': {
          'poll': {
            'id': 'p1',
            'question': 'Vad ska vi äta?',
            'creatorId': 'user-a',
            'isClosed': false,
            'options': [
              {'id': 'opt-a', 'text': 'Tacos', 'voterIds': <String>[]},
              {'id': 'opt-b', 'text': 'Pasta', 'voterIds': <String>[]},
            ],
          },
        },
      });
    }

    Future<void> castVote(
      CollectionReference<Map<String, dynamic>> messagesRef,
      String messageId,
      String voterId,
      List<String> optionIds,
    ) => messagesRef.doc(messageId).collection('poll_votes').doc(voterId).set({
      'voterId': voterId,
      'optionIds': optionIds,
    });

    List<String> votersFor(Message message, String optionId) {
      final options =
          (message.metadata!['poll'] as Map)['options'] as List<dynamic>;
      final option = options.firstWhere(
        (o) => (o as Map)['id'] == optionId,
      );
      return List<String>.from((option as Map)['voterIds'] as List);
    }

    test('getMessage folds the subcollection into voterIds', () async {
      // This path is not cosmetic: `MessagingService.closePoll` reads the poll
      // through `getMessage` and picks the winner by vote count.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await seedPollMessage(messagesRef);
      await castVote(messagesRef, 'poll-1', 'user-b', ['opt-b']);
      await castVote(messagesRef, 'poll-1', 'user-c', ['opt-b']);

      final message = await MessageQueryModule(
        messagesRef: messagesRef,
      ).getMessage('poll-1');

      expect(votersFor(message!, 'opt-b'), ['user-b', 'user-c']);
      expect(votersFor(message, 'opt-a'), isEmpty);
    });

    test('the stream folds votes in, and re-emits when one changes', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await seedPollMessage(messagesRef);
      await castVote(messagesRef, 'poll-1', 'user-b', ['opt-a']);

      final stream = MessageQueryModule(
        messagesRef: messagesRef,
      ).getConversationMessages(conversationId: _conversationId);

      final first = await stream.first;
      expect(votersFor(first.single, 'opt-a'), ['user-b']);

      // A vote arriving with no new message must still reach the screen —
      // otherwise a tap does nothing visible until somebody says something.
      final later = stream.firstWhere(
        (msgs) => votersFor(msgs.single, 'opt-a').length == 2,
      );
      await castVote(messagesRef, 'poll-1', 'user-c', ['opt-a']);
      await expectLater(later, completes);
    });

    test('a multi-choice row counts toward every option it names', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await seedPollMessage(messagesRef);
      await castVote(messagesRef, 'poll-1', 'user-b', ['opt-a', 'opt-b']);

      final message = await MessageQueryModule(
        messagesRef: messagesRef,
      ).getMessage('poll-1');

      expect(votersFor(message!, 'opt-a'), ['user-b']);
      expect(votersFor(message, 'opt-b'), ['user-b']);
    });

    test('a stale inline voterIds array is REPLACED, not merged', () async {
      // Rows written before the move still carry the old array. The tally is
      // the truth; leaving the array to win would show votes that no
      // `poll_votes` row backs and that no erasure sweep could ever reach.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await seedPollMessage(messagesRef);
      await messagesRef.doc('poll-1').update({
        'metadata.poll.options': [
          {
            'id': 'opt-a',
            'text': 'Tacos',
            'voterIds': ['ghost-uid'],
          },
          {'id': 'opt-b', 'text': 'Pasta', 'voterIds': <String>[]},
        ],
      });
      await castVote(messagesRef, 'poll-1', 'user-b', ['opt-b']);

      final message = await MessageQueryModule(
        messagesRef: messagesRef,
      ).getMessage('poll-1');

      expect(votersFor(message!, 'opt-a'), isEmpty);
      expect(votersFor(message, 'opt-b'), ['user-b']);
    });

    test('a non-poll message is passed through untouched', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await _seedMessage(
        messagesRef,
        id: 'm-1',
        content: 'hej',
        sentAt: DateTime.utc(2026, 1, 1, 10),
      );

      final page = await MessageQueryModule(
        messagesRef: messagesRef,
      ).getConversationMessagesPage(conversationId: _conversationId);

      expect(page.single.content, 'hej');
      expect(page.single.metadata?['poll'], isNull);
    });

    test('the page reader hydrates too', () async {
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');
      await seedPollMessage(messagesRef);
      await castVote(messagesRef, 'poll-1', 'user-b', ['opt-a']);

      final page = await MessageQueryModule(
        messagesRef: messagesRef,
      ).getConversationMessagesPage(conversationId: _conversationId);

      expect(votersFor(page.single, 'opt-a'), ['user-b']);
    });

    test('the cap hydrates the NEWEST polls, not the oldest', () async {
      // The cap existed with nothing pinning WHICH polls it keeps, and it kept
      // the wrong ones: both readers hand the hydrator its list oldest-first,
      // so taking the first N dropped the polls at the BOTTOM of the chat —
      // the ones on screen. They rendered "0 röster" over real votes, which is
      // exactly the failure the module's own header says must not happen.
      //
      // Seeded one past the cap so precisely one poll is dropped, and votes are
      // cast on both ends: without an assertion at each end, selecting from the
      // wrong end still satisfies the other. Deleting `.reversed` from
      // `_pollIds` reddens this test and nothing else.
      final firestore = FakeFirebaseFirestore();
      final messagesRef = firestore.collection('messages');

      const cap = MessageQueryModule.maxHydratedPolls;
      for (var i = 0; i <= cap; i++) {
        await seedPollMessage(
          messagesRef,
          id: 'poll-$i',
          // Ascending, so `poll-0` is the oldest and `poll-$cap` the newest.
          sentAt: DateTime.utc(2026, 1, 1, 10).add(Duration(minutes: i)),
        );
      }
      await castVote(messagesRef, 'poll-0', 'user-oldest', ['opt-a']);
      await castVote(messagesRef, 'poll-$cap', 'user-newest', ['opt-a']);

      final page = await MessageQueryModule(
        messagesRef: messagesRef,
      ).getConversationMessagesPage(conversationId: _conversationId);

      final newest = page.firstWhere((m) => m.id == 'poll-$cap');
      final oldest = page.firstWhere((m) => m.id == 'poll-0');

      expect(
        votersFor(newest, 'opt-a'),
        ['user-newest'],
        reason: 'the newest poll is on screen and must be hydrated',
      );
      expect(
        votersFor(oldest, 'opt-a'),
        isEmpty,
        reason:
            'the one poll past the cap is the OLDEST, not the newest — '
            'its stored (empty) array is passed through untouched',
      );
    });
  });
}
