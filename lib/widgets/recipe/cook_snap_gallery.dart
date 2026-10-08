/// Horizontal gallery of cooking photos posted on a recipe.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/recipe/cook_snap_photo_carousel.dart';

/// Displays cook snaps in a horizontal scrollable gallery.
///
/// Shows loading/empty/error states via StateWidget.
/// Square thumbnails with author name and relative time below.
class CookSnapGallery extends StatelessWidget {
  const CookSnapGallery({
    super.key,
    required this.snaps,
    required this.isLoading,
    required this.isUploading,
    required this.onAdd,
    required this.onDelete,
    required this.onReport,
    required this.currentUserId,
    this.error,
  });

  final List<CookSnap> snaps;
  final bool isLoading;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(String snapId) onDelete;
  final void Function(CookSnap snap) onReport;
  final String? currentUserId;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  snaps.isEmpty
                      ? context.l10n.cookSnapSectionTitle
                      : context.l10n.cookSnapSectionTitleCount(snaps.length),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (isUploading)
                SizedBox(
                  width: AppDimensions.minTouchTarget,
                  child: PlateLine(
                    semanticLabel: context.l10n.uploadingCookSnap,
                  ),
                )
              else
                IconButton(
                  icon: const ButleryIcon(ButleryIcons.camera),
                  tooltip: context.l10n.cookSnapAddTooltip,
                  onPressed: onAdd,
                  iconSize: AppDimensions.iconSizeM,
                ),
            ],
          ),
        ),

        // Content
        if (isLoading && snaps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spacingMd,
              horizontal: AppDimensions.spacingLg,
            ),
            child: PlateLine(semanticLabel: context.l10n.loadingCookSnaps),
          )
        else if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
            ),
            child: StateWidget.error(message: error!),
          )
        else if (snaps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingSm,
            ),
            child: StateWidget.empty(
              icon: ButleryIcons.camera,
              title: context.l10n.cookSnapEmptyTitle,
              subtitle: context.l10n.cookSnapEmptySubtitle,
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingLg,
              ),
              itemCount: snaps.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.spacingSm),
              itemBuilder: (context, index) => _SnapThumbnail(
                snap: snaps[index],
                isOwn: snaps[index].userId == currentUserId,
                onDelete: () => onDelete(snaps[index].id),
                onReport: () => onReport(snaps[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class _SnapThumbnail extends StatelessWidget {
  const _SnapThumbnail({
    required this.snap,
    required this.isOwn,
    required this.onDelete,
    required this.onReport,
  });

  final CookSnap snap;
  final bool isOwn;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = snap.thumbnailUrl ?? snap.photoUrl;

    final actorName = isOwn ? context.l10n.cookSnapMe : snap.userDisplayName;
    return Semantics(
      label: context.l10n.a11yCookSnapOptions(actorName),
      button: true,
      child: GestureDetector(
        // Tap opens the album full-screen; long-press keeps the
        // delete/report options sheet (BUT-949).
        onTap: () => CookSnapPhotoCarousel.openFullScreen(
          context,
          snap.photoUrls,
        ),
        onLongPress: () => _showOptions(context),
        child: SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        cacheKey: FirebaseUrlUtils.stableCacheKey(imageUrl),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                          child: ButleryIcon(
                            ButleryIcons.imageOff,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    if (snap.hasMultiplePhotos)
                      Positioned(
                        top: AppDimensions.spacingXs,
                        right: AppDimensions.spacingXs,
                        child: _PhotoCountBadge(count: snap.photoUrls.length),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                actorName,
                style: AppTextStyles.labelSmall.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                ContextualTimeFormatter.compact(snap.createdAt),
                style: AppTextStyles.labelSmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn)
              ListTile(
                leading: ButleryIcon(
                  ButleryIcons.trash2,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(context.l10n.cookSnapDelete),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              )
            else
              ListTile(
                leading: const ButleryIcon(Icons.flag),
                title: Text(context.l10n.cookSnapReport),
                onTap: () {
                  Navigator.pop(context);
                  onReport();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// BUT-949: small overlay badge marking a multi-photo album thumbnail, drawn
/// as a translucent paper tile (overlay.paperCard) with ink text (B83-3).
class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: context.modeColors.overlayPaperCard,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButleryIcon(ButleryIcons.image, size: 12, color: ink),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
