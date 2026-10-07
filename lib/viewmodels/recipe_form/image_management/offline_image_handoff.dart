// lib/viewmodels/recipe_form/image_management/offline_image_handoff.dart
//
// BUT-2162: an image the network failed while the recipe is saved waits in
// the offline queue, which adds it to the recipe once it is up. Offline,
// every upload fails that way at once (StorageService checks first).
library;

import 'dart:io';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';

class OfflineImageHandoff {
  OfflineImageHandoff(this._images, this._queue);

  final RecipeImageManager _images;
  final OfflineService? _queue;

  /// Queues the images the network failed, once the recipe they belong to
  /// is saved, so each upload can wait for the recipe's own queued write.
  /// An image leaves the form only once the queue holds it: one the queue
  /// cannot take stays in the form, and the saved recipe stays saved.
  Future<void> queueFor(
    String recipeId,
    String? userId, {
    required bool formAlive,
  }) async {
    final queue = _queue;
    if (queue == null || !queue.isQueueReady || userId == null) return;
    final queued = <File>[];
    for (final image in _images.networkFailedImages) {
      try {
        await queue.queueRecipeImage(image.path, recipeId, userId);
        queued.add(image);
      } catch (e) {
        AppLogger.error('❌ Bilden kunde inte läggas i kön: $e');
      }
    }
    if (formAlive) _images.releaseToOfflineQueue(queued);
  }
}
