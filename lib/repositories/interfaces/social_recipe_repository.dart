import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/shared_recipe.dart';
import '../../models/shared_menu.dart';

abstract class SocialRecipeRepository {
  CollectionReference<Map<String, dynamic>> get sharedRecipesRef;
  CollectionReference<Map<String, dynamic>> get sharedMenusRef;
  CollectionReference<Map<String, dynamic>> get sharedContentRef;
  CollectionReference<Map<String, dynamic>> get recipeCommentsRef;
  Stream<User?> authStateChanges();
  User? get currentUser;
  
  // Shared content methods
  Future<List<SharedRecipe>> getSharedRecipes(String userId);
  Future<List<SharedMenu>> getSharedMenus(String userId);
  Future<void> markSharedRecipeAsViewed(String recipeId, String userId);
  Future<void> markSharedMenuAsViewed(String menuId, String userId);
  Future<void> markSharedRecipeAsImported(String recipeId, String userId);
  Future<void> markSharedMenuAsImported(String menuId, String userId);
  Future<void> dismissSharedRecipe(String recipeId, String userId);
  Future<void> dismissSharedMenu(String menuId, String userId);
  Future<void> undismissSharedRecipe(String recipeId, String userId);
  Future<void> undismissSharedMenu(String menuId, String userId);
  Future<void> shareContent({
    required String fromUserId,
    required String toUserId,
    required String contentType,
    required Map<String, dynamic> contentData,
  });
}
