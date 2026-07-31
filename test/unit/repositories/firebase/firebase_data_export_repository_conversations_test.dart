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
  });
}
