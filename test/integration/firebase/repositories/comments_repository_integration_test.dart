/// Integration tests for Firebase Comments Repository
///
/// Tests comments repository operations using FakeFirebaseFirestore (Fake Lane)
/// including comment creation, updates, and streaming.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/recipe_comment.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../test_support/test_data_isolator.dart';
import '../../../test_support/timestamp_test_helper.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';

void main() {
  group('Firebase Comments Repository Integration', () {
    late FirebaseFirestore firestore;
    late FirebaseCommentsRepository repository;
    late MockUser testUser;
    late MockFirebaseAuth mockAuth;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest('CommentsRepository');

      // Setup Fake Firebase instances (Fake Lane)
      firestore = FirestoreSingleton.instance;

      // Create mock user with authentication
      testUser = MockUser(
        uid: 'test-user-uid',
        email: 'test@example.com',
        displayName: 'Test User',
      );

      mockAuth = MockFirebaseAuth(mockUser: testUser, signedIn: true);

      // Create repository with injected dependencies
      final authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);
      repository = FirebaseCommentsRepository(
        firestore: firestore,
        authRepository: authRepository,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest('CommentsRepository');
    });

    group('Comments with timestamps', () {
      test('should create comment with server timestamp', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final userId = testUser.uid;
        const content = 'This is a test comment';

        // Act
        final comment = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
        );

        // Assert
        expect(comment, isNotNull);
        expect(comment.recipeId, equals(recipeId));
        expect(comment.authorId, equals(userId));
        expect(comment.text, equals(content));

        // Verify in Firestore
        final doc = await firestore
            .collection('recipe_comments')
            .doc(comment.id)
            .get();

        expect(doc.exists, isTrue);

        // Handle both DateTime and Timestamp
        final createdAt = doc.data()?['createdAt'];
        expect(createdAt, anyOf(isA<DateTime>(), isA<Timestamp>()));

        // Verify timestamp is close to current time
        final timestamp = TimestampTestHelper.toDateTime(createdAt);
        expect(timestamp, isNotNull);
        expect(
          timestamp!.difference(DateTime.now()).inMinutes.abs(),
          lessThan(1),
        );
      });

      /// BUT-1756: `createdAt` and `editedAt` are both minted from
      /// `clock.now()` (via [TestTimestampProvider]), and two wall-clock reads
      /// separated only by a fake-Firestore round-trip routinely land inside the
      /// same tick — the host clock's granularity, not the repository, then
      /// decides whether a strict `isAfter` passes. Control the clock instead of
      /// racing it: the assertion keeps its intent (the edit is stamped LATER
      /// than the creation, not merely "not before") and becomes deterministic.
      ///
      /// A tolerance would have been the other option and is the wrong one here
      /// — "within a second of each other" is exactly what a broken `editedAt`
      /// that copies `createdAt` also satisfies.
      test('should update comment with editedAt timestamp', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final userId = testUser.uid;
        const originalContent = 'Original comment';
        const updatedContent = 'Updated comment';

        var now = DateTime.utc(2026, 1, 1, 12);

        await withClock(Clock(() => now), () async {
          // Create comment
          final comment = await repository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: originalContent,
          );

          // The edit happens later than the creation. That gap is the whole
          // subject of the assertion below, so it is staged rather than hoped
          // for.
          now = now.add(const Duration(seconds: 1));

          // Act
          await repository.updateComment(comment.id, updatedContent);

          // Assert
          final doc = await firestore
              .collection('recipe_comments')
              .doc(comment.id)
              .get();

          expect(doc.data()?['text'], equals(updatedContent));

          // Handle both DateTime and Timestamp
          final editedAtValue = doc.data()?['editedAt'];
          final updatedAtValue = doc.data()?['updatedAt'];
          expect(editedAtValue, anyOf(isA<DateTime>(), isA<Timestamp>()));
          expect(updatedAtValue, anyOf(isA<DateTime>(), isA<Timestamp>()));

          // Verify editedAt is after createdAt
          final createdAt = TimestampTestHelper.toDateTime(
            doc.data()?['createdAt'],
          );
          final editedAt = TimestampTestHelper.toDateTime(editedAtValue);
          expect(createdAt, isNotNull);
          expect(editedAt, isNotNull);
          expect(editedAt!.isAfter(createdAt!), isTrue);
        });
      });

      test('should stream comments with proper timestamp ordering', () async {
        // Arrange
        const recipeId = 'recipe_123';
        final userId = testUser.uid;

        // Create comments with server timestamps
        for (int i = 0; i < 3; i++) {
          await firestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Comment $i',
            'parentCommentId': null,
            'createdAt': DateTime.now(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });

          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Act
        final stream = repository.getCommentsStream(recipeId);
        final comments = await stream.first;

        // Assert
        expect(comments.length, equals(3));

        // Verify comments are ordered by createdAt ascending. The
        // `isAtSameMomentAs` arm is deliberate (BUT-1756): these three stamps
        // come from real `DateTime.now()` reads, so equality is a legitimate
        // outcome and tightening this to a strict `isBefore` reintroduces the
        // same-tick coin flip.
        for (int i = 0; i < comments.length - 1; i++) {
          expect(
            comments[i].createdAt.isBefore(comments[i + 1].createdAt) ||
                comments[i].createdAt.isAtSameMomentAs(
                  comments[i + 1].createdAt,
                ),
            isTrue,
          );
        }
      });
    });

    group(
      'Like System with Transactions',
      skip:
          'FakeFirebaseFirestore does '
          'not implement FieldValue.increment — cannot exercise the real '
          'transaction path. Covered by Cloud Functions + emulator tests '
          '(BUT-387 Phase 7).',
      () {
        test(
          'should toggle like with transaction and increment counter',
          () async {
            // Arrange
            const recipeId = 'recipe_123';
            const commentId = 'comment_123';
            final userId = testUser.uid;

            // Create comment
            await firestore.collection('recipe_comments').doc(commentId).set({
              'recipeId': recipeId,
              'authorId': 'author_456',
              'authorDisplayName': 'Author User',
              'text': 'Great recipe!',
              'parentCommentId': null,
              'createdAt': DateTime.now(),
              'likedByUserIds': [],
              'replyCount': 0,
              'isDeleted': false,
              'likesCount': 0,
            });

            // Act - Toggle like on
            await repository.toggleCommentLike(commentId, userId);

            // Assert - Like added
            final likeDoc = await firestore
                .collection('recipe_comments')
                .doc(commentId)
                .collection('likes')
                .doc(userId)
                .get();
            expect(likeDoc.exists, isTrue);

            final commentDoc = await firestore
                .collection('recipe_comments')
                .doc(commentId)
                .get();
            expect(commentDoc.data()?['likesCount'], equals(1));

            // Act - Toggle like off
            await repository.toggleCommentLike(commentId, userId);

            // Assert - Like removed
            final likeDocAfter = await firestore
                .collection('recipe_comments')
                .doc(commentId)
                .collection('likes')
                .doc(userId)
                .get();
            expect(likeDocAfter.exists, isFalse);

            final commentDocAfter = await firestore
                .collection('recipe_comments')
                .doc(commentId)
                .get();
            expect(commentDocAfter.data()?['likesCount'], equals(0));
          },
        );

        test('should handle concurrent likes correctly', () async {
          // Arrange
          const recipeId = 'recipe_123';
          const commentId = 'comment_for_concurrent';

          // Create comment
          await firestore.collection('recipe_comments').doc(commentId).set({
            'recipeId': recipeId,
            'authorId': 'author_456',
            'authorDisplayName': 'Author User',
            'text': 'Test concurrent likes!',
            'parentCommentId': null,
            'createdAt': DateTime.now(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
            'likesCount': 0,
          });

          // Act - Multiple users like concurrently
          final futures = <Future>[];
          for (int i = 0; i < 5; i++) {
            futures.add(repository.toggleCommentLike(commentId, 'user_$i'));
          }
          await Future.wait(futures);

          // Assert - All likes counted correctly
          final commentDoc = await firestore
              .collection('recipe_comments')
              .doc(commentId)
              .get();
          expect(commentDoc.data()?['likesCount'], equals(5));

          // Verify like subcollection
          final likes = await firestore
              .collection('recipe_comments')
              .doc(commentId)
              .collection('likes')
              .get();
          expect(likes.docs.length, equals(5));
        });
      },
    );

    group(
      'Reply System with Counters',
      skip:
          'FakeFirebaseFirestore does '
          'not implement FieldValue.increment used by replyCount updates. '
          'Emulator-level coverage lives in BUT-387 Phase 7.',
      () {
        test('should increment reply count when adding reply', () async {
          // Arrange
          const recipeId = 'recipe_123';
          const parentId = 'parent_comment';
          final userId = testUser.uid;

          // Create parent comment
          await firestore.collection('recipe_comments').doc(parentId).set({
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Parent comment',
            'parentCommentId': null,
            'createdAt': DateTime.now(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });

          // Act - Add replies
          for (int i = 0; i < 3; i++) {
            await repository.addComment(
              recipeId: recipeId,
              userId: userId,
              content: 'Reply $i',
              parentCommentId: parentId,
            );
          }

          // Assert - Reply count updated
          final parentDoc = await firestore
              .collection('recipe_comments')
              .doc(parentId)
              .get();
          expect(parentDoc.data()?['replyCount'], equals(3));

          // Verify replies exist
          final replies = await firestore
              .collection('recipe_comments')
              .where('parentCommentId', isEqualTo: parentId)
              .get();
          expect(replies.docs.length, equals(3));
        });
      },
    );

    group('Batch Operations', () {
      test('should handle batch comment creation', () async {
        // Arrange
        const recipeId = 'recipe_batch_test';
        final userId = testUser.uid;
        final batch = firestore.batch();

        // Act - Create multiple comments in batch
        for (int i = 0; i < 10; i++) {
          final docRef = firestore.collection('recipe_comments').doc();
          batch.set(docRef, {
            'recipeId': recipeId,
            'authorId': userId,
            'authorDisplayName': 'Test User',
            'text': 'Batch comment $i',
            'parentCommentId': null,
            'createdAt': DateTime.now(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': false,
          });
        }

        await batch.commit();

        // Assert - All comments created
        final comments = await firestore
            .collection('recipe_comments')
            .where('recipeId', isEqualTo: recipeId)
            .get();

        expect(comments.docs.length, equals(10));

        // Verify all have timestamps
        for (final doc in comments.docs) {
          final createdAt = doc.data()['createdAt'];
          expect(createdAt, anyOf(isA<DateTime>(), isA<Timestamp>()));
        }
      });
    });

    group('Complex Queries', () {
      test('should query comments with multiple conditions', () async {
        // Arrange
        const recipeId = 'recipe_complex_query';
        final userId = testUser.uid;

        // Create mix of comments
        for (int i = 0; i < 10; i++) {
          await firestore.collection('recipe_comments').add({
            'recipeId': recipeId,
            'authorId': i % 2 == 0 ? userId : 'other_user',
            'authorDisplayName': i % 2 == 0 ? 'Test User' : 'Other User',
            'text': 'Comment $i',
            'parentCommentId': i < 5 ? null : 'parent_id',
            'createdAt': DateTime.now(),
            'likedByUserIds': [],
            'replyCount': 0,
            'isDeleted': i % 3 == 0,
            'likesCount': i,
          });
        }

        // Act - Query top-level, non-deleted comments by test user
        final query = await firestore
            .collection('recipe_comments')
            .where('recipeId', isEqualTo: recipeId)
            .where('authorId', isEqualTo: userId)
            .where('parentCommentId', isNull: true)
            .where('isDeleted', isEqualTo: false)
            .get();

        // Assert
        expect(query.docs.length, equals(2)); // Comments 2 and 4

        // Act - Query most liked comments
        final popularQuery = await firestore
            .collection('recipe_comments')
            .where('recipeId', isEqualTo: recipeId)
            .where('likesCount', isGreaterThanOrEqualTo: 5)
            .orderBy('likesCount', descending: true)
            .get();

        // Assert
        expect(popularQuery.docs.length, equals(5)); // Comments 5-9
        expect(popularQuery.docs.first.data()['likesCount'], equals(9));
      });
    });

    group('Real-time Updates', () {
      test('should receive real-time comment updates', () async {
        // Arrange
        const recipeId = 'recipe_realtime';
        final userId = testUser.uid;

        // Setup stream listener
        final streamController = repository.getCommentsStream(recipeId);
        final updates = <List<RecipeComment>>[];

        final subscription = streamController.listen((comments) {
          updates.add(comments);
        });

        // Wait for initial empty state
        await Future.delayed(const Duration(milliseconds: 100));

        // Act - Add comments
        for (int i = 0; i < 3; i++) {
          await repository.addComment(
            recipeId: recipeId,
            userId: userId,
            content: 'Realtime comment $i',
          );
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Assert - Received updates
        expect(updates.length, greaterThanOrEqualTo(3));
        expect(updates.last.length, equals(3));

        // Cleanup
        await subscription.cancel();
      });
    });
  });
}
