import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import '../interfaces/recipe_repository.dart';
import '../../models/recipe.dart';

class FirebaseRecipeRepository implements RecipeRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  FirebaseRecipeRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository;

  CollectionReference<Map<String, dynamic>>? get _userCollection {
    final uid = _authRepository.currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  @override
  Future<Recipe> create(Recipe recipe) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(recipe.id).set(recipe.toFirestore());
    return recipe;
  }

  @override
  Future<void> update(Recipe recipe) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(recipe.id).update(recipe.toFirestore());
  }

  @override
  Future<void> delete(String id) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(id).delete();
  }

  @override
  Future<List<Recipe>> readAll() async {
    final ref = _userCollection;
    if (ref == null) return [];
    final snapshot = await ref.orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map((d) => Recipe.fromFirestore(d)).toList();
  }

  @override
  Future<Recipe?> read(String id) async {
    final ref = _userCollection;
    if (ref == null) return null;
    final doc = await ref.doc(id).get();
    if (!doc.exists) return null;
    return Recipe.fromFirestore(doc);
  }

  @override
  Stream<List<Recipe>> watchRecipes(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('recipes')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Recipe.fromFirestore).toList());
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    final lower = query.toLowerCase();
    final all = await readAll();
    return all
        .where((r) => r.title.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<void> addRecipes(List<Recipe> recipes) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    final batch = _firestore.batch();
    for (final recipe in recipes) {
      batch.set(ref.doc(recipe.id), recipe.toFirestore());
    }
    await batch.commit();
  }
}
