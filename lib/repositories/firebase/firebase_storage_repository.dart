import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';
import 'package:butlery/core/utils/logger.dart';

/// Firebase implementation of the StorageRepository interface.
///
/// This repository provides Firebase Storage functionality while maintaining
/// the abstraction required for dependency injection and testability.
/// It encapsulates all Firebase-specific storage operations and can be
/// easily mocked or replaced with alternative implementations.
class FirebaseStorageRepository implements StorageRepository {
  final FirebaseStorage _storage;
  final Uuid _uuid;
  
  // Image compression constants - optimized for mobile with aspect ratio preservation
  static const int _defaultMaxWidth = 1200;   // Max width while preserving aspect ratio
  static const int _defaultMaxHeight = 1200;  // Max height while preserving aspect ratio  
  static const int _defaultQuality = 85;      // Higher quality for recipe photos (vs 75)
  static const int _defaultThumbnailSize = 300;
  static const int _defaultThumbnailQuality = 70;
  
  /// Creates a FirebaseStorageRepository with optional custom FirebaseStorage instance.
  /// 
  /// If no instance is provided, it uses the default FirebaseStorage.instance.
  /// This allows for dependency injection in tests while maintaining production simplicity.
  FirebaseStorageRepository({
    FirebaseStorage? storage,
    Uuid? uuid,
  }) : _storage = storage ?? FirebaseStorage.instance,
       _uuid = uuid ?? const Uuid();
  
  @override
  Future<String?> uploadImage({
    required File imageFile,
    required String userId,
    required String path,
    Map<String, String>? metadata,
    Function(double progress)? onProgress,
  }) async {
    try {
      AppLogger.info('Starting image upload: ${imageFile.path}');
      
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
      );
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
  }) async {
    try {
      final storageRef = _storage.ref().child(path);
      
      // Create upload task
      final uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
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
      
      return downloadUrl;
    } catch (e) {
      AppLogger.error('Image data upload failed: $e');
      return null;
    }
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
    final successfulUploads = results.where((url) => url != null).cast<String>().toList();
    
    AppLogger.info('✅ Parallel upload completed: ${successfulUploads.length}/$total successful');
    return successfulUploads;
  }
  
  @override
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract reference from URL
      final ref = _storage.refFromURL(imageUrl);
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
      final listResult = await _storage.ref('users/$userId/recipes').listAll();
      
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
  
  @override
  dynamic getReference(String url) {
    try {
      return _storage.refFromURL(url);
    } catch (e) {
      AppLogger.error('Failed to get reference from URL: $e');
      return null;
    }
  }
  
  @override
  dynamic createReference(String path) {
    return _storage.ref().child(path);
  }
  
  @override
  Future<Uint8List?> compressImage({
    required File imageFile,
    int maxWidth = _defaultMaxWidth,
    int maxHeight = _defaultMaxHeight,
    int quality = _defaultQuality,
  }) async {
    try {
      // Read original image
      final bytes = await imageFile.readAsBytes();
      final originalSize = bytes.length;
      
      // Skip compression for small images (under 500KB) to save processing time
      const maxSizeWithoutCompression = 500 * 1024; // 500KB
      if (originalSize < maxSizeWithoutCompression) {
        AppLogger.info('⚡ Skipping compression for small image: ${(originalSize / 1024).toStringAsFixed(1)}KB');
        return bytes;
      }
      
      AppLogger.info('🔄 Compressing image with aspect ratio preservation: ${(originalSize / 1024).toStringAsFixed(1)}KB');
      
      // Compress with aspect-ratio preservation using quality-based approach
      var compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,  // Automatic EXIF rotation
        keepExif: false,           // Remove EXIF data for smaller file size
        // Let flutter_image_compress handle dimensions automatically to preserve aspect ratio
      );
      
      // If result is still too large, apply additional compression passes
      int currentQuality = quality;
      while (compressed.length > 1024 * 1024 && currentQuality > 50) {
        currentQuality -= 10;
        AppLogger.info('🔄 Image still large (${formatBytes(compressed.length)}), reducing quality to $currentQuality');
        
        compressed = await FlutterImageCompress.compressWithList(
          bytes,
          quality: currentQuality,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
          keepExif: false,
        );
      }
      
      final compressedSize = compressed.length;
      final reduction = ((1 - (compressedSize / originalSize)) * 100)
          .toStringAsFixed(1);
      
      AppLogger.info(
        '✅ Image compressed with aspect ratio preserved: ${formatBytes(originalSize)} → ${formatBytes(compressedSize)} ($reduction% reduction)',
      );
      
      return compressed;
    } catch (e) {
      AppLogger.error('Image compression failed: $e');
      return null;
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
        metadata: {
          'type': 'thumbnail',
          'originalPath': originalPath,
        },
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
        
        final ref = _storage.refFromURL(thumbUrl);
        await ref.delete();
        AppLogger.info('Thumbnail deleted');
      }
    } catch (e) {
      // Ignore if thumbnail doesn't exist
      AppLogger.debug('Thumbnail deletion failed (may not exist): $e');
    }
  }
  
  @override
  String generateFileName({
    required String originalPath,
    String? prefix,
  }) {
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
    
    // Check file size (max 10MB)
    const maxSize = 10 * 1024 * 1024; // 10MB
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