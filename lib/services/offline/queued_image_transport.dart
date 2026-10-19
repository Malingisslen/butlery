// lib/services/offline/queued_image_transport.dart
//
// BUT-2294: what the offline queue uses to put an image in Storage and take
// it back out.
library;

import 'dart:io';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/storage_service.dart';

Future<UploadedImage> uploadQueuedImage(
  String localPath,
  String userId,
  String objectId,
) async {
  final result = await ServiceLocator.get<StorageService>().uploadImageFile(
    File(localPath),
    userId,
    objectId: objectId,
  );
  // uploadImageFile returns null for a failure it has no code for.
  if (result == null) throw StateError('Image upload failed');
  return (url: result.imageUrl, thumbnailUrl: result.thumbnailUrl);
}

/// Deletes the image and, by the storage layer's naming, its thumbnail.
Future<bool> deleteQueuedImage(UploadedImage image) {
  return ServiceLocator.get<StorageService>().deleteImage(image.url);
}
