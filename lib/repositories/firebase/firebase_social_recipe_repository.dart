import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/social_recipe_repository.dart';
import '../../models/shared_recipe.dart';
import '../../models/shared_menu.dart';

class FirebaseSocialRecipeRepository implements SocialRecipeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseSocialRecipeRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  CollectionReference<Map<String, dynamic>> get sharedRecipesRef =>
      _firestore.collection('shared_recipes');

  @override
  CollectionReference<Map<String, dynamic>> get sharedMenusRef =>
      _firestore.collection('shared_menus');

  @override
  CollectionReference<Map<String, dynamic>> get sharedContentRef =>
      _firestore.collection('shared_content');

  @override
  CollectionReference<Map<String, dynamic>> get recipeCommentsRef =>
      _firestore.collection('recipe_comments');

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<List<SharedRecipe>> getSharedRecipes(String userId) async {
    try {
      final snapshot = await sharedRecipesRef
          .where('sharedWithUserIds', arrayContains: userId)
          .get();
      
      return snapshot.docs.map((doc) => SharedRecipe.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get shared recipes: $e');
    }
  }

  @override
  Future<List<SharedMenu>> getSharedMenus(String userId) async {
    try {
      final snapshot = await sharedMenusRef
          .where('sharedWithUserIds', arrayContains: userId)
          .get();
      
      return snapshot.docs.map((doc) => SharedMenu.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get shared menus: $e');
    }
  }

  @override
  Future<void> markSharedRecipeAsViewed(String recipeId, String userId) async {
    await sharedRecipesRef.doc(recipeId).update({
      'viewedByUserIds': FieldValue.arrayUnion([userId]),
      'viewedAt.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSharedMenuAsViewed(String menuId, String userId) async {
    await sharedMenusRef.doc(menuId).update({
      'viewedByUserIds': FieldValue.arrayUnion([userId]),
      'viewedAt.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSharedRecipeAsImported(String recipeId, String userId) async {
    await sharedRecipesRef.doc(recipeId).update({
      'importedByUserIds': FieldValue.arrayUnion([userId]),
      'importedAt.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markSharedMenuAsImported(String menuId, String userId) async {
    await sharedMenusRef.doc(menuId).update({
      'importedByUserIds': FieldValue.arrayUnion([userId]),
      'importedAt.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> dismissSharedRecipe(String recipeId, String userId) async {
    await sharedRecipesRef.doc(recipeId).update({
      'dismissedByUserIds': FieldValue.arrayUnion([userId]),
      'dismissedAt.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> dismissSharedMenu(String menuId, String userId) async {
    await sharedMenusRef.doc(menuId).update({
      'dismissedByUserIds': FieldValue.arrayUnion([userId]),
      'dismissedAt.$userId': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> undismissSharedRecipe(String recipeId, String userId) async {
    await sharedRecipesRef.doc(recipeId).update({
      'dismissedByUserIds': FieldValue.arrayRemove([userId]),
      'dismissedAt.$userId': FieldValue.delete(),
    });
  }

  @override
  Future<void> undismissSharedMenu(String menuId, String userId) async {
    await sharedMenusRef.doc(menuId).update({
      'dismissedByUserIds': FieldValue.arrayRemove([userId]),
      'dismissedAt.$userId': FieldValue.delete(),
    });
  }

  @override
  Future<void> shareContent({
    required String fromUserId,
    required String toUserId,
    required String contentType,
    required Map<String, dynamic> contentData,
  }) async {
    await sharedContentRef.add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'contentType': contentType,
      'contentData': contentData,
      'sharedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}
