/// Image Grid Widgets - Grid layout components for multiple images.
/// Extracted from editable_image_widget.dart for better organization.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_shadows.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/core/utils/logger.dart';

/// Provides grid layout components for displaying multiple images.
class ImageGridWidgets {
  /// Build adaptive grid layout for multiple images
  static Widget buildMultiImageGrid({
    required List<String> imageUrls,
    required ImageConfig config,
    required int primaryIndex,
    required bool isLoading,
    required bool isAddingImage,
    required Function(int) onPrimaryImageChanged,
    required Function(int) onImageTap,
    required Function(int) onRemoveImage,
    required VoidCallback onAddImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppDimensions.spacingSm,
            mainAxisSpacing: AppDimensions.spacingSm,
            childAspectRatio: 1.2,
          ),
          itemCount: imageUrls.length,
          itemBuilder: (context, index) {
            return buildGridImageItem(
              context: context,
              index: index,
              imageUrl: imageUrls[index],
              config: config,
              isPrimary: index == primaryIndex,
              showEditControls: config.showEditControls,
              onPrimaryImageChanged: onPrimaryImageChanged,
              onImageTap: onImageTap,
              onRemoveImage: onRemoveImage,
            );
          },
        ),
        if (imageUrls.length < config.maxImages) ...[
          const SizedBox(height: AppDimensions.spacingSm),
          buildAddImageButton(
            config: config,
            remainingSlots: config.maxImages - imageUrls.length,
            isLoading: isLoading || isAddingImage,
            onAddImage: onAddImage,
          ),
        ],
      ],
    );
  }

  /// Build individual image item for grid layout
  static Widget buildGridImageItem({
    required BuildContext context,
    required int index,
    required String imageUrl,
    required ImageConfig config,
    required bool isPrimary,
    required bool showEditControls,
    required Function(int) onPrimaryImageChanged,
    required Function(int) onImageTap,
    required Function(int) onRemoveImage,
  }) {
    return Semantics(
      label: isPrimary
          ? context.l10n.a11yPrimaryImageTap
          : context.l10n.a11ySelectAsPrimary,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppLogger.debug(
              '👆 TOUCH: Image $index tapped! isPrimary: $isPrimary');

          if (config.enableHapticFeedback) {
            HapticFeedback.lightImpact();
          }

          if (!isPrimary) {
            AppLogger.debug('🌟 GRID: Setting primary at index $index');
            onPrimaryImageChanged(index);
          } else {
            AppLogger.debug(
                '🌟 GRID: Primary image tapped - calling onImageTap');
            onImageTap(index);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: config.effectiveBorderRadius,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: isPrimary
                        ? AppDimensions.borderWidthThick * 2
                        : AppDimensions.borderWidthStandard,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: config.effectiveBorderRadius,
                  child: ImageComponents.buildAdaptiveImage(
                    pathOrUrl: imageUrl,
                    config: config,
                    fit: BoxFit.cover,
                    placeholder: ImageComponents.buildLoadingPlaceholder(
                      config: config,
                    ),
                    errorWidget: ImageComponents.buildErrorPlaceholder(
                      config: config,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: AppDimensions.spacingXs,
              left: AppDimensions.spacingXs,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingXs,
                    vertical: AppDimensions.spacingXxs,
                  ),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Theme.of(context).primaryColor
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: AppDimensions.opacityMediumDark),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusS),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPrimary ? Icons.star : Icons.star_outline,
                        size: AppDimensions.iconSizeXs,
                        color: AppColors.cardWhite,
                      ),
                      if (isPrimary) ...[
                        const SizedBox(width: AppDimensions.spacingXxs),
                        Text(
                          context.l10n.imagePrimary,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.cardWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (showEditControls)
              Positioned(
                bottom: AppDimensions.spacingXs,
                right: AppDimensions.spacingXs,
                child: Semantics(
                  label: context.l10n.a11yRemoveImage,
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      AppLogger.debug(
                          '🗑️ DELETE: Delete button tapped for image $index');
                      onRemoveImage(index);
                    },
                    child: buildGridActionButton(
                      icon: Icons.close,
                      tooltip: context.l10n.imageRemoveImage,
                      isDestructive: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build action button for grid layout
  static Widget buildGridActionButton({
    required IconData icon,
    required String tooltip,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: AppDimensions.iconSizeAction,
        height: AppDimensions.iconSizeAction,
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.error : AppColors.cardWhite,
          shape: BoxShape.circle,
          boxShadow: AppShadows.subtle,
        ),
        child: Icon(
          icon,
          size: AppDimensions.iconSizeS,
          color: isDestructive ? AppColors.cardWhite : AppColors.textDark,
        ),
      ),
    );
  }

  /// Build add image button for grid layout
  static Widget buildAddImageButton({
    required ImageConfig config,
    required int remainingSlots,
    required bool isLoading,
    required VoidCallback onAddImage,
  }) {
    return Builder(
      builder: (context) => Semantics(
        label: context.l10n.a11yAddImage,
        button: true,
        enabled: !isLoading,
        child: GestureDetector(
          onTap: isLoading ? null : onAddImage,
          child: Container(
            height: AppDimensions.buttonHeight,
            decoration: BoxDecoration(
              borderRadius: config.effectiveBorderRadius,
              border: Border.all(
                color: AppColors.forestGreen
                    .withValues(alpha: AppDimensions.opacityMediumLight),
                width: AppDimensions.borderWidthThin,
              ),
              color: AppColors.forestGreen
                  .withValues(alpha: AppDimensions.opacityExtraVeryLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  const SizedBox(
                    width: AppDimensions.iconSizeM,
                    height: AppDimensions.iconSizeM,
                    child: CircularProgressIndicator(
                      strokeWidth: AppDimensions.borderWidthThin,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.forestGreen),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Flexible(
                    child: Text(
                      context.l10n.imageAdding,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.forestGreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.forestGreen,
                    size: AppDimensions.iconSizeM,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Flexible(
                    child: Text(
                      context.l10n.imageAddCount(remainingSlots),
                      style: AppTextStyles.contentLabel.copyWith(
                        color: AppColors.forestGreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
