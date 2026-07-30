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
    /// messages ordered by an increasing `timestamp` so the repository's
    /// `orderBy` is deterministic.
    Future<void> seedConversation(int messageCount) async {
      final convo = firestore
          .collection(FirestoreCollections.conversations)
          .doc(conversationId);
      await convo.set(<String, dynamic>{
        'participantIds': <String>[userId, 'other-user'],
      });
      for (var i = 0; i < messageCount; i++) {
        await convo.collection(FirestoreCollections.messages).doc('msg-$i').set(
          <String, dynamic>{
            'text': 'message $i',
            'senderId': userId,
            'timestamp': Timestamp.fromDate(
              DateTime.utc(2026, 1, 1).add(
                Duration(seconds: i),
              ),
            ),
          },
        );
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
  });
}
