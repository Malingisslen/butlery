// lib/views/photo_import/image_preview.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/content_cards/image_preview_card.dart';
import 'package:butlery/widgets/common/buttons/overlay_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Image preview area for the photo import flow.
///
/// Renders one of three states driven by [PhotoImportViewModel]: a loading
/// card while OCR is processing, the chosen image with a remove overlay when
/// an image exists, or an empty placeholder prompting the user to select one.
class ImagePreview extends StatelessWidget {
  final PhotoImportViewModel viewModel;

  const ImagePreview({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.isProcessing) {
      return ImagePreviewCard.loading(
        context: context,
        child: StateWidget.loading(message: context.l10n.importProcessingImage),
      );
    }

    if (viewModel.hasImage) {
      // Calculate adaptive height based on screen size (max 40% of screen height, min 200px)
      final screenHeight = MediaQuery.of(context).size.height;
      final adaptiveHeight = (screenHeight * 0.4).clamp(200.0, 400.0);

      return ImagePreviewCard.loading(
        context: context,
        height: adaptiveHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          child: Stack(
            children: [
              Image.memory(
                viewModel.imageBytes!,
                height: adaptiveHeight,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: AppDimensions.spacingS,
                right: AppDimensions.spacingS,
                child: OverlayButton.remove(
                  onPressed: () => _handleRemove(context),
                  tooltip: context.l10n.importRemoveImage,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ImagePreviewCard.empty(
      context: context,
      child: StateWidget.empty(
        title: context.l10n.importNoImageSelected,
        subtitle: context.l10n.importTapButtonToSelect,
        icon: Icons.add_photo_alternate,
      ),
    );
  }

  /// Removes the photo, but first confirms when the heirloom form holds
  /// user-entered details — clearing the photo also wipes that form (BUT-954
  /// hard-destructive: the typed origin notes are gone and can't be undone).
  Future<void> _handleRemove(BuildContext context) async {
    if (viewModel.hasHeirloomContent) {
      final l10n = context.l10n;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.importHeirloomClearTitle),
          content: Text(l10n.importHeirloomClearMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    viewModel.clearPhoto();
  }
}
