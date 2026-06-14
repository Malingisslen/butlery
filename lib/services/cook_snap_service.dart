/// Service orchestrating CookSnap photo uploads, CRUD, and notifications.
library;

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rxdart/rxdart.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/models/social/activity_event.dart';

class CookSnapService extends BaseService {
  final CookSnapRepository _repository;
  final FriendsRepository _friendsRepository;

  CookSnapService({
    required CookSnapRepository repository,
    required FriendsRepository friendsRepository,
  })  : _repository = repository,
        _friendsRepository = friendsRepository;

  @override
  String get serviceName => 'CookSnapService';

  /// Picks one or more images, uploads them, and creates a CookSnap.
  ///
  /// BUT-949: when [allowMultiple] is true and [source] is the gallery, the
  /// user may pick up to [CookSnap.maxPhotos] photos (an album); the camera
  /// path always yields a single photo. The first photo is the album cover.
  ///
  /// Returns the created CookSnap, or null if the user cancelled or an error
  /// occurred.
  Future<CookSnap?> addCookSnap({
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
    required ImageSource source,
    String? caption,
    bool allowMultiple = false,
    CookSnapVisibility visibility = CookSnapVisibility.sameAsRecipe,
  }) async {
    return executeServiceOperation<CookSnap?>(
      () async {
        // Check connectivity
        final connectivity =
            ServiceLocator.get<ConnectivityMonitoringService>();
        if (!connectivity.isConnectedToInternet) {
          throw Exception('Cannot upload photos while offline');
        }

        // Validate caption — gate via ContentFilterService.ensureClean to
        // share the canonical pre-publish path with recipe titles, group
        // names, and profile bios (BUT-517).
        var validCaption = caption;
        if (validCaption != null && validCaption.trim().isNotEmpty) {
          final filter = ServiceLocator.get<ContentFilterService>();
          final result =
              filter.ensureClean(validCaption, fieldName: 'cook_snap_caption');
          if (!result.isClean) {
            throw Exception(
                result.reason ?? 'Caption contains inappropriate language');
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

        // Emit activity event (fire-and-forget)
        try {
          ServiceLocator.get<ActivityFeedService>().emitEvent(
            ActivityEventType.cooked,
            recipeId,
            recipeName,
            extraData: {
              'photoUrl': snap.photoUrl,
              // BUT-949: full album so the feed can render a carousel.
              'photoUrls': snap.photoUrls,
              if (validCaption != null) 'caption': validCaption,
            },
          );
        } catch (_) {}

        // Notify recipe author (if not self)
        if (recipeAuthorId != userId) {
          _notifyRecipeAuthor(
            recipeAuthorId: recipeAuthorId,
            senderName: profile?.displayName ?? '?',
            recipeName: recipeName,
          );
        }

        return snap;
      },
      operationName: 'addCookSnap',
    );
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
        .switchMap((friendIds) => _repository.watchCookSnaps(
              recipeId,
              viewerId: userId,
              friendIds: friendIds,
              limit: limit,
            ));
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
      );
    } catch (e) {
      // Non-critical — don't fail the snap creation if notification fails
      AppLogger.warning('Failed to send cook snap notification: $e');
    }
  }
}
