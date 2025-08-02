import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/mixins/firebase_service_mixin.dart';

/// Firebase Storage service for image upload and management
class StorageService extends BaseService with FirebaseServiceMixin {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();
  
  @override
  String get serviceName => 'StorageService';

  // Image compression constants
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1080;
  static const int _quality = 85;
  static const int _thumbnailSize = 300;
  static const int _thumbnailQuality = 70;

  Future<String?> uploadImageFile(
    File imageFile,
    String userId, {
    Function(double)? onProgress,
  }) async {
    return await executeServiceOperation(
      () async {
        return await _uploadImageFileInternal(imageFile, userId, onProgress);
      },
      operationName: 'Upload image file',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }

  Future<String> _uploadImageFileInternal(
    File imageFile,
    String userId,
    Function(double)? onProgress,
  ) async {
      AppLogger.info('Börjar uppladdning av bild: ${imageFile.path}');

      // Compress image first
      final compressedBytes = await _compressImage(imageFile);
      if (compressedBytes == null) {
        throw Exception('Kunde inte komprimera bild');
      }

      // Generate unique filename
      final fileName = _generateFileName(imageFile.path);
      final storageRef = _storage.ref().child(
        'users/$userId/recipes/$fileName',
      );

      // Create upload task
      final uploadTask = storageRef.putData(
        compressedBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'originalSize': imageFile.lengthSync().toString(),
            'compressedSize': compressedBytes.length.toString(),
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
      AppLogger.info('Bild uppladdad! URL: $downloadUrl');

      // Create thumbnail in background
      _createAndUploadThumbnail(imageFile, userId, fileName);

      return downloadUrl;
  }

  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles,
    String userId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    return await super.executeBatchOperation(
      imageFiles.map((file) => () async {
        final url = await uploadImageFile(file, userId);
        return url ?? '';
      }).toList(),
      'Upload multiple images',
      requiresAuth: true,
      requiresNetwork: true,
    ).then((results) => results.where((url) => url.isNotEmpty).toList());
  }

  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract reference from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      AppLogger.info('Bild borttagen från Storage: $imageUrl');

      // Try to delete thumbnail too
      await _deleteThumbnail(imageUrl);

      return true;
    } catch (e) {
      AppLogger.error('Kunde inte ta bort bild: $e');
      return false;
    }
  }

  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }

  Future<Uint8List?> _compressImage(File file) async {
    try {
      // Read original image
      final bytes = await file.readAsBytes();

      // Compress with flutter_image_compress
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxWidth,
        minHeight: _maxHeight,
        quality: _quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true, // Automatic EXIF rotation
      );

      final originalSize = bytes.length;
      final compressedSize = compressed.length;
      final reduction = ((1 - (compressedSize / originalSize)) * 100)
          .toStringAsFixed(1);

      AppLogger.info(
        'Bild komprimerad: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} ($reduction% minskning)',
      );

      return compressed;
    } catch (e) {
      AppLogger.error('Fel vid bildkomprimering: $e');
      return null;
    }
  }

  Future<void> _createAndUploadThumbnail(
    File imageFile,
    String userId,
    String originalFileName,
  ) async {
    try {
      // Read original image
      final bytes = await imageFile.readAsBytes();

      // Create thumbnail
      final thumbnailBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _thumbnailSize,
        minHeight: _thumbnailSize,
        quality: _thumbnailQuality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      // Generate thumbnail filename
      final thumbFileName = originalFileName.replaceAll('.jpg', '_thumb.jpg');
      final storageRef = _storage.ref().child(
        'users/$userId/recipes/thumbnails/$thumbFileName',
      );

      // Upload thumbnail
      await storageRef.putData(
        thumbnailBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      AppLogger.info('Thumbnail skapad och uppladdad');
    } catch (e) {
      AppLogger.error('Fel vid thumbnail-skapande: $e');
      // Not critical if thumbnail fails
    }
  }

  Future<void> _deleteThumbnail(String imageUrl) async {
    try {
      // Convert URL to thumbnail path
      if (imageUrl.contains('/recipes/') &&
          !imageUrl.contains('/thumbnails/')) {
        final thumbUrl = imageUrl
            .replaceAll('/recipes/', '/recipes/thumbnails/')
            .replaceAll('.jpg', '_thumb.jpg');

        final ref = _storage.refFromURL(thumbUrl);
        await ref.delete();
        AppLogger.info('Thumbnail borttagen');
      }
    } catch (e) {
      // Ignore if thumbnail doesn't exist
    }
  }

  String _generateFileName(String originalPath) {
    final extension = path.extension(originalPath).toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = _uuid.v4().substring(0, 8);

    // If no extension or unsupported, use .jpg
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final fileExtension =
        validExtensions.contains(extension) ? extension : '.jpg';

    return 'recipe_${timestamp}_$uniqueId$fileExtension';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static bool isValidImageFile(File file) {
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

  Future<String?> uploadRecipeImage(
    File imageFile,
    String recipeId, {
    Function(double)? onProgress,
  }) async {
    // Use current user ID or fallback logic
    const userId = 'current_user'; // This should be replaced with actual user ID logic
    return await uploadImageFile(imageFile, userId, onProgress: onProgress);
  }

  Future<void> deleteRecipeImage(String imageUrl) async {
    await deleteImage(imageUrl);
  }

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
        formattedSize: _formatBytes(totalSize),
      );
    } catch (e) {
      AppLogger.error('Kunde inte hämta storage-info: $e');
      return null;
    }
  }
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
}
