// lib/widgets/recipe/heirloom_section.dart
//
// BUT-410: side-by-side / stacked scan + parsed detail for heirloom recipes.
// Mobile → image block stacked above the parsed text (swipe/scroll naturally).
// Tablet → the image block is laid out inside the recipe_detail_tablet_content
// left column by the caller, so this widget is layout-agnostic.
//
// Tapping the scan opens it fullscreen via the shared FullscreenImageViewer.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';
import 'package:butlery/widgets/recipe/heirloom_stamp.dart';

/// Section rendering the original heirloom scan with a rust corner stamp.
///
/// Always returns a compact [AspectRatio] block — pass [maxHeight] to cap
/// vertical room on larger screens (tablet two-column). Tap opens the image
/// fullscreen; an optional [note] line appears below the image when present.
class HeirloomSection extends StatelessWidget {
  final HeirloomMetadata heirloom;

  /// Cap on the image block's height — useful for tablet columns where
  /// we don't want the scan to dwarf the parsed text.
  final double? maxHeight;

  const HeirloomSection({
    super.key,
    required this.heirloom,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = heirloom.sourceImageUrl;

    final imageBlock = ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: AppColors.cream,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                cacheKey: FirebaseUrlUtils.stableCacheKey(imageUrl),
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textOnCream),
                ),
              ),
            ),
            HeirloomStamp(heirloom: heirloom),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openFullscreen(context, imageUrl),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final note = heirloom.note;
    if (note == null || note.isEmpty) return imageBlock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        imageBlock,
        const SizedBox(height: AppDimensions.spacingS),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
          child: Text(
            note,
            style: const TextStyle(
              color: AppColors.textOnCream,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _openFullscreen(BuildContext context, String imageUrl) {
    RecipeDetailSharedWidgets.showFullscreenImage(context, [imageUrl], 0);
  }
}
