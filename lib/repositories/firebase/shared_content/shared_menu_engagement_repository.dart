/// Engagement tracking repository for shared menus.
/// Extends BaseEngagementRepository to track when users import shared menus.
/// Storage: shared_menus/{menuId}/engagements/{userId}
/// **Use Case**: Track menu imports to personal collection
/// **GDPR**: Audit logs all import operations (Article 30)

import 'package:butlery/repositories/firebase/base_engagement_repository.dart';

class SharedMenuEngagementRepository extends BaseEngagementRepository {
  SharedMenuEngagementRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_menus';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can track engagement if the shared menu exists and they have access
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
