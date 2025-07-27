import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import '../interfaces/recipe_repository.dart';
import '../../models/recipe_unified.dart';
import '../../models/recipe_change.dart';
import 'base_firebase_repository.dart';
import '../../core/exceptions/permission_exceptions.dart';

/// Firebase repository for user recipes stored in /users/{userId}/recipes collection.
///
/// Refactored to extend BaseFirebaseRepository with UserScopedFirebaseRepository mixin,
/// eliminating 40+ lines of duplicate CRUD code and authentication checks.
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    with UserScopedFirebaseRepository<Recipe>
    implements RecipeRepository {
  // ignore: use_super_parameters
  FirebaseRecipeRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  }) : super(
          firestore: firestore,
          authRepository: authRepository,
        );

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'recipes';

  @override
  Recipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Recipe.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Recipe entity) => entity.toFirestore();

  @override
  String getId(Recipe entity) => entity.id;

  // ===== ENHANCED BASE CLASS METHODS WITH PERMISSION VALIDATION =====

  @override
  Future<Recipe> create(Recipe entity) async {
    // Validate user owns the recipe they're creating
    final currentUser = requireCurrentUserId();
    
    // For personal recipes, createdBy should match current user
    final ownerId = entity.socialData?.ownerId ?? entity.createdBy ?? currentUser;
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: ownerId,
      operation: 'create recipe',
    );
    
    // Validate required fields
    validateRequiredFields(
      data: entity.toFirestore(),
      requiredFields: ['title', 'userId', 'createdAt', 'updatedAt'],
      resourceType: 'recipe',
    );
    
    return await super.create(entity);
  }

  @override
  Future<void> update(Recipe entity) async {
    // Validate user owns the recipe they're updating
    final currentUser = requireCurrentUserId();
    
    // First check if recipe exists and user owns it
    final existing = await read(entity.id);
    if (existing == null) {
      throw ResourceNotFoundException(
        'Recipe not found',
        resourceType: 'recipe',
        resourceId: entity.id,
      );
    }
    
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: existing.socialData?.ownerId ?? existing.createdBy ?? '',
      resourceType: 'recipe',
      resourceId: entity.id,
    );
    
    return await super.update(entity);
  }

  @override
  Future<void> delete(String id) async {
    // Validate user owns the recipe they're deleting
    final currentUser = requireCurrentUserId();
    
    // First check if recipe exists and user owns it
    final existing = await read(id);
    if (existing == null) {
      throw ResourceNotFoundException(
        'Recipe not found',
        resourceType: 'recipe',
        resourceId: id,
      );
    }
    
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: existing.socialData?.ownerId ?? existing.createdBy ?? '',
      resourceType: 'recipe',
      resourceId: id,
    );
    
    return await super.delete(id);
  }

  @override
  Future<List<Recipe>> readAll() async {
    // Override to add ordering that was in original implementation
    try {
      final ref = getCollectionRef();
      final snapshot = await ref.orderBy('updatedAt', descending: true).get();
      return snapshot.docs.map(fromFirestore).toList();
    } catch (e) {
      // Fall back to safe version if no user
      return await readAllSafe();
    }
  }

  // ===== SPECIALIZED RECIPE OPERATIONS =====

  @override
  Stream<List<Recipe>> watchRecipes(String userId) {
    // Use the mixin method to get user-specific collection
    return getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(fromFirestore).toList());
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    final lower = query.toLowerCase();
    final all = await readAll();
    return all.where((r) => r.title.toLowerCase().contains(lower)).toList();
  }

  @override
  Future<void> addRecipes(List<Recipe> recipes) async {
    // Use the base class batch method
    await createBatch(recipes);
  }

  @override
  StreamSubscription subscribeToUserRecipes(
    String userId,
    void Function(List<RecipeChange>) onData, {
    Function? onError,
  }) {
    return getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final changes = snapshot.docChanges.map((change) {
        final recipe = fromFirestore(change.doc);
        final type = switch (change.type) {
          DocumentChangeType.added => RecipeChangeType.added,
          DocumentChangeType.modified => RecipeChangeType.modified,
          DocumentChangeType.removed => RecipeChangeType.removed,
        };
        return RecipeChange(type: type, recipe: recipe);
      }).toList();

      if (changes.isNotEmpty) onData(changes);
    }, onError: onError);
  }

  @override
  Future<List<Recipe>> fetchArchiveRecipes() async {
    // Archive recipes are stored in a global collection, not user-scoped
    final snap =
        await FirebaseFirestore.instance.collection('butlery_archive').get();
    return snap.docs.map(fromFirestore).toList();
  }

  @override
  Future<Recipe> fetchArchiveRecipe(String id) async {
    // Archive recipes are stored in a global collection, not user-scoped
    final doc = await FirebaseFirestore.instance
        .collection('butlery_archive')
        .doc(id)
        .get();
    if (!doc.exists) {
      throw Exception('Archive recipe not found');
    }
    return fromFirestore(doc);
  }

  @override
  Future<List<Recipe>> fetchUserRecipes(String userId) async {
    // Use the mixin method for user-specific collection
    final snap = await getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs.map(fromFirestore).toList();
  }
}
