/// The small square picture that stands before a dish in a list row.
///
/// One size and one radius for every list that shows a dish (the week menu's
/// list, Hem's week), so the picture never has to be drawn again per view. A
/// dish with no photo is a bare tonal square, as drawn.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/recipe_image_widget.dart';

class RecipeThumbnail extends StatelessWidget {
  const RecipeThumbnail({
    super.key,
    this.imageUrls = const [],
    this.size = AppDimensions.space32 + AppDimensions.space4,
  });

  final List<String> imageUrls;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.radiusControl);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(
          dimension: size,
          child: imageUrls.isEmpty
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                )
              : RecipeImageWidget.card(
                  imageUrls: imageUrls,
                  showMultipleIndicator: false,
                  customWidth: size,
                  customHeight: size,
                  borderRadius: radius,
                ),
        ),
      ),
    );
  }
}
