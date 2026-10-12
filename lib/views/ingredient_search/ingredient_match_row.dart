import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/badges/match_percent_pill.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

/// One hit in the ingredient search, as Skarmar v12 del 3 #ingredienssok
/// draws it: a thumbnail, the title with its ingredient match
/// count, what is missing under it, and the match as an outlined pill on the right.
class IngredientMatchRow extends StatelessWidget {
  const IngredientMatchRow({
    required this.recipe,
    required this.matchPercent,
    required this.matchedCount,
    required this.totalCount,
    required this.missingNames,
    required this.onTap,
    super.key,
  });

  final Recipe recipe;

  /// 0.0 to 1.0.
  final double matchPercent;
  final int matchedCount;
  final int totalCount;

  /// Names of the ingredients the recipe needs and the search did not name.
  final List<String> missingNames;
  final VoidCallback onTap;

  static const double _thumbnailSize = 78;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final muted = cs.onSurfaceVariant;
    final pct = (matchPercent * 100).round().clamp(0, 100);
    final imageUrl = recipe.displayThumbnailUrl;

    return Semantics(
      button: true,
      label: recipe.title,
      excludeSemantics: true,
      value: l10n.recipeCardPantryMatchA11y(pct),
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.space12,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                    child: SizedBox(
                      width: _thumbnailSize,
                      height: _thumbnailSize,
                      child: ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: imageUrl == null || imageUrl.isEmpty
                            ? null
                            : SimpleImageWidget(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                config: ImageConfig.thumbnail(
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusControl,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: cs.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppDimensions.space4),
                        Text.rich(
                          TextSpan(
                            text: l10n.ingredientMatchCount(
                              matchedCount,
                              totalCount,
                            ),
                            children: [
                              if (recipe.isCollaborative)
                                TextSpan(
                                  text:
                                      ' · ${l10n.ingredientSearchSharedBadge}',
                                  style: AppTextStyles.bodySmallBold.copyWith(
                                    color: context.modeColors.success,
                                  ),
                                ),
                            ],
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: muted,
                          ),
                        ),
                        if (missingNames.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.space8),
                          Text(
                            l10n.ingredientMissing(missingNames.join(', ')),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: muted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  MatchPercentPill(percent: pct),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
