import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'social_recipe_repository.dart';

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
}
