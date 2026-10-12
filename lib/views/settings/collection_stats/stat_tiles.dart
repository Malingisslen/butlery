import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';

/// The four figures on the ink band at the top of Min samling, two by two.
class StatTiles extends StatelessWidget {
  const StatTiles({
    required this.totalRecipes,
    required this.favorites,
    required this.recentlyCooked,
    required this.withImages,
    super.key,
  });

  final int totalRecipes;
  final int favorites;
  final int recentlyCooked;
  final int withImages;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tiles = [
      (totalRecipes, l10n.statsTotalRecipes),
      (favorites, l10n.statsFavorites),
      (recentlyCooked, l10n.statsRecentlyCooked),
      (withImages, l10n.statsWithImages),
    ];
    return ColoredBox(
      color: cs.primary,
      child: Padding(
        padding: ButleryPageBody.margin(
          context,
          top: AppDimensions.space24,
          bottom: AppDimensions.space24,
        ),
        child: Column(
          children: [
            for (var row = 0; row < tiles.length; row += 2) ...[
              if (row > 0) const SizedBox(height: AppDimensions.space24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppDimensions.space12,
                      ),
                      child: _StatTile(
                        value: tiles[row].$1,
                        label: tiles[row].$2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _StatTile(
                      value: tiles[row + 1].$1,
                      label: tiles[row + 1].$2,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppTextStyles.headlineBold.copyWith(
              color: cs.onPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onPrimary),
          ),
        ],
      ),
    );
  }
}
