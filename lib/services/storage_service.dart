import 'dart:io';
import 'dart:typed_data';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart' as permission;

// Re-export StorageInfo from repository interface
export 'package:butlery/repositories/interfaces/storage_repository.dart'
    show StorageInfo;

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

  // ===== FIREBASE SERVICE MIXIN IMPLEMENTATION =====

  @override
  FirestoreRepository get firestoreRepository => _firestoreRepository;

  /// Upload an image file to storage
  Future<String?> uploadImageFile(
    File imageFile,
    String userId, {
    Function(double)? onProgress,
  }) async {
    return await executeServiceOperation<String?>(
      () async {
        // Generate unique filename
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

        if (url != null) {
          // Create thumbnail in background
          _createThumbnailInBackground(imageFile, userId, path);
        }

        return url;
      },
      operationName: 'Upload image file',
      requiresAuth: true,
      requiresNetwork: true,
      defaultValue: null,
    );
  }

  /// Upload image from bytes (for web platform)
  Future<String?> uploadImageBytes(
    Uint8List imageBytes,
    String userId,
    String fileName, {
    Function(double)? onProgress,
    String? prefix, // Allow custom prefix for different image types
  }) async {
    return await executeServiceOperation<String?>(
      () async {
        // Use provided prefix or default to avatar
        final imagePrefix = prefix ?? 'avatar';
        final pathFolder = imagePrefix == 'avatar' ? 'avatars' : 'recipes';

        // Generate unique filename if not provided
        final uniqueFileName = _repository.generateFileName(
          originalPath: fileName,
          prefix: imagePrefix,
        );
        final path = 'users/$userId/$pathFolder/$uniqueFileName';

        final url = await _repository.uploadImageData(
          imageData: imageBytes,
          userId: userId,
          path: path,
          onProgress: onProgress,
        );

        return url;
      },
      operationName: 'Upload image bytes',
      requiresAuth: true,
      requiresNetwork: true,
      defaultValue: null,
    );
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

  /// Upload a recipe image
  Future<String?> uploadRecipeImage(
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

  /// Create thumbnail in background (fire-and-forget)
  void _createThumbnailInBackground(
    File imageFile,
    String userId,
    String originalPath,
  ) {
    // Run in background without waiting
    Future(() async {
      try {
        await _repository.createAndUploadThumbnail(
          imageFile: imageFile,
          userId: userId,
          originalPath: originalPath,
        );
      } catch (e) {
        AppLogger.error('Thumbnail creation failed: $e');
        // Not critical if thumbnail fails
      }
    });
  }
}
