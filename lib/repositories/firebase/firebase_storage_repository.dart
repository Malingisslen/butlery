import 'package:clock/clock.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/repositories/base/base_storage_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/storage_upload_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/image_format_utils.dart';
import 'package:butlery/services/performance/firebase_performance_service.dart';

/// Firebase implementation of the StorageRepository interface with security validation.
/// This repository provides Firebase Storage functionality while maintaining
/// the abstraction required for dependency injection and testability.
/// It encapsulates all Firebase-specific storage operations and can be
/// easily mocked or replaced with alternative implementations.
/// **Architecture:** Extends BaseStorageRepository for unified storage patterns
/// **Security Features:**
/// - Ownership validation for all file operations (upload, delete)
/// - Authentication checks preventing unauthorized access
/// - Path-based security (users can only access their own directories)
/// - Comprehensive audit logging for GDPR compliance
/// - Image-specific operations (compression, thumbnails, batch uploads)
class FirebaseStorageRepository extends BaseStorageRepository
    implements StorageRepository {
  final Uuid _uuid;

  // Image compression constants - optimized for mobile with aspect ratio preservation
  static const int _defaultMaxWidth =
      1200; // Max width while preserving aspect ratio
  static const int _defaultMaxHeight =
      1200; // Max height while preserving aspect ratio
  static const int _defaultQuality =
      85; // Higher quality for recipe photos (vs 75)
  static const int _defaultThumbnailSize = 300;
  static const int _defaultThumbnailQuality = 70;

  /// Creates a FirebaseStorageRepository with security validation.
  /// [storage] Optional FirebaseStorage instance (default: FirebaseStorage.instance)
  /// [authRepository] Required for authentication and permission checks
  /// [auditRepository] Optional for GDPR-compliant audit logging
  /// [uuid] Optional UUID generator (for testing)
  /// This allows for dependency injection in tests while maintaining production simplicity.
  FirebaseStorageRepository({
    super.storage,
    required super.authRepository,
    super.auditRepository,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Get current authenticated user ID
  String? _getCurrentUserId() {
    return currentUserId; // Use inherited getter from BaseStorageRepository
  }

  /// Validate that user can upload to the specified path
  /// **Security Rule:** Users can only upload to their own directory (users/{userId}/...)
  Future<void> _validateUploadPermission(String userId, String path) async {
    final currentUserId = _getCurrentUserId();

    if (currentUserId == null) {
      await logPermissionCheck(
        userId: 'anonymous',
        resource: 'storage/$path',
        operation: 'upload',
        granted: false,
        auditRepository: auditRepository,
      );
      throw PermissionDeniedException(
        'User must be authenticated to upload files',
        resource: 'storage',
        operation: 'upload',
      );
    }

    // Validate user is uploading to their own path
    if (userId != currentUserId) {
      await logPermissionCheck(
        userId: currentUserId,
        resource: 'storage/$path',
        operation: 'upload',
        granted: false,
        details: 'User attempted to upload to another user\'s directory',
        auditRepository: auditRepository,
      );
      throw PermissionDeniedException(
        'Users can only upload files to their own directory',
        resource: 'storage/$path',
        operation: 'upload',
        userId: currentUserId,
      );
    }

    // Validate path starts with users/{userId}/
    if (!path.startsWith('users/$userId/')) {
      await logPermissionCheck(
        userId: currentUserId,
        resource: 'storage/$path',
        operation: 'upload',
        granted: false,
        details: 'Invalid path format - must start with users/{userId}/',
        auditRepository: auditRepository,
      );
      throw PermissionDeniedException(
        'Invalid upload path - must be in user directory',
        resource: 'storage/$path',
        operation: 'upload',
        userId: currentUserId,
      );
    }

    // Log successful permission check
    await logPermissionCheck(
      userId: currentUserId,
      resource: 'storage/$path',
      operation: 'upload',
      granted: true,
      auditRepository: auditRepository,
    );
  }

  /// Validate that user can delete the specified file
  /// **Security Rule:** Users can only delete their own files (files in users/{userId}/...)
  Future<void> _validateDeletePermission(String imageUrl) async {
    final currentUserId = _getCurrentUserId();

    if (currentUserId == null) {
      await logPermissionCheck(
        userId: 'anonymous',
        resource: 'storage/$imageUrl',
        operation: 'delete',
        granted: false,
        auditRepository: auditRepository,
      );
      throw PermissionDeniedException(
        'User must be authenticated to delete files',
        resource: 'storage',
        operation: 'delete',
      );
    }

    // Extract userId from URL path
    final userIdFromPath = _extractUserIdFromPath(imageUrl);

    if (userIdFromPath == null || userIdFromPath != currentUserId) {
      await logPermissionCheck(
        userId: currentUserId,
        resource: 'storage/$imageUrl',
        operation: 'delete',
        granted: false,
        details: 'User attempted to delete another user\'s file',
        auditRepository: auditRepository,
      );
      throw PermissionDeniedException(
        'Users can only delete their own files',
        resource: 'storage',
        operation: 'delete',
        userId: currentUserId,
      );
    }

    // Log successful permission check
    await logPermissionCheck(
      userId: currentUserId,
      resource: 'storage/$imageUrl',
      operation: 'delete',
      granted: true,
      auditRepository: auditRepository,
    );
  }

  /// Extract user ID from storage path or URL
  /// Expected formats:
  /// - users/{userId}/recipes/...
  /// - https://...users%2F{userId}%2Frecipes%2F...
  String? _extractUserIdFromPath(String pathOrUrl) {
    try {
      // Handle URL-encoded paths in download URLs
      final decodedPath = Uri.decodeFull(pathOrUrl);

      // Extract userId from path pattern: users/{userId}/...
      final match = RegExp(r'users[/\\]([^/\\]+)[/\\]').firstMatch(decodedPath);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to extract userId from path: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadImage({
    required File imageFile,
    required String userId,
    required String path,
    Map<String, String>? metadata,
    Function(double progress)? onProgress,
    String? cacheControl,
  }) async {
    try {
      AppLogger.info('Starting image upload: ${imageFile.path}');

      // GDPR: files under `users/{userId}/...` are walked automatically by
      // storage_deletion_operations.dart on account deletion — no per-feature
      // cascade needed for heirloom scans or any other user-scoped upload.

      // 🔒 SECURITY: Validate upload permission before proceeding
      await _validateUploadPermission(userId, path);

      // Compress image first
      final compressedBytes = await compressImage(imageFile: imageFile);
      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      return await uploadImageData(
        imageData: compressedBytes,
        userId: userId,
        path: path,
        metadata: {
          ...?metadata,
          'originalSize': imageFile.lengthSync().toString(),
          'compressedSize': compressedBytes.length.toString(),
        },
        onProgress: onProgress,
        cacheControl: cacheControl,
      );
    } on StorageUploadException {
      // BUT-971: typed storage error from uploadImageData — propagate so the
      // upload service classifier can map quota / unauthorized / canceled
      // to user-facing copy. Don't collapse to null here.
      rethrow;
    } catch (e) {
      AppLogger.error('Image upload failed: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadImageData({
    required Uint8List imageData,
    required String userId,
    required String path,
    Map<String, String>? metadata,
    Function(double progress)? onProgress,
    String? cacheControl,
  }) async {
    return await FirebasePerformanceService.traceImageUpload(
      (trace) async {
        try {
          // 🔒 SECURITY: Validate upload permission before proceeding
          await _validateUploadPermission(userId, path);

          final storageRef = storage.ref().child(path);

          // Create upload task
          final contentType =
              ImageFormatUtils.detectMimeTypeWithFallback(imageData, path);

          final uploadTask = storageRef.putData(
            imageData,
            SettableMetadata(
              contentType: contentType,
              cacheControl: cacheControl,
              customMetadata: {
                'uploadedAt': clock.now().toIso8601String(),
                'uploadedBy': userId, // 🔒 SECURITY: Required by storage.rules
                ...?metadata,
              },
            ),
          );

          // Listen to progress if callback provided
          if (onProgress != null) {
            uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
              final progress = snapshot.bytesTransferred / snapshot.totalBytes;
              onProgress(progress);
            });
          }

          // Wait for upload to complete
          final taskSnapshot = await uploadTask;

          // Get download URL
          final downloadUrl = await taskSnapshot.ref.getDownloadURL();
          AppLogger.info('Image uploaded successfully: $downloadUrl');

          // Add trace metrics
          trace.setMetric('size_bytes', imageData.length);
          trace.putAttribute('user_id', userId);
          trace.putAttribute('success', 'true');

          return downloadUrl;
        } catch (e) {
          AppLogger.error('Image data upload failed: $e');
          trace.putAttribute('success', 'false');
          trace.putAttribute('error', e.toString());
          // BUT-971: surface typed storage-domain failures so the UI can
          // distinguish "your photo storage is full" from generic "upload
          // failed." `FirebaseException.code` from the `firebase_storage`
          // plugin is already the bare token (e.g. `quota-exceeded`,
          // `unauthorized`, `canceled`, `retry-limit-exceeded`); the
          // `storage/` prefix only appears in `.toString()`. Callers
          // match on the bare token via `StorageUploadException.is*`.
          if (e is FirebaseException && e.plugin == 'firebase_storage') {
            throw StorageUploadException(
              e.code,
              e.message ?? e.toString(),
            );
          }
          return null;
        }
      },
      imageSize: imageData.length,
      imageFormat: 'jpeg',
    );
  }

  @override
  Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    required String userId,
    required String basePath,
    Function(int completed, int total)? onProgress,
  }) async {
    final total = imageFiles.length;
    int completed = 0;

    AppLogger.info('🚀 Starting parallel upload of $total images');

    // Create upload futures for parallel processing
    final uploadFutures = imageFiles.map((file) async {
      final fileName = generateFileName(originalPath: file.path);
      final fullPath = '$basePath/$fileName';

      final url = await uploadImage(
        imageFile: file,
        userId: userId,
        path: fullPath,
      );

      // Update progress atomically
      if (onProgress != null) {
        completed++;
        onProgress(completed, total);
      }

      return url;
    }).toList();

    // Wait for all uploads to complete in parallel
    final results = await Future.wait(uploadFutures);

    // Filter out null results
    final successfulUploads =
        results.where((url) => url != null).cast<String>().toList();

    AppLogger.info(
      '✅ Parallel upload completed: ${successfulUploads.length}/$total successful',
    );
    return successfulUploads;
  }

  @override
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // 🔒 SECURITY: Validate delete permission before proceeding
      await _validateDeletePermission(imageUrl);

      // Extract reference from URL
      final ref = storage.refFromURL(imageUrl);
      await ref.delete();

      AppLogger.info('Image deleted from storage: $imageUrl');

      // Try to delete thumbnail too
      await deleteThumbnail(imageUrl);

      return true;
    } catch (e) {
      AppLogger.error('Failed to delete image: $e');
      return false;
    }
  }

  @override
  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }

  @override
  Future<StorageInfo?> getUserStorageInfo(String userId) async {
    try {
      final listResult = await storage.ref('users/$userId/recipes').listAll();

      int totalSize = 0;
      int fileCount = 0;

      for (final item in listResult.items) {
        final metadata = await item.getMetadata();
        totalSize += metadata.size ?? 0;
        fileCount++;
      }

      return StorageInfo(
        totalBytes: totalSize,
        fileCount: fileCount,
        formattedSize: formatBytes(totalSize),
      );
    } catch (e) {
      AppLogger.error('Failed to get storage info: $e');
      return null;
    }
  }

  /// Get storage reference from a download URL
  /// This is different from the inherited getReference(path) which takes a storage path
  Reference? getReferenceFromURL(String url) {
    try {
      return storage.refFromURL(url);
    } catch (e) {
      AppLogger.error('Failed to get reference from URL: $e');
      return null;
    }
  }

  @override
  dynamic createReference(String path) {
    return storage.ref().child(path);
  }

  @override
  Future<Uint8List?> compressImage({
    required File imageFile,
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
    int quality = _defaultQuality,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await compressImageBytes(
        bytes,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );
    } catch (e) {
      AppLogger.error('Image compression failed: $e');
      return null;
    }
  }

  @override
  Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
    int quality = _defaultQuality,
  }) async {
    try {
      final originalSize = bytes.length;

      const maxSizeWithoutCompression =
          UploadConstants.skipCompressionThreshold;
      if (originalSize < maxSizeWithoutCompression) {
        AppLogger.info(
          '⚡ Skipping compression for small image: ${(originalSize / 1024).toStringAsFixed(1)}KB',
        );
        return bytes;
      }

      AppLogger.info(
        '🔄 Compressing image: ${(originalSize / 1024).toStringAsFixed(1)}KB',
      );

      // Compress with dimension enforcement and aspect-ratio preservation
      var compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
        keepExif: false,
      );

      // Progressive quality reduction if still too large (max 4 iterations)
      int currentQuality = quality;
      while (compressed.length > UploadConstants.compressionTargetBytes &&
          currentQuality > 50) {
        currentQuality -= 10;
        compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: maxWidth,
          minHeight: maxHeight,
          quality: currentQuality,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
          keepExif: false,
        );
      }

      final reduction =
          ((1 - (compressed.length / originalSize)) * 100).toStringAsFixed(1);
      AppLogger.info(
        '✅ Image compressed: ${formatBytes(originalSize)} → ${formatBytes(compressed.length)} ($reduction% reduction)',
      );

      return compressed;
    } catch (e) {
      AppLogger.error('Image compression failed, using original: $e');
      return bytes;
    }
  }

  @override
  Future<String?> createAndUploadThumbnail({
    required File imageFile,
    required String userId,
    required String originalPath,
    int thumbnailSize = _defaultThumbnailSize,
    int thumbnailQuality = _defaultThumbnailQuality,
  }) async {
    try {
      // Read original image
      final bytes = await imageFile.readAsBytes();

      // Create thumbnail
      final thumbnailBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: thumbnailSize,
        minHeight: thumbnailSize,
        quality: thumbnailQuality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      // Generate thumbnail path
      final thumbPath = originalPath
          .replaceAll('/recipes/', '/recipes/thumbnails/')
          .replaceAll('.jpg', '_thumb.jpg');

      // Upload thumbnail
      final thumbnailUrl = await uploadImageData(
        imageData: thumbnailBytes,
        userId: userId,
        path: thumbPath,
        metadata: {'type': 'thumbnail', 'originalPath': originalPath},
      );

      if (thumbnailUrl != null) {
        AppLogger.info('Thumbnail created and uploaded');
      }

      return thumbnailUrl;
    } catch (e) {
      AppLogger.error('Thumbnail creation failed: $e');
      return null;
    }
  }

  @override
  Future<void> deleteThumbnail(String imageUrl) async {
    try {
      // Convert URL to thumbnail path
      if (imageUrl.contains('/recipes/') &&
          !imageUrl.contains('/thumbnails/')) {
        final thumbUrl = imageUrl
            .replaceAll('/recipes/', '/recipes/thumbnails/')
            .replaceAll('.jpg', '_thumb.jpg');

        final ref = storage.refFromURL(thumbUrl);
        await ref.delete();
        AppLogger.info('Thumbnail deleted');
      }
    } catch (e) {
      // Ignore if thumbnail doesn't exist
      AppLogger.debug('Thumbnail deletion failed (may not exist): $e');
    }
  }

  @override
  String generateFileName({required String originalPath, String? prefix}) {
    final extension = path.extension(originalPath).toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = _uuid.v4().substring(0, 8);

    // If no extension or unsupported, use .jpg
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final fileExtension =
        validExtensions.contains(extension) ? extension : '.jpg';

    final filePrefix = prefix ?? 'recipe';
    return '${filePrefix}_${timestamp}_$uniqueId$fileExtension';
  }

  @override
  bool isValidImageFile(File file) {
    final extension = path.extension(file.path).toLowerCase();
    const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

    // Check extension
    if (!validExtensions.contains(extension)) {
      return false;
    }

    const maxSize = UploadConstants.maxStorageFileBytes;
    if (file.lengthSync() > maxSize) {
      return false;
    }

    return true;
  }

  @override
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
