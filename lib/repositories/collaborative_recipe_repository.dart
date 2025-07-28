import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';

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

  // Missing methods for collaborative manager
  Stream<RealtimeRecipe?> getRealtimeRecipeStream(String id) {
    return _firestore
        .collection('realtime_recipes')
        .doc(id)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return RealtimeRecipe.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Stream<List<LiveEditor>> getParticipantsStream(String id) {
    return _firestore
        .collection('realtime_recipes')
        .doc(id)
        .collection('presence')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LiveEditor.fromFirestore(doc.data()))
          .toList();
    });
  }

  Future<void> updateUserPresence(String recipeId, String userId, String displayName) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set({
      'userId': userId,
      'displayName': displayName,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'isActive': true,
    }, SetOptions(merge: true));
  }

  Future<void> clearUserPresence(String recipeId, String userId) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .update({'isActive': false});
  }
}
