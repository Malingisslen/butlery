/// Specialized metadata repository for dismissal/archived status tracking.
/// Extends BaseMetadataRepository to provide convenient methods for dismissing
/// and un-dismissing content (hiding shared recipes, archiving notifications, etc.).
/// **Use Cases:**
/// - Shared recipes: Allow users to hide shared recipes from their feed
/// - Shared menus: Allow users to dismiss menu recommendations
/// - Notifications: Track archived/dismissed notifications
/// - Discovery content: Allow users to dismiss discovery recommendations
/// **Usage Example:**
/// ```dart
/// class SharedRecipeDismissalRepository extends BaseDismissalRepository {
///   SharedRecipeDismissalRepository({
///     required super.authRepository,
///     super.auditRepository,
///   });
///   @override
///   String get parentCollectionName => 'shared_recipes';
///   @override
///   Future<bool> validateMetadataAccess(String userId, String resourceId) async {
///     // User can dismiss if they can read the shared recipe
///     final recipe = await _recipeRepository.read(resourceId);
///     return recipe != null;
///   }
/// }
/// ```

import 'package:butlery/repositories/firebase/base_metadata_repository.dart';
import 'package:butlery/models/metadata/dismissal_metadata.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Base repository for dismissal/archived status metadata operations.
/// Provides convenient methods for dismissing and un-dismissing content.
/// Metadata stored in subcollections: {parent_collection}/{resource_id}/dismissals/{user_id}
abstract class BaseDismissalRepository
    extends BaseMetadataRepository<DismissalMetadata> {
  BaseDismissalRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  /// The metadata type for dismissal tracking
  @override
  String get metadataType => 'dismissal';

  /// Convert Firestore document to DismissalMetadata
  @override
  DismissalMetadata fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DismissalMetadata.fromFirestore(doc);
  }

  /// Convert DismissalMetadata to Firestore data
  @override
  Map<String, dynamic> toFirestore(DismissalMetadata metadata) {
    return metadata.toFirestore();
  }

  // ===== CONVENIENCE METHODS =====

  /// Dismiss content for the current user.
  /// [resourceId] ID of the content being dismissed
  /// [reason] Optional reason for dismissal ('not_interested', 'already_have', etc.)
  /// **Security**: Validates metadata access and enforces self-annotation
  /// **Audit**: Logs dismissal operation to FirebaseAuditRepository (GDPR Article 30)
  /// **Use Case**: User clicks "Not interested" on shared recipe → hide from feed
  Future<void> dismiss(String resourceId, {String? reason}) async {
    final userId = requireCurrentUserId();
    await addMetadata(
      resourceId,
      userId,
      additionalData: {
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Un-dismiss (restore) content for the current user.
  /// [resourceId] ID of the content being un-dismissed
  /// **Security**: Validates metadata access and enforces self-removal
  /// **Audit**: Logs un-dismissal operation to FirebaseAuditRepository
  /// **Use Case**: User wants to see previously dismissed content again
  Future<void> undismiss(String resourceId) async {
    final userId = requireCurrentUserId();
    await removeMetadata(resourceId, userId);
  }

  /// Check if the current user has dismissed the content.
  /// [resourceId] ID of the content to check
  /// Returns true if the current user has dismissed the content, false otherwise
  /// **Note**: No permission validation (existence check is non-sensitive)
  /// **Use Case**: Filter dismissed items from feed
  Future<bool> isDismissed(String resourceId) async {
    final userId = requireCurrentUserId();
    return await hasMetadata(resourceId, userId);
  }

  /// Get the dismissal metadata for the current user.
  /// [resourceId] ID of the content
  /// Returns DismissalMetadata if exists, null otherwise (includes reason)
  /// **Security**: Validates metadata access before returning data
  Future<DismissalMetadata?> getUserDismissal(String resourceId) async {
    final userId = requireCurrentUserId();
    return await getMetadata(resourceId, userId);
  }

  /// Get all users who have dismissed the content.
  /// [resourceId] ID of the content
  /// Returns list of DismissalMetadata for all dismissals
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Content moderation - see how many users dismissed content
  Future<List<DismissalMetadata>> getDismissals(String resourceId) async {
    return await getMetadataForResource(resourceId);
  }

  /// Get the number of users who have dismissed the content.
  /// [resourceId] ID of the content
  /// Returns count of dismissals
  /// **Security**: Validates metadata access before returning count
  /// **Use Case**: Content quality metrics
  Future<int> getDismissalCount(String resourceId) async {
    return await getMetadataCount(resourceId);
  }

  /// Get dismissals filtered by reason.
  /// [resourceId] ID of the content
  /// [reason] Filter by dismissal reason
  /// Returns list of DismissalMetadata matching the reason
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Analyze why users dismiss content ("not_interested" vs "already_have")
  Future<List<DismissalMetadata>> getDismissalsByReason(
    String resourceId,
    String reason,
  ) async {
    final allDismissals = await getDismissals(resourceId);
    return allDismissals.where((d) => d.reason == reason).toList();
  }

  /// Dismiss multiple items in batch.
  /// [resourceIds] List of content IDs to dismiss
  /// [reason] Optional reason for all dismissals
  /// **Security**: Validates metadata access for each resource
  /// **Use Case**: Bulk dismiss notifications, bulk hide recommendations
  Future<void> dismissMultiple(
    List<String> resourceIds, {
    String? reason,
  }) async {
    final userId = requireCurrentUserId();
    await addMetadataBatch(
      resourceIds,
      userId,
      additionalData: {
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Un-dismiss multiple items in batch.
  /// [resourceIds] List of content IDs to un-dismiss
  /// **Security**: Validates metadata access and enforces self-removal for each resource
  /// **Use Case**: Bulk restore dismissed items
  Future<void> undismissMultiple(List<String> resourceIds) async {
    final userId = requireCurrentUserId();
    await removeMetadataBatch(resourceIds, userId);
  }
}
