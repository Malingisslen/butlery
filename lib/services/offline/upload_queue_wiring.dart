// lib/services/offline/upload_queue_wiring.dart
//
// BUT-2294: the upload queue as the app runs it: how an image reaches Storage
// and which handler uses it, by entity type. Handlers look their services up
// when they run, not when the queue is built, because the queue starts before
// the rest of the app has registered.
library;

import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/offline/avatar_upload_completion.dart';
import 'package:butlery/services/offline/chat_image_upload_completion.dart';
import 'package:butlery/services/offline/comment_upload_completion.dart';
import 'package:butlery/services/offline/cook_snap_upload_completion.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/offline_purge_store.dart';
import 'package:butlery/services/offline/offline_service_links.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/queued_image_transport.dart';
import 'package:butlery/services/offline/upload_completion.dart';
import 'package:butlery/services/offline/unsent_image_discard.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';

/// Local only: runs at startup for every user on the device, signed in or not.
Future<void> sweepUnsentImages(AppDatabase database) =>
    sweepExpiredUnsent(database, clock.now());

UploadQueueProcessor buildUploadQueueProcessor({
  required AppDatabase database,
  required OfflineUserStorage storage,
  required OfflineServiceLinks links,
}) {
  return UploadQueueProcessor(
    database: database,
    storage: storage,
    upload: (localPath, userId, objectId, targetPath) => uploadQueuedImage(
      links.storage(),
      localPath,
      userId,
      objectId,
      targetPath,
    ),
    deleteUploaded: (image) => deleteQueuedImage(links.storage(), image),
    ensureSession: (userId) =>
        refreshUploadSession(userId, storage, auth: links.auth()),
    completions: {
      SyncQueueEntityType.avatar: AvatarUploadCompletion(
        database: database,
        storage: storage,
        setAvatar: ({required userId, required expected, required url}) {
          final users = links.users();
          // Another account signed in since the picture was chosen: the
          // picture waits for its owner.
          if (users.currentUserId != userId) {
            throw StateError('The account of the queued picture is not active');
          }
          return users.setQueuedAvatar(expected: expected, url: url);
        },
      ),
      SyncQueueEntityType.chatImage: ChatImageUploadCompletion(
        database: database,
        storage: storage,
        repository: () => links.messaging(),
      ),
      SyncQueueEntityType.comment: CommentUploadCompletion(
        database: database,
        storage: storage,
        repository: () => links.comments(),
      ),
      SyncQueueEntityType.cookSnap: CookSnapUploadCompletion(
        database: database,
        storage: storage,
        repository: () => links.cookSnaps(),
        author: (userId) {
          final profile = links.users().currentUserProfile;
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
            }) => links.cookSnapService().announceCookSnap(
              snap,
              recipeAuthorId: recipeAuthorId,
              recipeName: recipeName,
              senderName: senderName,
            ),
      ),
    },
  );
}

/// Forces a fresh sign-in token before a queued upload is sent, so a token
/// that outlived its account does not let a late upload through. An erased
/// account ends the pass and its queue is dropped; a disabled or expired one
/// only ends the pass. Failing to reach the server is not an answer: the
/// upload that follows reports it.
Future<void> refreshUploadSession(
  String userId,
  OfflineUserStorage storage, {
  required AuthRepository auth,
  OfflinePurgeStore? purgeStore,
}) async {
  final user = auth.currentUser;
  // Another account is signed in: the pass stops at its own current-user check.
  if (user == null || user.uid != userId) return;
  try {
    await user.getIdToken(true);
  } on FirebaseAuthException catch (e) {
    switch (e.code) {
      case 'user-not-found':
        // Recorded first, so a clear that fails is finished at the next start.
        final owed = purgeStore ?? OfflinePurgeStore();
        await owed.record(userId);
        await storage.clearUserData(userId);
        await owed.forget(userId);
        throw const SessionEnded();
      case 'user-disabled':
      case 'user-token-expired':
      case 'invalid-user-token':
        // A disabled account can be enabled again, and its unsent work with it.
        throw const SessionEnded();
      default:
        AppLogger.warning('Token refresh before upload failed: ${e.code}');
    }
  } catch (_) {
    AppLogger.warning('Token refresh before upload failed');
  }
}
