// lib/models/social/social_comment.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Social comment model for recipe discussions and engagement
class SocialComment {
  /// Unique identifier for the comment
  final String id;
  
  /// Recipe ID this comment belongs to
  final String recipeId;
  
  /// User ID of the comment author
  final String authorId;
  
  /// Comment text content
  final String text;
  
  /// When the comment was created
  final DateTime createdAt;
  
  /// Parent comment ID for replies (null for top-level comments)
  final String? parentCommentId;
  
  /// Whether current user has liked this comment
  bool isLiked;
  
  /// Number of likes on this comment
  int likeCount;

  SocialComment({
    required this.id,
    required this.recipeId,
    required this.authorId,
    required this.text,
    required this.createdAt,
    this.parentCommentId,
    this.isLiked = false,
    this.likeCount = 0,
  });

  /// Create from Firestore document
  factory SocialComment.fromFirestore(String id, Map<String, dynamic> data) {
    return SocialComment(
      id: id,
      recipeId: data['recipeId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      parentCommentId: data['parentCommentId'] as String?,
      isLiked: data['isLiked'] as bool? ?? false,
      likeCount: data['likeCount'] as int? ?? 0,
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'recipeId': recipeId,
      'authorId': authorId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'parentCommentId': parentCommentId,
      'isLiked': isLiked,
      'likeCount': likeCount,
    };
  }

  /// Convert to JSON format
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipeId': recipeId,
      'authorId': authorId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'parentCommentId': parentCommentId,
      'isLiked': isLiked,
      'likeCount': likeCount,
    };
  }

  /// Create from JSON format
  factory SocialComment.fromJson(Map<String, dynamic> json) {
    return SocialComment(
      id: json['id'] as String,
      recipeId: json['recipeId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      parentCommentId: json['parentCommentId'] as String?,
      isLiked: json['isLiked'] as bool? ?? false,
      likeCount: json['likeCount'] as int? ?? 0,
    );
  }

  @override
  String toString() {
    return 'SocialComment(id: $id, recipeId: $recipeId, authorId: $authorId, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialComment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}