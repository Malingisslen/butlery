// lib/views/edit_recipe/edit_recipe_image_picker.dart

import 'package:flutter/material.dart';
import '../../viewmodels/recipe_form_viewmodel.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/common/utility_components.dart';

/// Image picker functionality for edit recipe view
class EditRecipeImagePicker {
  
  /// Show image picker modal with camera, gallery, and URL options
  static Future<void> pickImage(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppDimensions.spacingL),
              child: Text(
                'Lägg till bild',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Ta foto'),
              subtitle: const Text('Använd kameran'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Från galleriet'),
              subtitle: Text(
                viewModel.canAddMoreImages
                    ? 'Välj upp till ${RecipeFormViewModel.maxImages - viewModel.imageUrls.length} bilder'
                    : 'Välj en bild från galleriet',
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.link,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: const Text('Lägg till från URL'),
              subtitle: const Text('För bilder från webben'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Avbryt'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'camera':
        await viewModel.pickAndUploadImage(context);
        break;
      case 'gallery':
        if (viewModel.canAddMoreImages && viewModel.imageUrls.length < 4) {
          await viewModel.pickMultipleImages(context);
        } else {
          await viewModel.pickAndUploadImage(context);
        }
        break;
      case 'url':
        await _showUrlDialog(context, viewModel);
        break;
    }
  }

  /// Show URL input dialog for adding images from web
  static Future<void> _showUrlDialog(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lägg till bild från URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Bild-URL',
            hintText: 'https://exempel.com/bild.jpg',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Avbryt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Lägg till'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      if (Uri.tryParse(url) != null &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        viewModel.addImageUrl(url);
      } else {
        if (context.mounted) {
          UtilityComponents.showErrorSnackbar(context, 'Ogiltig URL');
        }
      }
    }
  }
}