// lib/widgets/recipe/recipe_image_picker.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles image picker UI and logic for recipe forms.
class RecipeImagePicker {
  static const String _logTag = 'RECIPE_IMAGE_PICKER';

  /// Shows the image picker bottom sheet and handles selection.
  /// Returns the selected choice or null if cancelled.
  static Future<void> showAndPick({
    required BuildContext context,
    required RecipeFormViewModel viewModel,
  }) async {
    AppLogger.info('[$_logTag] _pickImage called');

    final choice = await _showPickerBottomSheet(context, viewModel);

    AppLogger.info('[$_logTag] User choice: $choice');

    if (choice == null || !context.mounted) {
      AppLogger.info('[$_logTag] Choice was null or not mounted, returning');
      return;
    }

    try {
      await _handleChoice(context, viewModel, choice);
    } catch (e) {
      AppLogger.error('[$_logTag] Error during image selection: $e');
      if (context.mounted) {
        UtilityComponents.showErrorSnackbar(
          context,
          context.l10n
              .errorCouldNotLoad(context.l10n.commonImage.toLowerCase()),
        );
      }
    }
  }

  /// Shows the picker bottom sheet and returns the user's choice.
  static Future<String?> _showPickerBottomSheet(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppDimensions.paddingAll16,
              child: Text(
                context.l10n.imageAddImage,
                style: AppTextStyles.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(context.l10n.imageTakePhoto),
              subtitle: Text(context.l10n.imageUseCamera),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(context.l10n.imageFromGallery),
              subtitle: Text(
                viewModel.canAddMoreImages
                    ? context.l10n.imageSelectUpTo(
                        RecipeFormViewModel.maxImages -
                            viewModel.imageUrls.length,
                      )
                    : context.l10n.imageSelectFromGallery,
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(context.l10n.commonCancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles the user's choice and calls the appropriate viewModel method.
  static Future<void> _handleChoice(
    BuildContext context,
    RecipeFormViewModel viewModel,
    String choice,
  ) async {
    switch (choice) {
      case 'camera':
        AppLogger.info('[$_logTag] Calling viewModel.pickImageFromCamera');
        await viewModel.pickImageFromCamera(context);
        break;
      case 'gallery':
        // Use canAddMoreImages and proper limit checking
        if (viewModel.canAddMoreImages &&
            (RecipeFormViewModel.maxImages - viewModel.imageUrls.length) > 1) {
          AppLogger.info(
              '[$_logTag] Calling viewModel.pickMultipleImagesFromGallery');
          await viewModel.pickMultipleImagesFromGallery(context);
        } else {
          AppLogger.info(
              '[$_logTag] Calling viewModel.pickImageFromGallery (single)');
          await viewModel.pickImageFromGallery(context);
        }
        break;
    }
  }
}
