import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_repository.dart';
import '../recipe_repository.dart';
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
  Future<void> addRecipe(Recipe recipe) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(recipe.id).set(recipe.toFirestore());
  }

  @override
  Future<void> updateRecipe(Recipe recipe) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(recipe.id).update(recipe.toFirestore());
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(id).delete();
  }

  @override
  Future<List<Recipe>> getAllRecipes() async {
    final ref = _userCollection;
    if (ref == null) return [];
    final snapshot = await ref.orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map((d) => Recipe.fromFirestore(d)).toList();
  }
}
