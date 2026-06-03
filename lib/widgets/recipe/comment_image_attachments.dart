// lib/widgets/recipe/comment_image_attachments.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// BUT-1049: renders a comment's image attachments as a horizontal row of
/// square 80x80 cropped thumbnails. Tapping a thumbnail opens a full-screen,
/// pinch-zoomable viewer (no `photo_view` dependency — a plain `Dialog` +
/// `InteractiveViewer` + `PageView`). Square design language: zero-radius
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
            const SizedBox(width: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final url = imageUrls[index];
          return Semantics(
            label: context.l10n.a11yCommentImageThumbnail,
            button: true,
            child: InkWell(
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
                    child: Icon(Icons.broken_image, color: cs.onSurfaceVariant),
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
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _CommentImageViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    );
  }
}

/// Full-screen, swipeable + pinch-zoomable viewer for comment images.
class _CommentImageViewer extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _CommentImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              final url = imageUrls[index];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    cacheKey: FirebaseUrlUtils.stableCacheKey(url),
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: LoadingIndicator(size: 24, strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: AppDimensions.spacingM,
            right: AppDimensions.spacingM,
            child: SafeArea(
              child: IconButton(
                tooltip: context.l10n.a11yCloseImageViewer,
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
