// lib/services/offline/upload_queue_wiring.dart
//
// BUT-2294: the upload queue as the app runs it: how an image reaches Storage
// and which handler uses it, by entity type. Handlers look their services up
// when they run, not when the queue is built, because the queue starts before
// the rest of the app has registered.
library;

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline/cook_snap_upload_completion.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_transport.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:butlery/services/user_service.dart';

UploadQueueProcessor buildUploadQueueProcessor({
  required AppDatabase database,
  required OfflineUserStorage storage,
}) {
  return UploadQueueProcessor(
    database: database,
    storage: storage,
    upload: uploadQueuedImage,
    deleteUploaded: deleteQueuedImage,
    completions: {
      SyncQueueEntityType.cookSnap: CookSnapUploadCompletion(
        database: database,
        storage: storage,
        repository: () => ServiceLocator.get<CookSnapRepository>(),
        author: (userId) {
          final profile = ServiceLocator.get<UserService>().currentUserProfile;
          // A snap is public and cannot be taken back by the queue, so it is
          // never published under a name the app has not loaded yet.
          if (profile == null || profile.uid != userId) {
            throw StateError('The profile of the queued snap is not loaded');
          }
          return (
            displayName: profile.displayName,
            avatarUrl: profile.avatarUrl,
          );
        },
        announce:
            (
              snap, {
              required recipeAuthorId,
              required recipeName,
              required senderName,
            }) => ServiceLocator.get<CookSnapService>().announceCookSnap(
              snap,
              recipeAuthorId: recipeAuthorId,
              recipeName: recipeName,
              senderName: senderName,
            ),
      ),
    },
  );
}
