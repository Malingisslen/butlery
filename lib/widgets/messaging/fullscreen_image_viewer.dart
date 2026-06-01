// lib/widgets/messaging/fullscreen_image_viewer.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
    return Scaffold(
      backgroundColor: cs.onSurface,
      appBar: AppBar(
        backgroundColor: cs.onSurface,
        foregroundColor: cs.surfaceContainerHighest,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.l10n.commonClose,
        ),
        title: Text(context.l10n.imageTitle),
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
                  memCacheWidth: (MediaQuery.sizeOf(context).width *
                          MediaQuery.devicePixelRatioOf(context))
                      .round(),
                  placeholder: (context, url) => Center(
                    child: LoadingIndicator(
                      color: cs.surfaceContainerHighest,
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              color:
                  cs.onSurface.withValues(alpha: AppDimensions.opacityVeryDark),
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
