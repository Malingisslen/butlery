/// Specialized metadata repository for view/read status tracking.
/// Extends BaseMetadataRepository to provide convenient methods for marking
/// content as viewed/read and checking view status.
/// **Use Cases:**
/// - Shared recipes: Track who has viewed each shared recipe
/// - Notifications: Track read status for notifications
/// - Messages: Track read receipts for messages
/// - Shared menus: Track who has viewed each shared menu
/// **Usage Example:**
/// ```dart
/// class SharedRecipeViewRepository extends BaseViewRepository {
///   SharedRecipeViewRepository({
///     required super.authRepository,
///     super.auditRepository,
///   });
///   @override
///   String get parentCollectionName => 'shared_recipes';
///   @override
///   Future<bool> validateMetadataAccess(String userId, String resourceId) async {
///     // User can view metadata if they can read the shared recipe
///     final recipe = await _recipeRepository.read(resourceId);
///     return recipe != null;
///   }
/// }
/// ```

import 'package:butlery/repositories/firebase/base_metadata_repository.dart';
import 'package:butlery/models/metadata/view_metadata.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Base repository for view/read status metadata operations.
/// Provides convenient methods for marking content as viewed and checking view status.
/// Metadata stored in subcollections: {parent_collection}/{resource_id}/views/{user_id}
abstract class BaseViewRepository extends BaseMetadataRepository<ViewMetadata> {
  BaseViewRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  /// The metadata type for view tracking
  @override
  String get metadataType => 'view';

  /// Convert Firestore document to ViewMetadata
  @override
  ViewMetadata fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ViewMetadata.fromFirestore(doc);
  }

  /// Convert ViewMetadata to Firestore data
  @override
  Map<String, dynamic> toFirestore(ViewMetadata metadata) {
    return metadata.toFirestore();
  }

  /// Mark content as viewed by the current user.
  /// This is a convenience wrapper around addMetadata() with clearer semantics.
  /// [resourceId] ID of the content being marked as viewed
  /// **Security**: Validates metadata access and enforces self-annotation
  /// **Audit**: Logs view operation to FirebaseAuditRepository (GDPR Article 30)
  /// **Use Case**: User opens recipe detail view → mark as viewed
  Future<void> markAsViewed(String resourceId) async {
    final userId = requireCurrentUserId();
    await addMetadata(resourceId, userId);
  }

  /// Check if the current user has viewed the content.
  /// [resourceId] ID of the content to check
  /// Returns true if the current user has viewed the content, false otherwise
  /// **Note**: No permission validation (existence check is non-sensitive)
  Future<bool> hasViewed(String resourceId) async {
    final userId = requireCurrentUserId();
    return await hasMetadata(resourceId, userId);
  }

  /// Get the view metadata for the current user.
  /// [resourceId] ID of the content
  /// Returns ViewMetadata if exists, null otherwise
  /// **Security**: Validates metadata access before returning data
  Future<ViewMetadata?> getUserView(String resourceId) async {
    final userId = requireCurrentUserId();
    return await getMetadata(resourceId, userId);
  }

  /// Get all users who have viewed the content.
  /// [resourceId] ID of the content
  /// Returns list of ViewMetadata for all users who have viewed the content
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Show "Viewed by 5 people" on shared content
  Future<List<ViewMetadata>> getViewers(String resourceId) async {
    return await getMetadataForResource(resourceId);
  }

  /// Get the number of users who have viewed the content.
  /// [resourceId] ID of the content
  /// Returns count of users who have viewed the content
  /// **Security**: Validates metadata access before returning count
  /// **Use Case**: Display view count on shared content
  Future<int> getViewCount(String resourceId) async {
    return await getMetadataCount(resourceId);
  }

  /// Mark multiple items as viewed in batch.
  /// [resourceIds] List of content IDs to mark as viewed
  /// **Security**: Validates metadata access for each resource
  /// **Use Case**: Mark all notifications as read, mark all messages as read
  Future<void> markMultipleAsViewed(List<String> resourceIds) async {
    final userId = requireCurrentUserId();
    await addMetadataBatch(resourceIds, userId);
  }
}
