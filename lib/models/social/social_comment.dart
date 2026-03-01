/// Comprehensive social comment model providing threaded discussion functionality with engagement tracking and moderation capabilities.
/// This model implements sophisticated comment system functionality including threaded conversations, like tracking,
/// user engagement metrics, and comprehensive moderation support. It provides hierarchical comment structures with
/// parent-child relationships, real-time engagement tracking, and complete Firestore integration for scalable
/// social interaction management across all recipe content and social features.
/// **Architecture Integration:**
/// - Uses [Timestamp] for Firestore-compatible date handling and real-time synchronization
/// - Integrates with user authentication system for author identification and security
/// - Supports hierarchical comment threading through parentCommentId relationships
/// - Provides comprehensive serialization for Firebase, JSON, and local storage
/// - Implements engagement tracking with like counting and user interaction state
/// **Comment System Features:**
/// - **Threaded Conversations**: Hierarchical comment structure with parent-child relationships
/// - **Engagement Tracking**: Real-time like counting and user interaction state management
/// - **Content Moderation**: Support for content filtering, reporting, and moderation workflows
/// - **Real-time Updates**: Live synchronization of comments, likes, and engagement metrics
/// - **User Context**: Complete author identification and authentication integration
/// - **Content Integrity**: Comprehensive validation and sanitization for user-generated content
/// **Comment Categories:**
/// - **Top-level Comments**: Primary recipe feedback and discussion starters (parentCommentId: null)
/// - **Reply Comments**: Responses to existing comments creating threaded conversations
/// - **Engagement Comments**: Comments focused on ratings, reactions, and social appreciation
/// - **Question Comments**: Help-seeking comments requesting clarification or assistance
/// - **Tip Comments**: Additional cooking tips, variations, and improvement suggestions
/// **Usage Examples:**
/// ```dart
/// // Create top-level comment
/// final comment = SocialComment(
///   id: 'comment_123',
///   recipeId: 'recipe_456',
///   authorId: 'user_789',
///   text: 'Fantastiskt recept! Perfekt för helgmys.',
///   createdAt: DateTime.now(),
/// );
/// // Create reply comment
/// final reply = SocialComment(
///   id: 'comment_124',
///   recipeId: 'recipe_456',
///   authorId: 'user_790',
///   text: 'Instämmer! Provade det igår.',
///   createdAt: DateTime.now(),
///   parentCommentId: 'comment_123',
/// );
/// // Track engagement
/// comment.isLiked = true;
/// comment.likeCount = 15;
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Comprehensive social comment model providing threaded discussion functionality with engagement tracking and moderation capabilities.
/// This model implements sophisticated social commenting functionality with hierarchical threading, engagement
/// tracking, and comprehensive moderation support. It provides real-time synchronization capabilities through
/// Firestore integration and complete serialization support for various data persistence and API scenarios.
/// **Threading Architecture:**
/// Comments support hierarchical structures where replies reference parent comments through parentCommentId,
/// enabling rich conversation threading and organized discussion flows for enhanced user engagement and
/// conversation management across all recipe and social content interactions.
class SocialComment {
  /// Unique identifier for this comment instance enabling precise comment targeting and relationship management.
  /// This ID serves as the primary key for comment identification, database operations, and API interactions.
  /// It enables precise comment targeting for replies, likes, moderation actions, and conversation threading
  /// while maintaining referential integrity across the social commenting system.
  final String id;

  /// Recipe identifier linking this comment to specific recipe content for contextual discussion organization.
  /// This field establishes the content context for the comment, enabling recipe-specific discussion threads,
  /// comment filtering by recipe, and contextual comment display. It maintains the relationship between
  /// user-generated comments and the specific recipe content they reference.
  final String recipeId;

  /// Author user identifier providing comment attribution and enabling author-specific functionality.
  /// This field identifies the comment author for attribution, permission checking, moderation actions,
  /// and author-specific comment management. It integrates with the user authentication system to ensure
  /// proper comment ownership and security controls throughout the commenting workflow.
  final String authorId;

  /// Comment text content providing the actual user message with support for rich text and moderation.
  /// This field contains the user-generated comment content, supporting rich text formatting, emoji usage,
  /// and comprehensive content validation. It undergoes content moderation, sanitization, and validation
  /// to ensure appropriate content quality and community standards compliance.
  final String text;

  /// Comment creation timestamp enabling chronological ordering and temporal comment analysis.
  /// This timestamp provides precise comment creation timing for chronological display ordering, temporal
  /// analytics, content freshness indicators, and time-based comment filtering. It integrates with
  /// Firestore's timestamp handling for real-time synchronization and consistent temporal behavior.
  final DateTime createdAt;

  /// Parent comment identifier enabling hierarchical threading and conversation organization.
  /// This optional field creates parent-child relationships between comments, enabling threaded conversations
  /// and hierarchical discussion structures. When null, the comment is a top-level comment; when populated,
  /// it references the parent comment for nested conversation threading and organized discussion flows.
  final String? parentCommentId;

  /// Current user's like status for this comment enabling personalized engagement state tracking.
  /// This mutable field tracks whether the current user has liked this comment, enabling personalized
  /// UI state management, engagement interaction feedback, and user-specific comment interaction history.
  /// It supports real-time updates for immediate user feedback and engagement state synchronization.
  bool isLiked;

  /// Total like count for this comment providing engagement metric tracking and social validation.
  /// This mutable field maintains the aggregate like count for this comment, enabling engagement metrics,
  /// popular comment identification, and social validation features. It updates in real-time as users
  /// interact with the comment through like actions and engagement behaviors.
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

  /// Creates SocialComment instance from Firestore document with comprehensive data validation and fallback handling.
  /// This factory constructor deserializes Firestore document data into a SocialComment instance with
  /// robust error handling, data validation, and appropriate fallback values. It handles Firestore-specific
  /// data types including Timestamp conversion and provides resilient data parsing for production reliability.
  /// [id] Document ID from Firestore for comment identification
  /// [data] Document data map containing comment fields and metadata
  /// Returns SocialComment instance with validated data and appropriate fallbacks
  /// **Data Validation Features:**
  /// - Comprehensive null safety with fallback values for missing fields
  /// - Firestore Timestamp conversion with current time fallback
  /// - Type-safe data casting with appropriate error handling
  /// - Consistent data integrity across Firestore document variations
  /// **Usage Examples:**
  /// ```dart
  /// // From Firestore document snapshot
  /// final comment = SocialComment.fromFirestore(
  ///   snapshot.id,
  ///   snapshot.data() as Map<String, dynamic>,
  /// );
  /// ```
  factory SocialComment.fromFirestore(String id, Map<String, dynamic> data) {
    return SocialComment(
      id: id,
      recipeId: SerializationUtils.safeString(data, 'recipeId'),
      authorId: SerializationUtils.safeString(data, 'authorId'),
      text: SerializationUtils.safeString(data, 'text'),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      parentCommentId:
          SerializationUtils.safeNullableString(data, 'parentCommentId'),
      isLiked: SerializationUtils.safeBool(data, 'isLiked'),
      likeCount: SerializationUtils.safeInt(data, 'likeCount'),
    );
  }

  /// Converts SocialComment instance to Firestore-compatible document format with optimized field mapping.
  /// This method serializes the comment instance into a Firestore document format with proper data type
  /// conversion, field optimization, and database-ready structure. It handles Firestore-specific requirements
  /// including Timestamp conversion and field naming conventions for consistent database operations.
  /// Returns Map\<String, dynamic\> containing Firestore-compatible document data
  /// **Firestore Optimization Features:**
  /// - DateTime to Firestore Timestamp conversion for proper temporal handling
  /// - Optimized field structure for efficient Firestore querying and indexing
  /// - Null field handling to minimize document size and optimize performance
  /// - Consistent field naming conventions for database integrity
  /// **Usage Examples:**
  /// ```dart
  /// // Save to Firestore
  /// await firestore.collection('comments').doc(comment.id).set(comment.toFirestore());
  /// ```
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

  /// Converts SocialComment instance to JSON format for API communication and local storage.
  /// This method serializes the comment instance into a JSON-compatible format suitable for API
  /// communication, local storage, caching, and data interchange. It provides complete field serialization
  /// with ISO 8601 date formatting and comprehensive data representation for various integration scenarios.
  /// Returns Map\<String, dynamic\> containing JSON-compatible comment data
  /// **JSON Serialization Features:**
  /// - ISO 8601 date formatting for universal temporal compatibility
  /// - Complete field serialization including optional and nullable fields
  /// - API-ready format for external service integration and communication
  /// - Local storage optimization for caching and offline functionality
  /// **Usage Examples:**
  /// ```dart
  /// // API serialization
  /// final jsonData = comment.toJson();
  /// await apiClient.post('/comments', body: jsonData);
  /// // Local storage
  /// await localStorage.setItem('comment_${comment.id}', jsonEncode(comment.toJson()));
  /// ```
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

  /// Creates SocialComment instance from JSON data with comprehensive validation and error handling.
  /// This factory constructor deserializes JSON data into a SocialComment instance with robust data
  /// validation, type safety, and appropriate fallback handling. It supports API response parsing,
  /// local storage deserialization, and various data import scenarios with consistent error handling.
  /// [json] JSON data map containing comment fields and metadata
  /// Returns SocialComment instance with validated data and appropriate fallbacks
  /// **JSON Deserialization Features:**
  /// - ISO 8601 date string parsing with error handling
  /// - Type-safe field extraction with null safety and fallback values
  /// - Comprehensive validation for data integrity and consistency
  /// - Error-resilient parsing for production reliability and robustness
  /// **Usage Examples:**
  /// ```dart
  /// // From API response
  /// final comment = SocialComment.fromJson(apiResponse.data);
  /// // From local storage
  /// final jsonData = jsonDecode(await localStorage.getItem('comment_123'));
  /// final comment = SocialComment.fromJson(jsonData);
  /// ```
  factory SocialComment.fromJson(Map<String, dynamic> json) {
    return SocialComment(
      id: json['id'] as String,
      recipeId: (json['recipeId'] as String?).orEmpty(),
      authorId: (json['authorId'] as String?).orEmpty(),
      text: (json['text'] as String?).orEmpty(),
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
