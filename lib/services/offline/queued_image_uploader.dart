// lib/services/offline/queued_image_uploader.dart
//
// BUT-2162: what the offline queue calls to put a queued image on the server.
library;

/// Where an uploaded image ended up.
typedef UploadedImage = ({String url, String? thumbnailUrl});

/// Puts the image at [localPath] on the server for [userId]. Throws when it
/// did not get there, so the queue can tell a failure it retries from one
/// that waits for the user (`permanentFailureReason`).
///
/// The object is named after [objectId], the queue row's id, so uploading the
/// same row twice (a crash before the queue noted the first) overwrites
/// instead of leaving a second copy in Storage.
///
/// [targetPath] is the Storage folder the row was queued for. It decides where
/// the object goes, because the cleanup that erases a user's images only knows
/// the folder each kind of image belongs in.
typedef QueuedImageUploader =
    Future<UploadedImage> Function(
      String localPath,
      String userId,
      String objectId,
      String targetPath,
    );

/// Takes an image the queue uploaded back out of Storage, when the row it
/// belonged to was discarded, refused or replaced before it was used.
/// True when the object is gone, false or a throw when it may still be there.
typedef UploadedImageDeleter = Future<bool> Function(UploadedImage image);
