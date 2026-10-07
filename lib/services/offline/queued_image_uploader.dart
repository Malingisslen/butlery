// lib/services/offline/queued_image_uploader.dart
//
// BUT-2162: what the offline queue calls to put a queued image on the server.
library;

/// Where an uploaded image ended up.
typedef UploadedImage = ({String url, String? thumbnailUrl});

/// Puts the image at [localPath] on the server for [userId]. Throws when it
/// did not get there, so the queue can tell a failure it retries from one
/// that waits for the user (`permanentFailureReason`).
typedef QueuedImageUploader =
    Future<UploadedImage> Function(String localPath, String userId);
