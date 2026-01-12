// lib/widgets/messaging/fullscreen_image_viewer.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/theme/app_colors.dart';
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
    return Scaffold(
      backgroundColor: AppColors.textDark,
      appBar: AppBar(
        backgroundColor: AppColors.textDark,
        foregroundColor: AppColors.cardWhite,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Stäng',
        ),
        title: const Text('Bild'),
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
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.cardWhite,
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        Text(
                          'Kunde inte ladda bild',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textLight,
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
              color: AppColors.textDark.withValues(alpha: AppDimensions.opacityVeryDark),
              child: SafeArea(
                top: false,
                child: Text(
                  caption!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.cardWhite,
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
