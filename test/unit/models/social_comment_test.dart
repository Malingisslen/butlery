// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/social/social_comment.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('SocialComment', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final createdAt = DateTime.now();

        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Fantastiskt recept! Perfekt för helgmys.',
          createdAt: createdAt,
        );

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals('recipe_456'));
        expect(comment.authorId, equals('user_789'));
        expect(
            comment.text, equals('Fantastiskt recept! Perfekt för helgmys.'));
        expect(comment.createdAt, equals(createdAt));
        expect(comment.parentCommentId, isNull);
        expect(comment.isLiked, isFalse);
        expect(comment.likeCount, equals(0));
      });

      test('should create with all parameters', () {
        final createdAt = DateTime.now();

        final comment = SocialComment(
          id: 'comment_124',
          recipeId: 'recipe_456',
          authorId: 'user_790',
          text: 'Instämmer! Provade det igår.',
          createdAt: createdAt,
          parentCommentId: 'comment_123',
          isLiked: true,
          likeCount: 15,
        );

        expect(comment.parentCommentId, equals('comment_123'));
        expect(comment.isLiked, isTrue);
        expect(comment.likeCount, equals(15));
      });
    });

    group('Factory Methods', () {
      test('should create from Firestore data', () {
        final firestoreData = {
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'text': 'Great recipe!',
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1, 12, 0)),
          'parentCommentId': 'comment_001',
          'isLiked': true,
          'likeCount': 10,
        };

        final comment =
            SocialComment.fromFirestore('comment_123', firestoreData);

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals('recipe_456'));
        expect(comment.authorId, equals('user_789'));
        expect(comment.text, equals('Great recipe!'));
        expect(comment.createdAt.year, equals(2025));
        expect(comment.createdAt.month, equals(1));
        expect(comment.parentCommentId, equals('comment_001'));
        expect(comment.isLiked, isTrue);
        expect(comment.likeCount, equals(10));
      });

      test('should handle missing optional fields in Firestore', () {
        final firestoreData = {
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'text': 'Nice!',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };

        final comment =
            SocialComment.fromFirestore('comment_123', firestoreData);

        expect(comment.parentCommentId, isNull);
        expect(comment.isLiked, isFalse);
        expect(comment.likeCount, equals(0));
      });

      test('should handle null required fields with defaults', () {
        final firestoreData = <String, dynamic>{
          'createdAt': Timestamp.fromDate(DateTime.now()),
        };

        final comment =
            SocialComment.fromFirestore('comment_123', firestoreData);

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals(''));
        expect(comment.authorId, equals(''));
        expect(comment.text, equals(''));
        expect(comment.isLiked, isFalse);
        expect(comment.likeCount, equals(0));
      });

      test('should create from JSON', () {
        final jsonData = {
          'id': 'comment_123',
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'text': 'Excellent!',
          'createdAt': '2025-01-01T12:00:00.000',
          'parentCommentId': 'comment_001',
          'isLiked': true,
          'likeCount': 5,
        };

        final comment = SocialComment.fromJson(jsonData);

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals('recipe_456'));
        expect(comment.authorId, equals('user_789'));
        expect(comment.text, equals('Excellent!'));
        expect(comment.createdAt.year, equals(2025));
        expect(comment.parentCommentId, equals('comment_001'));
        expect(comment.isLiked, isTrue);
        expect(comment.likeCount, equals(5));
      });

      test('should handle null fields in JSON', () {
        final jsonData = {
          'id': 'comment_123',
          'recipeId': null,
          'authorId': null,
          'text': null,
          'createdAt': '2025-01-01T12:00:00.000',
          'parentCommentId': null,
          'isLiked': null,
          'likeCount': null,
        };

        final comment = SocialComment.fromJson(jsonData);

        expect(comment.recipeId, equals(''));
        expect(comment.authorId, equals(''));
        expect(comment.text, equals(''));
        expect(comment.parentCommentId, isNull);
        expect(comment.isLiked, isFalse);
        expect(comment.likeCount, equals(0));
      });
    });

    group('Threading Support', () {
      test('should identify top-level comment', () {
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Top level comment',
          createdAt: DateTime.now(),
          parentCommentId: null,
        );

        expect(comment.parentCommentId, isNull);
      });

      test('should identify reply comment', () {
        final reply = SocialComment(
          id: 'comment_124',
          recipeId: 'recipe_456',
          authorId: 'user_790',
          text: 'This is a reply',
          createdAt: DateTime.now(),
          parentCommentId: 'comment_123',
        );

        expect(reply.parentCommentId, equals('comment_123'));
      });

      test('should support nested threading', () {
        // Create a chain of comments
        final topLevel = SocialComment(
          id: 'comment_1',
          recipeId: 'recipe_456',
          authorId: 'user_1',
          text: 'Original comment',
          createdAt: DateTime.now(),
        );

        final firstReply = SocialComment(
          id: 'comment_2',
          recipeId: 'recipe_456',
          authorId: 'user_2',
          text: 'Reply to original',
          createdAt: DateTime.now(),
          parentCommentId: topLevel.id,
        );

        final secondReply = SocialComment(
          id: 'comment_3',
          recipeId: 'recipe_456',
          authorId: 'user_3',
          text: 'Reply to reply',
          createdAt: DateTime.now(),
          parentCommentId: firstReply.id,
        );

        expect(topLevel.parentCommentId, isNull);
        expect(firstReply.parentCommentId, equals('comment_1'));
        expect(secondReply.parentCommentId, equals('comment_2'));
      });
    });

    group('Mutable Like Tracking', () {
      test('should track like state changes', () {
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Test comment',
          createdAt: DateTime.now(),
        );

        expect(comment.isLiked, isFalse);
        expect(comment.likeCount, equals(0));

        // Simulate liking the comment
        comment.isLiked = true;
        comment.likeCount = 1;

        expect(comment.isLiked, isTrue);
        expect(comment.likeCount, equals(1));

        // Simulate more likes
        comment.likeCount = 10;
        expect(comment.likeCount, equals(10));

        // Simulate unliking
        comment.isLiked = false;
        comment.likeCount = 9;

        expect(comment.isLiked, isFalse);
        expect(comment.likeCount, equals(9));
      });

      test('should maintain like state independently', () {
        final comment1 = SocialComment(
          id: 'comment_1',
          recipeId: 'recipe_456',
          authorId: 'user_1',
          text: 'Comment 1',
          createdAt: DateTime.now(),
          isLiked: true,
          likeCount: 5,
        );

        final comment2 = SocialComment(
          id: 'comment_2',
          recipeId: 'recipe_456',
          authorId: 'user_2',
          text: 'Comment 2',
          createdAt: DateTime.now(),
          isLiked: false,
          likeCount: 3,
        );

        expect(comment1.isLiked, isTrue);
        expect(comment1.likeCount, equals(5));
        expect(comment2.isLiked, isFalse);
        expect(comment2.likeCount, equals(3));

        // Change one comment's state
        comment1.isLiked = false;
        comment1.likeCount = 4;

        // Other comment should remain unchanged
        expect(comment2.isLiked, isFalse);
        expect(comment2.likeCount, equals(3));
      });
    });

    group('Serialization', () {
      test('should serialize to Firestore format', () {
        final createdAt = DateTime(2025, 1, 1, 12, 0);
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Great recipe!',
          createdAt: createdAt,
          parentCommentId: 'comment_001',
          isLiked: true,
          likeCount: 10,
        );

        final firestore = comment.toFirestore();

        expect(firestore['recipeId'], equals('recipe_456'));
        expect(firestore['authorId'], equals('user_789'));
        expect(firestore['text'], equals('Great recipe!'));
        expect(firestore['createdAt'], isA<Timestamp>());
        expect(
            (firestore['createdAt'] as Timestamp).toDate(), equals(createdAt));
        expect(firestore['parentCommentId'], equals('comment_001'));
        expect(firestore['isLiked'], isTrue);
        expect(firestore['likeCount'], equals(10));
        expect(firestore.containsKey('id'),
            isFalse); // ID is not included in Firestore
      });

      test('should serialize to JSON format', () {
        final createdAt = DateTime(2025, 1, 1, 12, 0);
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Amazing!',
          createdAt: createdAt,
          parentCommentId: null,
          isLiked: false,
          likeCount: 0,
        );

        final json = comment.toJson();

        expect(json['id'], equals('comment_123'));
        expect(json['recipeId'], equals('recipe_456'));
        expect(json['authorId'], equals('user_789'));
        expect(json['text'], equals('Amazing!'));
        expect(json['createdAt'], equals('2025-01-01T12:00:00.000'));
        expect(json['parentCommentId'], isNull);
        expect(json['isLiked'], isFalse);
        expect(json['likeCount'], equals(0));
      });

      test('should round-trip through Firestore', () {
        final original = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Delicious!',
          createdAt: DateTime(2025, 1, 1, 12, 0),
          parentCommentId: 'comment_001',
          isLiked: true,
          likeCount: 5,
        );

        final firestore = original.toFirestore();
        final restored = SocialComment.fromFirestore(original.id, firestore);

        expect(restored.id, equals(original.id));
        expect(restored.recipeId, equals(original.recipeId));
        expect(restored.authorId, equals(original.authorId));
        expect(restored.text, equals(original.text));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.parentCommentId, equals(original.parentCommentId));
        expect(restored.isLiked, equals(original.isLiked));
        expect(restored.likeCount, equals(original.likeCount));
      });

      test('should round-trip through JSON', () {
        final original = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Perfect!',
          createdAt: DateTime(2025, 1, 1, 12, 0),
          parentCommentId: null,
          isLiked: false,
          likeCount: 0,
        );

        final json = original.toJson();
        final restored = SocialComment.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.recipeId, equals(original.recipeId));
        expect(restored.authorId, equals(original.authorId));
        expect(restored.text, equals(original.text));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.parentCommentId, equals(original.parentCommentId));
        expect(restored.isLiked, equals(original.isLiked));
        expect(restored.likeCount, equals(original.likeCount));
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final comment1 = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Text 1',
          createdAt: DateTime(2025, 1, 1),
        );

        final comment2 = SocialComment(
          id: 'comment_123',
          recipeId: 'different_recipe',
          authorId: 'different_user',
          text: 'Different text',
          createdAt: DateTime(2025, 2, 1),
          isLiked: true,
          likeCount: 100,
        );

        expect(comment1, equals(comment2));
        expect(comment1.hashCode, equals(comment2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        final comment1 = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Same text',
          createdAt: DateTime.now(),
        );

        final comment2 = SocialComment(
          id: 'comment_456',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Same text',
          createdAt: DateTime.now(),
        );

        expect(comment1, isNot(equals(comment2)));
        expect(comment1.hashCode, isNot(equals(comment2.hashCode)));
      });
    });

    group('Edge Cases', () {
      test('should handle empty text', () {
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: '',
          createdAt: DateTime.now(),
        );

        expect(comment.text, equals(''));
      });

      test('should handle Swedish text', () {
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text:
              'Jättegott! Åt detta igår med familjen. Önskar fler såna recept!',
          createdAt: DateTime.now(),
        );

        expect(
            comment.text,
            equals(
                'Jättegott! Åt detta igår med familjen. Önskar fler såna recept!'));
      });

      test('should handle emoji in text', () {
        final comment = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Så gott! 😍🍽️👨‍🍳',
          createdAt: DateTime.now(),
        );

        expect(comment.text, equals('Så gott! 😍🍽️👨‍🍳'));
      });

      test('should handle orphaned reply (parent deleted)', () {
        final orphanedReply = SocialComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          text: 'Reply to deleted comment',
          createdAt: DateTime.now(),
          parentCommentId: 'deleted_comment_999',
        );

        expect(orphanedReply.parentCommentId, equals('deleted_comment_999'));
      });

      test('should handle null timestamp with fallback to now', () {
        final firestoreData = {
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'text': 'Test',
          'createdAt': null,
        };

        final beforeCreation = DateTime.now();
        final comment =
            SocialComment.fromFirestore('comment_123', firestoreData);
        final afterCreation = DateTime.now();

        expect(
            comment.createdAt.isAfter(beforeCreation) ||
                comment.createdAt.isAtSameMomentAs(beforeCreation),
            isTrue);
        expect(
            comment.createdAt.isBefore(afterCreation) ||
                comment.createdAt.isAtSameMomentAs(afterCreation),
            isTrue);
      });
    });
  });
}
