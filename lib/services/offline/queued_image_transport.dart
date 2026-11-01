// lib/services/offline/queued_image_transport.dart
//
// BUT-2294: what the offline queue uses to put an image in Storage and take
// it back out.
library;

import 'dart:io';

import 'package:butlery/services/offline/queued_image_uploader.dart';
import 'package:butlery/services/storage_service.dart';

Future<UploadedImage> uploadQueuedImage(
  StorageService storage,
  String localPath,
  String userId,
  String objectId,
  String targetPath,
) async {
  // The folder is read from a row on the device, so only the folders a queued
  // image can belong in are honoured: nothing may put an object elsewhere.
  if (targetPath == 'users/$userId/comment_images') {
    final url = await storage.uploadQueuedCommentImage(
      File(localPath),
      userId,
      objectId: objectId,
    );
    if (url == null) throw StateError('Comment image upload failed');
    return (url: url, thumbnailUrl: null);
  }
  if (targetPath == 'users/$userId/chat_images') {
    final url = await storage.uploadQueuedChatImage(
      File(localPath),
      userId,
      objectId: objectId,
    );
    if (url == null) throw StateError('Chat image upload failed');
    return (url: url, thumbnailUrl: null);
  }
  if (targetPath == 'users/$userId/avatars') {
    final url = await storage.uploadQueuedAvatar(
      File(localPath),
      userId,
      objectId: objectId,
    );
    if (url == null) throw StateError('Avatar upload failed');
    return (url: url, thumbnailUrl: null);
  }
  if (targetPath != 'users/$userId/recipes') {
    throw StateError('Unknown upload folder for a queued image');
  }
  final result = await storage.uploadImageFile(
    File(localPath),
    userId,
    objectId: objectId,
  );
  // uploadImageFile returns null for a failure it has no code for.
  if (result == null) throw StateError('Image upload failed');
  return (url: result.imageUrl, thumbnailUrl: result.thumbnailUrl);
}

/// Deletes the image and, by the storage layer's naming, its thumbnail.
Future<bool> deleteQueuedImage(StorageService storage, UploadedImage image) {
  return storage.deleteImage(image.url);
}
