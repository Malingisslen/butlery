/// View status tracking repository for shared menus.
/// Extends BaseViewRepository to track when users view shared menus.
/// Storage: shared_menus/{menuId}/views/{userId}
/// **Use Case**: Mark menu as viewed when user opens it
/// **GDPR**: Audit logs all view operations (Article 30)

import 'package:butlery/repositories/firebase/base_view_repository.dart';

class SharedMenuViewRepository extends BaseViewRepository {
  SharedMenuViewRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_menus';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can view metadata if the shared menu exists and they have access
    // This is validated by checking if the menu document exists
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
