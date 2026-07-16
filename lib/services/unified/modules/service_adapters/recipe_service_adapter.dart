// lib/services/unified/modules/service_adapters/recipe_service_adapter.dart

import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service adapter that provides repository pattern access for UnifiedRecipeService modules
/// This adapter abstracts Firebase operations through repository interfaces,
/// allowing modules to follow clean architecture principles while maintaining
/// backward compatibility with existing code.
class RecipeServiceAdapter {
  final RecipeRepository _recipeRepository;
  final CommentsRepository? _commentsRepository;
  final RatingsRepository? _ratingsRepository;
  final NotificationsRepository? _notificationsRepository;
  final FirestoreRepository? _firestoreRepository;
  final StorageService? _storageService;

  RecipeServiceAdapter({
    required RecipeRepository recipeRepository,
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    NotificationsRepository? notificationsRepository,
    FirestoreRepository? firestoreRepository,
    StorageService? storageService,
  }) : _recipeRepository = recipeRepository,
       _commentsRepository = commentsRepository,
       _ratingsRepository = ratingsRepository,
       _notificationsRepository = notificationsRepository,
       _firestoreRepository = firestoreRepository,
       _storageService = storageService;

  /// Create a new recipe using repository pattern
  Future<String?> createRecipe(Recipe recipe) async {
    try {
      AppLogger.info(
        '🔄 [RecipeServiceAdapter] Creating recipe: ${recipe.title}, id: ${recipe.id}',
      );
      final createdRecipe = await _recipeRepository.create(recipe);
      AppLogger.success('✅ Recipe created via repository: ${createdRecipe.id}');
      return createdRecipe.id;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Failed to create recipe via repository: $e');
      AppLogger.error('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Update an existing recipe using repository pattern
  Future<bool> updateRecipe(Recipe recipe) async {
    try {
      await _recipeRepository.update(recipe);
      AppLogger.success('✅ Recipe updated via repository: ${recipe.id}');
      return true;
    } catch (e) {
      AppLogger.error('❌ Failed to update recipe via repository', e);
      return false;
    }
  }

  /// Delete a recipe and cascade-delete related data (images, comments, ratings, social stats)
  Future<bool> deleteRecipe(String recipeId) async {
    try {
      // Fetch recipe once to get imageUrls before deletion
      final recipe = await _recipeRepository.read(recipeId);
      await _deleteRecipeImages(recipeId, recipe?.imageUrls ?? []);
      await _cleanupRecipeReferences(recipeId);
      await _recipeRepository.delete(recipeId);
      AppLogger.success('Recipe deleted via repository: $recipeId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete recipe via repository', e);
      return false;
    }
  }

  /// Delete images from Firebase Storage. Failures do not block recipe deletion.
  Future<void> _deleteRecipeImages(
    String recipeId,
    List<String> imageUrls,
  ) async {
    if (_storageService == null || imageUrls.isEmpty) return;

    try {
      await _storageService.deleteMultipleImages(imageUrls);
      AppLogger.info(
        'Deleted ${imageUrls.length} image(s) for recipe $recipeId',
      );
    } catch (e) {
      AppLogger.warning('Storage cleanup failed for recipe $recipeId: $e');
    }
  }

  /// Remove orphan comments, ratings, and social_stats for a deleted recipe
  Future<void> _cleanupRecipeReferences(String recipeId) async {
    final firestore = _firestoreRepository?.firestore;
    if (firestore == null) return;

    try {
      // Delete comments (paginated to respect batch limits)
      final commentQuery = firestore
          .collection(FirestoreCollections.recipeComments)
          .where('recipeId', isEqualTo: recipeId)
          .limit(450);
      var snapshot = await commentQuery.get();
      while (snapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await commentQuery.get();
      }

      // Delete ratings (paginated)
      final ratingQuery = firestore
          .collection(FirestoreCollections.recipeRatings)
          .where('recipeId', isEqualTo: recipeId)
          .limit(450);
      snapshot = await ratingQuery.get();
      while (snapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await ratingQuery.get();
      }

      // Delete social stats aggregate doc
      await firestore
          .collection(FirestoreCollections.recipeSocialStats)
          .doc(recipeId)
          .delete();

      // BUT-892: Delete cook_snaps records pointing at this recipe
      // (paginated). Cook snaps by ANY user (including non-owners with
      // share access) lose their parent recipe when the owner deletes it;
      // without this cleanup the snap doc persists with a dangling
      // recipeId reference.
      final cookSnapQuery = firestore
          .collection(FirestoreCollections.cookSnaps)
          .where('recipeId', isEqualTo: recipeId)
          .limit(450);
      snapshot = await cookSnapQuery.get();
      while (snapshot.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await cookSnapQuery.get();
      }

      // BUT-894: Delete shared_content recipe records pointing at this
      // recipe (paginated). Otherwise recipients keep a dead reference
      // in their inbox after the owner deletes the source recipe.
      // Each shared_content doc may have a `members` subcollection
      // (FirestoreCollections.members) — drain it before deleting the
      // parent so we don't leave orphaned member docs that would still
      // surface via collectionGroup queries.
      final sharedQuery = firestore
          .collection(FirestoreCollections.sharedContent)
          .where('originalRecipeId', isEqualTo: recipeId)
          .limit(450);
      snapshot = await sharedQuery.get();
      while (snapshot.docs.isNotEmpty) {
        for (final doc in snapshot.docs) {
          // Drain members subcollection (soft-cascade — best effort).
          final memberDocs = await doc.reference
              .collection(FirestoreCollections.members)
              .limit(450)
              .get();
          if (memberDocs.docs.isNotEmpty) {
            final memberBatch = firestore.batch();
            for (final m in memberDocs.docs) {
              memberBatch.delete(m.reference);
            }
            await memberBatch.commit();
          }
        }
        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < 450) break;
        snapshot = await sharedQuery.get();
      }
    } catch (e) {
      // Log but don't fail the recipe deletion for cleanup errors
      AppLogger.warning('⚠️ Partial cleanup failure for recipe $recipeId: $e');
    }
  }

  /// Get recipe by ID using repository pattern
  Future<Recipe?> getRecipeById(String recipeId) async {
    try {
      // Use base repository method if available, otherwise implement lookup
      // This is a temporary solution until the repository interface is expanded
      AppLogger.warning('⚠️ getById not implemented in RecipeRepository');
      return null;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipe by ID via repository', e);
      return null;
    }
  }

  /// Get recipes for user using repository pattern
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    try {
      return await _recipeRepository.fetchUserRecipes(userId);
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes for user via repository', e);
      return [];
    }
  }

  /// Search recipes using the repository's client-side title filter.
  ///
  /// An empty/whitespace query short-circuits to `[]` and never hits the
  /// repository — a bare `contains('')` would otherwise match every title and
  /// perform a needless 200-doc read.
  Future<List<Recipe>> searchRecipes(String query) async {
    if (query.trim().isEmpty) return const <Recipe>[];
    try {
      return await _recipeRepository.searchRecipes(query);
    } catch (e) {
      AppLogger.error('❌ Failed to search recipes via repository', e);
      return [];
    }
  }

  /// Send notification using repository pattern
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_notificationsRepository == null) {
      AppLogger.warning('⚠️ NotificationsRepository not available');
      return;
    }
    try {
      await _notificationsRepository.sendNotification(
        userId: userId,
        type: type,
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to send notification via repository', e);
    }
  }

  /// Get bulk rating statistics using repository pattern
  Future<Map<String, RatingStatistics>> getBulkRatingStatistics(
    List<String> recipeIds,
  ) async {
    if (_ratingsRepository == null) {
      AppLogger.warning('⚠️ RatingsRepository not available');
      return {};
    }
    try {
      return await _ratingsRepository.getBulkRatingStatistics(recipeIds);
    } catch (e) {
      AppLogger.error(
        '❌ Failed to get bulk rating statistics via repository',
        e,
      );
      return {};
    }
  }

  /// Get comments stream using repository pattern
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    if (_commentsRepository == null) {
      AppLogger.warning('⚠️ CommentsRepository not available');
      return Stream.value([]);
    }
    return _commentsRepository.getCommentsStream(recipeId);
  }

  /// Get rating statistics stream using repository pattern
  Stream<RatingStatistics> getRatingStatisticsStream(String recipeId) {
    if (_ratingsRepository == null) {
      AppLogger.warning('⚠️ RatingsRepository not available');
      return Stream.value(
        RatingStatistics(
          recipeId: recipeId,
          averageRating: 0.0,
          totalRatings: 0,
          ratingDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        ),
      );
    }
    return _ratingsRepository.getRatingStatisticsStream(recipeId);
  }
}
