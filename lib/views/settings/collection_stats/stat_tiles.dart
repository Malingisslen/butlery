import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

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
    final tiles = [
      (totalRecipes, l10n.statsTotalRecipes),
      (favorites, l10n.statsFavorites),
      (recentlyCooked, l10n.statsRecentlyCooked),
      (withImages, l10n.statsWithImages),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: _StatTile(value: tiles[i].$1, label: tiles[i].$2),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.space8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: AppTextStyles.headlineBold.copyWith(
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppDimensions.space4),
              Text(
                label,
                style: AppTextStyles.captionBase.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
