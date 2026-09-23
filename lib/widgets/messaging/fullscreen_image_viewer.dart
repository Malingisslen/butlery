// lib/widgets/messaging/fullscreen_image_viewer.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

/// Fullscreen image viewer with pinch-to-zoom and swipe gestures.
/// Provides immersive image viewing experience with:
/// - Pinch to zoom in/out
/// - Pan around zoomed image
/// - Double tap to zoom
/// - Swipe down to dismiss
/// - Dark background for focus
/// - Optional caption display
/// - Close button in app bar
/// **Usage Example:**
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (context) => FullscreenImageViewer(
///       imageUrl: imageUrl,
///       caption: caption,
///     ),
///     fullscreenDialog: true,
///   ),
/// );
/// ```
class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? caption;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // A modal over the photo: X, never a back arrow (Komponentark v1:57,
    // pattern 4). It stands on surface.ink in both modes (primary is ink in
    // both schemes), so the photo is framed dark in light and dark mode
    // alike; onSurface turned paper in dark mode.
    return Scaffold(
      backgroundColor: cs.primary,
      appBar: ButleryTopBar.undersida(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.l10n.commonClose,
        ),
        title: context.l10n.imageTitle,
      ),
      body: Column(
        children: [
          // Image viewer with zoom using InteractiveViewer
          Expanded(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  cacheKey: FirebaseUrlUtils.stableCacheKey(imageUrl),
                  fit: BoxFit.contain,
                  memCacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  // The plate line with what is loading, in paper on ink
                  // (onPrimary is #F5F4ED in both schemes).
                  placeholder: (context, url) => Center(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        textTheme: Theme.of(
                          context,
                        ).textTheme.apply(bodyColor: cs.onPrimary),
                      ),
                      child: PlateLineMessage(
                        message: context.l10n.loadingImage,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: cs.outline,
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        Text(
                          context.l10n.messagingImageLoadError,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Caption at bottom if available
          if (caption != null && caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              color: cs.onSurface.withValues(
                alpha: AppDimensions.opacityVeryDark,
              ),
              child: SafeArea(
                top: false,
                child: Text(
                  caption!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.surfaceContainerHighest,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
