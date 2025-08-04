import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

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
///   authRepository: ServiceLocator.get<AuthRepository>(),
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
    with StreamManagementMixin, UserScopedFirebaseRepository<Recipe>
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
    // ✅ PERFORMANCE FIX: Added limit to prevent unbounded query
    final snap = await getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .limit(50) // Limit to 50 most recent recipes
        .get();
    return snap.docs.map(fromFirestore).toList();
  }

  // ===== SEARCH AND FILTER METHODS =====

  /// Find recipes by meal type (e.g., 'Frukost', 'Lunch', 'Middag')
  Future<List<Recipe>> findByMealType(String mealType) async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    final snap = await getCollectionForUser(userId)
        .where('mealType', isEqualTo: mealType)
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .get();
    
    return snap.docs.map(fromFirestore).toList();
  }

  /// Find recipes containing a specific ingredient
  Future<List<Recipe>> findByIngredient(String ingredient) async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    // Note: Firestore doesn't support array-contains with case-insensitive search
    // This is a basic implementation - for production, consider using Algolia or similar
    final snap = await getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .limit(200)
        .get();
    
    final lowerIngredient = ingredient.toLowerCase();
    return snap.docs
        .map(fromFirestore)
        .where((recipe) => recipe.ingredients.any(
            (recipeIngredient) => recipeIngredient.toLowerCase().contains(lowerIngredient)))
        .toList();
  }

  /// Search recipes by title with more focused search
  Future<List<Recipe>> searchByTitle(String title) async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    final lowerTitle = title.toLowerCase();
    final snap = await getCollectionForUser(userId)
        .orderBy('updatedAt', descending: true)
        .limit(200)
        .get();
    
    return snap.docs
        .map(fromFirestore)
        .where((recipe) => recipe.title.toLowerCase().contains(lowerTitle))
        .toList();
  }

  // ===== PERMISSION METHODS =====

  /// Check if user can read a specific recipe
  Future<bool> canRead(String recipeId, String userId) async {
    try {
      final recipe = await read(recipeId);
      if (recipe == null) return false;
      
      // User can read if:
      // 1. They own the recipe
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy ?? '';
      if (ownerId == userId) return true;
      
      // 2. Recipe is shared with them (check member permissions)
      final memberPermissions = recipe.socialData?.memberPermissions ?? {};
      if (memberPermissions.containsKey(userId)) return true;
      
      // 3. Recipe is public (future feature)
      // if (recipe.socialData?.isPublic ?? false) return true;
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can write/edit a specific recipe
  Future<bool> canWrite(String recipeId, String userId) async {
    try {
      final recipe = await read(recipeId);
      if (recipe == null) return false;
      
      // User can write if:
      // 1. They own the recipe
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy ?? '';
      if (ownerId == userId) return true;
      
      // 2. They are a member with write permissions
      final memberPermissions = recipe.socialData?.memberPermissions ?? {};
      final userPermission = memberPermissions[userId];
      if (userPermission != null) {
        // Check if user has write or admin permission
        return userPermission == ResourcePermission.admin || 
               userPermission == ResourcePermission.editor;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can delete a specific recipe
  Future<bool> canDelete(String recipeId, String userId) async {
    try {
      final recipe = await read(recipeId);
      if (recipe == null) return false;
      
      // User can delete if they own the recipe
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy ?? '';
      return ownerId == userId;
    } catch (e) {
      return false;
    }
  }

  // ===== COLLABORATION METHODS =====

  /// Add a collaborator to a recipe
  Future<void> addCollaborator(String recipeId, String userId) async {
    final currentUser = requireCurrentUserId();
    
    // First verify current user owns the recipe
    final recipe = await read(recipeId);
    if (recipe == null) {
      throw ResourceNotFoundException(
        'Recipe not found',
        resourceType: 'recipe',
        resourceId: recipeId,
      );
    }
    
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: recipe.socialData?.ownerId ?? recipe.createdBy ?? '',
      resourceType: 'recipe',
      resourceId: recipeId,
    );
    
    // Add member with editor permission
    final currentMembers = recipe.socialData?.memberPermissions ?? {};
    if (!currentMembers.containsKey(userId)) {
      final updatedMembers = {...currentMembers, userId: ResourcePermission.editor};
      
      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
          memberPermissions: updatedMembers,
        ) ?? RecipeSocialData(
          memberPermissions: updatedMembers,
        ),
      );
      
      await update(updatedRecipe);
    }
  }

  /// Remove a collaborator from a recipe
  Future<void> removeCollaborator(String recipeId, String userId) async {
    final currentUser = requireCurrentUserId();
    
    // First verify current user owns the recipe
    final recipe = await read(recipeId);
    if (recipe == null) {
      throw ResourceNotFoundException(
        'Recipe not found',
        resourceType: 'recipe',
        resourceId: recipeId,
      );
    }
    
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: recipe.socialData?.ownerId ?? recipe.createdBy ?? '',
      resourceType: 'recipe',
      resourceId: recipeId,
    );
    
    // Remove member from the recipe
    final currentMembers = recipe.socialData?.memberPermissions ?? {};
    if (currentMembers.containsKey(userId)) {
      final updatedMembers = Map<String, ResourcePermission>.from(currentMembers);
      updatedMembers.remove(userId);
      
      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
          memberPermissions: updatedMembers,
        ),
      );
      
      await update(updatedRecipe);
    }
  }
}
