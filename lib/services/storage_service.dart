// lib/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../core/utils/logger.dart';

/// Service för att hantera bilduppladdning till Firebase Storage
/// Med förbättrad komprimering och progress tracking
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Konstanter för bildkomprimering
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1080;
  static const int _quality = 85;
  static const int _thumbnailSize = 300;
  static const int _thumbnailQuality = 70;

  /// Ladda upp en bild från fil (kamera/galleri) MED PROGRESS
  Future<String?> uploadImageFile(
    File imageFile,
    String userId, {
    Function(double)? onProgress,
  }) async {
    try {
      AppLogger.info('Börjar uppladdning av bild: ${imageFile.path}');

      // Komprimera bilden först
      final compressedBytes = await _compressImage(imageFile);
      if (compressedBytes == null) {
        AppLogger.error('Kunde inte komprimera bild');
        return null;
      }

      // Generera unikt filnamn
      final fileName = _generateFileName(imageFile.path);
      final storageRef = _storage.ref().child(
        'users/$userId/recipes/$fileName',
      );

      // Skapa upload task
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

      // Lyssna på progress om callback finns
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      // Vänta på att uppladdningen är klar
      final taskSnapshot = await uploadTask;

      // Hämta nedladdnings-URL
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      AppLogger.info('Bild uppladdad! URL: $downloadUrl');

      // Skapa thumbnail i bakgrunden
      _createAndUploadThumbnail(imageFile, userId, fileName);

      return downloadUrl;
    } catch (e) {
      AppLogger.error('Fel vid bilduppladdning: $e');
      return null;
    }
  }

  /// Ladda upp flera bilder samtidigt MED DETALJERAD PROGRESS
  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles,
    String userId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImageFile(
        imageFiles[i],
        userId,
        onProgress: (fileProgress) {
          // Rapportera total progress
          if (onProgress != null) {
            onProgress(i + (fileProgress > 0.99 ? 1 : 0), imageFiles.length);
          }
        },
      );

      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  /// Ta bort en bild från Storage
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extrahera referens från URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      AppLogger.info('Bild borttagen från Storage: $imageUrl');

      // Försök ta bort thumbnail också
      await _deleteThumbnail(imageUrl);

      return true;
    } catch (e) {
      AppLogger.error('Kunde inte ta bort bild: $e');
      return false;
    }
  }

  /// Ta bort flera bilder
  Future<void> deleteMultipleImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImage(url);
    }
  }

  /// Komprimera bild innan uppladdning MED BÄTTRE KVALITET
  Future<Uint8List?> _compressImage(File file) async {
    try {
      // Läs originalbilden
      final bytes = await file.readAsBytes();

      // Komprimera med flutter_image_compress
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxWidth,
        minHeight: _maxHeight,
        quality: _quality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true, // Automatisk EXIF-rotation
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

  /// Skapa och ladda upp thumbnail
  Future<void> _createAndUploadThumbnail(
    File imageFile,
    String userId,
    String originalFileName,
  ) async {
    try {
      // Läs originalbilden
      final bytes = await imageFile.readAsBytes();

      // Skapa thumbnail
      final thumbnailBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _thumbnailSize,
        minHeight: _thumbnailSize,
        quality: _thumbnailQuality,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );

      // Generera thumbnail-filnamn
      final thumbFileName = originalFileName.replaceAll('.jpg', '_thumb.jpg');
      final storageRef = _storage.ref().child(
        'users/$userId/recipes/thumbnails/$thumbFileName',
      );

      // Ladda upp thumbnail
      await storageRef.putData(
        thumbnailBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      AppLogger.info('Thumbnail skapad och uppladdad');
    } catch (e) {
      AppLogger.error('Fel vid thumbnail-skapande: $e');
      // Inte kritiskt om thumbnail misslyckas
    }
  }

  /// Ta bort thumbnail
  Future<void> _deleteThumbnail(String imageUrl) async {
    try {
      // Konvertera URL till thumbnail path
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
      // Ignorera om thumbnail inte finns
    }
  }

  /// Generera unikt filnamn för bild
  String _generateFileName(String originalPath) {
    final extension = path.extension(originalPath).toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = _uuid.v4().substring(0, 8);

    // Om ingen extension eller inte stödd, använd .jpg
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final fileExtension =
        validExtensions.contains(extension) ? extension : '.jpg';

    return 'recipe_${timestamp}_$uniqueId$fileExtension';
  }

  /// Formatera bytes till läsbar text
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Validera att en fil är en giltig bild
  static bool isValidImageFile(File file) {
    final extension = path.extension(file.path).toLowerCase();
    const validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

    // Kontrollera extension
    if (!validExtensions.contains(extension)) {
      return false;
    }

    // Kontrollera filstorlek (max 10MB)
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (file.lengthSync() > maxSize) {
      return false;
    }

    return true;
  }

  /// Hämta Storage-användning för en användare
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

/// Information om användarens Storage-användning
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
