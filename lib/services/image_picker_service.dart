// lib/services/image_picker_service.dart
// UPPDATERAD VERSION: Med omfattande debug-logging

import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/utils/logger.dart';
import 'storage_service.dart';

/// Service för att välja bilder från kamera eller galleri
/// Med omfattande debug-logging och förbättrad permissions-hantering
/// UI-logik har flyttats till ImagePickerDialogs för clean architecture
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Välj en bild från kamera eller galleri MED OMFATTANDE DEBUG
  Future<File?> pickImage(ImageSource source) async {
    try {
      AppLogger.info('🔍 Startar bildval från: ${source.name}');

      // Kontrollera permissions
      final hasPermission = await _checkAndRequestPermission(source);
      AppLogger.info('🔑 Permission resultat: $hasPermission');

      if (!hasPermission) {
        AppLogger.warning('❌ Permission nekad för ${source.name}');
        return null;
      }

      AppLogger.info('📱 Anropar image picker...');
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        AppLogger.info('❌ Ingen bild vald (användaren avbröt)');
        return null;
      }

      AppLogger.info('✅ Bild vald: ${pickedFile.path}');

      final file = File(pickedFile.path);

      // Kontrollera att filen existerar
      final exists = await file.exists();
      AppLogger.info('📁 Fil existerar: $exists');

      if (!exists) {
        AppLogger.error('❌ Filen existerar inte på disk');
        return null;
      }

      // Kontrollera filstorlek
      final size = await file.length();
      AppLogger.info('📊 Filstorlek: $size bytes (${_formatBytes(size)})');

      // Validera filen
      final isValid = StorageService.isValidImageFile(file);
      AppLogger.info('✅ Fil är giltig: $isValid');

      if (!isValid) {
        AppLogger.error('❌ Ogiltig bildfil: ${file.path}');
        return null;
      }

      AppLogger.success('🎉 Bildval framgångsrikt!');
      return file;
    } catch (e, stackTrace) {
      AppLogger.error('💥 Fel vid bildval: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Välj flera bilder från galleri MED DEBUG
  Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      AppLogger.info('🔍 Startar val av flera bilder (max: $maxImages)');

      // Kontrollera gallery permission
      final hasPermission = await _checkAndRequestPermission(
        ImageSource.gallery,
      );
      AppLogger.info('🔑 Gallery permission: $hasPermission');

      if (!hasPermission) {
        AppLogger.warning('❌ Gallery permission nekad');
        return [];
      }

      AppLogger.info('📱 Anropar multiple image picker...');

      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (pickedFiles.isEmpty) {
        AppLogger.info('❌ Inga bilder valda');
        return [];
      }

      AppLogger.info('📸 ${pickedFiles.length} bilder valda från picker');

      // Begränsa antal bilder
      final limitedFiles = pickedFiles.take(maxImages).toList();

      if (pickedFiles.length > maxImages) {
        AppLogger.info(
          '✂️ Begränsar från ${pickedFiles.length} till $maxImages bilder',
        );
      }

      // Konvertera till File och validera
      final files = <File>[];
      for (int i = 0; i < limitedFiles.length; i++) {
        final xFile = limitedFiles[i];
        AppLogger.info('🔍 Bearbetar bild ${i + 1}: ${xFile.path}');

        final file = File(xFile.path);

        // Kontrollera att filen existerar
        final exists = await file.exists();
        if (!exists) {
          AppLogger.warning('⚠️ Fil ${i + 1} existerar inte: ${file.path}');
          continue;
        }

        // Kontrollera filstorlek
        final size = await file.length();
        AppLogger.info('📊 Bild ${i + 1} storlek: ${_formatBytes(size)}');

        if (StorageService.isValidImageFile(file)) {
          files.add(file);
          AppLogger.info('✅ Bild ${i + 1} godkänd');
        } else {
          AppLogger.warning('❌ Bild ${i + 1} är ogiltig: ${file.path}');
        }
      }

      AppLogger.success('🎉 ${files.length} giltiga bilder valda');
      return files;
    } catch (e, stackTrace) {
      AppLogger.error('💥 Fel vid val av flera bilder: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  /// Kontrollera och begär permissions MED DEBUG
  Future<bool> _checkAndRequestPermission(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        AppLogger.info('🔍 Kontrollerar kamera-permission...');
        final status = await Permission.camera.status;
        AppLogger.info('📷 Kamera permission status: ${status.name}');

        if (status.isDenied) {
          AppLogger.info('🔑 Begär kamera-permission...');
          final result = await Permission.camera.request();
          AppLogger.info('📷 Kamera permission resultat: ${result.name}');
          return result.isGranted;
        }
        return status.isGranted;
      } else {
        // För galleri - hantera både photos och storage permissions smart
        AppLogger.info('🔍 Kontrollerar galleri-permission...');
        final status = await Permission.photos.status;
        AppLogger.info('🖼️ Galleri permission status: ${status.name}');

        // LIMITED är OK för galleri - användaren har valt vissa bilder
        if (status.isGranted || status.isLimited) {
          return true;
        }

        if (status.isDenied) {
          AppLogger.info('🔑 Begär galleri-permission...');
          final result = await Permission.photos.request();
          AppLogger.info('🖼️ Galleri permission resultat: ${result.name}');

          // LIMITED är också OK
          if (result.isGranted || result.isLimited) {
            return true;
          }
        }

        // Om photos permission är permanently denied, testa storage (äldre Android)
        if (status.isPermanentlyDenied) {
          final storageStatus = await Permission.storage.status;

          if (storageStatus.isDenied) {
            final storageResult = await Permission.storage.request();
            return storageResult.isGranted;
          }
          return storageStatus.isGranted;
        }

        return false;
      }
    } catch (e) {
      AppLogger.error('💥 Fel vid permission-kontroll: $e');
      return false;
    }
  }

  /// Formatera bytes till läsbar text
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Debug-metod för att testa permissions manuellt
  Future<void> debugPermissions() async {
    AppLogger.info('🔍 DEBUG: Kontrollerar alla permissions...');

    // Kamera
    final cameraStatus = await Permission.camera.status;
    AppLogger.info('📷 Kamera: ${cameraStatus.name}');

    // Photos
    final photosStatus = await Permission.photos.status;
    AppLogger.info('🖼️ Photos: ${photosStatus.name}');

    // Storage (äldre Android)
    final storageStatus = await Permission.storage.status;
    AppLogger.info('💾 Storage: ${storageStatus.name}');

    // Media (nyare Android)
    final mediaStatus = await Permission.mediaLibrary.status;
    AppLogger.info('📱 Media: ${mediaStatus.name}');
  }
}