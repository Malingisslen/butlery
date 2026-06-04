/// BUT-1194: unit coverage for `FirebaseCommentsRepository.getCommentLikers`
/// (now on the `CommentLikesOperations` mixin, BUT-1190).
///
/// Pre-existing test gap flagged by the testing-specialist during the BUT-1190
/// facade extraction: `getCommentLikers` had zero direct coverage. It reads the
/// per-comment `likes` subcollection ordered by `likedAt desc`, capped by
/// `limit`. `orderBy('likedAt')` works on FakeFirebaseFirestore, so no emulator
/// lane is needed — likes are seeded with explicit Timestamps for deterministic
/// ordering (the production write path stamps `serverTimestamp()`, which a fake
/// can't order meaningfully across rapid writes).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseCommentsRepository.getCommentLikers', () {
    late FirebaseCommentsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = FakeAuthRepository();
      mockAuthRepo.setAuthState(
        user: FakeUser(uid: 'user-123', displayName: 'Test User'),
        userId: 'user-123',
        isAuthenticated: true,
      );
      repository = FirebaseCommentsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    CollectionReference<Map<String, dynamic>> likesOf(String commentId) =>
        fakeFirestore
            .collection(FirestoreCollections.recipeComments)
            .doc(commentId)
            .collection(FirestoreCollections.likes);

    Future<void> seedLike(String commentId, String userId, DateTime likedAt) {
      return likesOf(commentId).doc(userId).set({
        'userId': userId,
        'likedAt': Timestamp.fromDate(likedAt),
      });
    }

    test('returns liker userIds ordered by likedAt descending', () async {
      await seedLike('c1', 'oldest', DateTime(2026, 1, 1));
      await seedLike('c1', 'newest', DateTime(2026, 1, 3));
      await seedLike('c1', 'middle', DateTime(2026, 1, 2));

      final likers = await repository.getCommentLikers('c1');

      expect(likers, ['newest', 'middle', 'oldest']);
    });

    test('respects an explicit limit, keeping the most-recent likers',
        () async {
      await seedLike('c1', 'oldest', DateTime(2026, 1, 1));
      await seedLike('c1', 'newest', DateTime(2026, 1, 3));
      await seedLike('c1', 'middle', DateTime(2026, 1, 2));

      final likers = await repository.getCommentLikers('c1', limit: 2);

      expect(likers, ['newest', 'middle']);
    });

    test('default limit (100) returns all when under the cap', () async {
      for (var i = 0; i < 5; i++) {
        await seedLike('c1', 'u$i', DateTime(2026, 1, 1 + i));
      }

      final likers = await repository.getCommentLikers('c1');

      expect(likers, hasLength(5));
    });

    test('returns an empty list when the comment has no likes', () async {
      final likers = await repository.getCommentLikers('no-likes');

      expect(likers, isEmpty);
    });
  });
}
