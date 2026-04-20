import 'dart:io';
import 'dart:typed_data';

/// Storage repository interface for abstracting file storage operations.
/// This interface provides a contract for storage implementations, enabling
/// dependency injection and testability while maintaining flexibility to switch
/// between different storage providers (Firebase Storage, AWS S3, local storage, etc.).
/// The repository pattern abstracts the underlying storage implementation,
/// allowing services to depend on this interface rather than concrete Firebase
/// classes, which significantly improves testability and maintainability.
abstract class StorageRepository {
  /// Upload an image file to storage.
  /// Returns the download URL of the uploaded file, or null if upload fails.
  /// When [cacheControl] is provided it's forwarded as the Cache-Control
  /// header on the stored object (e.g. `public, max-age=31536000, immutable`
  /// for content-addressed uploads like heirloom scans).
  Future<String?> uploadImage({
    required File imageFile,
    required String userId,
    required String path,
    Map<String, String>? metadata,
    Function(double progress)? onProgress,
    String? cacheControl,
  });

  /// Upload image data (bytes) to storage.
  /// Returns the download URL of the uploaded file, or null if upload fails.
  /// When [cacheControl] is provided it's forwarded as the Cache-Control
  /// header on the stored object.
  Future<String?> uploadImageData({
    required Uint8List imageData,
    required String userId,
    required String path,
    Map<String, String>? metadata,
    Function(double progress)? onProgress,
    String? cacheControl,
  });

  /// Upload multiple images in batch
  Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    required String userId,
    required String basePath,
    Function(int completed, int total)? onProgress,
  });

  /// Delete an image from storage
  Future<bool> deleteImage(String imageUrl);

  /// Delete multiple images from storage
  Future<void> deleteMultipleImages(List<String> imageUrls);

  /// Get storage information for a user
  Future<StorageInfo?> getUserStorageInfo(String userId);

  /// Get a reference from a storage URL
  /// Returns null if URL is invalid
  dynamic getReference(String url);

  /// Create a storage reference for a given path
  dynamic createReference(String path);

  /// Compress an image file
  /// Returns compressed image data, or null if compression fails
  Future<Uint8List?> compressImage({
    required File imageFile,
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
  });

  /// Compress image from raw bytes (for web platform or bytes-based uploads).
  /// Returns compressed bytes, or original bytes on failure.
  Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 85,
  });

  /// Create and upload a thumbnail for an image
  Future<String?> createAndUploadThumbnail({
    required File imageFile,
    required String userId,
    required String originalPath,
    int thumbnailSize = 300,
    int thumbnailQuality = 70,
  });

  /// Delete a thumbnail image
  Future<void> deleteThumbnail(String imageUrl);

  /// Generate a unique filename for storage
  String generateFileName({
    required String originalPath,
    String? prefix,
  });

  /// Check if a file is a valid image
  bool isValidImageFile(File file);

  /// Format bytes into human-readable string
  String formatBytes(int bytes);
}

/// Storage usage information
class StorageInfo {
  final int totalBytes;
  final int fileCount;
  final String formattedSize;

  StorageInfo({
    required this.totalBytes,
    required this.fileCount,
    required this.formattedSize,
  });

  /// Create a copy with optional parameter overrides
  StorageInfo copyWith({
    int? totalBytes,
    int? fileCount,
    String? formattedSize,
  }) {
    return StorageInfo(
      totalBytes: totalBytes ?? this.totalBytes,
      fileCount: fileCount ?? this.fileCount,
      formattedSize: formattedSize ?? this.formattedSize,
    );
  }

  @override
  String toString() {
    return 'StorageInfo(totalBytes: $totalBytes, fileCount: $fileCount, formattedSize: $formattedSize)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is StorageInfo &&
        other.totalBytes == totalBytes &&
        other.fileCount == fileCount &&
        other.formattedSize == formattedSize;
  }

  @override
  int get hashCode => Object.hash(totalBytes, fileCount, formattedSize);
}
