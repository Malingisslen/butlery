// lib/widgets/common/star_rating_row.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/tappable_wrapper.dart';

/// Shared star rating row supporting display-only and interactive modes.
///
/// Interactive when [onRatingChanged] is provided; display-only otherwise.
/// Used by recipe detail metadata and menu rating section.
class StarRatingRow extends StatelessWidget {
  final double rating;
  final double size;
  final ValueChanged<double>? onRatingChanged;
  final String Function(int starValue)? semanticsLabel;

  /// Width and height of each star's cell. Null packs the stars tight; a
  /// value spreads them out so each is a full touch target, as the family
  /// rating screen draws them.
  final double? slot;

  /// Draw an unrated star as the same solid star in the muted colour, not as
  /// an outline.
  final bool solidEmpty;

  const StarRatingRow({
    super.key,
    required this.rating,
    this.size = AppDimensions.iconSizeL,
    this.onRatingChanged,
    this.semanticsLabel,
    this.slot,
    this.solidEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final starColor = context.modeColors.starGold;
    final interactive = onRatingChanged != null;

    // One group of five. Read-only, it is a single value; interactive, each
    // star is a button and the one matching the rating is selected.
    return Semantics(
      container: true,
      explicitChildNodes: interactive,
      value: interactive ? null : _ratingValue(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starValue = index + 1;
          final isFilled = starValue <= rating;
          final isHalf = !isFilled && starValue - 0.5 <= rating;

          final icon = ButleryIcon(
            isFilled
                ? ButleryIcons.star
                : isHalf
                ? ButleryIcons.starHalf
                : solidEmpty
                ? ButleryIcons.star
                : ButleryIcons.starOutline,
            color: isFilled || isHalf ? starColor : cs.onSurfaceVariant,
            size: size,
          );
          final star = slot == null
              ? icon
              : SizedBox(
                  width: slot,
                  height: slot,
                  child: Center(child: icon),
                );

          if (!interactive) return ExcludeSemantics(child: star);

          final label = semanticsLabel != null
              ? semanticsLabel!(starValue)
              : context.l10n.a11yRateStars(starValue);
          return TappableWrapper(
            onTap: () => onRatingChanged!(starValue.toDouble()),
            semanticLabel: label,
            selected: rating > 0 && starValue == rating.round(),
            child: star,
          );
        }),
      ),
    );
  }

  String _ratingValue() =>
      rating % 1 == 0 ? rating.toInt().toString() : rating.toStringAsFixed(1);
}
