/// View status tracking repository for shared recipes.
/// Extends BaseViewRepository to track when users view shared recipes.
/// Storage: shared_recipes/{recipeId}/views/{userId}
/// **Use Case**: Mark recipe as viewed when user opens it
/// **GDPR**: Audit logs all view operations (Article 30)

import 'package:butlery/repositories/firebase/base_view_repository.dart';

class SharedRecipeViewRepository extends BaseViewRepository {
  SharedRecipeViewRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get parentCollectionName => 'shared_recipes';

  @override
  Future<bool> validateMetadataAccess(String userId, String resourceId) async {
    // User can view metadata if the shared recipe exists and they have access
    // This is validated by checking if the recipe document exists
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
