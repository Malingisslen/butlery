/// Comprehensive unit tests for FirebaseCommentsRepository.
///
/// Tests recipe comment system functionality including threaded discussions,
/// like/unlike features, permission validation, and comment statistics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseCommentsRepository - Comment System', () {
    late FirebaseCommentsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: 'user-123', displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseCommentsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should allow user to create comment as themselves', () async {
        // Arrange
        final comment = _createComment('recipe-1', 'user-123');

        // Act
        final canCreate =
            await repository.validateCreatePermission('user-123', comment);

        // Assert
        expect(canCreate, isTrue);
      });

      test('should reject user from creating comment as another user',
          () async {
        // Arrange
        final comment = _createComment('recipe-1', 'other-user');

        // Act
        final canCreate =
            await repository.validateCreatePermission('user-123', comment);

        // Assert
        expect(canCreate, isFalse);
      });

      test('should allow all authenticated users to read comments', () async {
        // Arrange
        final comment = _createComment('recipe-1', 'other-user');

        // Act
        final canRead = await repository.validateReadPermission(
            'user-123', 'comment-1', comment);

        // Assert
        expect(canRead, isTrue); // Comments are public
      });

      test('should allow user to update their own comment', () async {
        // Arrange
        final comment = _createComment('recipe-1', 'user-123');

        // Act
        final canUpdate = await repository.validateUpdatePermission(
            'user-123', 'comment-1', comment);

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject user from updating another user\'s comment',
          () async {
        // Arrange
        final comment = _createComment('recipe-1', 'other-user');

        // Act
        final canUpdate = await repository.validateUpdatePermission(
            'user-123', 'comment-1', comment);

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow user to delete their own comment', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-123', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act
        final canDelete =
            await repository.validateDeletePermission('user-123', commentId);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject user from deleting another user\'s comment',
          () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act
        final canDelete =
            await repository.validateDeletePermission('user-123', commentId);

        // Assert
        expect(canDelete, isFalse);
      });

      test('should reject delete when comment does not exist', () async {
        // Act
        final canDelete = await repository.validateDeletePermission(
            'user-123', 'nonexistent');

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Add Comment', () {
      test('should add top-level comment successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const userId = 'user-123';
        const content = 'Great recipe!';

        // Act
        final result = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
        );

        // Assert
        expect(result.recipeId, equals(recipeId));
        expect(result.authorId, equals(userId));
        expect(result.text, equals(content));
        expect(result.parentCommentId, isNull); // Top-level comment
        expect(result.likesCount, equals(0));
      },
          skip:
              'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should add reply comment successfully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const parentCommentId = 'parent-1';
        const userId = 'user-123';
        const content = 'I agree!';

        // Act
        final result = await repository.addComment(
          recipeId: recipeId,
          userId: userId,
          content: content,
          parentCommentId: parentCommentId,
        );

        // Assert
        expect(result.recipeId, equals(recipeId));
        expect(result.parentCommentId, equals(parentCommentId)); // Reply
      },
          skip:
              'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should reject empty comment content', () async {
        // Act & Assert
        expect(
          () => repository.addComment(
            recipeId: 'recipe-1',
            userId: 'user-123',
            content: '',
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should reject whitespace-only comment content', () async {
        // Act & Assert
        expect(
          () => repository.addComment(
            recipeId: 'recipe-1',
            userId: 'user-123',
            content: '   ',
          ),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should reject user from creating comment as another user',
          () async {
        // Act & Assert
        expect(
          () => repository.addComment(
            recipeId: 'recipe-1',
            userId: 'other-user', // Trying to create comment as someone else
            content: 'Test comment',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Update Comment', () {
      test('should update comment content successfully', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-123', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        const newContent = 'Updated comment text';

        // Act
        await repository.updateComment(commentId, newContent);

        // Assert
        final doc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(doc.data()!['text'], equals(newContent));
      },
          skip:
              'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should reject empty update content', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-123', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act & Assert
        expect(
          () => repository.updateComment(commentId, ''),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('should reject user from updating another user\'s comment',
          () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act & Assert
        expect(
          () => repository.updateComment(commentId, 'Updated text'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject update when comment does not exist', () async {
        // Act & Assert
        expect(
          () => repository.updateComment('nonexistent', 'Updated text'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Delete Comment', () {
      test('should delete comment successfully', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-123', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Verify comment exists before deletion
        var doc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(doc.exists, isTrue);

        // Act
        await repository.deleteComment(commentId);

        // Assert
        doc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        expect(doc.exists, isFalse);
      });

      test('should reject user from deleting another user\'s comment',
          () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act & Assert
        expect(
          () => repository.deleteComment(commentId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject delete when comment does not exist', () async {
        // Act & Assert
        expect(
          () => repository.deleteComment('nonexistent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Get Comments', () {
      test('should retrieve all comments for a recipe', () async {
        // Arrange
        const recipeId = 'recipe-1';
        await _seedComment(fakeFirestore, 'comment-1',
            _createComment(recipeId, 'user-1', id: 'comment-1'));
        await _seedComment(fakeFirestore, 'comment-2',
            _createComment(recipeId, 'user-2', id: 'comment-2'));
        await _seedComment(fakeFirestore, 'comment-3',
            _createComment(recipeId, 'user-3', id: 'comment-3'));

        // Act
        final comments = await repository.getCommentsForRecipe(recipeId);

        // Assert
        expect(comments.length, equals(3));
        expect(comments.every((c) => c.recipeId == recipeId), isTrue);
      });

      test('should return empty list when no comments exist', () async {
        // Act
        final comments =
            await repository.getCommentsForRecipe('recipe-with-no-comments');

        // Assert
        expect(comments, isEmpty);
      });

      test('should respect 50 comment limit', () async {
        // Arrange - Create more than 50 comments
        const recipeId = 'recipe-1';
        for (int i = 0; i < 60; i++) {
          await _seedComment(
            fakeFirestore,
            'comment-$i',
            _createComment(recipeId, 'user-$i', id: 'comment-$i'),
          );
        }

        // Act
        final comments = await repository.getCommentsForRecipe(recipeId);

        // Assert
        expect(comments.length, equals(50)); // Enforces limit
      });

      test('should include both top-level and reply comments', () async {
        // Arrange
        const recipeId = 'recipe-1';
        await _seedComment(fakeFirestore, 'comment-1',
            _createComment(recipeId, 'user-1', id: 'comment-1'));
        await _seedComment(
            fakeFirestore,
            'reply-1',
            _createComment(recipeId, 'user-2',
                id: 'reply-1', parentId: 'comment-1'));

        // Act
        final comments = await repository.getCommentsForRecipe(recipeId);

        // Assert
        expect(comments.length, equals(2)); // Both top-level and reply
        final topLevel = comments.where((c) => c.parentCommentId == null);
        final replies = comments.where((c) => c.parentCommentId != null);
        expect(topLevel.length, equals(1));
        expect(replies.length, equals(1));
      });
    });

    group('Get Replies', () {
      test('should retrieve all replies to a comment', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const parentCommentId = 'comment-1';
        await _seedComment(fakeFirestore, parentCommentId,
            _createComment(recipeId, 'user-1', id: parentCommentId));
        await _seedComment(
            fakeFirestore,
            'reply-1',
            _createComment(recipeId, 'user-2',
                id: 'reply-1', parentId: parentCommentId));
        await _seedComment(
            fakeFirestore,
            'reply-2',
            _createComment(recipeId, 'user-3',
                id: 'reply-2', parentId: parentCommentId));

        // Act
        final replies = await repository.getReplies(parentCommentId);

        // Assert
        expect(replies.length, equals(2));
        expect(
            replies.every((r) => r.parentCommentId == parentCommentId), isTrue);
      });

      test('should return empty list when comment has no replies', () async {
        // Act
        final replies = await repository.getReplies('comment-with-no-replies');

        // Assert
        expect(replies, isEmpty);
      });
    });

    group('Toggle Comment Like', () {
      test('should like a comment successfully', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        const userId = 'user-123';

        // Act
        await repository.toggleCommentLike(commentId, userId);

        // Assert - Verify like subcollection
        final likeDoc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .get();
        expect(likeDoc.exists, isTrue);
        expect(likeDoc.data()!['userId'], equals(userId));
      },
          skip:
              'FakeFirebaseFirestore FieldValue.increment limitation - tested in integration tests');

      test('should unlike a comment successfully', () async {
        // Arrange
        const commentId = 'comment-1';
        const userId = 'user-123';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Seed existing like
        await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .set({'userId': userId, 'likedAt': Timestamp.now()});

        // Act
        await repository.toggleCommentLike(commentId, userId);

        // Assert - Verify like was removed
        final likeDoc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .get();
        expect(likeDoc.exists, isFalse);
      },
          skip:
              'FakeFirebaseFirestore FieldValue.increment limitation - tested in integration tests');

      test('should reject user from toggling like as another user', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act & Assert
        expect(
          () => repository.toggleCommentLike(
              commentId, 'other-user'), // Trying to like as someone else
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject toggle when comment does not exist', () async {
        // Act & Assert
        expect(
          () => repository.toggleCommentLike('nonexistent', 'user-123'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Like Status', () {
      test('should get like count for a comment', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-1', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);
        await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .update({'likesCount': 5});

        // Act
        final count = await repository.getCommentLikeCount(commentId);

        // Assert
        expect(count, equals(5));
      });

      test('should return 0 when comment has no likes', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-1', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act
        final count = await repository.getCommentLikeCount(commentId);

        // Assert
        expect(count, equals(0));
      });

      test('should check if user has liked a comment', () async {
        // Arrange
        const commentId = 'comment-1';
        const userId = 'user-123';
        final comment = _createComment('recipe-1', 'other-user', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Seed user like
        await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .collection('likes')
            .doc(userId)
            .set({'userId': userId, 'likedAt': Timestamp.now()});

        // Act
        final hasLiked =
            await repository.hasUserLikedComment(commentId, userId);

        // Assert
        expect(hasLiked, isTrue);
      });

      test('should return false when user has not liked comment', () async {
        // Arrange
        const commentId = 'comment-1';
        final comment = _createComment('recipe-1', 'user-1', id: commentId);
        await _seedComment(fakeFirestore, commentId, comment);

        // Act
        final hasLiked =
            await repository.hasUserLikedComment(commentId, 'user-123');

        // Assert
        expect(hasLiked, isFalse);
      });
    });

    group('Comments Stream', () {
      test('should stream comments for a recipe', () async {
        // Arrange
        const recipeId = 'recipe-1';
        await _seedComment(fakeFirestore, 'comment-1',
            _createComment(recipeId, 'user-1', id: 'comment-1'));
        await _seedComment(fakeFirestore, 'comment-2',
            _createComment(recipeId, 'user-2', id: 'comment-2'));

        // Act
        final stream = repository.getCommentsStream(recipeId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<RecipeComment>>((comments) {
            return comments.length == 2 &&
                comments.every((c) => c.recipeId == recipeId);
          })),
        );
      });

      test('should respect 50 comment limit in stream', () async {
        // Arrange - Create more than 50 comments
        const recipeId = 'recipe-1';
        for (int i = 0; i < 60; i++) {
          await _seedComment(
            fakeFirestore,
            'comment-$i',
            _createComment(recipeId, 'user-$i', id: 'comment-$i'),
          );
        }

        // Act
        final stream = repository.getCommentsStream(recipeId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<RecipeComment>>((comments) {
            return comments.length == 50; // Enforces limit
          })),
        );
      });
    });

    group('Comment Statistics', () {
      test('should calculate statistics correctly', () async {
        // Arrange
        const recipeId = 'recipe-1';
        final now = DateTime.now();

        // Top-level comments
        await _seedComment(
            fakeFirestore,
            'comment-1',
            _createComment(recipeId, 'user-1',
                id: 'comment-1',
                createdAt: now.subtract(const Duration(hours: 3))));
        await _seedComment(
            fakeFirestore,
            'comment-2',
            _createComment(recipeId, 'user-2',
                id: 'comment-2',
                createdAt: now.subtract(const Duration(hours: 2))));

        // Replies
        await _seedComment(
            fakeFirestore,
            'reply-1',
            _createComment(recipeId, 'user-3',
                id: 'reply-1',
                parentId: 'comment-1',
                createdAt: now.subtract(const Duration(hours: 1))));
        await _seedComment(
            fakeFirestore,
            'reply-2',
            _createComment(recipeId, 'user-4',
                id: 'reply-2', parentId: 'comment-1', createdAt: now));

        // Add likes
        await fakeFirestore
            .collection('recipe_comments')
            .doc('comment-1')
            .update({'likesCount': 3});
        await fakeFirestore
            .collection('recipe_comments')
            .doc('comment-2')
            .update({'likesCount': 2});
        await fakeFirestore
            .collection('recipe_comments')
            .doc('reply-1')
            .update({'likesCount': 1});

        // Act
        final stats = await repository.getCommentStatistics(recipeId);

        // Assert
        expect(stats.totalComments, equals(2)); // Top-level only
        expect(stats.totalReplies, equals(2));
        expect(stats.totalLikes, equals(6)); // 3+2+1
        expect(stats.lastCommentAt, isNotNull);
        expect(
            stats.lastCommentAt!
                .isAfter(now.subtract(const Duration(seconds: 5))),
            isTrue); // Most recent
      });

      test('should handle empty recipe with no comments', () async {
        // Act
        final stats =
            await repository.getCommentStatistics('recipe-with-no-comments');

        // Assert
        expect(stats.totalComments, equals(0));
        expect(stats.totalReplies, equals(0));
        expect(stats.totalLikes, equals(0));
        expect(stats.lastCommentAt, isNull);
      });

      test('should respect 500 comment limit for statistics', () async {
        // Arrange - Create more than 500 comments
        const recipeId = 'recipe-1';
        for (int i = 0; i < 600; i++) {
          await _seedComment(
            fakeFirestore,
            'comment-$i',
            _createComment(recipeId, 'user-$i', id: 'comment-$i'),
          );
        }

        // Act
        final stats = await repository.getCommentStatistics(recipeId);

        // Assert
        // Should process max 500 comments (though all are top-level in this test)
        expect(stats.totalComments, lessThanOrEqualTo(500));
      });
    });

    group('Comment Model Integration', () {
      test('should correctly serialize and deserialize comments', () async {
        // Arrange
        const commentId = 'comment-1';
        final originalComment =
            _createComment('recipe-1', 'user-123', id: commentId);
        await _seedComment(fakeFirestore, commentId, originalComment);

        // Act
        final doc = await fakeFirestore
            .collection('recipe_comments')
            .doc(commentId)
            .get();
        final retrievedComment = RecipeComment.fromMap(doc.id, doc.data()!);

        // Assert
        expect(retrievedComment.id, equals(originalComment.id));
        expect(retrievedComment.recipeId, equals(originalComment.recipeId));
        expect(retrievedComment.authorId, equals(originalComment.authorId));
        expect(retrievedComment.text, equals(originalComment.text));
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test comment
RecipeComment _createComment(
  String recipeId,
  String authorId, {
  String? id,
  String? parentId,
  DateTime? createdAt,
}) {
  return RecipeComment(
    id: id ?? 'comment-${DateTime.now().millisecondsSinceEpoch}',
    recipeId: recipeId,
    authorId: authorId,
    authorDisplayName: 'User $authorId',
    text: 'This is a test comment',
    createdAt: createdAt ?? DateTime.now(),
    parentCommentId: parentId,
  );
}

/// Seed comment into fake Firestore
Future<void> _seedComment(
  FakeFirebaseFirestore firestore,
  String commentId,
  RecipeComment comment,
) async {
  final data = {
    'recipeId': comment.recipeId,
    'authorId': comment.authorId,
    'authorDisplayName': comment.authorDisplayName,
    'authorAvatarUrl': comment.authorAvatarUrl,
    'text': comment.text,
    'createdAt': Timestamp.fromDate(comment.createdAt),
    'editedAt':
        comment.editedAt != null ? Timestamp.fromDate(comment.editedAt!) : null,
    'likesCount': comment.likesCount,
    'parentCommentId': comment.parentCommentId,
    'replyCount': comment.replyCount,
    'isDeleted': comment.isDeleted,
  };

  await firestore.collection('recipe_comments').doc(commentId).set(data);
}
