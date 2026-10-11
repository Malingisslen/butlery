// lib/widgets/recipe/comment_image_attachments.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/image/fullscreen_image_viewer.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// BUT-1049: renders a comment's image attachments as a horizontal row of
/// square 80x80 cropped thumbnails. Tapping a thumbnail opens the shared
/// FullscreenImageViewer. Square design language: zero-radius
/// `ClipRRect` rather than rounded corners.
class CommentImageAttachments extends StatelessWidget {
  final List<String> imageUrls;

  const CommentImageAttachments({super.key, required this.imageUrls});

  static const double _thumbnailSize = 80;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: _thumbnailSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppDimensions.space4),
        itemBuilder: (context, index) {
          final url = imageUrls[index];
          return Semantics(
            label: context.l10n.a11yCommentImageThumbnail,
            button: true,
            child: PressScale(
              onTap: () => _openViewer(context, index),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: CachedNetworkImage(
                  imageUrl: url,
                  cacheKey: FirebaseUrlUtils.stableCacheKey(url),
                  width: _thumbnailSize,
                  height: _thumbnailSize,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      ColoredBox(color: cs.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: ButleryIcon(
                      ButleryIcons.imageOff,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    FullscreenImageViewer.open(context, imageUrls, initialIndex: initialIndex);
  }
}
