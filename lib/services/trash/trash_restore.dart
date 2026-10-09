/// BUT-907: restoring one recipe from the trash.
///
/// The server write is the repository's (the recipe back, the trash row
/// gone, in one write). What follows it here is what a recipe coming back
/// changes on this side: its tags, the user's public recipe count and the
/// copy this device shows.
library;

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

class TrashRestore {
  TrashRestore({
    required TrashRepository repository,
    required UserRepository? Function() userRepository,
    required TaggingService? Function() taggingService,
    required Future<bool> Function(String recipeId, String userId)
    hasUnsentWrite,
    required Future<void> Function(Recipe recipe) adoptRecipe,
  }) : _repository = repository,
       _userRepository = userRepository,
       _taggingService = taggingService,
       _hasUnsentWrite = hasUnsentWrite,
       _adoptRecipe = adoptRecipe;

  final TrashRepository _repository;
  final UserRepository? Function() _userRepository;
  final TaggingService? Function() _taggingService;

  /// Whether the offline queue holds a write of the recipe the server has
  /// not confirmed (BUT-2162).
  final Future<bool> Function(String recipeId, String userId) _hasUnsentWrite;

  /// Puts the restored recipe in the device cache and the recipe list.
  final Future<void> Function(Recipe recipe) _adoptRecipe;

  /// Restores [item] for [userId] and returns the recipe as the server now
  /// holds it. Throws what [TrashRepository.restoreRecipe] throws, and then
  /// nothing here has run.
  Future<Recipe> restore(TrashItem item, String userId) async {
    final restored = await _repository.restoreRecipe(
      item,
      tagResult: await _tagsFor(item.recipe),
    );

    // As a delete decrements it (PersonalRecipeModule.deletePersonalRecipe),
    // and like it, a counter failure does not fail what already happened.
    try {
      await _userRepository()?.incrementPublicRecipeCount(userId);
    } catch (e) {
      AppLogger.warning('Failed to increment recipe count after restore: $e');
    }

    // A device copy with an unsent write is newer than the restore to the
    // user; the queue sends it against the restored revision (a conflict
    // the user decides, BUT-2213) and refreshes the screen after.
    // The restore is committed; a device-side failure here must not report
    // it as failed, or a retry would answer "gone" for a recipe that is back.
    try {
      if (await _hasUnsentWrite(restored.id, userId)) {
        AppLogger.info('Restored recipe kept local (unsent write)');
      } else {
        await _adoptRecipe(restored);
      }
    } catch (e) {
      AppLogger.warning('Restored recipe not adopted on the device: $e');
    }
    return restored;
  }

  /// New tags when the stored ones are missing or stale, made the way a
  /// save makes them (`PersonalRecipeModule._applyTagging`): a failure is
  /// stored as a failed result, which the retagging paths pick up. Null
  /// keeps the stored tags.
  Future<TagResult?> _tagsFor(Recipe recipe) async {
    final tagging = _taggingService();
    if (tagging == null || !tagging.needsRetagging(recipe)) return null;
    final generated = await tagging.generateTags(recipe);
    if (generated != null) return generated;
    AppLogger.warning('Tagging failed for restored recipe ${recipe.id}');
    return TagResult.failed(reason: 'Tagging failed on restore');
  }
}
