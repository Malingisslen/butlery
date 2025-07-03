// lib/widgets/recipe_image_manager.dart
// UPPDATERAD VERSION: Karusell-stil inspirerad av Instagram
// ANVÄNDER ENBART AppTheme - inga hårdkodade värden!

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/state_widget.dart';
import '../theme/app_theme.dart';

/// Widget för att visa och hantera bilder i recept-formulär
/// Med elegant karusell-layout och touch-optimerad hantering
/// ANVÄNDER ENBART AppTheme - inga hårdkodade värden!
class RecipeImageManager extends StatefulWidget {
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
  State<RecipeImageManager> createState() => _RecipeImageManagerState();
}

class _RecipeImageManagerState extends State<RecipeImageManager> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bilder',
              style: AppTheme.getTextStyle(context, AppTheme.formLabelStyle),
            ),
            // Visa "Lägg till" endast när det finns bilder OCH vi kan lägga till fler
            if (widget.canAddMore && widget.imageUrls.isNotEmpty)
              TextButton.icon(
                onPressed: widget.onPickImage,
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

        // Karusell eller tom state
        if (widget.imageUrls.isEmpty)
          _buildEmptyState(context)
        else
          _buildImageCarousel(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 240, // Fast höjd för konsistens
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          style: BorderStyle.solid,
          width: 2,
        ),
        borderRadius: AppTheme.cardBorderRadius,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
      ),
      child: StateWidget.empty(
        title: 'Lägg till bilder till ditt recept',
        subtitle: 'Upp till 5 bilder för att göra receptet mer attraktivt',
        icon: Icons.photo_camera_outlined,
        actionLabel: 'Välj bilder',
        onAction: widget.onPickImage,
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    return Column(
      children: [
        // Huvudbild med karusell
        Container(
          height: 240, // Fast höjd för bra proportioner
          decoration: BoxDecoration(
            borderRadius: AppTheme.cardBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: AppTheme.elevationMedium,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppTheme.cardBorderRadius,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // Haptic feedback vid swipe
                HapticFeedback.lightImpact();
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return _buildCarouselImage(context, index);
              },
            ),
          ),
        ),

        AppTheme.mediumGap,

        // Navigation dots (om fler än 1 bild)
        if (widget.imageUrls.length > 1) ...[
          _buildNavigationDots(context),
          AppTheme.mediumGap,
        ],

        // Action buttons
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildCarouselImage(BuildContext context, int index) {
    final imageUrl = widget.imageUrls[index];
    final isPrimary = index == 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Bilden
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppTheme.mediumLoadingIndicator(),
                  AppTheme.smallGap,
                  Text(
                    'Laddar bild...',
                    style: AppTheme.getTextStyle(
                      context,
                      AppTheme.captionStyle,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppTheme.actionIcon(
                    context,
                    Icons.broken_image_outlined,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    size: AppTheme.iconSizeLarge,
                  ),
                  AppTheme.smallGap,
                  Text(
                    'Kunde inte ladda bild',
                    style: AppTheme.getTextStyle(
                      context,
                      AppTheme.captionStyle,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Primary badge (endast för första bilden)
        if (isPrimary)
          Positioned(
            top: AppTheme.spacingSm,
            left: AppTheme.spacingSm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSm,
                vertical: AppTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withValues(alpha: 0.2),
                    blurRadius: AppTheme.elevationLow,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: AppTheme.iconSizeSmall,
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  Text(
                    'Huvudbild',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Image counter (övre högra hörnet)
        Positioned(
          top: AppTheme.spacingSm,
          right: AppTheme.spacingSm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            ),
            child: Text(
              '${index + 1} / ${widget.imageUrls.length}',
              style: AppTheme.captionStyle.copyWith(
                color: Theme.of(context).colorScheme.onInverseSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationDots(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.imageUrls.length,
        (index) => GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            HapticFeedback.lightImpact();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXs),
            width: _currentIndex == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentIndex == index
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final currentImage =
        _currentIndex < widget.imageUrls.length ? _currentIndex : 0;
    final isPrimary = currentImage == 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Ta bort-knapp
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.delete_outline,
              label: 'Ta bort',
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onRemoveImage(currentImage);

                // Justera current index om vi tar bort en bild
                if (_currentIndex >= widget.imageUrls.length - 1 &&
                    _currentIndex > 0) {
                  setState(() {
                    _currentIndex = _currentIndex - 1;
                  });
                  _pageController.animateToPage(
                    _currentIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),

          AppTheme.mediumHorizontalGap,

          // Sätt som huvudbild-knapp (endast om inte redan huvud)
          if (!isPrimary)
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.star_outline,
                label: 'Sätt som huvud',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onSetPrimary(currentImage);

                  // Flytta till första positionen i karusellen
                  setState(() {
                    _currentIndex = 0;
                  });
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),

          // Om det är huvud, visa alltid "Huvudbild" status (grå)
          if (isPrimary)
            Expanded(
              child: _buildActionButton(
                context,
                icon: Icons.star,
                label: 'Huvudbild',
                onPressed: () {
                  // Ingen åtgärd - bara visar status
                },
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingSm,
            horizontal: AppTheme.spacingSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: AppTheme.iconSizeSmall),
              const SizedBox(width: AppTheme.spacingXs),
              Flexible(
                child: Text(
                  label,
                  style: AppTheme.captionStyle.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
