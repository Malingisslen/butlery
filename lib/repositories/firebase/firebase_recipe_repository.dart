import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/modules/recipe_legacy_validator.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/performance/firebase_performance_service.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase Firestore implementation for recipe data operations and real-time synchronization.
/// This repository implements the [RecipeRepository] interface using Firebase Firestore
/// as the backend, storing user recipes in user-scoped collections at `/users/{userId}/recipes`.
/// It provides comprehensive recipe management with security validation, real-time streaming,
/// and performance optimizations.
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] with [UserScopedFirebaseRepository] mixin to eliminate
/// code duplication while providing specialized recipe operations. This design reduces
/// boilerplate by 40+ lines and ensures consistent authentication and permission patterns.
/// **Security Implementation:**
/// - **Permission Validation**: All operations validate user ownership and access rights
/// - **Authentication Checks**: Ensures authenticated users for all recipe operations
/// - **Resource Validation**: Validates recipe existence and user permissions
/// - **Audit Logging**: Logs permission checks for security monitoring
/// - **Field Validation**: Validates required fields and data integrity
/// **Performance Optimizations:**
/// - **Streaming Limits**: Caps recipe streams at 50 most recent recipes
/// - **Search Limits**: Limits search scope to 200 most recent recipes for performance
/// - **Archive Limits**: Restricts archive queries to 100 recipes maximum
/// - **Efficient Queries**: Uses server-side ordering and filtering where possible
/// - **Batch Operations**: Supports efficient bulk recipe operations
/// **Real-time Features:**
/// - **Recipe Streaming**: Live updates for recipe collections with automatic ordering
/// - **Change Tracking**: Detailed change notifications for collaborative features
/// - **Collaborative Editing**: Real-time synchronization for shared recipe editing
/// - **Archive Integration**: Access to community recipe archive with performance limits
/// **Usage Examples:**
/// ```dart
/// final recipeRepo = FirebaseRecipeRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Create with validation
/// final newRecipe = Recipe(title: 'Pasta', createdBy: userId);
/// await recipeRepo.create(newRecipe);
/// // Stream with performance limits
/// recipeRepo.watchRecipes(userId).listen((recipes) {
///   // Receives max 50 most recent recipes
/// });
/// // Search with scope limits
/// final results = await recipeRepo.searchRecipes('chicken');
/// // Searches within 200 most recent recipes
/// ```
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    with StreamManagementMixin, UserScopedFirebaseRepository<Recipe>
    implements RecipeRepository {
  late final RecipeLegacyValidator _legacyValidator;

  // ignore: use_super_parameters
  FirebaseRecipeRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  }) : super(
          firestore: firestore,
          authRepository: authRepository,
          auditRepository: auditRepository,
        ) {
    _legacyValidator = RecipeLegacyValidator(
      firestore: this.firestore,
      getUserRecipeDoc: (userId, recipeId) async =>
          getCollectionForUser(userId).doc(recipeId).get(),
      validateOwnership: validateOwnership,
    );
  }
  @override
  String get collectionName => FirestoreCollections.recipes;

  @override
  Recipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Recipe.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Recipe entity) => entity.toFirestore();

  @override
  String getId(Recipe entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(String userId, Recipe entity) async {
    // Users can only create recipes in their own collection
    // Validate ownerId matches the authenticated user
    final ownerId =
        (entity.socialData?.ownerId ?? entity.createdBy).orDefault(userId);
    return ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, Recipe? entity) async {
    if (entity == null) return false;

    // Owner can always read their own recipes
    final ownerId = (entity.socialData?.ownerId ?? entity.createdBy).orEmpty();
    if (ownerId == userId) return true;

    // Check if user is a collaborator/member with permissions (for collaborative recipes)
    if (entity.isCollaborative &&
        entity.socialData?.memberPermissions != null) {
      if (entity.socialData!.memberPermissions!.containsKey(userId)) {
        return true;
      }
    }

    // For now, allow guest viewing on collaborative recipes if enabled
    if (entity.isCollaborative &&
        (entity.socialData?.allowGuestViewing).orFalse()) {
      return true;
    }

    return false;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, Recipe entity) async {
    // Owner can always update
    final ownerId = (entity.socialData?.ownerId ?? entity.createdBy).orEmpty();
    if (ownerId == userId) return true;

    // For collaborative recipes, check if user has write permission
    if (entity.isCollaborative &&
        entity.socialData?.memberPermissions != null) {
      if (entity.socialData!.memberPermissions!.containsKey(userId)) {
        // For now, allow all members with permissions to edit collaborative recipes
        return true;
      }
    }

    return false;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Only the owner can delete recipes
    // Note: We need to fetch the recipe to check ownership
    try {
      final recipe = await read(resourceId);
      if (recipe == null) return false;

      final ownerId =
          (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty();
      return ownerId == userId;
    } catch (e) {
      AppLogger.error('Failed to validate delete permission: $e');
      return false;
    }
  }

  @override
  Future<Recipe> create(Recipe entity) async {
    return await FirebasePerformanceService.traceOperation(
      'recipe_create',
      (trace) async {
        // Validate user owns the recipe they're creating
        final currentUser = requireCurrentUserId();

        // For personal recipes, createdBy should match current user
        final ownerId = (entity.socialData?.ownerId ?? entity.createdBy)
            .orDefault(currentUser);
        await validateSelfOperation(
          currentUserId: currentUser,
          targetUserId: ownerId,
          operation: 'create recipe',
        );

        // Validate required fields - extract core data for validation
        final firestoreData = entity.toFirestore();
        final coreData =
            (firestoreData['core'] as Map<String, dynamic>?).orEmpty();

        // Check for required fields in core data
        validateRequiredFields(
          data: coreData,
          requiredFields: ['title', 'createdBy', 'createdAt', 'updatedAt'],
          resourceType: 'recipe',
        );

        // MODUL1 Phase 3: Auto-populate normalized ingredients for advanced features
        Recipe recipeToSave = entity;
        if (IngredientProcessor.needsNormalization(entity)) {
          final normalizedIngredients =
              IngredientProcessor.normalizeIngredientsForRecipe(
            entity.core.ingredients,
          );

          recipeToSave = entity.copyWith(
            ingredientsNormalized: normalizedIngredients,
          );
        }

        final result = await super.create(recipeToSave);

        // Add performance metrics
        trace.setMetric('ingredient_count', entity.core.ingredients.length);
        trace.putAttribute(
            'has_image', entity.imageUrls.isNotEmpty ? 'true' : 'false');
        trace.putAttribute(
            'is_collaborative', entity.isCollaborative ? 'true' : 'false');

        return result;
      },
    );
  }

  @override
  Future<void> update(Recipe entity) async {
    return await FirebasePerformanceService.traceOperation(
      'recipe_update',
      (trace) async {
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
          resourceOwnerId:
              (existing.socialData?.ownerId ?? existing.createdBy).orEmpty(),
          resourceType: 'recipe',
          resourceId: entity.id,
        );

        // MODUL1 Phase 3: Auto-populate normalized ingredients for advanced features
        Recipe recipeToSave = entity;
        if (IngredientProcessor.needsNormalization(entity)) {
          final normalizedIngredients =
              IngredientProcessor.normalizeIngredientsForRecipe(
            entity.core.ingredients,
          );

          recipeToSave = entity.copyWith(
            ingredientsNormalized: normalizedIngredients,
          );
        }

        await super.update(recipeToSave);

        // Add performance metrics
        trace.setMetric('ingredient_count', entity.core.ingredients.length);
        trace.putAttribute(
            'has_image', entity.imageUrls.isNotEmpty ? 'true' : 'false');
        trace.putAttribute(
            'is_collaborative', entity.isCollaborative ? 'true' : 'false');
        trace.putAttribute('ingredients_normalized',
            IngredientProcessor.needsNormalization(entity) ? 'true' : 'false');
      },
    );
  }

  @override
  Future<void> delete(String id) async {
    return await FirebasePerformanceService.traceOperation(
      'recipe_delete',
      (trace) async {
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

        // ULTRATHINK FIX: Enhanced ownership validation with legacy recipe support
        final isLegacy = _legacyValidator.isLegacyRecipe(existing);
        final canDelete =
            await _legacyValidator.validateDeletionWithLegacySupport(
          existing,
          currentUser,
          id,
          isLegacy,
          (recipe) =>
              (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty(),
        );

        if (!canDelete) {
          throw PermissionDeniedException(
            'User does not have permission to delete this recipe',
            resource: 'recipe',
            operation: 'delete',
            userId: currentUser,
          );
        }

        // If it's a legacy recipe, repair its data before/after deletion for audit purposes
        if (isLegacy) {
          await _legacyValidator.logLegacyDeletion(existing, currentUser);
        }

        await super.delete(id);

        // Add performance metrics
        trace.putAttribute('is_legacy', isLegacy ? 'true' : 'false');
        trace.putAttribute(
            'is_collaborative', existing.isCollaborative ? 'true' : 'false');
        trace.putAttribute(
            'had_image', existing.imageUrls.isNotEmpty ? 'true' : 'false');
      },
    );
  }

  @override
  Future<List<Recipe>> readAll() async {
    // Override to add ordering that was in original implementation
    try {
      final ref = getCollectionRef();
      // Order by the nested field path since data is stored in 'core' structure
      // PERFORMANCE FIX: Added limit to prevent loading all recipes at once
      final snapshot = await ref
          .orderBy('core.updatedAt', descending: true)
          .limit(
              100) // Limit to 100 most recent recipes to prevent app freezing
          .get();
      return snapshot.docs.map(fromFirestore).toList();
    } catch (e) {
      // Fall back to safe version if no user
      return await readAllSafe();
    }
  }

  @override
  Stream<List<Recipe>> watchRecipes(String userId) {
    // Use the mixin method to get user-specific collection
    // ✅ PERFORMANCE FIX: Added limit to prevent streaming large datasets
    return getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(50) // Stream max 50 most recent recipes
        .snapshots()
        .map((snap) => snap.docs.map(fromFirestore).toList());
  }

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    // ✅ PERFORMANCE FIX: Added limit and optimized search approach
    // Instead of loading ALL recipes, we limit and use server-side orderBy for better performance
    return await FirebasePerformanceService.traceSearch(
      (trace) async {
        final lower = query.toLowerCase();

        // For small datasets, this is acceptable, but for optimization we could implement
        // server-side text search with Algolia or similar in the future
        final userId = currentUserId;
        if (userId == null) return [];

        final snap = await getCollectionForUser(userId)
            .orderBy('core.updatedAt', descending: true)
            .limit(200) // Limit search scope to most recent 200 recipes
            .get();

        final results = snap.docs
            .map(fromFirestore)
            .where((r) => r.title.toLowerCase().contains(lower))
            .toList();

        trace.putAttribute('query_length', query.length.toString());
        trace.putAttribute('user_id', userId);
        trace.setMetric('result_count', results.length);

        return results;
      },
      searchType: 'recipe_title',
    );
  }

  @override
  Future<int> countRecipesByTagId(String tagId) async {
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      AppLogger.warning('Failed to count recipes with tag "$tagId": $e');
      return 0;
    }
  }

  @override
  Future<List<Recipe>> fetchRecipesByTagId(
    String tagId, {
    int limit = 100,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .orderBy('core.updatedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to get recipes with tag "$tagId": $e');
      return [];
    }
  }

  /// Renames a personal tag across all user recipes that contain it.
  ///
  /// Uses Firestore FieldValue.arrayRemove/arrayUnion for atomic per-document
  /// updates the denormalized name in personalTags array.
  /// personalTagIds (UUIDs) is unchanged since IDs don't change on rename.
  /// Returns the number of recipes updated.
  @override
  Future<int> renamePersonalTagInRecipes(
    String tagId,
    String newName,
  ) async {
    if (tagId.isEmpty || newName.isEmpty) return 0;
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .get();

      if (snap.docs.isEmpty) return 0;

      // Read-modify-write for personalTags (array of maps)
      const batchLimit = 500;
      int updated = 0;

      for (var i = 0; i < snap.docs.length; i += batchLimit) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(batchLimit);

        for (final doc in chunk) {
          final data = doc.data();
          final coreData = data['core'] as Map<String, dynamic>? ?? {};
          final personalTags = coreData['personalTags'] as List?;

          if (personalTags != null) {
            // Update the name field in the matching personalTags entry
            final updatedTags = personalTags.map((entry) {
              if (entry is Map && entry['tagId'] == tagId) {
                return {...entry, 'name': newName};
              }
              return entry;
            }).toList();

            batch.update(doc.reference, {
              'core.personalTags': updatedTags,
            });
          }
        }

        await batch.commit();
        updated += chunk.length;
      }

      return updated;
    } catch (e) {
      AppLogger.warning('Failed to rename tag "$tagId" to "$newName": $e');
      return 0;
    }
  }

  /// Removes a personal tag from all user recipes that contain it.
  ///
  /// Removes from both personalTagIds (UUID array) and personalTags (rich objects).
  /// Returns the number of recipes updated.
  @override
  Future<int> removePersonalTagFromRecipes(String tagId) async {
    if (tagId.isEmpty) return 0;
    final userId = currentUserId;
    if (userId == null) return 0;

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.personalTagIds', arrayContains: tagId)
          .get();

      if (snap.docs.isEmpty) return 0;

      const batchLimit = 500; // 1 op per doc (consolidated update)
      int updated = 0;

      for (var i = 0; i < snap.docs.length; i += batchLimit) {
        final batch = firestore.batch();
        final chunk = snap.docs.skip(i).take(batchLimit);

        for (final doc in chunk) {
          final data = doc.data();
          final coreData = data['core'] as Map<String, dynamic>? ?? {};
          final personalTags = coreData['personalTags'] as List?;

          // Single update with both field changes
          final updates = <String, dynamic>{
            'core.personalTagIds': FieldValue.arrayRemove([tagId]),
          };

          if (personalTags != null) {
            updates['core.personalTags'] = personalTags
                .where((entry) => entry is Map && entry['tagId'] != tagId)
                .toList();
          }

          batch.update(doc.reference, updates);
        }

        await batch.commit();
        updated += chunk.length;
      }

      return updated;
    } catch (e) {
      AppLogger.warning('Failed to remove tag "$tagId" from recipes: $e');
      return 0;
    }
  }

  @override
  Future<List<Recipe>> findBySourceUrl(String url) async {
    if (url.isEmpty) return [];
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.sourceUrl', isEqualTo: url)
          .limit(5)
          .get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to find recipes by source URL: $e');
      return [];
    }
  }

  @override
  Future<List<Recipe>> findByTitle(String title) async {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return [];
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snap = await getCollectionForUser(userId)
          .where('core.title', isEqualTo: normalized)
          .limit(5)
          .get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to find recipes by title: $e');
      return [];
    }
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
        .orderBy('core.updatedAt', descending: true)
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
    return await FirebasePerformanceService.traceFirebaseQuery(
      (trace) async {
        final snap = await firestore
            .collection(FirestoreCollections.butleryArchive)
            .orderBy('core.createdAt', descending: true)
            .limit(100) // Load max 100 archive recipes
            .get();

        final recipes = snap.docs.map(fromFirestore).toList();
        trace.putAttribute('source', 'archive');
        return recipes;
      },
      collection: 'butlery_archive',
    );
  }

  @override
  Future<Recipe> fetchArchiveRecipe(String id) async {
    // Archive recipes are stored in a global collection, not user-scoped
    final doc = await firestore.collection(FirestoreCollections.butleryArchive).doc(id).get();
    if (!doc.exists) {
      throw Exception('Archive recipe not found');
    }
    return fromFirestore(doc);
  }

  @override
  Future<List<Recipe>> fetchUserRecipes(String userId, {int limit = 50}) async {
    // Use the mixin method for user-specific collection
    return await FirebasePerformanceService.traceFirebaseQuery(
      (trace) async {
        final snap = await getCollectionForUser(userId)
            .orderBy('core.updatedAt', descending: true)
            .limit(limit)
            .get();

        final recipes = snap.docs.map(fromFirestore).toList();
        trace.putAttribute('user_id', userId);
        trace.setMetric('limit', limit);
        return recipes;
      },
      collection: 'recipes',
      resultCount: null, // Will be set after query
    );
  }

  @override
  Future<List<Recipe>> fetchAllUserRecipes(
    String userId, {
    int batchSize = 500,
  }) async {
    final allRecipes = <Recipe>[];
    DocumentSnapshot? lastDoc;

    while (true) {
      var query = getCollectionForUser(userId)
          .orderBy('core.updatedAt', descending: true)
          .limit(batchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      allRecipes.addAll(snap.docs.map(fromFirestore));
      lastDoc = snap.docs.last;

      // If fewer docs than batch size, we've reached the end
      if (snap.docs.length < batchSize) break;
    }

    return allRecipes;
  }

  /// Find recipes by meal type (e.g., 'Frukost', 'Lunch', 'Middag')
  Future<List<Recipe>> findByMealType(String mealType) async {
    return await FirebasePerformanceService.traceSearch(
      (trace) async {
        final userId = currentUserId;
        if (userId == null) return [];

        final snap = await getCollectionForUser(userId)
            .where('core.mealType', isEqualTo: mealType)
            .orderBy('core.updatedAt', descending: true)
            .limit(100)
            .get();

        final recipes = snap.docs.map(fromFirestore).toList();
        trace.putAttribute('meal_type', mealType);
        trace.setMetric('result_count', recipes.length);

        return recipes;
      },
      searchType: 'meal_type',
    );
  }

  /// Find recipes containing a specific ingredient
  Future<List<Recipe>> findByIngredient(String ingredient) async {
    final userId = currentUserId;
    if (userId == null) return [];

    // Note: Firestore doesn't support array-contains with case-insensitive search
    // This is a basic implementation - for production, consider using Algolia or similar
    final snap = await getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(200)
        .get();

    final lowerIngredient = ingredient.toLowerCase();
    return snap.docs
        .map(fromFirestore)
        .where((recipe) => recipe.ingredients.any((recipeIngredient) =>
            recipeIngredient.toLowerCase().contains(lowerIngredient)))
        .toList();
  }

  /// Search recipes by title with more focused search
  Future<List<Recipe>> searchByTitle(String title) async {
    final userId = currentUserId;
    if (userId == null) return [];

    final lowerTitle = title.toLowerCase();
    final snap = await getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(200)
        .get();

    return snap.docs
        .map(fromFirestore)
        .where((recipe) => recipe.title.toLowerCase().contains(lowerTitle))
        .toList();
  }

  /// Check if user can read a specific recipe
  Future<bool> canRead(String recipeId, String userId) async {
    try {
      final recipe = await read(recipeId);
      if (recipe == null) return false;

      // User can read if:
      // 1. They own the recipe
      final ownerId =
          (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty();
      if (ownerId == userId) return true;

      // 2. Recipe is shared with them (check member permissions)
      final memberPermissions =
          (recipe.socialData?.memberPermissions).orEmpty();
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
      final ownerId =
          (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty();
      if (ownerId == userId) return true;

      // 2. They are a member with write permissions
      final memberPermissions =
          (recipe.socialData?.memberPermissions).orEmpty();
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
      final ownerId =
          (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty();
      return ownerId == userId;
    } catch (e) {
      return false;
    }
  }

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
      resourceOwnerId:
          (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty(),
      resourceType: 'recipe',
      resourceId: recipeId,
    );

    // Add member with editor permission
    final currentMembers = (recipe.socialData?.memberPermissions).orEmpty();
    if (!currentMembers.containsKey(userId)) {
      final updatedMembers = {
        ...currentMembers,
        userId: ResourcePermission.editor
      };

      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
              memberPermissions: updatedMembers,
            ) ??
            RecipeSocialData(
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
      resourceOwnerId:
          (recipe.socialData?.ownerId ?? recipe.createdBy).orEmpty(),
      resourceType: 'recipe',
      resourceId: recipeId,
    );

    // Remove member from the recipe
    final currentMembers = (recipe.socialData?.memberPermissions).orEmpty();
    if (currentMembers.containsKey(userId)) {
      final updatedMembers =
          Map<String, ResourcePermission>.from(currentMembers);
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
