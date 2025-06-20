// lib/services/image_picker_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/utils/logger.dart';
import 'storage_service.dart';

/// Service för att välja bilder från kamera eller galleri
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  /// Visa dialog för att välja bildkälla
  Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
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
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_library, size: 28),
                  title: const Text('Välj från galleri'),
                  subtitle: const Text(
                    'Välj en befintlig bild från ditt galleri',
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  /// Välj en bild från kamera eller galleri
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 2400, // Begränsa storlek redan vid val
        maxHeight: 2400,
        imageQuality: 90, // Lite högre kvalitet före vår egen komprimering
      );

      if (pickedFile == null) {
        AppLogger.info('Ingen bild vald');
        return null;
      }

      final file = File(pickedFile.path);

      // Validera filen
      if (!StorageService.isValidImageFile(file)) {
        AppLogger.error('Ogiltig bildfil: ${file.path}');
        return null;
      }

      AppLogger.info('Bild vald: ${file.path}');
      return file;
    } catch (e) {
      AppLogger.error('Fel vid bildval: $e');
      return null;
    }
  }

  /// Välj flera bilder från galleri
  Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (pickedFiles.isEmpty) {
        AppLogger.info('Inga bilder valda');
        return [];
      }

      // Begränsa antal bilder
      final limitedFiles = pickedFiles.take(maxImages).toList();

      if (pickedFiles.length > maxImages) {
        AppLogger.info(
          'Valde ${pickedFiles.length} bilder, begränsar till $maxImages',
        );
      }

      // Konvertera till File och validera
      final files = <File>[];
      for (final xFile in limitedFiles) {
        final file = File(xFile.path);
        if (StorageService.isValidImageFile(file)) {
          files.add(file);
        } else {
          AppLogger.warning('Hoppade över ogiltig fil: ${file.path}');
        }
      }

      AppLogger.info('${files.length} giltiga bilder valda');
      return files;
    } catch (e) {
      AppLogger.error('Fel vid val av flera bilder: $e');
      return [];
    }
  }

  /// Visa en förhandsgranskning av vald bild med möjlighet att godkänna/avbryta
  Future<bool> showImagePreview(BuildContext context, File imageFile) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Image.file(imageFile, fit: BoxFit.contain),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Avbryt'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Använd bild'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ) ??
        false;
  }

  /// Visa fel-meddelande för bildval
  void showImageError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Visa laddningsindikator medan bild laddas upp
  void showUploadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(child: Text(message ?? 'Laddar upp bild...')),
                ],
              ),
            ),
          ),
    );
  }
}
