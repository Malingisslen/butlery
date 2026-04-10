/// Aggregated insights card showing dietary breakdown and top cuisines
/// for the user's recipe collection.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Shows dietary distribution and top cuisines for a recipe collection.
///
/// States:
/// - 0 recipes: returns SizedBox.shrink (hidden)
/// - 1-2 recipes: shows "add more recipes" message
/// - 3+ recipes: shows dietary bars + top cuisines
class CollectionInsightsCard extends StatelessWidget {
  const CollectionInsightsCard({
    super.key,
    required this.recipes,
  });

  final List<Recipe> recipes;

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
    final dietary = _computeDietaryStats();
    final topCuisines = _computeTopCuisines();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dietary breakdown
        for (final entry in dietary)
          _DietaryBar(
            label: entry.label,
            fraction: entry.fraction,
            percent: entry.percent,
          ),
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

  List<_DietaryStat> _computeDietaryStats() {
    final total = recipes.length;
    final keys = ['vegetarian', 'vegan', 'pescetarian'];
    final labels = ['Vegetariskt', 'Veganskt', 'Pescetarianskt'];

    final stats = <_DietaryStat>[];
    for (var i = 0; i < keys.length; i++) {
      final count = recipes.where((r) {
        final status = r.tagResult?.dietaryStatus[keys[i]];
        return status == TriState.free;
      }).length;

      if (count > 0) {
        final percent = (count * 100 / total).round();
        stats.add(_DietaryStat(
          label: labels[i],
          fraction: count / total,
          percent: percent,
        ));
      }
    }
    return stats;
  }

  List<_CuisineStat> _computeTopCuisines() {
    // Get cuisine keys from config to distinguish cuisine tags from other tags
    final configService = ServiceLocator.get<TagConfigService>();
    final cuisineKeys = configService.configOrNull?.cuisines.enabledEntries
            .map((e) => e.key)
            .toSet() ??
        <String>{};

    if (cuisineKeys.isEmpty) return [];

    final counts = <String, int>{};
    for (final recipe in recipes) {
      final tags = recipe.tagResult?.tags ?? {};
      for (final tag in tags) {
        if (cuisineKeys.contains(tag)) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
    }

    if (counts.isEmpty) return [];

    // Get display names from config
    final cuisineEntries = configService.configOrNull?.cuisines.enabledEntries;

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(3).map((e) {
      final entry = cuisineEntries?.where((c) => c.key == e.key).firstOrNull;
      final label = entry?.getTag('sv') ?? e.key;
      // Capitalize first letter
      final displayLabel = label.isNotEmpty
          ? '${label[0].toUpperCase()}${label.substring(1)}'
          : label;
      return _CuisineStat(label: displayLabel, count: e.value);
    }).toList();
  }
}

class _DietaryBar extends StatelessWidget {
  const _DietaryBar({
    required this.label,
    required this.fraction,
    required this.percent,
  });

  final String label;
  final double fraction;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
  final int percent;

  const _DietaryStat({
    required this.label,
    required this.fraction,
    required this.percent,
  });
}

class _CuisineStat {
  final String label;
  final int count;

  const _CuisineStat({required this.label, required this.count});
}
