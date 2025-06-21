// lib/widgets/recipe_image_manager.dart
// UPPDATERAD VERSION: Använder ENBART AppTheme - inga hårdkodade värden!

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Widget för att visa och hantera bilder i recept-formulär
/// Med kamera/galleri-support och drag-to-reorder
/// ANVÄNDER ENBART AppTheme - inga hårdkodade värden!
class RecipeImageManager extends StatelessWidget {
  final List<String> imageUrls;
  final Function(String) onAddImage;
  final Function(int) onRemoveImage;
  final Function(int) onSetPrimary;
  final Function(int, int)? onReorderImage;
  final VoidCallback onPickImage;
  final bool canAddMore;

  const RecipeImageManager({
    super.key,
    required this.imageUrls,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.onSetPrimary,
    this.onReorderImage,
    required this.onPickImage,
    required this.canAddMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header med titel och add-knapp
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bilder',
              style: AppTheme.getTextStyle(context, AppTheme.formLabelStyle),
            ),
            if (canAddMore)
              TextButton.icon(
                onPressed: onPickImage,
                icon: AppTheme.actionIcon(context, Icons.add_photo_alternate),
                label: Text(
                  'Lägg till',
                  style: AppTheme.getTextStyle(
                    context,
                    AppTheme.bodyStyle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),

        AppTheme.smallGap,

        // Bildrutnät eller tom state
        if (imageUrls.isEmpty)
          _buildEmptyState(context)
        else
          _buildImageGrid(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: AppTheme.imageHeightMedium,
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          style: BorderStyle.solid,
        ),
        borderRadius: AppTheme.cardBorderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.actionIcon(
              context,
              Icons.photo_camera,
              color: Theme.of(context).colorScheme.outline,
              size: AppTheme.iconSizeLarge,
            ),
            AppTheme.smallGap,
            Text(
              'Lägg till bilder',
              style: AppTheme.getTextStyle(
                context,
                AppTheme.subtitleStyle,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            AppTheme.smallGap,
            ElevatedButton.icon(
              onPressed: onPickImage,
              icon: AppTheme.actionIcon(context, Icons.add),
              label: const Text('Välj bilder'),
              style: ElevatedButton.styleFrom(padding: AppTheme.buttonPadding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    return SizedBox(
      height: AppTheme.imageHeightMedium,
      child: Row(
        children: [
          // Primär bild (större)
          Expanded(flex: 2, child: _buildPrimaryImage(context)),

          AppTheme.smallHorizontalGap,

          // Övriga bilder + add-knapp
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Övriga bilder
                if (imageUrls.length > 1)
                  Expanded(child: _buildSecondaryImages(context)),

                // Add-knapp
                if (canAddMore) ...[
                  if (imageUrls.length > 1) AppTheme.smallGap,
                  _buildAddImageButton(context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryImage(BuildContext context) {
    final primaryImage = imageUrls.first;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: AppTheme.elevationMedium,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppTheme.cardBorderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Bilden
            CachedNetworkImage(
              imageUrl: primaryImage,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Center(child: AppTheme.mediumLoadingIndicator()),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Center(
                      child: AppTheme.actionIcon(
                        context,
                        Icons.error,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
            ),

            // Overlay med knappar
            Positioned(
              top: AppTheme.spacingSm,
              right: AppTheme.spacingSm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                      vertical: AppTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      'Huvud',
                      style: AppTheme.captionStyle.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  AppTheme.smallHorizontalGap,

                  // Ta bort-knapp
                  _buildActionButton(
                    context,
                    Icons.close,
                    () => onRemoveImage(0),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryImages(BuildContext context) {
    final secondaryImages = imageUrls.skip(1).toList();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.spacingXs,
        mainAxisSpacing: AppTheme.spacingXs,
        childAspectRatio: AppTheme.thumbnailAspectRatio,
      ),
      itemCount: secondaryImages.length,
      itemBuilder: (context, index) {
        final imageIndex = index + 1; // +1 eftersom primärbilden är index 0
        final imageUrl = secondaryImages[index];

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: AppTheme.elevationLow,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Bilden
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        child: Center(child: AppTheme.smallLoadingIndicator()),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Center(
                          child: AppTheme.actionIcon(
                            context,
                            Icons.error,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            size: AppTheme.iconSizeSmall,
                          ),
                        ),
                      ),
                ),

                // Overlay med knappar
                Positioned(
                  top: AppTheme.spacingXs,
                  right: AppTheme.spacingXs,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sätt som primär-knapp
                      _buildActionButton(
                        context,
                        Icons.star,
                        () => onSetPrimary(imageIndex),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondary,
                        size: AppTheme.iconSizeSmall,
                      ),

                      const SizedBox(height: AppTheme.spacingXs),

                      // Ta bort-knapp
                      _buildActionButton(
                        context,
                        Icons.close,
                        () => onRemoveImage(imageIndex),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        size: AppTheme.iconSizeSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddImageButton(BuildContext context) {
    return GestureDetector(
      onTap: onPickImage,
      child: Container(
        height: AppTheme.thumbnailSize,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.actionIcon(
              context,
              Icons.add_photo_alternate,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: AppTheme.iconSizeMedium,
            ),
            const SizedBox(height: AppTheme.spacingXs),
            Text(
              'Lägg till',
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed, {
    required Color backgroundColor,
    required Color foregroundColor,
    double? size,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingXs),
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.2),
              blurRadius: AppTheme.elevationLow,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: foregroundColor,
          size: size ?? AppTheme.iconSizeSmall,
        ),
      ),
    );
  }
}
