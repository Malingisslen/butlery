/// Service orchestrating CookSnap photo uploads, CRUD, and notifications.
library;

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/offline/cook_snap_queue_metadata.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/models/social/activity_event.dart';

/// What [CookSnapService.addCookSnap] did with the picked photos.
class CookSnapAddResult {
  const CookSnapAddResult.created(CookSnap this.snap) : queued = false;

  /// The photos are on the device and the snap is created when they are all up.
  const CookSnapAddResult.queued() : snap = null, queued = true;

  final CookSnap? snap;
  final bool queued;
}

class CookSnapService extends BaseService {
  final CookSnapRepository _repository;
  final FriendsRepository _friendsRepository;

  CookSnapService({
    required CookSnapRepository repository,
    required FriendsRepository friendsRepository,
  }) : _repository = repository,
       _friendsRepository = friendsRepository;

  @override
  String get serviceName => 'CookSnapService';

  /// Picks one or more images, uploads them, and creates a CookSnap.
  ///
  /// BUT-949: when [allowMultiple] is true and [source] is the gallery, the
  /// user may pick up to [CookSnap.maxPhotos] photos (an album); the camera
  /// path always yields a single photo. The first photo is the album cover.
  ///
  /// Offline, the photos are queued on the device instead and the snap is
  /// created once they are all up ([CookSnapAddResult.queued]).
  ///
  /// Returns null if the user cancelled or an error occurred.
  Future<CookSnapAddResult?> addCookSnap({
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
    required ImageSource source,
    String? caption,
    bool allowMultiple = false,
    CookSnapVisibility visibility = CookSnapVisibility.sameAsRecipe,
  }) async {
    return executeServiceOperation<CookSnapAddResult?>(
      () async {
        final online = ServiceLocator.get<ConnectivityMonitoringService>()
            .isConnectedToInternet;
        // Refused before the picker opens, so photos are never picked only to
        // be lost (the web has no queue).
        final offline = ServiceLocator.tryGet<OfflineService>();
        if (!online && !(offline?.isQueueReady ?? false)) {
          throw Exception('Cannot upload photos while offline');
        }

        // Validate caption — at queue time too, so a refused caption never
        // waits in the queue. Gate via ContentFilterService.ensureClean to
        // share the canonical pre-publish path with recipe titles, group
        // names, and profile bios (BUT-517).
        var validCaption = caption;
        if (validCaption != null && validCaption.trim().isNotEmpty) {
          final filter = ServiceLocator.get<ContentFilterService>();
          final result = filter.ensureClean(
            validCaption,
            fieldName: 'cook_snap_caption',
          );
          if (!result.isClean) {
            throw Exception(
              result.reason ?? 'Caption contains inappropriate language',
            );
          }
          if (validCaption.length > CookSnap.maxCaptionLength) {
            validCaption = validCaption.substring(0, CookSnap.maxCaptionLength);
          }
        }

        // Pick image(s). BUT-949: album pick is gallery-only; the camera
        // path is inherently single-shot.
        final imagePicker = ServiceLocator.get<ImagePickerService>();
        final files = <File>[];
        if (allowMultiple && source == ImageSource.gallery) {
          files.addAll(
            await imagePicker.pickMultipleImages(maxImages: CookSnap.maxPhotos),
          );
        } else {
          final file = await imagePicker.pickImage(source);
          if (file != null) files.add(file);
        }
        if (files.isEmpty) return null;

        final permissionService = ServiceLocator.get<PermissionService>();
        final userId = permissionService.currentUserId;
        if (userId == null) throw Exception('Not authenticated');

        if (!online) {
          // The author's name and picture are read when the snap is created,
          // from the profile then, not stored with the photos now.
          await _queueOffline(
            offline!,
            files: files,
            userId: userId,
            recipeId: recipeId,
            recipeAuthorId: recipeAuthorId,
            recipeName: recipeName,
            visibility: visibility,
            caption: validCaption,
          );
          return const CookSnapAddResult.queued();
        }

        // Upload each photo, preserving pick order (cover first). The first
        // photo's thumbnail is used as the album thumbnail.
        final uploadService = ServiceLocator.get<ImageUploadService>();
        final photoUrls = <String>[];
        String? coverThumbnailUrl;
        for (final file in files) {
          final result = await uploadService.uploadImage(
            file: file,
            userId: userId,
          );
          if (!result.success || result.url == null) {
            throw Exception(result.error ?? 'Upload failed');
          }
          photoUrls.add(result.url!);
          coverThumbnailUrl ??= result.thumbnailUrl;
        }

        // Build CookSnap
        final userService = ServiceLocator.get<UserService>();
        final profile = userService.currentUserProfile;

        final snap = CookSnap.create(
          recipeId: recipeId,
          userId: userId,
          userDisplayName: profile?.displayName ?? '?',
          userAvatarUrl: profile?.avatarUrl,
          photoUrls: photoUrls,
          thumbnailUrl: coverThumbnailUrl,
          caption: validCaption,
          visibility: visibility,
        );

        // Save to Firestore
        await _repository.addCookSnap(snap);

        AppLogger.success('CookSnap added for recipe $recipeId');

        announceCookSnap(
          snap,
          recipeAuthorId: recipeAuthorId,
          recipeName: recipeName,
          senderName: profile?.displayName ?? '?',
        );

        return CookSnapAddResult.created(snap);
      },
      operationName: 'addCookSnap',
    );
  }

  Future<void> _queueOffline(
    OfflineService offline, {
    required List<File> files,
    required String userId,
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
    required CookSnapVisibility visibility,
    required String? caption,
  }) async {
    // List order is pick order; the cover is the first photo.
    await offline.userStorage.queueImageGroupForUser(
      imagePaths: [for (final file in files) file.path],
      entityType: cookSnapEntityType,
      entityId: const Uuid().v4(),
      userId: userId,
      targetPath: 'users/$userId/recipes',
      metadata: cookSnapQueueMetadata(
        recipeId: recipeId,
        recipeAuthorId: recipeAuthorId,
        recipeName: recipeName,
        visibility: visibility,
        caption: caption,
      ),
    );
    await offline.refreshSyncState();
    AppLogger.info('CookSnap for recipe $recipeId queued offline');
  }

  /// What follows a snap that has reached the server: the feed event and the
  /// note to the recipe's author. Shared with the offline queue, which sends
  /// the snap later.
  void announceCookSnap(
    CookSnap snap, {
    required String recipeAuthorId,
    required String recipeName,
    required String senderName,
  }) {
    try {
      ServiceLocator.get<ActivityFeedService>().emitEvent(
        ActivityEventType.cooked,
        snap.recipeId,
        recipeName,
        extraData: {
          'photoUrl': snap.photoUrl,
          // BUT-949: full album so the feed can render a carousel.
          'photoUrls': snap.photoUrls,
          'caption': ?snap.caption,
        },
      );
    } catch (_) {}

    if (recipeAuthorId != snap.userId) {
      _notifyRecipeAuthor(
        recipeAuthorId: recipeAuthorId,
        recipeId: snap.recipeId,
        senderName: senderName,
        recipeName: recipeName,
      );
    }
  }

  /// Deletes a cook snap and its storage files.
  Future<void> deleteCookSnap(String snapId) async {
    return executeServiceOperation(
      () async {
        await _repository.deleteCookSnap(snapId);
        AppLogger.info('CookSnap $snapId deleted');
      },
      operationName: 'deleteCookSnap',
    );
  }

  /// Gets cook snaps for a recipe, friends-gated. Fetches the caller's
  /// friend ids and passes [self + friend ids] as the allow-list. Returns
  /// an empty list when not authenticated.
  Future<List<CookSnap>> getCookSnapsForRecipe(
    String recipeId, {
    int limit = 20,
  }) async {
    final userId = _currentUserId();
    if (userId == null) return const [];
    final friendIds = await _resolveFriendIds(userId);
    return _repository.getCookSnapsForRecipe(
      recipeId,
      viewerId: userId,
      friendIds: friendIds.toSet(),
      limit: limit,
    );
  }

  /// Watches cook snaps for a recipe in real-time. Re-queries when the
  /// caller's friend list changes (debounced via `distinct`); identical
  /// friend-set emissions don't trigger a resubscribe.
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) {
    final userId = _currentUserId();
    if (userId == null) return Stream<List<CookSnap>>.value(const []);

    return _friendsRepository
        .friendIdsStream(userId)
        .map((ids) => ids.toSet())
        .distinct(const SetEquality<String>().equals)
        .switchMap(
          (friendIds) => _repository.watchCookSnaps(
            recipeId,
            viewerId: userId,
            friendIds: friendIds,
            limit: limit,
          ),
        );
  }

  String? _currentUserId() =>
      ServiceLocator.get<PermissionService>().currentUserId;

  /// Friend ids — read from the in-memory `UnifiedFriendsService` cache
  /// when available (saves a Firestore round-trip on the recipe-detail
  /// hot path) and fall back to a fresh repo fetch on cold start.
  Future<Iterable<String>> _resolveFriendIds(String userId) async {
    final unified = ServiceLocator.tryGet<UnifiedFriendsService>();
    if (unified != null && unified.isInitialized) {
      return unified.friends.map((u) => u.uid);
    }
    return _friendsRepository.fetchFriendIds(userId);
  }

  /// Gets all cook snaps by a user (for GDPR export).
  Future<List<CookSnap>> getCookSnapsByUser(String userId) async {
    return await _repository.getCookSnapsByUser(userId);
  }

  /// Deletes all cook snaps by a user (for account deletion).
  Future<int> deleteAllByUser(String userId) async {
    return await _repository.deleteAllByUser(userId);
  }

  void _notifyRecipeAuthor({
    required String recipeAuthorId,
    required String recipeId,
    required String senderName,
    required String recipeName,
  }) {
    try {
      final notificationService = ServiceLocator.get<NotificationService>();
      notificationService.sendImmediateNotification(
        targetUserIds: [recipeAuthorId],
        strategy: NotificationStrategy.cookSnapAdded,
        variables: {
          'senderName': senderName,
          'recipeName': recipeName,
        },
        additionalData: {'recipeId': recipeId},
      );
    } catch (e) {
      // Non-critical — don't fail the snap creation if notification fails
      AppLogger.warning('Failed to send cook snap notification: $e');
    }
  }
}
