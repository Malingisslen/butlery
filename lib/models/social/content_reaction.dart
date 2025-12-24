// lib/models/social/content_reaction.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/social/reaction_type.dart';

/// Universal content reaction model for expressing user sentiment on any content type
/// This model provides a flexible reaction system that can be applied to any content
/// throughout the application including recipes, comments, menus, shopping lists, and
/// future content types. It follows the established Firestore integration patterns and
/// provides comprehensive metadata for analytics and user experience optimization.
/// **Architecture Integration:**
/// - Follows existing model patterns from SocialComment and RecipeComment
/// - Integrates with Firestore using established serialization methods
/// - Supports all content types through contentType and contentId fields
/// - Provides audit trail with timestamp and user tracking
/// **Supported Content Types:**
/// - 'recipe' - Recipe reactions for cooking content
/// - 'comment' - Comment reactions for discussion engagement  
/// - 'menu' - Menu reactions for meal planning feedback
/// - 'shopping_list' - Shopping list reactions for utility feedback
/// - 'user_profile' - Profile reactions for social appreciation
/// - Extensible for future content types
/// **Usage Examples:**
/// ```dart
/// // Create recipe reaction
/// final reaction = ContentReaction(
///   contentId: 'recipe_123',
///   contentType: 'recipe',
///   userId: 'user_456',
///   reactionType: ReactionType.delicious,
/// );
/// // Toggle reaction
/// final updated = reaction.copyWith(
///   reactionType: ReactionType.love,
///   updatedAt: DateTime.now(),
/// );
/// ```
class ContentReaction {
  /// Unique identifier for this reaction instance
  final String id;
  
  /// ID of the content being reacted to (recipe ID, comment ID, etc.)
  final String contentId;
  
  /// Type of content being reacted to ('recipe', 'comment', 'menu', etc.)
  final String contentType;
  
  /// ID of the user who created this reaction
  final String userId;
  
  /// Type of reaction expressed (like, love, delicious, etc.)
  final ReactionType reactionType;
  
  /// When this reaction was originally created
  final DateTime createdAt;
  
  /// When this reaction was last modified (for reaction type changes)
  final DateTime? updatedAt;

  const ContentReaction({
    required this.id,
    required this.contentId,
    required this.contentType,
    required this.userId,
    required this.reactionType,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create reaction with auto-generated ID and current timestamp
  factory ContentReaction.create({
    required String contentId,
    required String contentType,
    required String userId,
    required ReactionType reactionType,
  }) {
    final now = DateTime.now();
    return ContentReaction(
      id: _generateId(contentId, contentType, userId),
      contentId: contentId,
      contentType: contentType,
      userId: userId,
      reactionType: reactionType,
      createdAt: now,
    );
  }

  /// Generate composite ID for reactions (ensures one reaction per user per content)
  static String _generateId(String contentId, String contentType, String userId) {
    return '${contentType}_${contentId}_$userId';
  }

  /// Create from Firestore document following established patterns
  factory ContentReaction.fromFirestore(String id, Map<String, dynamic> data) {
    return ContentReaction(
      id: id,
      contentId: SerializationUtils.safeString(data, 'contentId'),
      contentType: SerializationUtils.safeString(data, 'contentType'),
      userId: SerializationUtils.safeString(data, 'userId'),
      reactionType: ReactionType.fromKey(
        SerializationUtils.safeString(data, 'reactionType', defaultValue: 'like'),
      ),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    );
  }

  /// Convert to Firestore format following established patterns
  Map<String, dynamic> toFirestore() {
    return {
      'contentId': contentId,
      'contentType': contentType,
      'userId': userId,
      'reactionType': reactionType.key,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Convert to JSON format following established patterns
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'contentType': contentType,
      'userId': userId,
      'reactionType': reactionType.key,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  /// Create from JSON format following established patterns
  factory ContentReaction.fromJson(Map<String, dynamic> json) {
    final updatedAtStr = SerializationUtils.safeNullableString(json, 'updatedAt');
    return ContentReaction(
      id: SerializationUtils.safeString(json, 'id'),
      contentId: SerializationUtils.safeString(json, 'contentId'),
      contentType: SerializationUtils.safeString(json, 'contentType'),
      userId: SerializationUtils.safeString(json, 'userId'),
      reactionType: ReactionType.fromKey(
        SerializationUtils.safeString(json, 'reactionType', defaultValue: 'like'),
      ),
      createdAt: DateTime.parse(SerializationUtils.safeString(json, 'createdAt')),
      updatedAt: updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null,
    );
  }

  /// Create updated copy with new reaction type
  ContentReaction copyWith({
    String? id,
    String? contentId,
    String? contentType,
    String? userId,
    ReactionType? reactionType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContentReaction(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      userId: userId ?? this.userId,
      reactionType: reactionType ?? this.reactionType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this reaction was modified after creation
  bool get wasUpdated => updatedAt != null;

  /// Get age of this reaction
  Duration get age => DateTime.now().difference(createdAt);

  /// Get display text for this reaction
  String get displayText => reactionType.displayText;

  @override
  String toString() {
    return 'ContentReaction(id: $id, contentId: $contentId, contentType: $contentType, userId: $userId, reactionType: ${reactionType.key})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentReaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}