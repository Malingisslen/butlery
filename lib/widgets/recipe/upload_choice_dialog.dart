// lib/widgets/recipe/upload_choice_dialog.dart

import 'package:flutter/material.dart';
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
    dialogTitle = 'Bilduppladdning pågår';
    dialogContent =
        'Några bilder kunde inte laddas upp (${safetyResult.failedImagePaths.length}) och andra laddas fortfarande upp (${safetyResult.pendingImagePaths.length}).\n\nVad vill du göra?';
  } else if (hasFailedUploads) {
    dialogTitle = 'Bilduppladdning misslyckades';
    dialogContent =
        '${safetyResult.failedImagePaths.length} bilder kunde inte laddas upp.\n\nVad vill du göra?';
  } else {
    dialogTitle = 'Bilduppladdning pågår';
    dialogContent =
        '${safetyResult.pendingImagePaths.length} bilder laddas fortfarande upp.\n\nVad vill du göra?';
  }

  // Add common actions
  actions.addAll([
    TextButton(
      onPressed: () => Navigator.of(context).pop(UploadChoice.cancel),
      child: const Text('Avbryt'),
    ),
    if (hasPendingUploads)
      TextButton(
        onPressed: () => Navigator.of(context).pop(UploadChoice.wait),
        child: const Text('Vänta på uppladdning'),
      ),
    TextButton(
      onPressed: () =>
          Navigator.of(context).pop(UploadChoice.saveWithoutPending),
      style: TextButton.styleFrom(foregroundColor: AppColors.warning),
      child: Text(hasFailedUploads
          ? 'Spara utan misslyckade bilder'
          : 'Spara utan väntande bilder'),
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
