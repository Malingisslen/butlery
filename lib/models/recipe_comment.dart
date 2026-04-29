/// Recipe comment with threading, likes, and cached author metadata.
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/time_ago_formatter.dart';
import 'package:uuid/uuid.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Recipe comment with threaded discussions and social engagement.
///
/// Like tracking uses a subcollection pattern for scalability:
/// - `likesCount` is denormalized for quick display
/// - Individual likes stored in `recipe_comments/{id}/likes/{userId}` subcollection
/// - Use repository methods for like operations, not model methods
class RecipeComment {
  final String id;
  final String recipeId;
  final String authorId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int likesCount;
  final String? parentCommentId;
  final int replyCount;
  final bool isDeleted;
  final Map<String, List<String>> reactions;

  /// BUT-458: Denormalized recipe ownership for server-side rule enforcement.
  /// Comments live in a top-level `recipe_comments` collection, but recipes
  /// live under `users/{userId}/recipes/{recipeId}` — security rules cannot
  /// efficiently look up the owner from just the recipeId. Storing it on
  /// the comment itself lets the read rule restrict access to recipe
  /// owner + shared recipients + comment author. Legacy comments without
  /// these fields read as null and the rule falls back to author-only read.
  final String? recipeOwnerId;

  /// BUT-458: Denormalized recipe-share recipient list. Mirror of the
  /// `shared_content/{contentId}.sharedToUserIds` for the share record
  /// that exposed this recipe. Updated when the recipe is (re-)shared
  /// or unshared. Empty list = unshared / personal recipe.
  final List<String> sharedWithUserIds;

  RecipeComment({
    required this.id,
    required this.recipeId,
    required this.authorId,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.text,
    DateTime? createdAt,
    this.editedAt,
    this.likesCount = 0,
    this.parentCommentId,
    this.replyCount = 0,
    this.isDeleted = false,
    this.reactions = const {},
    this.recipeOwnerId,
    this.sharedWithUserIds = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  factory RecipeComment.create({
    required String recipeId,
    required String authorId,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String text,
    String? parentCommentId,
    String? recipeOwnerId,
    List<String> sharedWithUserIds = const [],
  }) {
    return RecipeComment(
      id: const Uuid().v4(),
      recipeId: recipeId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      text: text,
      createdAt: DateTime.now(),
      parentCommentId: parentCommentId,
      recipeOwnerId: recipeOwnerId,
      sharedWithUserIds: sharedWithUserIds,
    );
  }

  /// Comment modification methods.

  /// Creates a copy of this comment with updated values while preserving immutability.
  /// Used for all comment modifications while maintaining immutable data patterns.
  /// Note: Like operations should use repository methods, not copyWith.
  RecipeComment copyWith({
    String? text,
    DateTime? editedAt,
    int? likesCount,
    int? replyCount,
    bool? isDeleted,
    Map<String, List<String>>? reactions,
  }) {
    return RecipeComment(
      id: id,
      recipeId: recipeId,
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      text: text ?? this.text,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      likesCount: likesCount ?? this.likesCount,
      parentCommentId: parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      isDeleted: isDeleted ?? this.isDeleted,
      reactions: reactions ?? this.reactions,
    );
  }

  /// Edits the comment text and marks it as edited with current timestamp.
  /// Updates the comment content while preserving edit history through the editedAt timestamp.
  /// This method handles content modification while maintaining audit trail capabilities.
  /// [newText] The updated comment text content
  /// Returns a new [RecipeComment] instance with updated text and edit timestamp.
  RecipeComment edit(String newText) {
    return copyWith(text: newText, editedAt: DateTime.now());
  }

  /// Performs soft deletion of the comment while preserving structure.
  /// Marks the comment as deleted and replaces content with localized deletion message.
  /// Preserves the comment structure for threading while removing inappropriate content.
  /// Returns a new [RecipeComment] instance marked as deleted with Swedish deletion message.
  RecipeComment delete() {
    return copyWith(isDeleted: true, text: AppLocale.current.commentDeleted);
  }

  /// Comment analysis and utility methods for UI integration and business logic.

  /// Gets the total number of likes this comment has received.
  /// This is a denormalized count maintained by the repository.
  int get likeCount => likesCount;

  /// Checks if this comment has been edited after creation.
  bool get isEdited => editedAt != null;

  /// Checks if this is a top-level comment (not a reply).
  bool get isTopLevel => parentCommentId == null;

  /// Checks if this comment has direct replies.
  bool get hasReplies => replyCount > 0;

  /// Checks if the specified user can edit or delete this comment.
  /// Implements permission checking based on authorship and deletion status.
  /// Only the original author can edit non-deleted comments.
  /// [userId] The user identifier to check for edit permissions
  /// Returns true if the user can edit this comment (is author and comment not deleted).
  bool canBeEditedBy(String userId) => authorId == userId && !isDeleted;

  /// Gets user-friendly Swedish text for how long ago the comment was created.
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context.
  /// Returns Swedish time format: 'Nu', '5 min sedan', '2 tim sedan', '3 dagar sedan', '2 veckor sedan'.
  String get timeAgoText {
    return TimeAgoFormatter.standard(createdAt);
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the recipe comment to Firestore-compatible format for persistence.
  /// Note: likesCount is managed by repository, not written by model.
  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'authorId': authorId,
      'authorDisplayName': authorDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      'editedAt': editedAt != null
          ? AppTimestamp.fromDateTime(editedAt!).toFirestore()
          : null,
      'likesCount': likesCount,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      'isDeleted': isDeleted,
      'reactions': reactions,
      // BUT-458: Denormalized ownership fields for rule enforcement.
      // Only emit when populated — legacy paths that don't have access
      // to the recipe owner pass null and the rule falls back to author-
      // only read.
      if (recipeOwnerId != null) 'recipeOwnerId': recipeOwnerId,
      'sharedWithUserIds': sharedWithUserIds,
    };
  }

  /// Creates a recipe comment instance from Firestore repository data.
  /// Reads likesCount from denormalized field (maintained by repository).
  factory RecipeComment.fromMap(String id, Map<String, dynamic> data) {
    return RecipeComment(
      id: id,
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      authorId: SerializationUtils.safeString(data, 'authorId'),
      authorDisplayName: SerializationUtils.safeString(
          data, 'authorDisplayName',
          defaultValue: '?'),
      authorAvatarUrl:
          SerializationUtils.safeNullableString(data, 'authorAvatarUrl'),
      text: SerializationUtils.safeString(data, 'text'),
      createdAt:
          SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
      editedAt: SerializationUtils.safeDateTime(data, 'editedAt'),
      likesCount: SerializationUtils.safeInt(data, 'likesCount'),
      parentCommentId:
          SerializationUtils.safeNullableString(data, 'parentCommentId'),
      replyCount: SerializationUtils.safeInt(data, 'replyCount'),
      isDeleted: SerializationUtils.safeBool(data, 'isDeleted'),
      reactions:
          SerializationUtils.safeStringListMap(data, 'reactions') ?? const {},
      recipeOwnerId:
          SerializationUtils.safeNullableString(data, 'recipeOwnerId'),
      sharedWithUserIds:
          SerializationUtils.safeStringList(data, 'sharedWithUserIds'),
    );
  }

  /// Converts the recipe comment to JSON format for local caching.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'authorId': authorId,
      'authorDisplayName': authorDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'likesCount': likesCount,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      'isDeleted': isDeleted,
      'reactions': reactions,
    };
  }

  /// Creates a recipe comment instance from JSON data for caching.
  factory RecipeComment.fromJson(Map<String, dynamic> json) {
    return RecipeComment(
      id: SerializationUtils.safeString(json, 'id'),
      recipeId: SerializationUtils.safeString(json, 'recipeId'),
      authorId: SerializationUtils.safeString(json, 'authorId'),
      authorDisplayName: SerializationUtils.safeString(
          json, 'authorDisplayName',
          defaultValue: '?'),
      authorAvatarUrl:
          SerializationUtils.safeNullableString(json, 'authorAvatarUrl'),
      text: SerializationUtils.safeString(json, 'text'),
      createdAt: SerializationUtils.safeRequiredDateTime(json, 'createdAt'),
      editedAt: SerializationUtils.safeDateTime(json, 'editedAt'),
      likesCount: SerializationUtils.safeInt(json, 'likesCount'),
      parentCommentId:
          SerializationUtils.safeNullableString(json, 'parentCommentId'),
      replyCount: SerializationUtils.safeInt(json, 'replyCount'),
      isDeleted: SerializationUtils.safeBool(json, 'isDeleted'),
      reactions:
          SerializationUtils.safeStringListMap(json, 'reactions') ?? const {},
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the recipe comment for debugging and logging.
  /// Provides essential comment information in a readable format for development
  /// and debugging purposes with author, engagement, and threading information.
  @override
  String toString() {
    return 'RecipeComment(id: $id, author: $authorDisplayName, likes: $likeCount, replies: $replyCount)';
  }

  /// Compares two recipe comments for equality based on unique identifier.
  /// Uses comment ID for equality comparison ensuring consistent object
  /// identity across different instances of the same comment data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeComment && other.id == id;
  }

  /// Generates hash code based on unique comment identifier.
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and comment identification.
  @override
  int get hashCode => id.hashCode;
}
