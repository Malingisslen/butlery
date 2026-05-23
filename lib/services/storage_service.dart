import 'dart:io';
import 'dart:typed_data';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/exceptions/storage_upload_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
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
  /// BUT-1016 / BUT-971: bypasses [executeServiceOperation] for the same
  /// reason `uploadImageFile` does — `StorageUploadException`s (quota,
  /// unauthorized, canceled) must reach the upload-service classifier so
  /// the avatar / web upload UI surfaces actionable copy. Other exceptions
  /// still collapse to null, preserving the nullable-result contract.
  /// Auth is enforced at the repository layer via `_validateUploadPermission`.
  Future<String?> uploadImageBytes(
    Uint8List imageBytes,
    String userId,
    String fileName, {
    Function(double)? onProgress,
    String? prefix,
  }) async {
    try {
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
          '🚫 STORAGE_SERVICE: No authenticated user for image upload');
      return null;
    }

    AppLogger.info(
        '🎯 STORAGE_SERVICE: Uploading recipe image for user: $userId');
    return await uploadImageFile(imageFile, userId, onProgress: onProgress);
  }

  /// Delete a recipe image
  Future<void> deleteRecipeImage(String imageUrl) async {
    await deleteImage(imageUrl);
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
