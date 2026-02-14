// lib/widgets/recipe/upload_choice_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/theme/app_colors.dart';

/// Dialog for handling pending/failed uploads during recipe save.
/// Provides user choices when saving a recipe with incomplete uploads:
/// - Wait for pending uploads to complete
/// - Save without pending/failed images
/// - Cancel the save operation
/// **Usage:**
/// ```dart
/// final choice = await showUploadChoiceDialog(
///   context: context,
///   safetyResult: uploadSafetyResult,
/// );
/// ```
Future<UploadChoice?> showUploadChoiceDialog({
  required BuildContext context,
  required UploadSafetyResult safetyResult,
}) async {
  if (safetyResult.isSafe) {
    return UploadChoice.wait; // No issues, proceed normally
  }

  final hasFailedUploads = safetyResult.hasFailedUploads;
  final hasPendingUploads = safetyResult.hasPendingUploads;

  String dialogTitle;
  String dialogContent;
  final List<Widget> actions = [];

  if (hasFailedUploads && hasPendingUploads) {
    dialogTitle = context.l10n.uploadInProgress;
    dialogContent = context.l10n.uploadMixedStatus(
        safetyResult.failedImagePaths.length,
        safetyResult.pendingImagePaths.length);
  } else if (hasFailedUploads) {
    dialogTitle = context.l10n.uploadFailed;
    dialogContent =
        context.l10n.uploadFailedCount(safetyResult.failedImagePaths.length);
  } else {
    dialogTitle = context.l10n.uploadInProgress;
    dialogContent =
        context.l10n.uploadPendingCount(safetyResult.pendingImagePaths.length);
  }

  // Add common actions
  actions.addAll([
    TextButton(
      onPressed: () => Navigator.of(context).pop(UploadChoice.cancel),
      child: Text(context.l10n.commonCancel),
    ),
    if (hasPendingUploads)
      TextButton(
        onPressed: () => Navigator.of(context).pop(UploadChoice.wait),
        child: Text(context.l10n.uploadWait),
      ),
    TextButton(
      onPressed: () =>
          Navigator.of(context).pop(UploadChoice.saveWithoutPending),
      style: TextButton.styleFrom(foregroundColor: AppColors.warning),
      child: Text(hasFailedUploads
          ? context.l10n.uploadSaveWithoutFailed
          : context.l10n.uploadSaveWithoutPending),
    ),
  ]);

  return showDialog<UploadChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(dialogTitle),
      content: Text(dialogContent),
      actions: actions,
    ),
  );
}
