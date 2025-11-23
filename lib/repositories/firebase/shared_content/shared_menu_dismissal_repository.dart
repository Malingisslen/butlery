/// Dismissal tracking repository for shared menus.
/// Extends BaseDismissalRepository to track when users dismiss shared menus.
/// Storage: shared_menus/{menuId}/dismissals/{userId}
/// **Use Case**: Hide menu from user's shared content feed
/// **GDPR**: Audit logs all dismissal operations (Article 30)

import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';

class SharedMenuDismissalRepository extends BaseDismissalRepository {
  SharedMenuDismissalRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_menus';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can dismiss if the shared menu exists and they have access
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
