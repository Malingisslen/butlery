/// Engagement tracking repository for shared recipes.
/// Extends BaseEngagementRepository to track when users import shared recipes.
/// Storage: shared_content/{recipeId}/engagements/{userId}
/// **Use Case**: Track recipe imports to personal collection
/// **GDPR**: Audit logs all import operations (Article 30)

import 'package:butlery/repositories/firebase/base_engagement_repository.dart';

class SharedRecipeEngagementRepository extends BaseEngagementRepository {
  SharedRecipeEngagementRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_content';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can track engagement if the shared recipe exists and they have access
    try {
      final doc = await firestore
          .collection(parentCollectionName)
          .doc(resourceId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }
}
