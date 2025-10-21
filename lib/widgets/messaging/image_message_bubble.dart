// lib/widgets/messaging/image_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/messaging/fullscreen_image_viewer.dart';

/// Message bubble widget specifically for displaying image messages.
///
/// Provides rich image display with:
/// - Cached network image loading with placeholder
/// - Loading indicator during download
/// - Error state for failed loads
/// - Tap to view fullscreen
/// - Optional caption below image
/// - Rounded corners matching bubble design
/// - Maintains aspect ratio
///
/// **Usage Example:**
/// ```dart
/// ImageMessageBubble(
///   imageUrl: message.imageUrl,
///   caption: message.content,
///   isCurrentUser: message.senderId == currentUserId,
///   timestamp: message.createdAt,
/// )
/// ```
class ImageMessageBubble extends StatelessWidget {
  final String imageUrl;
  final String? caption;
  final bool isCurrentUser;
  final DateTime timestamp;

  const ImageMessageBubble({
    super.key,
    required this.imageUrl,
    this.caption,
    required this.isCurrentUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isCurrentUser
        ? AppColors.primaryBlue
        : AppColors.cardWhite;

    final textColor = isCurrentUser
        ? AppColors.cardWhite
        : AppColors.textDark;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 180,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with tap to fullscreen
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppDimensions.borderRadiusM),
              bottom: caption != null
                  ? Radius.zero
                  : const Radius.circular(AppDimensions.borderRadiusM),
            ),
            child: GestureDetector(
              onTap: () => _viewFullscreen(context),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppColors.backgroundBeige,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: AppColors.backgroundBeige,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 48,
                          color: AppColors.textLight,
                        ),
                        SizedBox(height: AppDimensions.spacingS),
                        Text(
                          'Kunde inte ladda bild',
                          style: TextStyle(
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

          // Caption and timestamp
          if (caption != null)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null) ...[
                    Text(
                      caption!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                  ],
                  Text(
                    _formatTimestamp(timestamp),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _viewFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrl: imageUrl,
          caption: caption,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
