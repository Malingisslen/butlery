// lib/widgets/image/image_picker_dialogs.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';

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
    BuildContext context,
  ) async {
    AppLogger.info('🔍 Visar bildkälla-dialog');

    return showButlerySheet<ImageSource>(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppDimensions.layoutMarginOf(context),
          vertical: AppDimensions.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.imageSelectSource,
              style: AppTextStyles.displaySmall,
            ),
            const SizedBox(height: AppDimensions.space24),
            ButleryItemRow(
              leadingIcon: ButleryIcons.camera,
              title: context.l10n.commonTakePhoto,
              subtitle: context.l10n.imageUseCameraForNewPhoto,
              onTap: () {
                AppLogger.info('📷 Användaren valde kamera');
                Navigator.pop(context, ImageSource.camera);
              },
            ),
            const ButleryDivider(),
            ButleryItemRow(
              leadingIcon: ButleryIcons.image,
              title: context.l10n.commonSelectFromGallery,
              subtitle: context.l10n.imageSelectExistingFromGallery,
              onTap: () {
                AppLogger.info('🖼️ Användaren valde galleri');
                Navigator.pop(context, ImageSource.gallery);
              },
            ),
            const SizedBox(height: AppDimensions.space24),
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
    final result = await showButleryDialog<bool>(
      context: context,
      builder: (context) => ButleryDialog.confirm(
        title: context.l10n.imagePermissionRequired,
        message: context.l10n.imagePermissionMessage(permission),
        primaryLabel: context.l10n.commonSettings,
        onPrimary: () async {
          await openAppSettings();
          if (context.mounted) {
            Navigator.pop(context, true);
          }
        },
      ),
    );

    return result ?? false;
  }

  /// Show error message for image operations
  static void showImageError(BuildContext context, String message) {
    AppLogger.error('🚨 Visar fel till användare: $message');
    SnackBarUtils.showFailure(context, what: message);
  }

  /// Show detailed upload dialog with progress
  static void showDetailedUploadDialog(
    BuildContext context, {
    required Stream<UploadProgress> progressStream,
  }) {
    AppLogger.info('📊 Visar upload progress dialog');

    showButleryDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: StreamBuilder<UploadProgress>(
          stream: progressStream,
          initialData: UploadProgress(0, 0, context.l10n.imageUploadPreparing),
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

            return ButleryDialog(
              title: context.l10n.imageUploadingImages,
              actions: const [],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The plate line with the real count (Komponentark
                  // v1:303-309; P4-U07 test plan: no Material progress bar).
                  PlateLine(
                    value: progress.total > 0
                        ? progress.completed / progress.total
                        : null,
                    semanticLabel: context.l10n.imageUploadingImages,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  Text(
                    progress.message,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.space4),
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
