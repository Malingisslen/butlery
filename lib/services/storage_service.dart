// lib/services/storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../core/utils/logger.dart';

/// Service för att hantera bilduppladdning till Firebase Storage
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // Konstanter för bildkomprimering
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1080;
  static const int _quality = 85;

  /// Ladda upp en bild från fil (kamera/galleri)
  Future<String?> uploadImageFile(File imageFile, String userId) async {
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

      // Ladda upp komprimerad bild
      final uploadTask = await storageRef.putData(
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

      // Hämta nedladdnings-URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      AppLogger.info('Bild uppladdad! URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      AppLogger.error('Fel vid bilduppladdning: $e');
      return null;
    }
  }

  /// Ladda upp flera bilder samtidigt
  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles,
    String userId, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < imageFiles.length; i++) {
      final url = await uploadImageFile(imageFiles[i], userId);
      if (url != null) {
        urls.add(url);
      }

      // Rapportera progress
      onProgress?.call(i + 1, imageFiles.length);
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

  /// Komprimera bild innan uppladdning
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
