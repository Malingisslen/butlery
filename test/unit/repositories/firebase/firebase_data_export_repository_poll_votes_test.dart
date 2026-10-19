/// BUT-2413: the Art. 15 vote leg reads `poll_votes` by the predicate the
/// Art. 17 sweep (`deletePollVotes`) erases by — `voterId == uid` across the
/// collection group — so the parent message's shape and the requester's
/// `memberSince` decide nothing.
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
  group('FirebaseDataExportRepository.exportPollVotesByUser (BUT-2413)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;

    const userId = 'user-abc';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      final auth = FakeAuthRepository();
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

    Future<void> seedVote(String messageId, String voterId) => firestore
        .collection(FirestoreCollections.messages)
        .doc(messageId)
        .collection(FirestoreCollections.pollVotes)
        .doc(voterId)
        .set(<String, dynamic>{
          'voterId': voterId,
          'optionIds': <String>['opt-a'],
          'votedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 3)),
        });

    test('returns the requester\'s rows under every message, with its id, '
        'and nobody else\'s', () async {
      // A share card (metadata without `poll`) and a message no conversation
      // read would reach: the two shapes the old per-poll probe skipped.
      await firestore
          .collection(FirestoreCollections.messages)
          .doc('msg-share')
          .set(<String, dynamic>{
            'conversationId': 'convo-1',
            'metadata': <String, dynamic>{'recipeId': 'r1'},
          });
      await seedVote('msg-share', userId);
      await seedVote('msg-unread', userId);
      await seedVote('msg-share', 'other-user');

      final rows = await repository.exportPollVotesByUser(userId);

      expect(
        rows.map((r) => r['message_id']).toSet(),
        equals(<String>{'msg-share', 'msg-unread'}),
      );
      expect(
        rows.every(
          (r) => (r['data'] as Map<String, dynamic>)['voterId'] == userId,
        ),
        isTrue,
        reason: 'another voter\'s choice is third-party behaviour',
      );
    });

    test('forwards its cap to the query', () async {
      for (var i = 0; i < 3; i++) {
        await seedVote('msg-$i', userId);
      }

      final rows = await repository.exportPollVotesByUser(
        userId,
        maxDocuments: 2,
      );

      expect(rows, hasLength(2));
    });
  });
}
