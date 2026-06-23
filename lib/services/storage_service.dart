import 'dart:io';
import 'dart:typed_data';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/exceptions/storage_upload_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart' as permission;

// Re-export StorageInfo from repository interface
export 'package:butlery/repositories/interfaces/storage_repository.dart'
    show StorageInfo;

/// Result of an image upload containing both the full image URL and optional thumbnail URL.
class ImageUploadResult {
  final String imageUrl;
  final String? thumbnailUrl;

  const ImageUploadResult({required this.imageUrl, this.thumbnailUrl});
}

/// Storage service for image upload and management
/// This service now uses dependency injection for better testability while
/// maintaining the singleton pattern and existing API. The repository pattern
/// allows for easy mocking in tests and switching between different storage
/// providers if needed.
class StorageService extends BaseService
    with FirebaseServiceMixin, SingletonServiceMixin<StorageService> {
  final StorageRepository _repository;
  final FirestoreRepository _firestoreRepository;

  StorageService._internal(this._repository, this._firestoreRepository);

  /// Factory constructor with dependency injection support.
  /// Requires [repository] and [firestoreRepository] parameters from DI container.
  /// Use `ServiceLocator.get<StorageService>()` to obtain instance.
  factory StorageService({
    required StorageRepository repository,
    FirestoreRepository? firestoreRepository,
  }) {
    final actualFirestoreRepo =
        firestoreRepository ?? ServiceLocator.get<FirestoreRepository>();
    return SingletonServiceMixin.createSingletonWithDependencies(
      () => StorageService._internal(repository, actualFirestoreRepo),
      dependencies: [repository, actualFirestoreRepo],
    );
  }

  @override
  String get serviceName => 'StorageService';
  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;

  /// Upload an image file to storage, returning both the full image URL and thumbnail URL.
  ///
  /// BUT-971: uses direct try/catch instead of [executeServiceOperation] so
  /// `StorageUploadException`s (quota / unauthorized / canceled) propagate
  /// up to the upload-service classifier. `safeExecute` would swallow them
  /// and collapse to null, leaving the UI unable to differentiate causes.
  /// Other exceptions still collapse to null, preserving the existing
  /// nullable-result contract for callers that don't care about cause.
  /// Auth is enforced at the repository layer via `_validateUploadPermission`.
  Future<ImageUploadResult?> uploadImageFile(
    File imageFile,
    String userId, {
    Function(double)? onProgress,
  }) async {
    try {
      // BUT-1020: surface offline state immediately so the user sees the
      // network-error copy without waiting ~1-2s for the Firebase SDK to
      // exhaust its retry budget. Uses the same typed exception path as
      // BUT-971 storage failures so the existing classifier routes this to
      // `ImageUploadErrorType.network`. Reads from `OfflineService` (DI-
      // registered) rather than a static connectivity utility so tests can
      // toggle the state without DNS-mocking.
      final offline = ServiceLocator.tryGet<OfflineService>();
      if (offline != null && !offline.isOnline) {
        throw const StorageUploadException(
          'network-request-failed',
          'No internet connection available',
        );
      }

      final fileName = _repository.generateFileName(
        originalPath: imageFile.path,
        prefix: 'recipe',
      );
      final path = 'users/$userId/recipes/$fileName';

      final url = await _repository.uploadImage(
        imageFile: imageFile,
        userId: userId,
        path: path,
        onProgress: onProgress,
      );

      if (url == null) return null;

      // Await thumbnail creation — ~30KB, <1 second
      String? thumbUrl;
      try {
        thumbUrl = await _repository.createAndUploadThumbnail(
          imageFile: imageFile,
          userId: userId,
          originalPath: path,
        );
      } catch (e) {
        AppLogger.error('Thumbnail creation failed: $e');
      }

      return ImageUploadResult(imageUrl: url, thumbnailUrl: thumbUrl);
    } on StorageUploadException {
      rethrow;
    } catch (e) {
      AppLogger.error('Upload image file failed: $e');
      return null;
    }
  }

  /// Upload image from bytes (for web platform and avatar uploads).
  /// Compresses bytes before uploading when possible.
  ///
  /// BUT-1016: same direct-try/catch + `on StorageUploadException { rethrow; }`
  /// pattern as `uploadImageFile` (BUT-971). Typed storage errors (quota,
  /// unauthorized, canceled) must reach `image_upload_service`'s
  /// `_uploadFromBytes → _retryManager.classifyError` so the avatar / web
  /// upload UI surfaces actionable copy instead of "unknown error." Auth is
  /// enforced at the repository layer via `_validateUploadPermission`.
  Future<String?> uploadImageBytes(
    Uint8List imageBytes,
    String userId,
    String fileName, {
    Function(double)? onProgress,
    String? prefix,
  }) async {
    try {
      // BUT-1020: same offline pre-flight as `uploadImageFile`.
      final offline = ServiceLocator.tryGet<OfflineService>();
      if (offline != null && !offline.isOnline) {
        throw const StorageUploadException(
          'network-request-failed',
          'No internet connection available',
        );
      }

      final imagePrefix = prefix ?? 'avatar';
      final pathFolder = imagePrefix == 'avatar' ? 'avatars' : 'recipes';

      final uploadBytes = await _repository.compressImageBytes(imageBytes);

      final uniqueFileName = _repository.generateFileName(
        originalPath: fileName,
        prefix: imagePrefix,
      );
      final path = 'users/$userId/$pathFolder/$uniqueFileName';

      return await _repository.uploadImageData(
        imageData: uploadBytes,
        userId: userId,
        path: path,
        metadata: {
          'originalSize': imageBytes.length.toString(),
          'compressedSize': uploadBytes.length.toString(),
        },
        onProgress: onProgress,
      );
    } on StorageUploadException {
      rethrow;
    } catch (e) {
      AppLogger.error('Upload image bytes failed: $e');
      return null;
    }
  }

  /// Upload multiple images
  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles,
    String userId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final result = await executeServiceOperation(
      () async {
        return await _repository.uploadMultipleImages(
          imageFiles: imageFiles,
          userId: userId,
          basePath: 'users/$userId/recipes',
          onProgress: onProgress,
        );
      },
      operationName: 'Upload multiple images',
      requiresAuth: true,
      requiresNetwork: true,
      defaultValue: <String>[],
    );
    return result ?? <String>[];
  }

  /// Delete an image from storage
  Future<bool> deleteImage(String imageUrl) async {
    final result = await executeServiceOperation(
      () async {
        return await _repository.deleteImage(imageUrl);
      },
      operationName: 'Delete image',
      requiresAuth: true,
      requiresNetwork: true,
      defaultValue: false,
    );
    return result ?? false;
  }

  /// Delete multiple images from storage
  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    await executeServiceOperation(
      () async {
        await _repository.deleteMultipleImages(imageUrls);
      },
      operationName: 'Delete multiple images',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  /// Check if a file is a valid image
  bool isValidImageFile(File file) {
    // Delegate to repository implementation
    return _repository.isValidImageFile(file);
  }

  /// Upload a recipe image, returning both the full image URL and thumbnail URL.
  Future<ImageUploadResult?> uploadRecipeImage(
    File imageFile,
    String recipeId, {
    Function(double)? onProgress,
  }) async {
    // Get authenticated user ID from permission service
    final permissionService =
        ServiceLocator.get<permission.PermissionService>();
    final userId = permissionService.currentUserId;

    if (userId == null) {
      AppLogger.error(
        '🚫 STORAGE_SERVICE: No authenticated user for image upload',
      );
      return null;
    }

    AppLogger.info(
      '🎯 STORAGE_SERVICE: Uploading recipe image for user: ${userId.maskedUserId}',
    );
    return await uploadImageFile(imageFile, userId, onProgress: onProgress);
  }

  /// Delete a recipe image
  Future<void> deleteRecipeImage(String imageUrl) async {
    await deleteImage(imageUrl);
  }

  /// BUT-1049: Upload a comment-attachment image to the author-scoped path
  /// `users/{authorId}/comment_images/{imageId}.jpg`. Author-scoped (not
  /// comment-scoped) on purpose: images upload BEFORE the comment doc exists,
  /// so we can't key on a commentId yet. Returns the download URL, or null on
  /// failure (callers must treat null as "do not post the comment").
  ///
  /// Uses the same `uploadImageFile` resilience path as recipe photos
  /// (compression + offline pre-flight + typed-error propagation), but writes
  /// to the fixed contract path here rather than letting `uploadImageFile`
  /// derive a `recipes/` path.
  Future<String?> uploadCommentImage(
    File imageFile, {
    Function(double)? onProgress,
  }) async {
    final permissionService =
        ServiceLocator.get<permission.PermissionService>();
    final userId = permissionService.currentUserId;

    if (userId == null) {
      AppLogger.error(
        '🚫 STORAGE_SERVICE: No authenticated user for comment image upload',
      );
      return null;
    }

    try {
      final offline = ServiceLocator.tryGet<OfflineService>();
      if (offline != null && !offline.isOnline) {
        throw const StorageUploadException(
          'network-request-failed',
          'No internet connection available',
        );
      }

      final imageId = _repository.generateFileName(
        originalPath: imageFile.path,
        prefix: 'comment',
      );
      final path = 'users/$userId/comment_images/$imageId';

      return await _repository.uploadImage(
        imageFile: imageFile,
        userId: userId,
        path: path,
        onProgress: onProgress,
      );
    } on StorageUploadException {
      rethrow;
    } catch (e) {
      AppLogger.error('Upload comment image failed: $e');
      return null;
    }
  }

  /// Get storage information for a user
  Future<StorageInfo?> getUserStorageInfo(String userId) async {
    return await executeServiceOperation<StorageInfo?>(
      () async {
        return await _repository.getUserStorageInfo(userId);
      },
      operationName: 'Get user storage info',
      requiresAuth: true,
      requiresNetwork: true,
      defaultValue: null,
    );
  }
}
