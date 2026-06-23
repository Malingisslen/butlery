/// Tests that saveFeedback gates the write behind validateCreatePermission +
/// audit log (WS10) — previously it called collection.add directly, bypassing
/// both. Permission contract: a user may only submit feedback under their own
/// userId.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/firebase/firebase_feedback_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

FeedbackEntry _entry({required String userId}) => FeedbackEntry(
  id: 'fb1',
  userId: userId,
  category: FeedbackCategory.bug,
  description: 'Something broke',
  recentInteractions: const [],
  createdAt: DateTime.utc(2026, 1, 1),
);

FirebaseFeedbackRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = 'alice',
}) {
  final auth = FakeAuthRepository()
    ..setAuthState(
      user: FakeUser(uid: authedUserId),
      userId: authedUserId,
      isAuthenticated: true,
    );
  return FirebaseFeedbackRepository(firestore: firestore, authRepository: auth);
}

void main() {
  group('saveFeedback permission gating', () {
    test('writes when the entry is owned by the current user', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, authedUserId: 'alice');

      await repo.saveFeedback(_entry(userId: 'alice'));

      final docs = await firestore.collection('feedback').get();
      expect(docs.docs, hasLength(1));
    });

    test(
      'throws PermissionDenied and writes nothing for a forged userId',
      () async {
        final firestore = FakeFirebaseFirestore();
        // Authed as bob, but the entry claims to be alice's.
        final repo = _repo(firestore, authedUserId: 'bob');

        await expectLater(
          () => repo.saveFeedback(_entry(userId: 'alice')),
          throwsA(isA<PermissionDeniedException>()),
        );

        final docs = await firestore.collection('feedback').get();
        expect(
          docs.docs,
          isEmpty,
          reason: 'a denied create must not persist anything',
        );
      },
    );
  });
}
