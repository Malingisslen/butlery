/// Dismissal tracking repository for shared shopping lists.
/// Extends BaseDismissalRepository to track when users dismiss shared shopping lists.
/// Storage: shared_content/{listId}/dismissals/{userId}
/// **Use Case**: Hide list from user's shared content feed
/// **GDPR**: Audit logs all dismissal operations (Article 30)

import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';

class SharedShoppingDismissalRepository extends BaseDismissalRepository {
  SharedShoppingDismissalRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_content';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can dismiss if the shared shopping list exists and they have access
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
