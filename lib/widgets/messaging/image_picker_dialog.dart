// lib/widgets/messaging/image_picker_dialog.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Bottom sheet dialog for selecting image source (camera or gallery).
/// Provides a clean, modern interface for image source selection with:
/// - Camera option with icon
/// - Gallery option with icon
/// - Cancel button
/// - Swedish localization
/// **Usage Example:**
/// ```dart
/// final source = await showImagePickerDialog(context);
/// if (source != null) {
///   // User selected a source
///   final image = await ImagePicker().pickImage(source: source);
/// }
/// ```
class ImagePickerDialog extends StatelessWidget {
  const ImagePickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.paddingL,
            horizontal: AppDimensions.paddingM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                context.l10n.imageSelectImage,
                style: AppTextStyles.titleBold,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spacingXl),

              // Camera option
              _SourceOption(
                icon: Icons.camera_alt,
                label: context.l10n.commonTakePhoto,
                color: cs.primary,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),

              const SizedBox(height: AppDimensions.spacingM),

              // Gallery option
              _SourceOption(
                icon: Icons.photo_library,
                label: context.l10n.commonSelectFromGallery,
                color: context.butleryColors.success,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),

              const SizedBox(height: AppDimensions.spacingXl),

              // Cancel button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.paddingM,
                  ),
                ),
                child: Text(context.l10n.commonCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual source option widget.
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: AppDimensions.opacityVeryLight),
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    size: AppDimensions.iconSizeL,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                Text(
                  label,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: color,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: AppDimensions.iconSizeS,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Show image picker dialog as bottom sheet.
/// Returns selected [ImageSource] or null if cancelled.
Future<ImageSource?> showImagePickerDialog(BuildContext context) async {
  return await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const ImagePickerDialog(),
  );
}
