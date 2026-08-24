/// GDPR Article 15/20 boundary coverage for the conversation leg of
/// [FirebaseDataExportRepository].
///
/// BUT-1721: `messages_truncated` was computed as
/// `docs.length >= maxMessagesPerConversation` against a query limited to
/// exactly that cap. A full page and a clipped page are indistinguishable under
/// that shape, so a conversation holding EXACTLY the cap — nothing lost —
/// reported itself truncated. BUT-1721's aggregator then lifts a section's
/// truncation flag into `export_metadata`, which turns the false positive into
/// a complete Art. 15 bundle telling the data subject their messages were
/// clipped.
///
/// The fix reads one document past the cap, the same probe-one-extra shape as
/// [ExportPaginationHelper.fetchCapped]. The decisive test is therefore the
/// EXACTLY-AT-CAP case: below-cap passes under both the old and the new
/// implementation and proves nothing on its own.
///
/// BUT-1767: every case here used to seed `conversations/{id}/messages` with a
/// `timestamp` field — the same wrong collection AND the same non-existent sort
/// field the implementation used, so the caps were exercised over a query that
/// in production matched nothing (and, having no rule block, was denied
/// outright). The fixture now writes what `MessageDto.toFirestore` writes: a
/// TOP-LEVEL `messages` doc carrying `conversationId` and `sentAt`.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseDataExportRepository — conversation caps (BUT-1721)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;
    late FakeAuthRepository auth;

    const userId = 'user-abc';
    const conversationId = 'convo-1';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseDataExportRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    /// Seeds one conversation the user participates in, carrying [messageCount]
    /// top-level messages with an increasing `sentAt` so the repository's
    /// `orderBy` is deterministic.
    Future<void> seedConversation(
      int messageCount, {
      String senderId = userId,
    }) async {
      await firestore
          .collection(FirestoreCollections.conversations)
          .doc(conversationId)
          .set(<String, dynamic>{
            'participantIds': <String>[userId, 'other-user'],
          });
      for (var i = 0; i < messageCount; i++) {
        await firestore
            .collection(FirestoreCollections.messages)
            .doc('msg-$i')
            .set(<String, dynamic>{
              'conversationId': conversationId,
              'content': 'message $i',
              'senderId': senderId,
              'sentAt': Timestamp.fromDate(
                DateTime.utc(2026, 1, 1).add(
                  Duration(seconds: i),
                ),
              ),
            });
      }
    }

    test(
      'a conversation holding EXACTLY the cap is not reported as truncated',
      () async {
        await seedConversation(3);

        final result = await repository.exportConversationsAndMessages(
          userId,
          maxMessagesPerConversation: 3,
        );

        expect(result, hasLength(1));
        expect(
          result.single['messages_truncated'],
          isFalse,
          reason:
              'Nothing was clipped — every message the conversation holds is in '
              'the bundle, so the Art. 15 export must not claim otherwise.',
        );
        expect(result.single['messages'] as List<dynamic>, hasLength(3));
      },
    );

    test('one message past the cap IS reported as truncated, and is cut to the '
        'cap', () async {
      await seedConversation(4);

      final result = await repository.exportConversationsAndMessages(
        userId,
        maxMessagesPerConversation: 3,
      );

      expect(result, hasLength(1));
      expect(result.single['messages_truncated'], isTrue);
      expect(
        result.single['messages'] as List<dynamic>,
        hasLength(3),
        reason:
            'The probe document is a truncation SIGNAL, not payload — it must '
            'not ride along into the export.',
      );
    });

    test(
      'a conversation below the cap is complete and not truncated',
      () async {
        await seedConversation(2);

        final result = await repository.exportConversationsAndMessages(
          userId,
          maxMessagesPerConversation: 3,
        );

        expect(result, hasLength(1));
        expect(result.single['messages_truncated'], isFalse);
        expect(result.single['messages'] as List<dynamic>, hasLength(2));
      },
    );

    test(
      'BUT-1767: messages are read from the top-level collection, oldest first',
      () async {
        await seedConversation(3);

        final result = await repository.exportConversationsAndMessages(userId);

        final messages = (result.single['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          messages.map((m) => m['id']),
          equals(<String>['msg-0', 'msg-1', 'msg-2']),
          reason:
              'Reading `conversations/{id}/messages` or sorting on `timestamp` '
              'both yield an EMPTY list — this is the assertion that separates '
              'the fix from the defect.',
        );
        expect(
          (messages.first['data'] as Map<String, dynamic>)['conversationId'],
          equals(conversationId),
        );
      },
    );

    test(
      'BUT-1767: messages the user RECEIVED are exported too',
      () async {
        await seedConversation(2, senderId: 'other-user');

        final result = await repository.exportConversationsAndMessages(userId);

        expect(
          result.single['messages'] as List<dynamic>,
          hasLength(2),
          reason:
              'The gateway returns the whole thread; the requester participates '
              'in it, so both halves are their Art. 15 record.',
        );
      },
    );

    /// BUT-1832. A poll vote used to live inside the message document, in
    /// `metadata.poll.options[].voterIds`, and therefore left with the message.
    /// It now lives at `messages/{id}/poll_votes/{voterUid}` — a path the rules,
    /// the collection-group index and the Art. 17 deletion sweep all reached,
    /// and Art. 15 did not. The message's own `voterIds` arrays are no longer
    /// written by anyone, so without this leg a data subject's bundle shows
    /// their votes as empty arrays.
    Future<void> seedPollMessage(
      String messageId, {
      required Map<String, Map<String, dynamic>> votes,
    }) async {
      await firestore
          .collection(FirestoreCollections.messages)
          .doc(messageId)
          .set(<String, dynamic>{
            'conversationId': conversationId,
            'content': 'Vad ska vi äta?',
            'senderId': 'other-user',
            'sentAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
            'metadata': <String, dynamic>{
              'poll': <String, dynamic>{
                'question': 'Vad ska vi äta?',
                'options': <Map<String, dynamic>>[
                  {'id': 'opt-a', 'text': 'Tacos', 'voterIds': <String>[]},
                  {'id': 'opt-b', 'text': 'Pasta', 'voterIds': <String>[]},
                ],
              },
            },
          });
      for (final entry in votes.entries) {
        await firestore
            .collection(FirestoreCollections.messages)
            .doc(messageId)
            .collection(FirestoreCollections.pollVotes)
            .doc(entry.key)
            .set(entry.value);
      }
    }

    test(
      "BUT-1832: the requester's own poll vote is exported with the message",
      () async {
        await seedConversation(1);
        await seedPollMessage(
          'msg-poll',
          votes: <String, Map<String, dynamic>>{
            userId: <String, dynamic>{
              'voterId': userId,
              'optionIds': <String>['opt-b'],
              'votedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 3)),
            },
          },
        );

        final result = await repository.exportConversationsAndMessages(userId);
        final messages = (result.single['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final poll = messages.firstWhere((m) => m['id'] == 'msg-poll');

        expect(
          poll['your_poll_vote'],
          isA<Map<String, dynamic>>().having(
            (v) => v['optionIds'],
            'optionIds',
            equals(<String>['opt-b']),
          ),
          reason:
              'The vote is the only record of a choice the requester made. It '
              'is erased by the Art. 17 cascade, so Art. 15 has to be able to '
              'show it.',
        );
        expect(
          ((poll['data'] as Map<String, dynamic>)['metadata']
              as Map<String, dynamic>)['poll'],
          isNotNull,
          reason:
              'the vote rides BESIDE the stored document, never merged into it '
              '— `data` stays the message as Firestore holds it',
        );
      },
    );

    test(
      'BUT-1832: another participant\'s vote row is NOT exported',
      () async {
        await seedConversation(1);
        await seedPollMessage(
          'msg-poll',
          votes: <String, Map<String, dynamic>>{
            'other-user': <String, dynamic>{
              'voterId': 'other-user',
              'optionIds': <String>['opt-a'],
              'votedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 3)),
            },
          },
        );

        final result = await repository.exportConversationsAndMessages(userId);
        final messages = (result.single['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final poll = messages.firstWhere((m) => m['id'] == 'msg-poll');

        expect(
          poll.containsKey('your_poll_vote'),
          isFalse,
          reason:
              'How somebody else voted is third-party behaviour. Reading the '
              'whole subcollection would put every participant\'s uid and '
              'choice in the requester\'s bundle.',
        );
      },
    );

    test(
      'BUT-1832: a message with no poll is not probed and carries no vote key',
      () async {
        await seedConversation(1);
        // A TRAP row, at a path production never writes: `votePoll` only ever
        // writes under a poll message. Without it this test asserted nothing —
        // with `_hasPoll` deleted the probe simply found no document, so "guard
        // held" and "probe found nothing" were the same observable and the
        // mutant survived. Now the guard is the ONLY thing keeping this key
        // out, and removing it reddens here directly instead of incidentally
        // tripping the cap test next door.
        await firestore
            .collection(FirestoreCollections.messages)
            .doc('msg-0')
            .collection(FirestoreCollections.pollVotes)
            .doc(userId)
            .set(<String, dynamic>{
              'voterId': userId,
              'optionIds': <String>['opt-a'],
            });

        final result = await repository.exportConversationsAndMessages(userId);
        final messages = (result.single['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        expect(messages.single.containsKey('your_poll_vote'), isFalse);
      },
    );

    test(
      'BUT-1832: a complete conversation carries no poll_votes_truncated flag',
      () async {
        // Recall control. `DataExportService`'s nested walk lifts any
        // `*_truncated` into the bundle's truncation notice, so a flag stuck
        // true tells every data subject their export is incomplete when it is
        // not — the BUT-1721 false-positive direction, whose fix is the top
        // half of this very file. Measured: without this, initialising the flag
        // to `true` left the whole suite green.
        await seedConversation(1);
        await seedPollMessage(
          'msg-poll-only',
          votes: <String, Map<String, dynamic>>{
            userId: <String, dynamic>{
              'voterId': userId,
              'optionIds': <String>['opt-a'],
            },
          },
        );

        final result = await repository.exportConversationsAndMessages(userId);

        expect(result.single.containsKey('poll_votes_truncated'), isFalse);
        // Positive control: the absence above is not an export that fell over
        // before it ever reached a poll.
        final messages = (result.single['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(
          messages.any((m) => m.containsKey('your_poll_vote')),
          isTrue,
          reason:
              'the vote overlay must have run for the absence to mean '
              'anything',
        );
      },
    );

    test(
      'BUT-1832: past the lookup cap the conversation reports itself clipped',
      () async {
        await seedConversation(1);
        for (var i = 0; i < 2; i++) {
          await seedPollMessage(
            'msg-poll-$i',
            votes: <String, Map<String, dynamic>>{
              userId: <String, dynamic>{
                'voterId': userId,
                'optionIds': <String>['opt-a'],
                'votedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 3)),
              },
            },
          );
        }

        final capped = FirebaseDataExportRepository(
          firestore: firestore,
          authRepository: auth,
          maxPollVoteLookupsPerConversation: 1,
        );
        final result = await capped.exportConversationsAndMessages(userId);
        final messages = (result.single['messages'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final probed = messages
            .where((m) => m.containsKey('your_poll_vote'))
            .length;

        expect(probed, 1, reason: 'the cap is a read budget, and it holds');
        expect(
          result.single['poll_votes_truncated'],
          isTrue,
          reason:
              'A silently short bundle is the failure mode this key exists to '
              'prevent — `DataExportService` lifts any `*_truncated` flag into '
              'the truncation notice the data subject reads.',
        );
      },
    );
  });
}
