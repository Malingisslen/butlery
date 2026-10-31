// lib/views/recipe_detail/borrowed_image_frame.dart
//
// A photo shown from the recipe's web page rather than taken by the user. The
// paper edge and the credit pill set it apart from the user's own photos,
// which run edge to edge, so nobody reads it as theirs.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/borrowed_image.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Draws [child] framed and credited when [imageUrl] is borrowed from
/// [sourceUrl], and unchanged otherwise.
class BorrowedImageFrame extends StatelessWidget {
  const BorrowedImageFrame({
    super.key,
    required this.imageUrl,
    required this.sourceUrl,
    required this.child,
  });

  static const double edge = 6;

  final String imageUrl;
  final String? sourceUrl;

  /// The photo, with its own tap and semantics.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isBorrowedImage(imageUrl: imageUrl, sourceUrl: sourceUrl)) {
      return child;
    }
    final site = sourceSiteName(sourceUrl)!;
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(edge),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
              child: child,
            ),
            // A sibling of the photo, not inside it: the credit is its own
            // screen-reader node, separate from "open the photo full screen".
            PositionedDirectional(
              start: AppDimensions.space8,
              end: AppDimensions.space8,
              bottom: AppDimensions.space8,
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: BorrowedImageCredit(site: site),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BorrowedImageCredit extends StatelessWidget {
  const BorrowedImageCredit({super.key, required this.site});

  /// The credit for a gallery of [imageUrls], or null when none of them is
  /// borrowed from [sourceUrl].
  static BorrowedImageCredit? forGallery({
    required List<String> imageUrls,
    required String? sourceUrl,
  }) {
    final borrowed = imageUrls.any(
      (url) => isBorrowedImage(imageUrl: url, sourceUrl: sourceUrl),
    );
    return borrowed
        ? BorrowedImageCredit(site: sourceSiteName(sourceUrl)!)
        : null;
  }

  final String site;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.a11yRecipeBorrowedImageCredit(site),
      excludeSemantics: true,
      // Opaque, so the text keeps its contrast on any photo.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space8,
            vertical: AppDimensions.space4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryIcon(
                ButleryIcons.image,
                size: AppDimensions.iconSizeS,
                color: cs.onSurface,
              ),
              const SizedBox(width: AppDimensions.space4),
              Flexible(
                child: Text(
                  context.l10n.recipeBorrowedImageCredit(site),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurface,
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
