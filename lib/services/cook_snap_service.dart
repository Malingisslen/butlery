/// Service orchestrating CookSnap photo uploads, CRUD, and notifications.
library;

import 'package:image_picker/image_picker.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';

class CookSnapService extends BaseService {
  final CookSnapRepository _repository;

  CookSnapService({required CookSnapRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'CookSnapService';

  /// Picks an image, uploads it, and creates a CookSnap.
  ///
  /// Returns the created CookSnap, or null if the user cancelled or an error occurred.
  Future<CookSnap?> addCookSnap({
    required String recipeId,
    required String recipeAuthorId,
    required String recipeName,
    required ImageSource source,
    String? caption,
  }) async {
    return executeServiceOperation<CookSnap?>(
      () async {
        // Check connectivity
        final connectivity =
            ServiceLocator.get<ConnectivityMonitoringService>();
        if (!connectivity.isConnectedToInternet) {
          throw Exception('Cannot upload photos while offline');
        }

        // Validate caption
        var validCaption = caption;
        if (validCaption != null && validCaption.trim().isNotEmpty) {
          final filter = ServiceLocator.get<ContentFilterService>();
          if (filter.containsProfanity(validCaption)) {
            throw Exception('Caption contains inappropriate language');
          }
          if (validCaption.length > CookSnap.maxCaptionLength) {
            validCaption = validCaption.substring(0, CookSnap.maxCaptionLength);
          }
        }

        // Pick image
        final imagePicker = ServiceLocator.get<ImagePickerService>();
        final file = await imagePicker.pickImage(source);
        if (file == null) return null;

        // Upload image
        final permissionService = ServiceLocator.get<PermissionService>();
        final userId = permissionService.currentUserId;
        if (userId == null) throw Exception('Not authenticated');

        final uploadService = ServiceLocator.get<ImageUploadService>();
        final result = await uploadService.uploadImage(
          file: file,
          userId: userId,
        );

        if (!result.success || result.url == null) {
          throw Exception(result.error ?? 'Upload failed');
        }

        // Build CookSnap
        final userService = ServiceLocator.get<UserService>();
        final profile = userService.currentUserProfile;

        final snap = CookSnap.create(
          recipeId: recipeId,
          userId: userId,
          userDisplayName: profile?.displayName ?? '?',
          userAvatarUrl: profile?.avatarUrl,
          photoUrl: result.url!,
          thumbnailUrl: result.thumbnailUrl,
          caption: validCaption,
        );

        // Save to Firestore
        await _repository.addCookSnap(snap);

        AppLogger.success('CookSnap added for recipe $recipeId');

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

  /// Gets cook snaps for a recipe.
  Future<List<CookSnap>> getCookSnapsForRecipe(
    String recipeId, {
    int limit = 20,
  }) async {
    return await _repository.getCookSnapsForRecipe(recipeId, limit: limit);
  }

  /// Watches cook snaps for a recipe in real-time.
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) {
    return _repository.watchCookSnaps(recipeId, limit: limit);
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
