import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_change.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/modules/recipe_gdpr_export_operations.dart';
import 'package:butlery/repositories/firebase/modules/recipe_legacy_validator.dart';
import 'package:butlery/repositories/firebase/modules/recipe_query_operations.dart';
import 'package:butlery/repositories/firebase/modules/recipe_tag_operations.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/performance/firebase_performance_service.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';

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
/// - **Streaming Limits**: Live watcher caps at [_defaultWatchPageSize] (100)
///   most recent recipes; older pages are fetched via [loadMoreRecipes]
///   cursor-paginated against `core.updatedAt`
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
/// // Stream with bounded initial page (100 most recent); call
/// // loadMoreRecipes(...) to fetch older recipes as the user scrolls.
/// recipeRepo.watchRecipes(userId).listen((recipes) {
///   // Receives the 100 most recent recipes
/// });
/// // Search with scope limits
/// final results = await recipeRepo.searchRecipes('chicken');
/// // Searches within 200 most recent recipes
/// ```
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    with StreamManagementMixin, UserScopedFirebaseRepository<Recipe>
    implements RecipeRepository {
  /// Default page size for the live watcher and cursor-paginated tail.
  /// Older pages are reachable via [loadMoreRecipes].
  static const int _defaultWatchPageSize = 100;

  late final RecipeLegacyValidator _legacyValidator;
  late final RecipeTagOperations _tagOperations;
  late final RecipeGdprExportOperations _gdprExportOperations;
  late final RecipeQueryOperations _queryOperations;

  FirebaseRecipeRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) {
    _legacyValidator = RecipeLegacyValidator(
      firestore: firestore,
      getUserRecipeDoc: (userId, recipeId) async =>
          getCollectionForUser(userId).doc(recipeId).get(),
      validateOwnership: validateOwnership,
    );
    _tagOperations = RecipeTagOperations(
      firestore: firestore,
      getCollectionForUser: getCollectionForUser,
    );
    _gdprExportOperations = RecipeGdprExportOperations(
      firestore: firestore,
      getCollectionForUser: getCollectionForUser,
      requireCurrentUserId: requireCurrentUserId,
      validateOwnership: validateOwnership,
    );
    _queryOperations = RecipeQueryOperations(
      getCollectionForUser: getCollectionForUser,
      fromFirestore: fromFirestore,
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
    final ownerId = (entity.socialData?.ownerId ?? entity.createdBy).orDefault(
      userId,
    );
    return ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    Recipe? entity,
  ) async {
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
    String userId,
    String resourceId,
    Recipe entity,
  ) async {
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
    String userId,
    String resourceId,
  ) async {
    // Only the owner can delete recipes
    // Note: We need to fetch the recipe to check ownership
    try {
      final recipe = await read(resourceId);
      if (recipe == null) return false;

      final ownerId = (recipe.socialData?.ownerId ?? recipe.createdBy)
          .orEmpty();
      return ownerId == userId;
    } catch (e) {
      AppLogger.error('Failed to validate delete permission: $e');
      return false;
    }
  }

  /// Sanitize user-supplied text fields before writing to Firestore.
  Recipe _sanitizeRecipe(Recipe recipe) {
    final sanitizer = HtmlSanitizer.instance;
    return recipe.copyWith(
      title: sanitizer.sanitizeText(recipe.title),
      description: sanitizer.sanitizeText(recipe.description),
      sourceUrl: recipe.core.sourceUrl != null
          ? sanitizer.sanitizeUrl(recipe.core.sourceUrl!)
          : null,
    );
  }

  /// BUT-955: defense-in-depth cap on the share-set size of a Recipe document.
  /// All service-layer share entry points should fail-fast with a localized
  /// error before reaching this guard — but multiple writer paths
  /// (addMemberToRecipe, addMember, addCollaborators, repo.addCollaborator,
  /// shareRecipe, shareRecipeWithUsers) feed update/create, and capping at
  /// every callsite is bypass-prone. This is the chokepoint that closes
  /// the bug for real: every Firestore write goes through here.
  void _enforceShareCap(Recipe entity) {
    final members = entity.socialData?.memberPermissions;
    if (members == null) return;
    final ownerCount = entity.socialData?.ownerId != null ? 1 : 0;
    final total = members.length + ownerCount;
    if (total > Recipe.maxSharesPerRecipe) {
      throw StateError(
        'Recipe ${entity.id} would exceed share cap: '
        '$total > ${Recipe.maxSharesPerRecipe}',
      );
    }
  }

  @override
  Future<Recipe> create(Recipe entity) async {
    return await FirebasePerformanceService.traceOperation(
      'recipe_create',
      (trace) async {
        // Validate user owns the recipe they're creating
        final currentUser = requireCurrentUserId();

        // BUT-955: cap-guard before validation work.
        _enforceShareCap(entity);

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
        final coreData = (firestoreData['core'] as Map<String, dynamic>?)
            .orEmpty();

        // Check for required fields in core data
        validateRequiredFields(
          data: coreData,
          requiredFields: ['title', 'createdBy', 'createdAt', 'updatedAt'],
          resourceType: 'recipe',
        );

        // MODUL1 Phase 3: Auto-populate normalized ingredients for advanced features
        Recipe recipeToSave = _sanitizeRecipe(entity);
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
          'has_image',
          entity.imageUrls.isNotEmpty ? 'true' : 'false',
        );
        trace.putAttribute(
          'is_collaborative',
          entity.isCollaborative ? 'true' : 'false',
        );

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

        // BUT-955: cap-guard before read+validation. Catches every writer
        // path that builds an over-cap Recipe and calls update, including
        // addCollaborator, addMemberToRecipe, addCollaborators, etc.
        _enforceShareCap(entity);

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
          resourceOwnerId: (existing.socialData?.ownerId ?? existing.createdBy)
              .orEmpty(),
          resourceType: 'recipe',
          resourceId: entity.id,
        );

        // MODUL1 Phase 3: Auto-populate normalized ingredients for advanced features
        Recipe recipeToSave = _sanitizeRecipe(entity);
        if (IngredientProcessor.needsNormalization(recipeToSave)) {
          final normalizedIngredients =
              IngredientProcessor.normalizeIngredientsForRecipe(
                recipeToSave.core.ingredients,
              );

          recipeToSave = recipeToSave.copyWith(
            ingredientsNormalized: normalizedIngredients,
          );
        }

        await super.update(recipeToSave);

        // Add performance metrics
        trace.setMetric('ingredient_count', entity.core.ingredients.length);
        trace.putAttribute(
          'has_image',
          entity.imageUrls.isNotEmpty ? 'true' : 'false',
        );
        trace.putAttribute(
          'is_collaborative',
          entity.isCollaborative ? 'true' : 'false',
        );
        trace.putAttribute(
          'ingredients_normalized',
          IngredientProcessor.needsNormalization(entity) ? 'true' : 'false',
        );
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

        // Ownership validation with legacy recipe support
        final isLegacy = _legacyValidator.isLegacyRecipe(existing);
        final canDelete = await _legacyValidator
            .validateDeletionWithLegacySupport(
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
          'is_collaborative',
          existing.isCollaborative ? 'true' : 'false',
        );
        trace.putAttribute(
          'had_image',
          existing.imageUrls.isNotEmpty ? 'true' : 'false',
        );
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
            100,
          ) // Limit to 100 most recent recipes to prevent app freezing
          .get();
      return snapshot.docs.map(fromFirestore).toList();
    } catch (e) {
      // Fall back to safe version if no user
      return await readAllSafe();
    }
  }

  @override
  Stream<List<Recipe>> watchRecipes(
    String userId, {
    int pageSize = _defaultWatchPageSize,
  }) {
    return getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snap) => snap.docs.map(fromFirestore).toList());
  }

  @override
  Future<List<Recipe>> loadMoreRecipes(
    String userId, {
    required DateTime afterUpdatedAt,
    required String afterRecipeId,
    int pageSize = _defaultWatchPageSize,
  }) async {
    // Two recipes can share the same `core.updatedAt` (bulk imports), and
    // `startAfterDocument` is the only race-safe disambiguator Firestore
    // offers without a stored secondary sort key. If the boundary recipe was
    // deleted between pages we fall back to a value-cursor on `updatedAt`
    // alone — worst case re-emits one row already in the live page; the
    // consumer dedupes by id.
    try {
      final boundary = await getCollectionForUser(
        userId,
      ).doc(afterRecipeId).get();
      if (!boundary.exists) {
        final snap = await getCollectionForUser(userId)
            .orderBy('core.updatedAt', descending: true)
            .startAfter([Timestamp.fromDate(afterUpdatedAt)])
            .limit(pageSize)
            .get();
        return snap.docs.map(fromFirestore).toList();
      }
      final snap = await getCollectionForUser(userId)
          .orderBy('core.updatedAt', descending: true)
          .startAfterDocument(boundary)
          .limit(pageSize)
          .get();
      return snap.docs.map(fromFirestore).toList();
    } catch (e) {
      AppLogger.warning('Failed to load more recipes after $afterRecipeId: $e');
      return const <Recipe>[];
    }
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
      final snap = await getCollectionForUser(
        userId,
      ).where('core.personalTagIds', arrayContains: tagId).count().get();
      return snap.count ?? 0;
    } catch (e) {
      AppLogger.warning('Failed to count recipes with tag "$tagId": $e');
      return 0;
    }
  }

  @override
  Future<List<Recipe>> fetchRecipesByTagId(String tagId, {int limit = 100}) =>
      _queryOperations.fetchRecipesByTagId(currentUserId, tagId, limit: limit);

  @override
  Future<int> renamePersonalTagInRecipes(String tagId, String newName) =>
      _tagOperations.renamePersonalTagInRecipes(currentUserId, tagId, newName);

  @override
  Future<int> removePersonalTagFromRecipes(String tagId) =>
      _tagOperations.removePersonalTagFromRecipes(currentUserId, tagId);

  Future<int> addRemovePersonalTagFromRecipesToBatch(
    WriteBatch batch,
    String tagId,
  ) => _tagOperations.addRemovePersonalTagFromRecipesToBatch(
    currentUserId,
    batch,
    tagId,
  );

  Future<int> replaceTagInRecipes(
    String fromTagId,
    String toTagId,
    Map<String, dynamic> toTagRichEntry,
  ) => _tagOperations.replaceTagInRecipes(
    currentUserId,
    fromTagId,
    toTagId,
    toTagRichEntry,
  );

  @override
  Future<List<Recipe>> findBySourceUrl(String url) =>
      _queryOperations.findBySourceUrl(currentUserId, url);

  @override
  Future<List<Recipe>> findByTitle(String title) =>
      _queryOperations.findByTitle(currentUserId, title);

  /// Adds the atomic cook-count bump (`core.cookCount` increment +
  /// `core.lastCookedAt`) to an external [batch] without committing, so
  /// callers (FirebaseCookEventRepository) can commit it together with the
  /// cook-event document in one atomic write (BUT-838). Caller owns the
  /// batch lifecycle. FieldValue.increment handles concurrent writers and
  /// the null-legacy case (null + 1 = 1) matches the firestore rule branch
  /// that accepts `null -> 1` on first increment.
  void addIncrementCookCountToBatch(
    WriteBatch batch,
    String userId,
    String recipeId,
    DateTime cookedAt,
  ) {
    batch.update(getCollectionForUser(userId).doc(recipeId), {
      'core.cookCount': FieldValue.increment(1),
      'core.lastCookedAt': Timestamp.fromDate(cookedAt),
      'core.updatedAt': Timestamp.fromDate(cookedAt),
    });
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
    void Function(bool hasPendingWrites, bool isFromCache)? onSyncStatusChanged,
    int pageSize = _defaultWatchPageSize,
  }) {
    return getCollectionForUser(userId)
        .orderBy('core.updatedAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .listen((snapshot) {
          onSyncStatusChanged?.call(
            snapshot.metadata.hasPendingWrites,
            snapshot.metadata.isFromCache,
          );

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
    // Archive recipes are read-only and rarely change -- use cache-first
    final docRef = firestore
        .collection(FirestoreCollections.butleryArchive)
        .doc(id);
    final doc = await getDocCacheFirst(docRef);
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
        final snap = await getCollectionForUser(
          userId,
        ).orderBy('core.updatedAt', descending: true).limit(limit).get();

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
  Future<List<Recipe>> fetchPublicUserRecipes(
    String userId, {
    int limit = 50,
  }) async {
    return await FirebasePerformanceService.traceFirebaseQuery(
      (trace) async {
        final snap = await getCollectionForUser(userId)
            .where('isPublic', isEqualTo: true)
            .orderBy('core.updatedAt', descending: true)
            .limit(limit)
            .get();

        final recipes = snap.docs.map(fromFirestore).toList();
        trace.putAttribute('user_id', userId);
        trace.setMetric('limit', limit);
        return recipes;
      },
      collection: 'recipes',
      resultCount: null,
    );
  }

  @override
  Future<Recipe?> readSharedRecipe({
    required String ownerId,
    required String recipeId,
  }) async {
    // Traced like the other cross-user reads (fetchUserRecipes /
    // fetchPublicUserRecipes) so the feed-tap path is visible in Performance.
    try {
      return await FirebasePerformanceService.traceFirebaseQuery(
        (_) async {
          final doc = await getCollectionForUser(ownerId).doc(recipeId).get();
          if (!doc.exists) return null;
          return fromFirestore(doc);
        },
        collection: 'recipes',
        resultCount: null,
      );
    } on FirebaseException catch (e) {
      // permission-denied → the recipe isn't shared with us; treat as absent.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Future<List<Recipe>> fetchAllUserRecipes(
    String userId, {
    int batchSize = 500,
  }) async {
    final allRecipes = <Recipe>[];
    DocumentSnapshot? lastDoc;

    while (true) {
      var query = getCollectionForUser(
        userId,
      ).orderBy('core.updatedAt', descending: true).limit(batchSize);

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
    final snap = await getCollectionForUser(
      userId,
    ).orderBy('core.updatedAt', descending: true).limit(200).get();

    final lowerIngredient = ingredient.toLowerCase();
    return snap.docs
        .map(fromFirestore)
        .where(
          (recipe) => recipe.ingredients.any(
            (recipeIngredient) =>
                recipeIngredient.toLowerCase().contains(lowerIngredient),
          ),
        )
        .toList();
  }

  /// Search recipes by title with more focused search
  Future<List<Recipe>> searchByTitle(String title) async {
    final userId = currentUserId;
    if (userId == null) return [];

    final lowerTitle = title.toLowerCase();
    final snap = await getCollectionForUser(
      userId,
    ).orderBy('core.updatedAt', descending: true).limit(200).get();

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
      final ownerId = (recipe.socialData?.ownerId ?? recipe.createdBy)
          .orEmpty();
      if (ownerId == userId) return true;

      // 2. Recipe is shared with them (check member permissions)
      final memberPermissions = (recipe.socialData?.memberPermissions)
          .orEmpty();
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
      final ownerId = (recipe.socialData?.ownerId ?? recipe.createdBy)
          .orEmpty();
      if (ownerId == userId) return true;

      // 2. They are a member with write permissions
      final memberPermissions = (recipe.socialData?.memberPermissions)
          .orEmpty();
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
      final ownerId = (recipe.socialData?.ownerId ?? recipe.createdBy)
          .orEmpty();
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
      resourceOwnerId: (recipe.socialData?.ownerId ?? recipe.createdBy)
          .orEmpty(),
      resourceType: 'recipe',
      resourceId: recipeId,
    );

    // Add member with editor permission
    final currentMembers = (recipe.socialData?.memberPermissions).orEmpty();
    if (!currentMembers.containsKey(userId)) {
      final updatedMembers = {
        ...currentMembers,
        userId: ResourcePermission.editor,
      };

      final updatedRecipe = recipe.copyWith(
        socialData:
            recipe.socialData?.copyWith(
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
      resourceOwnerId: (recipe.socialData?.ownerId ?? recipe.createdBy)
          .orEmpty(),
      resourceType: 'recipe',
      resourceId: recipeId,
    );

    // Remove member from the recipe
    final currentMembers = (recipe.socialData?.memberPermissions).orEmpty();
    if (currentMembers.containsKey(userId)) {
      final updatedMembers = Map<String, ResourcePermission>.from(
        currentMembers,
      );
      updatedMembers.remove(userId);

      final updatedRecipe = recipe.copyWith(
        socialData: recipe.socialData?.copyWith(
          memberPermissions: updatedMembers,
        ),
      );

      await update(updatedRecipe);
    }
  }

  /// BUT-501: Export every personal recipe under `users/{userId}/recipes`
  /// for GDPR Article 20. Ownership is structural — caller must verify
  /// the authenticated uid matches [userId] before calling.
  Future<List<Map<String, dynamic>>> exportPersonalRecipesByUser(
    String userId, {
    int maxDocuments = 1000,
  }) => _gdprExportOperations.exportPersonalRecipesByUser(
    userId,
    maxDocuments: maxDocuments,
  );

  /// BUT-501: Export every top-level `recipes` doc owned by [userId]
  /// (legacy `userId` field). Used alongside [exportPersonalRecipesByUser]
  /// to fully cover both storage shapes.
  Future<List<Map<String, dynamic>>> exportTopLevelRecipesByOwner(
    String userId, {
    int maxDocuments = 1000,
  }) => _gdprExportOperations.exportTopLevelRecipesByOwner(
    userId,
    maxDocuments: maxDocuments,
  );
}
