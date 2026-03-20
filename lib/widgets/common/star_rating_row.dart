// lib/widgets/common/star_rating_row.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Shared star rating row supporting display-only and interactive modes.
///
/// Used by recipe detail metadata and menu rating section.
class StarRatingRow extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<double>? onRatingChanged;
  final String Function(int starValue)? semanticsLabel;

  const StarRatingRow({
    super.key,
    required this.rating,
    this.size = AppDimensions.iconSizeL,
    this.interactive = false,
    this.onRatingChanged,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final starColor = context.butleryColors.starGold;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= rating;
        final isHalf = !isFilled && starValue - 0.5 <= rating;

        final star = Icon(
          isFilled
              ? Icons.star
              : isHalf
                  ? Icons.star_half
                  : Icons.star_border,
          color: isFilled || isHalf ? starColor : cs.onSurfaceVariant,
          size: size,
        );

        if (!interactive || onRatingChanged == null) return star;

        Widget tappableStar = GestureDetector(
          onTap: () => onRatingChanged!(starValue.toDouble()),
          child: star,
        );

        if (semanticsLabel != null) {
          tappableStar = Semantics(
            label: semanticsLabel!(starValue),
            child: tappableStar,
          );
        }

        return tappableStar;
      }),
    );
  }
}
