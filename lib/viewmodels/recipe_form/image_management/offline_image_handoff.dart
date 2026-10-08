// lib/viewmodels/recipe_form/image_management/offline_image_handoff.dart
//
// BUT-2162: an image the network failed while the recipe is saved waits in
// the offline queue, which adds it to the recipe once it is up. Offline,
// every upload fails that way at once (StorageService checks first).
library;

import 'dart:io';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
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

  /// BUT-2293: the queue adds an image it has finished sending to the
  /// recipe's copy on the device. A form that read the recipe before that
  /// never showed the image, so saving the form's list as it stands would
  /// send the recipe without it. [formHad] is the list the device copy held
  /// as far as this form knows: as opened, or as this form last saved it.
  Future<({List<String> imageUrls, String? thumbnailUrl})> keepQueuedImages(
    String recipeId,
    String? userId, {
    required List<String> formHad,
    required List<String> imageUrls,
    required String? thumbnailUrl,
  }) async {
    final unchanged = (imageUrls: imageUrls, thumbnailUrl: thumbnailUrl);
    final queue = _queue;
    if (queue == null || !queue.isQueueReady || userId == null) {
      return unchanged;
    }
    final Recipe? onDevice;
    try {
      onDevice = await queue.getOfflineRecipeForUser(recipeId, userId);
    } catch (e) {
      AppLogger.error('❌ Receptets bilder på enheten kunde inte läsas: $e');
      return unchanged;
    }
    if (onDevice == null) return unchanged;
    final added = onDevice.imageUrls
        .where((url) => !formHad.contains(url) && !imageUrls.contains(url))
        .toList();
    if (added.isEmpty) return unchanged;
    return (
      imageUrls: [...imageUrls, ...added],
      thumbnailUrl: thumbnailUrl ?? onDevice.core.thumbnailUrl,
    );
  }
}
