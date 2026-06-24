/// Specialized metadata repository for engagement tracking (imports, joins, etc.).
/// Extends BaseMetadataRepository to provide convenient methods for tracking
/// user engagement with content such as importing recipes, joining groups, etc.
/// **Use Cases:**
/// - Shared recipes: Track when users import recipes to their personal collection
/// - Shared menus: Track when users import menus
/// - Groups: Track when users join groups
/// - Shopping lists: Track when users join collaborative lists
/// **Usage Example:**
/// ```dart
/// class SharedRecipeEngagementRepository extends BaseEngagementRepository {
///   SharedRecipeEngagementRepository({
///     required super.authRepository,
///     super.auditRepository,
///   });
///   @override
///   String get parentCollectionName => 'shared_content';
///   @override
///   Future<bool> validateMetadataAccess(String userId, String resourceId) async {
///     // User can track engagement if they can read the shared recipe
///     final recipe = await _recipeRepository.read(resourceId);
///     return recipe != null;
///   }
/// }
/// ```

import 'package:butlery/repositories/firebase/base_metadata_repository.dart';
import 'package:butlery/models/metadata/engagement_metadata.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Base repository for engagement metadata operations.
/// Provides convenient methods for tracking user engagement (imports, joins, etc.).
/// Metadata stored in subcollections: {parent_collection}/{resource_id}/engagements/{user_id}
abstract class BaseEngagementRepository
    extends BaseMetadataRepository<EngagementMetadata> {
  BaseEngagementRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  /// The metadata type for engagement tracking
  @override
  String get metadataType => 'engagement';

  /// Convert Firestore document to EngagementMetadata
  @override
  EngagementMetadata fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return EngagementMetadata.fromFirestore(doc);
  }

  /// Convert EngagementMetadata to Firestore data
  @override
  Map<String, dynamic> toFirestore(EngagementMetadata metadata) {
    return metadata.toFirestore();
  }

  /// Mark content as engaged (imported, joined, etc.) by the current user.
  /// [resourceId] ID of the content being engaged with
  /// [action] Type of engagement ('import', 'join', 'copy', etc.)
  /// [targetId] Optional ID of created entity (imported recipe ID, etc.)
  /// **Security**: Validates metadata access and enforces self-annotation
  /// **Audit**: Logs engagement operation to FirebaseAuditRepository (GDPR Article 30)
  /// **Use Case**: User imports shared recipe → mark as imported with target recipe ID
  Future<void> markAsEngaged(
    String resourceId, {
    required String action,
    String? targetId,
  }) async {
    final userId = requireCurrentUserId();
    await addMetadata(
      resourceId,
      userId,
      additionalData: {
        'action': action,
        'targetId': ?targetId,
      },
    );
  }

  /// Check if the current user has engaged with the content.
  /// [resourceId] ID of the content to check
  /// Returns true if the current user has engaged with the content, false otherwise
  /// **Note**: No permission validation (existence check is non-sensitive)
  Future<bool> hasEngaged(String resourceId) async {
    final userId = requireCurrentUserId();
    return await hasMetadata(resourceId, userId);
  }

  /// Get the engagement metadata for the current user.
  /// [resourceId] ID of the content
  /// Returns EngagementMetadata if exists, null otherwise (includes action and targetId)
  /// **Security**: Validates metadata access before returning data
  Future<EngagementMetadata?> getUserEngagement(String resourceId) async {
    final userId = requireCurrentUserId();
    return await getMetadata(resourceId, userId);
  }

  /// Get all users who have engaged with the content.
  /// [resourceId] ID of the content
  /// Returns list of EngagementMetadata for all engagements
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Show "Imported by 12 people" on shared content
  Future<List<EngagementMetadata>> getEngagements(String resourceId) async {
    return await getMetadataForResource(resourceId);
  }

  /// Get the number of users who have engaged with the content.
  /// [resourceId] ID of the content
  /// Returns count of engagements
  /// **Security**: Validates metadata access before returning count
  /// **Use Case**: Display engagement count on shared content
  Future<int> getEngagementCount(String resourceId) async {
    return await getMetadataCount(resourceId);
  }

  /// Get engagements filtered by action type.
  /// [resourceId] ID of the content
  /// [action] Filter by action type ('import', 'join', etc.)
  /// Returns list of EngagementMetadata matching the action
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: Show "5 imports, 3 joins" statistics
  Future<List<EngagementMetadata>> getEngagementsByAction(
    String resourceId,
    String action,
  ) async {
    final allEngagements = await getEngagements(resourceId);
    return allEngagements.where((e) => e.action == action).toList();
  }
}
