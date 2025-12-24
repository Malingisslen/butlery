// lib/widgets/image/image_picker_dialogs.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

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
  static Future<ImageSource?> showImageSourceDialog(
      BuildContext context) async {
    AppLogger.info('🔍 Visar bildkälla-dialog');

    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.borderRadiusM)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppDimensions.avatarSizeMedium,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.neutralMedium,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius10),
              ),
            ),
            Text(
              'Välj bildkälla',
              style: AppTextStyles.displaySmall
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, size: AppDimensions.iconSizeL),
              title: const Text('Ta foto'),
              subtitle: const Text('Använd kameran för att ta en ny bild'),
              onTap: () {
                AppLogger.info('📷 Användaren valde kamera');
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  size: AppDimensions.iconSizeL),
              title: const Text('Välj från galleri'),
              subtitle: const Text(
                'Välj en befintlig bild från ditt galleri',
              ),
              onTap: () {
                AppLogger.info('🖼️ Användaren valde galleri');
                Navigator.pop(context, ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppDimensions.spacingLg),
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
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Inställningar',
            onPressed: () async {
              await openAppSettings();
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
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
        backgroundColor: AppColors.error,
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
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                  Text(
                    progress.message,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    '$percentage% (${progress.completed}/${progress.total})',
                    style: AppTextStyles.bodySmall,
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
