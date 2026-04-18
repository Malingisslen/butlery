/// Aggregated insights card showing dietary breakdown and top cuisines
/// for the user's recipe collection.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/base/base_service.dart' show StringExtensions;
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Shows dietary distribution and top cuisines for a recipe collection.
///
/// Cuisine keys and display names must be passed in to avoid
/// ServiceLocator access in the build path.
class CollectionInsightsCard extends StatelessWidget {
  const CollectionInsightsCard({
    super.key,
    required this.recipes,
    this.cuisineDisplayNames = const {},
  });

  final List<Recipe> recipes;

  /// Map of cuisine key → display name, provided by the parent view.
  final Map<String, String> cuisineDisplayNames;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: AppDimensions.responsiveContentPadding(context),
      child: ExpansionTile(
        leading: Icon(
          Icons.insights,
          color: colorScheme.primary,
          size: AppDimensions.iconSizeM,
        ),
        title: Text(
          context.l10n.collectionInsightsTitle,
          style: AppTextStyles.labelLarge.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        // Show recipe count when collapsed so users know the accordion
        // has meaningful content before expanding.
        subtitle: Text(
          context.l10n.recipeCountBadge(recipes.length),
          style: AppTextStyles.bodySmall.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
              vertical: AppDimensions.spacingSm,
            ),
            child: recipes.length < 3
                ? _buildInsufficientData(context)
                : _buildStats(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientData(BuildContext context) {
    return Text(
      context.l10n.collectionInsightsInsufficientData,
      style: AppTextStyles.bodyMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    final dietary = _computeDietaryStats(context);
    final topCuisines = _computeTopCuisines();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in dietary)
          _DietaryBar(label: entry.label, fraction: entry.fraction),
        if (topCuisines.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.collectionInsightsTopCuisines,
            style: AppTextStyles.labelMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          for (final cuisine in topCuisines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spacingXxs),
              child: Text(
                '${cuisine.label} (${cuisine.count})',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppDimensions.spacingSm),
      ],
    );
  }

  List<_DietaryStat> _computeDietaryStats(BuildContext context) {
    final total = recipes.length;
    final entries = [
      ('vegetarian', context.l10n.collectionInsightsDietaryVegetarian),
      ('vegan', context.l10n.collectionInsightsDietaryVegan),
      ('pescetarian', context.l10n.collectionInsightsDietaryPescetarian),
    ];

    final stats = <_DietaryStat>[];
    for (final (key, label) in entries) {
      final count = recipes.where((r) {
        final status = r.tagResult?.dietaryStatus[key];
        return status == TriState.free;
      }).length;

      if (count > 0) {
        stats.add(_DietaryStat(label: label, fraction: count / total));
      }
    }
    return stats;
  }

  List<_CuisineStat> _computeTopCuisines() {
    if (cuisineDisplayNames.isEmpty) return [];

    final counts = <String, int>{};
    for (final recipe in recipes) {
      final tags = recipe.tagResult?.tags ?? {};
      for (final tag in tags) {
        if (cuisineDisplayNames.containsKey(tag)) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
    }

    if (counts.isEmpty) return [];

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) {
      final label = cuisineDisplayNames[e.key] ?? e.key;
      return _CuisineStat(label: label.capitalize(), count: e.value);
    }).toList();
  }
}

class _DietaryBar extends StatelessWidget {
  const _DietaryBar({
    required this.label,
    required this.fraction,
  });

  final String label;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (fraction * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$percent% $label',
            style: AppTextStyles.bodySmall.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: fraction,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
            minHeight: 6,
            borderRadius: BorderRadius.zero,
          ),
        ],
      ),
    );
  }
}

class _DietaryStat {
  final String label;
  final double fraction;
  const _DietaryStat({required this.label, required this.fraction});
}

class _CuisineStat {
  final String label;
  final int count;
  const _CuisineStat({required this.label, required this.count});
}
