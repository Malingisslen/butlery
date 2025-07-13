import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/realtime/realtime_recipe.dart';

class CollaborativeRecipeRepository {
  final FirebaseFirestore _firestore;

  CollaborativeRecipeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createRealtimeRecipe(RealtimeRecipe recipe) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipe.id)
        .set(recipe.toFirestore());
  }

  Future<void> updateRealtimeRecipe(RealtimeRecipe recipe) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipe.id)
        .update(recipe.toFirestore());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRealtimeRecipe(String id) {
    return _firestore.collection('realtime_recipes').doc(id).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActivePresence(String id) {
    return _firestore
        .collection('realtime_recipes')
        .doc(id)
        .collection('presence')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  Future<void> setPresence(
    String recipeId,
    String userId,
    Map<String, dynamic> data,
  ) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set(data);
  }

  Future<void> updatePresence(
    String recipeId,
    String userId,
    Map<String, dynamic> data,
  ) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .update(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchRealtimeRecipe(String id) {
    return _firestore.collection('realtime_recipes').doc(id).get();
  }
}
