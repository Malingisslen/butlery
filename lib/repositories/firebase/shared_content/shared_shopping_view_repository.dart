/// View status tracking repository for shared shopping lists.
/// Extends BaseViewRepository to track when users view shared shopping lists.
/// Storage: shared_content/{listId}/views/{userId}
/// **Use Case**: Mark list as viewed when user opens it
/// **GDPR**: Audit logs all view operations (Article 30)

import 'package:butlery/repositories/firebase/base_view_repository.dart';

class SharedShoppingViewRepository extends BaseViewRepository {
  SharedShoppingViewRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_content';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can view metadata if the shared shopping list exists and they have access
    // This is validated by checking if the list document exists
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
