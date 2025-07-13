// lib/models/recipe_comment.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';


class RecipeComment {
  final String id;
  final String recipeId; // Which recipe this comments on
  final String authorId; // Who wrote the comment
  final String authorDisplayName; // Cache for performance
  final String? authorAvatarUrl; // Cache for performance
  final String text; // Comment content
  final DateTime createdAt;
  final DateTime? editedAt; // If comment was edited
  final List<String> likedByUserIds; // Who liked this comment
  final String? parentCommentId; // For replies (null = top-level)
  final int replyCount; // Number of replies
  final bool isDeleted; // Soft delete

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

  /// Factory constructor with auto-generated ID
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

  /// Create copy with updated values
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

  /// Add like from user
  RecipeComment addLike(String userId) {
    if (likedByUserIds.contains(userId)) return this;

    return copyWith(likedByUserIds: [...likedByUserIds, userId]);
  }

  /// Remove like from user
  RecipeComment removeLike(String userId) {
    if (!likedByUserIds.contains(userId)) return this;

    return copyWith(
      likedByUserIds: likedByUserIds.where((id) => id != userId).toList(),
    );
  }

  /// Edit comment text
  RecipeComment edit(String newText) {
    return copyWith(text: newText, editedAt: DateTime.now());
  }

  /// Soft delete comment
  RecipeComment delete() {
    return copyWith(isDeleted: true, text: '[Kommentar borttagen]');
  }

  // Getters
  int get likeCount => likedByUserIds.length;
  bool get isEdited => editedAt != null;
  bool get isTopLevel => parentCommentId == null;
  bool get hasReplies => replyCount > 0;

  /// Check if user liked this comment
  bool isLikedBy(String userId) => likedByUserIds.contains(userId);

  /// Check if user can edit/delete (author or admin)
  bool canBeEditedBy(String userId) => authorId == userId && !isDeleted;

  /// Time ago text (e.g., "2 timer sedan")
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

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'authorId': authorId,
      'authorDisplayName': authorDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'likedByUserIds': likedByUserIds,
      'parentCommentId': parentCommentId,
      'replyCount': replyCount,
      'isDeleted': isDeleted,
    };
  }

  /// Create from Firestore document
  factory RecipeComment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return RecipeComment(
      id: doc.id,
      recipeId: data['recipeId'] as String,
      authorId: data['authorId'] as String,
      authorDisplayName: data['authorDisplayName'] as String? ?? 'Användare',
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      likedByUserIds: List<String>.from(data['likedByUserIds'] ?? []),
      parentCommentId: data['parentCommentId'] as String?,
      replyCount: data['replyCount'] as int? ?? 0,
      isDeleted: data['isDeleted'] as bool? ?? false,
    );
  }

  /// JSON serialization för caching
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

  @override
  String toString() {
    return 'RecipeComment(id: $id, author: $authorDisplayName, likes: $likeCount, replies: $replyCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipeComment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
