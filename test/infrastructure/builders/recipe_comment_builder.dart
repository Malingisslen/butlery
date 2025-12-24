/// Test data builder for RecipeComment objects
///
/// Provides fluent API for creating test recipe comment instances with defaults.
library;

// ignore_for_file: prefer_final_fields

import 'package:butlery/models/recipe_comment.dart';
import 'package:uuid/uuid.dart';

class RecipeCommentBuilder {
  String _id = const Uuid().v4();
  String _recipeId = 'recipe-123';
  String _authorId = 'author-123';
  String _authorDisplayName = 'Test Author';
  String? _authorAvatarUrl;
  String _text = 'This is a test comment';
  DateTime _createdAt = DateTime.now();
  DateTime? _editedAt;
  List<String> _likedByUserIds = [];
  String? _parentCommentId;
  int _replyCount = 0;
  bool _isDeleted = false;

  RecipeCommentBuilder();

  /// Set comment ID
  RecipeCommentBuilder withId(String id) {
    _id = id;
    return this;
  }

  /// Set recipe ID
  RecipeCommentBuilder forRecipe(String recipeId) {
    _recipeId = recipeId;
    return this;
  }

  /// Set author ID
  RecipeCommentBuilder byAuthor(String authorId) {
    _authorId = authorId;
    return this;
  }

  /// Set author display name
  RecipeCommentBuilder withAuthorName(String displayName) {
    _authorDisplayName = displayName;
    return this;
  }

  /// Set author avatar URL
  RecipeCommentBuilder withAuthorAvatar(String avatarUrl) {
    _authorAvatarUrl = avatarUrl;
    return this;
  }

  /// Set comment text
  RecipeCommentBuilder withText(String text) {
    _text = text;
    return this;
  }

  /// Set creation time
  RecipeCommentBuilder createdAt(DateTime createdAt) {
    _createdAt = createdAt;
    return this;
  }

  /// Mark as edited
  RecipeCommentBuilder editedAt(DateTime editedAt) {
    _editedAt = editedAt;
    return this;
  }

  /// Add likes from users
  RecipeCommentBuilder likedBy(List<String> userIds) {
    _likedByUserIds = userIds;
    return this;
  }

  /// Set as reply to another comment
  RecipeCommentBuilder asReplyTo(String parentCommentId) {
    _parentCommentId = parentCommentId;
    return this;
  }

  /// Set reply count
  RecipeCommentBuilder withReplyCount(int count) {
    _replyCount = count;
    return this;
  }

  /// Mark as deleted
  RecipeCommentBuilder asDeleted() {
    _isDeleted = true;
    _text = '[Deleted]'; // Common pattern for deleted comments
    return this;
  }

  /// Configure as Swedish comment
  RecipeCommentBuilder asSwedishComment() {
    _authorDisplayName = 'Anna Andersson';
    _text = 'Fantastiskt recept! Hela familjen älskade det.';
    return this;
  }

  /// Configure as positive review
  RecipeCommentBuilder asPositiveReview() {
    _text =
        'This recipe turned out amazing! The instructions were clear and easy to follow.';
    _likedByUserIds = ['user-1', 'user-2', 'user-3'];
    return this;
  }

  /// Configure as question comment
  RecipeCommentBuilder asQuestion() {
    _text = 'Can I substitute the butter with oil? And if so, how much?';
    _replyCount = 2; // Simulating that it has replies
    return this;
  }

  /// Configure as reply
  RecipeCommentBuilder asReply() {
    _parentCommentId = 'parent-comment-123';
    _text = 'Thanks for the suggestion! I tried it and it worked perfectly.';
    return this;
  }

  /// Configure as edited comment
  RecipeCommentBuilder asEdited() {
    _editedAt = _createdAt.add(const Duration(hours: 2));
    _text = 'EDIT: Updated with more details after trying the recipe again.';
    return this;
  }

  /// Configure as popular comment
  RecipeCommentBuilder asPopular() {
    _likedByUserIds = List.generate(25, (i) => 'user-$i');
    _replyCount = 15;
    _text =
        'Pro tip: Let the dough rest for an extra 30 minutes for better texture!';
    return this;
  }

  /// Build the RecipeComment instance
  RecipeComment build() {
    return RecipeComment(
      id: _id,
      recipeId: _recipeId,
      authorId: _authorId,
      authorDisplayName: _authorDisplayName,
      authorAvatarUrl: _authorAvatarUrl,
      text: _text,
      createdAt: _createdAt,
      editedAt: _editedAt,
      likedByUserIds: _likedByUserIds,
      parentCommentId: _parentCommentId,
      replyCount: _replyCount,
      isDeleted: _isDeleted,
    );
  }

  /// Build multiple comments with unique IDs
  List<RecipeComment> buildMany(int count) {
    return List.generate(count, (index) {
      _id = const Uuid().v4();
      _text = 'Test comment ${index + 1}';
      _createdAt = DateTime.now().subtract(Duration(hours: index));
      return build();
    });
  }
}
