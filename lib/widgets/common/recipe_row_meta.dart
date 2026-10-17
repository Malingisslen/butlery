// lib/widgets/common/recipe_row_meta.dart
//
// The meta line under a recipe's name in a list: the time and, when the
// recipe has a rating, a star and the figure ("180 min · ★ 4,9"). Rows of
// someone else's recipes draw it with RecipeThumb.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/recipe/butlery_betyg_pill.dart'
    show formatRatingComma;

class RecipeRowMeta extends StatelessWidget {
  const RecipeRowMeta({this.minutes, this.rating, this.lead, super.key});

  final int? minutes;
  final double? rating;

  /// Words before the time, such as "delad i går".
  final String? lead;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      if (lead != null) Text(lead!),
      if (minutes != null) Text(context.l10n.recipeRowMinutes(minutes!)),
      if (rating != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ButleryIcon(
              ButleryIcons.star,
              size: AppDimensions.iconSizeXs,
              color: context.modeColors.starGold,
            ),
            const SizedBox(width: AppDimensions.space4),
            Text(formatRatingComma(rating!)),
          ],
        ),
    ];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const Text(' · '),
          parts[i],
        ],
      ],
    );
  }
}
