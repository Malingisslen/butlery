// lib/widgets/image/image_picker_dialogs.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../core/utils/logger.dart';

/// Progress data for upload operations
class UploadProgress {
  final int completed;
  final int total;
  final String message;

  UploadProgress(this.completed, this.total, this.message);

  double get percentage => total > 0 ? completed / total : 0.0;
  bool get isCompleted => completed >= total && total > 0;
}

/// UI dialogs for image picker functionality
/// Separates UI logic from the image picker service layer
class ImagePickerDialogs {
  /// Show dialog for selecting image source (camera or gallery)
  static Future<ImageSource?> showImageSourceDialog(BuildContext context) async {
    AppLogger.info('🔍 Visar bildkälla-dialog');

    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
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

  /// Show permission dialog when access is needed
  static Future<bool> showPermissionDialog(
    BuildContext context,
    String permission,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

  /// Show error message for image operations
  static void showImageError(BuildContext context, String message) {
    AppLogger.error('🚨 Visar fel till användare: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show detailed upload dialog with progress
  static void showDetailedUploadDialog(
    BuildContext context, {
    required Stream<UploadProgress> progressStream,
  }) {
    AppLogger.info('📊 Visar upload progress dialog');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: StreamBuilder<UploadProgress>(
          stream: progressStream,
          initialData: UploadProgress(0, 0, 'Förbereder...'),
          builder: (context, snapshot) {
            final progress = snapshot.data!;
            final percentage = progress.total > 0
                ? (progress.completed / progress.total * 100).toInt()
                : 0;

            // Log progress (but not too often)
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
                    value: progress.total > 0
                        ? progress.completed / progress.total
                        : null,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
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
}