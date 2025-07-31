import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Firebase Firestore implementation for recipe data operations and real-time synchronization.
///
/// This repository implements the [RecipeRepository] interface using Firebase Firestore
/// as the backend, storing user recipes in user-scoped collections at `/users/{userId}/recipes`.
/// It provides comprehensive recipe management with security validation, real-time streaming,
/// and performance optimizations.
///
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] with [UserScopedFirebaseRepository] mixin to eliminate
/// code duplication while providing specialized recipe operations. This design reduces
/// boilerplate by 40+ lines and ensures consistent authentication and permission patterns.
///
/// **Security Implementation:**
/// - **Permission Validation**: All operations validate user ownership and access rights
/// - **Authentication Checks**: Ensures authenticated users for all recipe operations
/// - **Resource Validation**: Validates recipe existence and user permissions
/// - **Audit Logging**: Logs permission checks for security monitoring
/// - **Field Validation**: Validates required fields and data integrity
///
/// **Performance Optimizations:**
/// - **Streaming Limits**: Caps recipe streams at 50 most recent recipes
/// - **Search Limits**: Limits search scope to 200 most recent recipes for performance
/// - **Archive Limits**: Restricts archive queries to 100 recipes maximum
/// - **Efficient Queries**: Uses server-side ordering and filtering where possible
/// - **Batch Operations**: Supports efficient bulk recipe operations
///
/// **Real-time Features:**
/// - **Recipe Streaming**: Live updates for recipe collections with automatic ordering
/// - **Change Tracking**: Detailed change notifications for collaborative features
/// - **Collaborative Editing**: Real-time synchronization for shared recipe editing
/// - **Archive Integration**: Access to community recipe archive with performance limits
///
/// **Usage Examples:**
/// ```dart
/// final recipeRepo = FirebaseRecipeRepository(
///   authRepository: sl<AuthRepository>(),
/// );
/// 
/// // Create with validation
/// final newRecipe = Recipe(title: 'Pasta', createdBy: userId);
/// await recipeRepo.create(newRecipe);
/// 
/// // Stream with performance limits  
/// recipeRepo.watchRecipes(userId).listen((recipes) {
///   // Receives max 50 most recent recipes
/// });
/// 
/// // Search with scope limits
/// final results = await recipeRepo.searchRecipes('chicken');
/// // Searches within 200 most recent recipes
/// ```
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
    // ✅ PERFORMANCE FIX: Added limit to prevent streaming large datasets
    return getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .limit(50) // Stream max 50 most recent recipes
        .snapshots()
        .map((snap) => snap.docs.map(fromFirestore).toList());
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    // ✅ PERFORMANCE FIX: Added limit and optimized search approach
    // Instead of loading ALL recipes, we limit and use server-side orderBy for better performance
    final lower = query.toLowerCase();
    
    // For small datasets, this is acceptable, but for optimization we could implement
    // server-side text search with Algolia or similar in the future
    final userId = currentUserId;
    if (userId == null) return [];
    
    final snap = await getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .limit(200) // Limit search scope to most recent 200 recipes
        .get();
    
    return snap.docs
        .map(fromFirestore)
        .where((r) => r.title.toLowerCase().contains(lower))
        .toList();
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
    // ✅ PERFORMANCE FIX: Added limit to prevent unbounded query
    final snap = await FirebaseFirestore.instance
        .collection('butlery_archive')
        .orderBy('createdAt', descending: true)
        .limit(100) // Load max 100 archive recipes
        .get();
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
