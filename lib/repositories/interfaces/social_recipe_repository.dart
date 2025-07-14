import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class SocialRecipeRepository {
  CollectionReference<Map<String, dynamic>> get sharedRecipesRef;
  CollectionReference<Map<String, dynamic>> get sharedMenusRef;
  CollectionReference<Map<String, dynamic>> get sharedContentRef;
  CollectionReference<Map<String, dynamic>> get recipeCommentsRef;
  Stream<User?> authStateChanges();
  User? get currentUser;
}
