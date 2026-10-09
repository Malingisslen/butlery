// lib/services/unified/modules/service_adapters/recipe_service_adapter.dart

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/offline/queued_recipe_writer.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_reference_cleanup.dart';
import 'package:butlery/core/utils/logger.dart';

/// Service adapter that provides repository pattern access for UnifiedRecipeService modules
/// This adapter abstracts Firebase operations through repository interfaces,
/// allowing modules to follow clean architecture principles while maintaining
/// backward compatibility with existing code.
class RecipeServiceAdapter implements QueuedRecipeWriter {
  final RecipeRepository _recipeRepository;
  final CommentsRepository? _commentsRepository;
  final RatingsRepository? _ratingsRepository;
  final NotificationsRepository? _notificationsRepository;
  final FirestoreRepository? _firestoreRepository;

  /// BUT-907: required, so a construction site that forgets it does not
  /// compile and its deletes cannot skip the trash.
  final TrashRepository _trashRepository;

  RecipeServiceAdapter({
    required RecipeRepository recipeRepository,
    required TrashRepository trashRepository,
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    NotificationsRepository? notificationsRepository,
    FirestoreRepository? firestoreRepository,
  }) : _recipeRepository = recipeRepository,
       _trashRepository = trashRepository,
       _commentsRepository = commentsRepository,
       _ratingsRepository = ratingsRepository,
       _notificationsRepository = notificationsRepository,
       _firestoreRepository = firestoreRepository;

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

  /// Moves a recipe to the trash and deletes what others left on it
  /// (comments, ratings, social stats, cook snaps, shares).
  Future<bool> deleteRecipe(String recipeId) async {
    try {
      await delete(recipeId);
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete recipe via repository', e);
      return false;
    }
  }

  @override
  Future<int> create(Recipe recipe) => _recipeRepository.createOnce(recipe);

  @override
  Future<int> update(Recipe recipe) =>
      _recipeRepository.updateAtRevision(recipe, expectedRev: recipe.rev);

  /// BUT-907: the recipe goes to the trash with its photos, in one write
  /// that also deletes it, BEFORE the cleanup that cannot be undone; a failed
  /// trash write fails the delete. The photos are deleted when the trash row
  /// is (`onTrashItemDeleted`), never here.
  ///
  /// A recipe already gone writes nothing and throws
  /// [ResourceNotFoundException], so a queued delete sent twice stays
  /// harmless.
  @override
  Future<void> delete(String recipeId) async {
    final recipe = await _recipeRepository.read(recipeId);
    final firestore = _firestoreRepository?.firestore;
    if (recipe == null) {
      // A retry after a crash between the trash write and the cleanup lands
      // here, so the cleanup still runs before the not-found answer.
      if (firestore != null) {
        await RecipeReferenceCleanup.run(firestore, recipeId);
      }
      throw ResourceNotFoundException(
        'Recipe not found',
        resourceType: 'recipe',
        resourceId: recipeId,
      );
    }
    await _trashRepository.moveRecipeToTrash(recipe);
    if (firestore != null) {
      await RecipeReferenceCleanup.run(firestore, recipeId);
    }
    AppLogger.success('Recipe moved to trash via repository: $recipeId');
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
