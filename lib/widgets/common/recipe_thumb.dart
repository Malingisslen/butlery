// lib/widgets/common/recipe_thumb.dart
//
// The small square picture at the start of a recipe row: the recipe's photo,
// or a green-tinted plate when it has none (Skarmar v12 #publikprofil,
// #delat-med-mig). A row of recipes someone else shared or made public draws
// it, so the pictures cannot differ from page to page.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';

class RecipeThumb extends StatelessWidget {
  const RecipeThumb({this.imageUrl, this.dimmed = false, super.key});

  final String? imageUrl;

  /// A recipe that is no longer shared: the plate in the neutral tint.
  final bool dimmed;

  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final plate = ColoredBox(
      color: dimmed
          ? cs.surfaceContainerHighest
          : context.modeColors.surfaceTintSuccess,
    );
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty || dimmed
            ? plate
            : CachedNetworkImage(
                imageUrl: url,
                cacheKey: FirebaseUrlUtils.stableCacheKey(url),
                fit: BoxFit.cover,
                placeholder: (_, _) => plate,
                errorWidget: (_, _, _) => plate,
              ),
      ),
    );
  }
}
