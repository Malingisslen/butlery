import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RecipeComment', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna Andersson',
          text: 'Fantastiskt recept!',
        );

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals('recipe_456'));
        expect(comment.authorId, equals('user_789'));
        expect(comment.authorDisplayName, equals('Anna Andersson'));
        expect(comment.text, equals('Fantastiskt recept!'));
        expect(comment.createdAt, isNotNull);
        expect(comment.editedAt, isNull);
        expect(comment.authorAvatarUrl, isNull);
        expect(comment.likesCount, equals(0));
        expect(comment.parentCommentId, isNull);
        expect(comment.replyCount, equals(0));
        expect(comment.isDeleted, isFalse);
      });

      test('should create with all parameters', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final editedTime = DateTime(2024, 1, 15, 12, 0);

        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna Andersson',
          authorAvatarUrl: 'https://example.com/avatar.jpg',
          text: 'Uppdaterad kommentar',
          createdAt: createdTime,
          editedAt: editedTime,
          likesCount: 2,
          parentCommentId: 'parent_comment_123',
          replyCount: 3,
          isDeleted: false,
        );

        expect(
            comment.authorAvatarUrl, equals('https://example.com/avatar.jpg'));
        expect(comment.createdAt, equals(createdTime));
        expect(comment.editedAt, equals(editedTime));
        expect(comment.likesCount, equals(2));
        expect(comment.likeCount, equals(2));
        expect(comment.parentCommentId, equals('parent_comment_123'));
        expect(comment.replyCount, equals(3));
      });

      test('should use current time when createdAt not provided', () {
        final beforeCreation = DateTime.now();

        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
        );

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

      test('should handle Swedish default values', () {
        // Test that Swedish characters work properly
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Åsa Öström',
          text: 'Jättegott med lingon och grädde!',
        );

        expect(comment.authorDisplayName, equals('Åsa Öström'));
        expect(comment.text, equals('Jättegott med lingon och grädde!'));
      });

      test('should validate threading with parentCommentId', () {
        final topLevel = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Original comment',
        );

        final reply = RecipeComment(
          id: 'comment_456',
          recipeId: 'recipe_456',
          authorId: 'user_999',
          authorDisplayName: 'Erik',
          text: 'Reply to original',
          parentCommentId: topLevel.id,
        );

        expect(topLevel.isTopLevel, isTrue);
        expect(reply.isTopLevel, isFalse);
        expect(reply.parentCommentId, equals(topLevel.id));
      });
    });

    group('Factory Methods', () {
      test('should create with auto-generated ID', () {
        final comment = RecipeComment.create(
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna Andersson',
          text: 'Great recipe!',
        );

        expect(comment.id, isNotEmpty);
        expect(comment.id.length, equals(36)); // UUID v4 length
        expect(comment.createdAt, isNotNull);
        expect(comment.editedAt, isNull);
        expect(comment.isDeleted, isFalse);
      });

      test('should create top-level comment', () {
        final comment = RecipeComment.create(
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          authorAvatarUrl: 'https://example.com/avatar.jpg',
          text: 'Top level comment',
        );

        expect(comment.parentCommentId, isNull);
        expect(comment.isTopLevel, isTrue);
        expect(
            comment.authorAvatarUrl, equals('https://example.com/avatar.jpg'));
      });

      test('should create reply comment', () {
        final comment = RecipeComment.create(
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Erik',
          text: 'This is a reply',
          parentCommentId: 'parent_123',
        );

        expect(comment.parentCommentId, equals('parent_123'));
        expect(comment.isTopLevel, isFalse);
      });
    });

    group('Like Count', () {
      test('should track likes count', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test comment',
          likesCount: 5,
        );

        expect(comment.likesCount, equals(5));
        expect(comment.likeCount, equals(5));
      });

      test('should default to zero likes', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test comment',
        );

        expect(comment.likesCount, equals(0));
        expect(comment.likeCount, equals(0));
      });

      test('should update likes count via copyWith', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test comment',
          likesCount: 0,
        );

        final liked = comment.copyWith(likesCount: 10);
        expect(liked.likeCount, equals(10));
        expect(comment.likeCount, equals(0)); // Original unchanged
      });
    });

    group('Comment Operations', () {
      late RecipeComment comment;

      setUp(() {
        comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Original text',
        );
      });

      test('should edit comment with timestamp', () {
        final beforeEdit = DateTime.now();
        final edited = comment.edit('Updated text');
        final afterEdit = DateTime.now();

        expect(edited.text, equals('Updated text'));
        expect(edited.editedAt, isNotNull);
        expect(
            edited.editedAt!.isAfter(beforeEdit) ||
                edited.editedAt!.isAtSameMomentAs(beforeEdit),
            isTrue);
        expect(
            edited.editedAt!.isBefore(afterEdit) ||
                edited.editedAt!.isAtSameMomentAs(afterEdit),
            isTrue);
        expect(edited.isEdited, isTrue);
      });

      test('should soft delete with Swedish message', () {
        final deleted = comment.delete();

        expect(deleted.isDeleted, isTrue);
        expect(deleted.text, equals('[Kommentar borttagen]'));
      });

      test('should check edit permissions', () {
        expect(comment.canBeEditedBy('user_789'), isTrue); // Author can edit
        expect(comment.canBeEditedBy('user_999'), isFalse); // Others cannot

        final deleted = comment.delete();
        expect(
            deleted.canBeEditedBy('user_789'), isFalse); // Cannot edit deleted
      });

      test('should validate edit status', () {
        expect(comment.isEdited, isFalse);

        final edited = comment.edit('New text');
        expect(edited.isEdited, isTrue);
      });

      test('should handle threading hierarchy', () {
        final parent = RecipeComment(
          id: 'parent_123',
          recipeId: 'recipe_456',
          authorId: 'user_1',
          authorDisplayName: 'User 1',
          text: 'Parent',
          replyCount: 2,
        );

        final child = RecipeComment(
          id: 'child_123',
          recipeId: 'recipe_456',
          authorId: 'user_2',
          authorDisplayName: 'User 2',
          text: 'Child',
          parentCommentId: parent.id,
        );

        expect(parent.hasReplies, isTrue);
        expect(parent.isTopLevel, isTrue);
        expect(child.hasReplies, isFalse);
        expect(child.isTopLevel, isFalse);
      });
    });

    group('Display Properties', () {
      test('should format Swedish time ago text', () {
        // Just now
        var comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
          createdAt: DateTime.now().subtract(Duration(seconds: 30)),
        );
        expect(comment.timeAgoText, equals('Nu'));

        // Minutes
        comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
          createdAt: DateTime.now().subtract(Duration(minutes: 30)),
        );
        expect(comment.timeAgoText, equals('30 min sedan'));

        // Hours
        comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
          createdAt: DateTime.now().subtract(Duration(hours: 5)),
        );
        expect(comment.timeAgoText, equals('5 tim sedan'));

        // Days
        comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
          createdAt: DateTime.now().subtract(Duration(days: 3)),
        );
        expect(comment.timeAgoText, equals('3 dagar sedan'));

        // BUT-1047: past 7-day window, ContextualTimeFormatter.standard
        // promotes to absolute date (yMMMd). The "2 veckor sedan" branch
        // belongs to the legacy TimeAgoFormatter behaviour; pin the new
        // promoted-date contract here instead — exact match is fragile
        // (locale + clock-dependent), so assert the promoted-format shape
        // (4-digit year + comma).
        comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
          createdAt: DateTime.now().subtract(Duration(days: 14)),
        );
        expect(comment.timeAgoText, isNot(contains('sedan')));
        expect(comment.timeAgoText, matches(RegExp(r'\d{4}$')));
        expect(comment.timeAgoText, contains(','));
      });

      test('should check top-level vs reply status', () {
        final topLevel = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Top level',
        );

        final reply = RecipeComment(
          id: 'comment_456',
          recipeId: 'recipe_456',
          authorId: 'user_999',
          authorDisplayName: 'Erik',
          text: 'Reply',
          parentCommentId: 'comment_123',
        );

        expect(topLevel.isTopLevel, isTrue);
        expect(reply.isTopLevel, isFalse);
      });

      test('should verify has replies indicator', () {
        final withoutReplies = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'No replies',
          replyCount: 0,
        );

        final withReplies = RecipeComment(
          id: 'comment_456',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Has replies',
          replyCount: 5,
        );

        expect(withoutReplies.hasReplies, isFalse);
        expect(withReplies.hasReplies, isTrue);
      });

      test('should display deleted content properly', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Original',
        );

        final deleted = comment.delete();

        expect(deleted.text, equals('[Kommentar borttagen]'));
        expect(deleted.isDeleted, isTrue);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON', () {
        final createdTime = DateTime(2024, 1, 15, 10, 30);
        final editedTime = DateTime(2024, 1, 15, 12, 0);

        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          authorAvatarUrl: 'https://example.com/avatar.jpg',
          text: 'Test comment',
          createdAt: createdTime,
          editedAt: editedTime,
          likesCount: 2,
          parentCommentId: 'parent_123',
          replyCount: 3,
          isDeleted: false,
        );

        final json = comment.toJson();

        expect(json['id'], equals('comment_123'));
        expect(json['recipeId'], equals('recipe_456'));
        expect(json['authorId'], equals('user_789'));
        expect(json['authorDisplayName'], equals('Anna'));
        expect(
            json['authorAvatarUrl'], equals('https://example.com/avatar.jpg'));
        expect(json['text'], equals('Test comment'));
        expect(json['createdAt'], equals(createdTime.toIso8601String()));
        expect(json['editedAt'], equals(editedTime.toIso8601String()));
        expect(json['likesCount'], equals(2));
        expect(json['parentCommentId'], equals('parent_123'));
        expect(json['replyCount'], equals(3));
        expect(json['isDeleted'], isFalse);
      });

      test('should deserialize from JSON', () {
        final json = {
          'id': 'comment_123',
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'authorDisplayName': 'Anna',
          'authorAvatarUrl': 'https://example.com/avatar.jpg',
          'text': 'Test comment',
          'createdAt': '2024-01-15T10:30:00.000',
          'editedAt': '2024-01-15T12:00:00.000',
          'likesCount': 2,
          'parentCommentId': 'parent_123',
          'replyCount': 3,
          'isDeleted': false,
        };

        final comment = RecipeComment.fromJson(json);

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals('recipe_456'));
        expect(comment.authorId, equals('user_789'));
        expect(comment.authorDisplayName, equals('Anna'));
        expect(
            comment.authorAvatarUrl, equals('https://example.com/avatar.jpg'));
        expect(comment.text, equals('Test comment'));
        expect(comment.createdAt, equals(DateTime(2024, 1, 15, 10, 30)));
        expect(comment.editedAt, equals(DateTime(2024, 1, 15, 12, 0)));
        expect(comment.likesCount, equals(2));
        expect(comment.parentCommentId, equals('parent_123'));
        expect(comment.replyCount, equals(3));
        expect(comment.isDeleted, isFalse);
      });

      test('should round-trip JSON serialization', () {
        final original = RecipeComment.create(
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test comment',
        );

        final json = original.toJson();
        final deserialized = RecipeComment.fromJson(json);

        expect(deserialized.id, equals(original.id));
        expect(deserialized.recipeId, equals(original.recipeId));
        expect(deserialized.authorId, equals(original.authorId));
        expect(deserialized.text, equals(original.text));
      });

      test('should handle null editedAt in JSON', () {
        final json = {
          'id': 'comment_123',
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'authorDisplayName': 'Anna',
          'text': 'Test',
          'createdAt': '2024-01-15T10:30:00.000',
          'editedAt': null,
          'likesCount': 0,
          'parentCommentId': null,
          'replyCount': 0,
          'isDeleted': false,
        };

        final comment = RecipeComment.fromJson(json);

        expect(comment.editedAt, isNull);
        expect(comment.isEdited, isFalse);
      });
    });

    group('Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
        );

        final firestore = comment.toFirestore();

        expect(firestore['recipeId'], equals('recipe_456'));
        expect(firestore['authorId'], equals('user_789'));
        expect(firestore['authorDisplayName'], equals('Anna'));
        expect(firestore['text'], equals('Test'));
        expect(firestore['likesCount'], equals(0));
        expect(firestore['parentCommentId'], isNull);
        expect(firestore['replyCount'], equals(0));
        expect(firestore['isDeleted'], isFalse);
        expect(firestore.containsKey('id'), isFalse); // ID is document ID
      });

      test('should deserialize from map', () {
        final data = {
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'authorDisplayName': 'Anna',
          'authorAvatarUrl': 'https://example.com/avatar.jpg',
          'text': 'Test comment',
          'createdAt': DateTime(2024, 1, 15, 10, 30),
          'editedAt': DateTime(2024, 1, 15, 12, 0),
          'likesCount': 1,
          'parentCommentId': 'parent_123',
          'replyCount': 2,
          'isDeleted': false,
        };

        final comment = RecipeComment.fromMap('comment_123', data);

        expect(comment.id, equals('comment_123'));
        expect(comment.recipeId, equals('recipe_456'));
        expect(comment.authorId, equals('user_789'));
        expect(comment.authorDisplayName, equals('Anna'));
        expect(comment.text, equals('Test comment'));
      });

      test('should handle various timestamp formats', () {
        // DateTime format
        var data = {
          'recipeId': 'r1',
          'authorId': 'u1',
          'authorDisplayName': 'A',
          'text': 'T',
          'createdAt': DateTime(2024, 1, 15)
        };
        var comment = RecipeComment.fromMap('c1', data);
        expect(comment.createdAt, equals(DateTime(2024, 1, 15)));

        // Milliseconds format
        data = {
          'recipeId': 'r1',
          'authorId': 'u1',
          'authorDisplayName': 'A',
          'text': 'T',
          'createdAt': 1705305600000
        }; // 2024-01-15 00:00:00 UTC
        comment = RecipeComment.fromMap('c1', data);
        expect(comment.createdAt.year, equals(2024));

        // Null/missing format (uses current time)
        data = {
          'recipeId': 'r1',
          'authorId': 'u1',
          'authorDisplayName': 'A',
          'text': 'T'
        };
        final beforeParse = DateTime.now();
        comment = RecipeComment.fromMap('c1', data);
        final afterParse = DateTime.now();
        expect(
            comment.createdAt.isAfter(beforeParse) ||
                comment.createdAt.isAtSameMomentAs(beforeParse),
            isTrue);
        expect(
            comment.createdAt.isBefore(afterParse) ||
                comment.createdAt.isAtSameMomentAs(afterParse),
            isTrue);
      });

      test('should provide defaults for missing fields', () {
        final minimalData = {
          'recipeId': 'recipe_456',
          'authorId': 'user_789',
          'text': 'Test',
        };

        final comment = RecipeComment.fromMap('comment_123', minimalData);

        expect(
            comment.authorDisplayName, equals('?')); // Language-neutral default
        expect(comment.authorAvatarUrl, isNull);
        expect(comment.likesCount, equals(0));
        expect(comment.replyCount, equals(0));
        expect(comment.isDeleted, isFalse);
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when IDs match', () {
        final comment1 = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Text 1',
        );

        final comment2 = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_999',
          authorId: 'user_999',
          authorDisplayName: 'Erik',
          text: 'Text 2',
        );

        expect(comment1, equals(comment2));
        expect(comment1.hashCode, equals(comment2.hashCode));
      });

      test('should not be equal when IDs differ', () {
        final comment1 = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Text',
        );

        final comment2 = RecipeComment(
          id: 'comment_456',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Text',
        );

        expect(comment1, isNot(equals(comment2)));
      });

      test('should be equal to itself', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Text',
        );

        expect(comment, equals(comment));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna Andersson',
          text: 'Great recipe!',
          likesCount: 3,
          replyCount: 5,
        );

        final str = comment.toString();

        expect(str, contains('comment_123'));
        expect(str, contains('Anna Andersson'));
        expect(str, contains('3')); // Like count
        expect(str, contains('5')); // Reply count
      });
    });

    group('Edge Cases', () {
      test('should handle very long comment text', () {
        final longText = 'A' * 5000;
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: longText,
        );

        expect(comment.text, equals(longText));
        expect(comment.text.length, equals(5000));
      });

      test('should handle empty text', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: '',
        );

        expect(comment.text, isEmpty);
      });

      test('should handle deep threading levels', () {
        final level1 = RecipeComment(
          id: 'level1',
          recipeId: 'recipe_456',
          authorId: 'user_1',
          authorDisplayName: 'User 1',
          text: 'Level 1',
        );

        final level2 = RecipeComment(
          id: 'level2',
          recipeId: 'recipe_456',
          authorId: 'user_2',
          authorDisplayName: 'User 2',
          text: 'Level 2',
          parentCommentId: level1.id,
        );

        final level3 = RecipeComment(
          id: 'level3',
          recipeId: 'recipe_456',
          authorId: 'user_3',
          authorDisplayName: 'User 3',
          text: 'Level 3',
          parentCommentId: level2.id,
        );

        expect(level1.isTopLevel, isTrue);
        expect(level2.isTopLevel, isFalse);
        expect(level3.isTopLevel, isFalse);
        expect(level3.parentCommentId, equals(level2.id));
      });

      test('should handle self-replies', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Original',
        );

        final selfReply = RecipeComment(
          id: 'comment_456',
          recipeId: 'recipe_456',
          authorId: 'user_789', // Same author
          authorDisplayName: 'Anna',
          text: 'Reply to myself',
          parentCommentId: comment.id,
        );

        expect(selfReply.authorId, equals(comment.authorId));
        expect(selfReply.parentCommentId, equals(comment.id));
      });

      test('should handle multiple edits', () {
        var comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Original',
        );

        comment = comment.edit('Edit 1');
        expect(comment.text, equals('Edit 1'));
        expect(comment.isEdited, isTrue);

        comment = comment.edit('Edit 2');
        expect(comment.text, equals('Edit 2'));
        expect(comment.isEdited, isTrue);

        comment = comment.edit('Edit 3');
        expect(comment.text, equals('Edit 3'));
        expect(comment.isEdited, isTrue);
      });

      test('should handle high like counts', () {
        // Like count is now maintained by repository, model just stores the count
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Test',
          likesCount: 100,
        );

        expect(comment.likeCount, equals(100));
        expect(comment.likesCount, equals(100));
      });

      test('should handle Swedish characters', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Åsa Öström',
          text: 'Jättegott! Älskar köttbullar med lingonsylt och gräddsås.',
        );

        expect(comment.authorDisplayName, equals('Åsa Öström'));
        expect(comment.text, contains('Jättegott'));
        expect(comment.text, contains('Älskar'));
        expect(comment.text, contains('köttbullar'));
        expect(comment.text, contains('lingonsylt'));
        expect(comment.text, contains('gräddsås'));
      });

      test('should handle emoji support', () {
        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna 😊',
          text: 'Fantastiskt recept! 🍽️ 😋 👍',
        );

        expect(comment.authorDisplayName, contains('😊'));
        expect(comment.text, contains('🍽️'));
        expect(comment.text, contains('😋'));
        expect(comment.text, contains('👍'));
      });

      test('should preserve whitespace', () {
        final textWithWhitespace = '''
First line
  Indented line
    More indentation
      
Last line with spaces before    ''';

        final comment = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: textWithWhitespace,
        );

        expect(comment.text, equals(textWithWhitespace));
      });

      test('should preserve immutability with copyWith', () {
        final original = RecipeComment(
          id: 'comment_123',
          recipeId: 'recipe_456',
          authorId: 'user_789',
          authorDisplayName: 'Anna',
          text: 'Original',
          likesCount: 1,
        );

        final modified = original.copyWith(
          text: 'Modified',
          likesCount: 2,
        );

        expect(original.text, equals('Original'));
        expect(original.likesCount, equals(1));
        expect(modified.text, equals('Modified'));
        expect(modified.likesCount, equals(2));
        expect(original.id, equals(modified.id));
      });
    });
  });
}
