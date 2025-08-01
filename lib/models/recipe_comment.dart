/// Comprehensive recipe comment model providing advanced threaded commenting and social interaction capabilities.
///
/// This model implements sophisticated recipe commenting functionality following Single Responsibility Principle,
/// handling all aspects of comment management including threaded discussions, social engagement tracking,
/// cached author metadata, and comprehensive moderation features. It provides complete commenting capabilities
/// while maintaining clean separation from recipe data and user management concerns.
///
/// **Single Responsibility Focus:**
/// This model exclusively handles recipe comment data and operations:
/// - **Threaded Commenting**: Complete hierarchical comment system with parent-child relationships and reply management
/// - **Social Engagement**: Comprehensive like system with user tracking and engagement analytics
/// - **Author Metadata Caching**: Performance-optimized author information storage for enhanced UI responsiveness
/// - **Content Moderation**: Soft deletion system with content preservation for moderation and audit trails
///
/// **What This Model Does NOT Handle:**
/// - Recipe data management and business logic (handled by Recipe models and services)
/// - User profile and authentication management (handled by user services)
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Comment persistence and storage operations (handled by repositories and services)
///
/// **Recipe Comment Features:**
/// - **Threaded Discussion System**: Complete hierarchical commenting with unlimited nesting and reply management
/// - **Social Engagement Tracking**: Advanced like system with user identification and engagement analytics
/// - **Performance Optimization**: Cached author metadata for enhanced UI responsiveness and reduced database queries
/// - **Content Moderation**: Comprehensive soft deletion with content preservation and moderation capabilities
/// - **Swedish Localization**: Complete Swedish language support for time formatting and user interface elements
///
/// **Usage Examples:**
/// ```dart
/// // Create new top-level comment
/// final comment = RecipeComment.create(
///   recipeId: recipeId,
///   authorId: currentUserId,
///   authorDisplayName: 'Anna Andersson',
///   authorAvatarUrl: 'https://example.com/avatar.jpg',
///   text: 'Fantastiskt recept! Hela familjen älskade det.',
/// );
/// 
/// // Create reply to existing comment
/// final reply = RecipeComment.create(
///   recipeId: recipeId,
///   authorId: currentUserId,
///   authorDisplayName: 'Erik Svensson',
///   text: 'Håller med! Gjorde det igår och det blev perfekt.',
///   parentCommentId: comment.id,
/// );
/// 
/// // Handle social engagement
/// final likedComment = comment.addLike(userId);
/// final unlikedComment = likedComment.removeLike(userId);
/// 
/// // Edit and moderate comments
/// final editedComment = comment.edit('Uppdaterad kommentar med mer detaljer.');
/// final deletedComment = comment.delete();
/// 
/// // Check comment properties
/// final isThreaded = comment.hasReplies;
/// final engagement = comment.likeCount;
/// final canEdit = comment.canBeEditedBy(currentUserId);
/// ```

// lib/models/recipe_comment.dart

import 'package:uuid/uuid.dart';
import 'package:butlery/core/types/app_timestamp.dart';

/// Comprehensive recipe comment model with threaded discussion and social engagement capabilities.
///
/// Represents a complete recipe comment with all associated metadata including author information,
/// threading hierarchy, social engagement data, and moderation features.
class RecipeComment {
  /// Unique identifier for this comment.
  final String id;
  
  /// Recipe identifier that this comment belongs to.
  ///
  /// Links the comment to its parent recipe for organization and retrieval.
  final String recipeId; // Which recipe this comments on
  
  /// User identifier of the comment author.
  ///
  /// References the user who created this comment for ownership and permissions.
  final String authorId; // Who wrote the comment
  
  /// Cached display name of the comment author for UI performance.
  ///
  /// Stored locally to avoid additional user profile lookups during comment display.
  final String authorDisplayName; // Cache for performance
  
  /// Cached avatar URL of the comment author for UI performance.
  ///
  /// Optional cached avatar image for enhanced comment display without additional queries.
  final String? authorAvatarUrl; // Cache for performance
  
  /// The actual comment text content.
  ///
  /// Main comment content provided by the user, supporting rich text and emoji.
  final String text; // Comment content
  
  /// Timestamp when the comment was originally created.
  ///
  /// Used for chronological ordering and time-based display formatting.
  final DateTime createdAt;
  
  /// Timestamp when the comment was last edited.
  ///
  /// Null for unedited comments, set when content is modified after creation.
  final DateTime? editedAt; // If comment was edited
  
  /// List of user IDs who have liked this comment.
  ///
  /// Tracks social engagement and enables like/unlike functionality with user identification.
  final List<String> likedByUserIds; // Who liked this comment
  
  /// Parent comment ID for threaded discussions.
  ///
  /// Null for top-level comments, references parent comment ID for replies.
  final String? parentCommentId; // For replies (null = top-level)
  
  /// Number of direct replies to this comment.
  ///
  /// Cached count for efficient UI display without querying child comments.
  final int replyCount; // Number of replies
  
  /// Soft deletion flag for content moderation.
  ///
  /// Allows content removal while preserving comment structure and audit trail.
  final bool isDeleted; // Soft delete

  /// Creates a new recipe comment with all required metadata and default values.
  ///
  /// [id] Unique identifier for the comment
  /// [recipeId] Target recipe identifier for comment association
  /// [authorId] Comment author's user identifier
  /// [authorDisplayName] Cached author name for UI performance
  /// [authorAvatarUrl] Optional cached author avatar for enhanced display
  /// [text] Main comment content with user-provided text
  /// [createdAt] Creation timestamp, defaults to current time
  /// [editedAt] Edit timestamp, null for unedited comments
  /// [likedByUserIds] List of users who liked this comment
  /// [parentCommentId] Parent comment ID for threading, null for top-level
  /// [replyCount] Number of direct replies for cached display
  /// [isDeleted] Soft deletion flag for content moderation
  RecipeComment({
    required this.id,
    required this.recipeId,
    required this.authorId,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.text,
    DateTime? createdAt,
    this.editedAt,
    this.likedByUserIds = const [],
    this.parentCommentId,
    this.replyCount = 0,
    this.isDeleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Factory constructor for creating new recipe comments with auto-generated ID.
  ///
  /// Creates a new comment with automatic ID generation and default settings for new comments.
  /// Comments are created as unedited, undeleted, and with no likes or replies initially.
  ///
  /// [recipeId] Target recipe identifier for comment association
  /// [authorId] Comment author's user identifier
  /// [authorDisplayName] Author's display name for caching and UI performance
  /// [authorAvatarUrl] Optional author avatar URL for enhanced comment display
  /// [text] Main comment content provided by the user
  /// [parentCommentId] Optional parent comment ID for threaded replies
  ///
  /// Returns a new [RecipeComment] instance with generated ID and current timestamp.
  factory RecipeComment.create({
    required String recipeId,
    required String authorId,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String text,
    String? parentCommentId,
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
    );
  }

  /// Comment modification and social interaction methods.

  /// Creates a copy of this comment with updated values while preserving immutability.
  ///
  /// Used for all comment modifications while maintaining immutable data patterns
  /// and ensuring consistent state management across the application.
  ///
  /// [text] Updated comment text content
  /// [editedAt] Edit timestamp for tracking modifications
  /// [likedByUserIds] Updated list of users who liked the comment
  /// [replyCount] Updated number of direct replies
  /// [isDeleted] Updated deletion status for moderation
  ///
  /// Returns a new [RecipeComment] instance with updated values.
  RecipeComment copyWith({
    String? text,
    DateTime? editedAt,
    List<String>? likedByUserIds,
    int? replyCount,
    bool? isDeleted,
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
      likedByUserIds: likedByUserIds ?? List.from(this.likedByUserIds),
      parentCommentId: parentCommentId,
      replyCount: replyCount ?? this.replyCount,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Adds a like from the specified user to this comment.
  ///
  /// Implements social engagement functionality with duplicate prevention.
  /// If the user has already liked the comment, returns the existing comment unchanged.
  ///
  /// [userId] The user identifier adding the like
  ///
  /// Returns a new [RecipeComment] instance with the like added, or unchanged if already liked.
  RecipeComment addLike(String userId) {
    if (likedByUserIds.contains(userId)) return this;

    return copyWith(likedByUserIds: [...likedByUserIds, userId]);
  }

  /// Removes a like from the specified user from this comment.
  ///
  /// Implements social engagement functionality with non-existent like handling.
  /// If the user hasn't liked the comment, returns the existing comment unchanged.
  ///
  /// [userId] The user identifier removing the like
  ///
  /// Returns a new [RecipeComment] instance with the like removed, or unchanged if not liked.
  RecipeComment removeLike(String userId) {
    if (!likedByUserIds.contains(userId)) return this;

    return copyWith(
      likedByUserIds: likedByUserIds.where((id) => id != userId).toList(),
    );
  }

  /// Edits the comment text and marks it as edited with current timestamp.
  ///
  /// Updates the comment content while preserving edit history through the editedAt timestamp.
  /// This method handles content modification while maintaining audit trail capabilities.
  ///
  /// [newText] The updated comment text content
  ///
  /// Returns a new [RecipeComment] instance with updated text and edit timestamp.
  RecipeComment edit(String newText) {
    return copyWith(text: newText, editedAt: DateTime.now());
  }

  /// Performs soft deletion of the comment while preserving structure.
  ///
  /// Marks the comment as deleted and replaces content with localized deletion message.
  /// Preserves the comment structure for threading while removing inappropriate content.
  ///
  /// Returns a new [RecipeComment] instance marked as deleted with Swedish deletion message.
  RecipeComment delete() {
    return copyWith(isDeleted: true, text: '[Kommentar borttagen]');
  }

  /// Comment analysis and utility methods for UI integration and business logic.

  /// Gets the total number of likes this comment has received.
  ///
  /// Provides quick access to social engagement metrics for UI display
  /// and analytics without needing to count the likedByUserIds list.
  int get likeCount => likedByUserIds.length;
  
  /// Checks if this comment has been edited after creation.
  ///
  /// Returns true when editedAt is not null, indicating the comment
  /// content has been modified since its original creation.
  bool get isEdited => editedAt != null;
  
  /// Checks if this is a top-level comment (not a reply).
  ///
  /// Returns true when parentCommentId is null, indicating this comment
  /// is directly attached to the recipe rather than being a reply.
  bool get isTopLevel => parentCommentId == null;
  
  /// Checks if this comment has direct replies.
  ///
  /// Returns true when replyCount is greater than zero, indicating
  /// other comments are threaded as replies to this comment.
  bool get hasReplies => replyCount > 0;

  /// Checks if the specified user has liked this comment.
  ///
  /// Provides convenient access to user-specific like status for UI state
  /// management and social engagement functionality.
  ///
  /// [userId] The user identifier to check for like status
  ///
  /// Returns true if the user has liked this comment.
  bool isLikedBy(String userId) => likedByUserIds.contains(userId);

  /// Checks if the specified user can edit or delete this comment.
  ///
  /// Implements permission checking based on authorship and deletion status.
  /// Only the original author can edit non-deleted comments.
  ///
  /// [userId] The user identifier to check for edit permissions
  ///
  /// Returns true if the user can edit this comment (is author and comment not deleted).
  bool canBeEditedBy(String userId) => authorId == userId && !isDeleted;

  /// Gets user-friendly Swedish text for how long ago the comment was created.
  ///
  /// Provides localized time-ago display optimized for Swedish users with natural
  /// language formatting for improved user experience and temporal context.
  ///
  /// Returns Swedish time format: 'Nu', '5 min sedan', '2 tim sedan', '3 dagar sedan', '2 veckor sedan'.
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min sedan';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} tim sedan';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} dagar sedan';
    } else {
      return '${(difference.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the recipe comment to Firestore-compatible format for persistence.
  ///
  /// Transforms all comment data into a format suitable for Firestore storage
  /// with proper timestamp handling and null value management for database efficiency.
  ///
  /// Returns a map containing all comment data formatted for Firestore persistence.
  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'authorId': authorId,
      'authorDisplayName': authorDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      'editedAt': editedAt != null ? AppTimestamp.fromDateTime(editedAt!).toFirestore() : null,
      'likedByUserIds': likedByUserIds,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      'isDeleted': isDeleted,
    };
  }

  /// Creates a recipe comment instance from Firestore repository data.
  ///
  /// Transforms Firestore document data into a complete [RecipeComment] instance
  /// with proper type conversion, timestamp parsing, and default value handling for robust data recovery.
  ///
  /// [id] Document identifier from Firestore
  /// [data] Raw document data from Firestore with all comment fields
  ///
  /// Returns a new [RecipeComment] instance with all data properly parsed and validated.
  factory RecipeComment.fromMap(String id, Map<String, dynamic> data) {
    return RecipeComment(
      id: id,
      recipeId: data['recipeId'] as String,
      authorId: data['authorId'] as String,
      authorDisplayName: data['authorDisplayName'] as String? ?? 'Användare',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: data['createdAt'] is DateTime 
          ? data['createdAt'] as DateTime
          : DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] is DateTime 
              ? data['editedAt'] as DateTime
              : DateTime.fromMillisecondsSinceEpoch(data['editedAt'] as int))
          : null,
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      parentCommentId: data['parentCommentId'] as String?,
      replyCount: data['replyCount'] as int? ?? 0,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  /// Converts the recipe comment to JSON format for local caching and serialization.
  ///
  /// Transforms all comment data into JSON-compatible format with proper DateTime
  /// serialization for local storage, caching, and data transfer operations.
  ///
  /// Returns a JSON-compatible map with all comment data properly serialized.
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
      'likedByUserIds': likedByUserIds,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      'isDeleted': isDeleted,
    };
  }

  /// Creates a recipe comment instance from JSON data for caching and deserialization.
  ///
  /// Transforms JSON data into a complete [RecipeComment] instance with proper
  /// type conversion and DateTime deserialization for cache recovery and data transfer.
  ///
  /// [json] JSON map containing all comment data with proper field names
  ///
  /// Returns a new [RecipeComment] instance with all data properly deserialized.
  factory RecipeComment.fromJson(Map<String, dynamic> json) {
    return RecipeComment(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String,
      authorId: json['authorId'] as String,
      authorDisplayName: json['authorDisplayName'] as String? ?? 'Användare',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt:
          json['editedAt'] != null
              ? DateTime.parse(json['editedAt'] as String)
              : null,
      likedByUserIds: List<String>.from(json['likedByUserIds'] ?? []),
      parentCommentId: json['parentCommentId'] as String?,
      replyCount: json['replyCount'] as int? ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the recipe comment for debugging and logging.
  ///
  /// Provides essential comment information in a readable format for development
  /// and debugging purposes with author, engagement, and threading information.
  @override
  String toString() {
    return 'RecipeComment(id: $id, author: $authorDisplayName, likes: $likeCount, replies: $replyCount)';
  }

  /// Compares two recipe comments for equality based on unique identifier.
  ///
  /// Uses comment ID for equality comparison ensuring consistent object
  /// identity across different instances of the same comment data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeComment && other.id == id;
  }

  /// Generates hash code based on unique comment identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and comment identification.
  @override
  int get hashCode => id.hashCode;
  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions  
    // Dispose of resources
    disposeStreams(); // From StreamManagementMixin
    super.dispose();
  }
}
