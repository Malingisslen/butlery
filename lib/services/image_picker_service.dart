// lib/services/image_picker_service.dart
// UPPDATERAD VERSION: Med omfattande debug-logging

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/utils/logger.dart';
import '../theme/app_theme.dart';
import 'storage_service.dart';

/// Progress data för uppladdning
class UploadProgress {
  final int completed;
  final int total;
  final String message;

  UploadProgress(this.completed, this.total, this.message);

  double get percentage => total > 0 ? completed / total : 0.0;
  bool get isCompleted => completed >= total && total > 0;
}

/// Service för att välja bilder från kamera eller galleri
/// Med omfattande debug-logging och förbättrad permissions-hantering
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Visa dialog för att välja bildkälla
  Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    AppLogger.info('🔍 Visar bildkälla-dialog');

    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Text(
                  'Välj bildkälla',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt, size: 28),
                  title: const Text('Ta foto'),
                  subtitle: const Text('Använd kameran för att ta en ny bild'),
                  onTap: () {
                    AppLogger.info('📷 Användaren valde kamera');
                    Navigator.pop(context, ImageSource.camera);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library, size: 28),
                  title: const Text('Välj från galleri'),
                  subtitle: const Text(
                    'Välj en befintlig bild från ditt galleri',
                  ),
                  onTap: () {
                    AppLogger.info('🖼️ Användaren valde galleri');
                    Navigator.pop(context, ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

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

  /// Visa permission-dialog
  Future<bool> showPermissionDialog(
    BuildContext context,
    String permission,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Behörighet krävs'),
            content: Text(
              'Butlery behöver tillgång till din $permission för att kunna '
              'lägga till bilder till recept. Gå till inställningar för att '
              'ge behörighet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Inställningar'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  /// Visa fel-meddelande för bildval
  void showImageError(BuildContext context, String message) {
    AppLogger.error('🚨 Visar fel till användare: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Visa uppladdningsdialog med detaljerad progress
  void showDetailedUploadDialog(
    BuildContext context, {
    required Stream<UploadProgress> progressStream,
  }) {
    AppLogger.info('📊 Visar upload progress dialog');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: StreamBuilder<UploadProgress>(
              stream: progressStream,
              initialData: UploadProgress(0, 0, 'Förbereder...'),
              builder: (context, snapshot) {
                final progress = snapshot.data!;
                final percentage =
                    progress.total > 0
                        ? (progress.completed / progress.total * 100).toInt()
                        : 0;

                // Logga progress (men inte för ofta)
                if (percentage % 25 == 0 || progress.isCompleted) {
                  AppLogger.info(
                    '📈 Upload progress: $percentage% - ${progress.message}',
                  );
                }

                return AlertDialog(
                  title: const Text('Laddar upp bilder'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value:
                            progress.total > 0
                                ? progress.completed / progress.total
                                : null,
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMd),
                      Text(
                        progress.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: AppTheme.spacingSm),
                      Text(
                        '$percentage% (${progress.completed}/${progress.total})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
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
