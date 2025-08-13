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
  
  // Image compression constants
  static const int _defaultMaxWidth = 1920;
  static const int _defaultMaxHeight = 1080;
  static const int _defaultQuality = 85;
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
    final results = <String>[];
    final total = imageFiles.length;
    
    for (int i = 0; i < total; i++) {
      final file = imageFiles[i];
      final fileName = generateFileName(originalPath: file.path);
      final fullPath = '$basePath/$fileName';
      
      final url = await uploadImage(
        imageFile: file,
        userId: userId,
        path: fullPath,
      );
      
      if (url != null) {
        results.add(url);
      }
      
      if (onProgress != null) {
        onProgress(i + 1, total);
      }
    }
    
    return results;
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
      
      // Compress with flutter_image_compress
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxWidth,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true, // Automatic EXIF rotation
      );
      
      final originalSize = bytes.length;
      final compressedSize = compressed.length;
      final reduction = ((1 - (compressedSize / originalSize)) * 100)
          .toStringAsFixed(1);
      
      AppLogger.info(
        'Image compressed: ${formatBytes(originalSize)} → ${formatBytes(compressedSize)} ($reduction% reduction)',
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