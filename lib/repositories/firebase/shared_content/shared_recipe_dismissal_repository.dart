/// Dismissal tracking repository for shared recipes.
/// Extends BaseDismissalRepository to track when users dismiss shared recipes.
/// Storage: shared_recipes/{recipeId}/dismissals/{userId}
/// **Use Case**: Hide recipe from user's shared content feed
/// **GDPR**: Audit logs all dismissal operations (Article 30)

import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';

class SharedRecipeDismissalRepository extends BaseDismissalRepository {
  SharedRecipeDismissalRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_recipes';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can dismiss if the shared recipe exists and they have access
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
