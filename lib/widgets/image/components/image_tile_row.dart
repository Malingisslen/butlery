// lib/widgets/image/components/image_tile_row.dart
//
// The pictures of a recipe as small tiles in a row (Skarmar v12 'Skriv nytt
// recept'): each picture a rounded square with its remove cross and, on the
// one that heads the recipe, "primär"; a plus tile last while there is room.
// Every form that edits a recipe's pictures draws them here, so none keeps
// a carousel or a grid of its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';
import 'package:butlery/widgets/image/image_components.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

class ImageTileRow extends StatelessWidget {
  const ImageTileRow({
    required this.imageUrls,
    required this.config,
    required this.primaryIndex,
    required this.isAdding,
    required this.onAdd,
    required this.onRemove,
    required this.onSetPrimary,
    required this.onOpen,
    this.uploadStatuses,
    this.onRetryUpload,
    this.onCancelUpload,
    super.key,
  });

  final List<String> imageUrls;
  final ImageConfig config;
  final int primaryIndex;

  /// A picture is being picked or uploaded; the plus tile waits.
  final bool isAdding;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onSetPrimary;
  final ValueChanged<int> onOpen;
  final Map<String, ImageUploadStatus>? uploadStatuses;
  final ValueChanged<String>? onRetryUpload;
  final ValueChanged<String>? onCancelUpload;

  static const double _tile = 96;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: [
        for (var i = 0; i < imageUrls.length; i++)
          _ImageTile(
            key: ValueKey('image-tile-$i'),
            imageUrl: imageUrls[i],
            config: config,
            isPrimary: i == primaryIndex,
            canRemove: config.showEditControls,
            status: uploadStatuses?[imageUrls[i]],
            onTap: () {
              if (config.enableHapticFeedback) HapticFeedback.lightImpact();
              i == primaryIndex ? onOpen(i) : onSetPrimary(i);
            },
            onRemove: () => onRemove(i),
            onRetryUpload: onRetryUpload,
            onCancelUpload: onCancelUpload,
          ),
        if (imageUrls.length < config.maxImages)
          _AddTile(
            isAdding: isAdding,
            onTap: isAdding ? null : onAdd,
          ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.imageUrl,
    required this.config,
    required this.isPrimary,
    required this.canRemove,
    required this.status,
    required this.onTap,
    required this.onRemove,
    required this.onRetryUpload,
    required this.onCancelUpload,
    super.key,
  });

  final String imageUrl;
  final ImageConfig config;
  final bool isPrimary;
  final bool canRemove;
  final ImageUploadStatus? status;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<String>? onRetryUpload;
  final ValueChanged<String>? onCancelUpload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    final uploading =
        status != null && status!.state != ImageUploadState.completed;
    return SizedBox(
      width: ImageTileRow._tile,
      height: ImageTileRow._tile,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: cs.secondaryContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: isPrimary
                    ? context.l10n.a11yPrimaryImageTap
                    : context.l10n.a11ySelectAsPrimary,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
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
              if (uploading)
                UploadProgressWidgets.buildUploadProgressOverlay(
                  status: status!,
                  imageUrl: imageUrl,
                  borderRadius: radius,
                  onRetryUpload: onRetryUpload,
                  onCancelUpload: onCancelUpload,
                ),
              if (isPrimary)
                Positioned(
                  left: AppDimensions.space4,
                  bottom: AppDimensions.space4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusControl,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space4,
                          vertical: AppDimensions.badgePaddingY,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ButleryIcon(
                              ButleryIcons.primary,
                              size: AppDimensions.iconSizeXs,
                              color: cs.onSurface,
                            ),
                            const SizedBox(width: AppDimensions.space4),
                            Text(
                              context.l10n.imagePrimary.toLowerCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (canRemove)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    label: context.l10n.imageRemoveImage,
                    button: true,
                    excludeSemantics: true,
                    child: PressFill(
                      surface: PressSurface.base,
                      child: InkWell(
                        onTap: onRemove,
                        child: SizedBox(
                          width: AppDimensions.minTouchTarget,
                          height: AppDimensions.minTouchTarget,
                          child: Center(
                            child: ButleryIcon(
                              ButleryIcons.x,
                              size: AppDimensions.iconSizeS,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.isAdding, required this.onTap});

  final bool isAdding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    return Semantics(
      label: context.l10n.a11yAddImageSlot,
      button: true,
      enabled: onTap != null,
      liveRegion: isAdding,
      excludeSemantics: true,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ButleryOutlinedBox(
            borderColor: cs.outlineVariant,
            borderRadius: radius,
            width: ImageTileRow._tile,
            height: ImageTileRow._tile,
            child: Center(
              child: isAdding
                  // The plate line, not a spinner.
                  ? const SizedBox(
                      width: AppDimensions.iconSizeL,
                      child: ExcludeSemantics(child: PlateLine()),
                    )
                  : ButleryIcon(
                      ButleryIcons.plus,
                      color: cs.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
