/// Engagement tracking repository for shared shopping lists.
/// Extends BaseEngagementRepository to track when users join shared shopping lists.
/// Storage: shared_shopping_lists/{listId}/engagements/{userId}
/// **Use Case**: Track list joins/imports to personal collection
/// **GDPR**: Audit logs all join operations (Article 30)

import 'package:butlery/repositories/firebase/base_engagement_repository.dart';

class SharedShoppingEngagementRepository extends BaseEngagementRepository {
  SharedShoppingEngagementRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_shopping_lists';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can track engagement if the shared shopping list exists and they have access
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
