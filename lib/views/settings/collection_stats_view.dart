import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';

class CollectionStatsView extends StatefulWidget {
  const CollectionStatsView({super.key});

  @override
  State<CollectionStatsView> createState() => _CollectionStatsViewState();
}

class _CollectionStatsViewState extends State<CollectionStatsView> {
  late final RecipeQueryViewModel _vm;

  @override
  void initState() {
    super.initState();
    // Not registered in DI — lightweight query projection, safe to own and dispose here
    _vm = RecipeQueryViewModel();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RecipeQueryViewModel>.value(
      value: _vm,
      child: const _CollectionStatsContent(),
    );
  }
}

class _CollectionStatsContent extends StatelessWidget {
  const _CollectionStatsContent();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<RecipeQueryViewModel>();
    final insights = vm.recipeInsights;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.statsMyStatistics),
        centerTitle: true,
      ),
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.paddingM,
              ),
              children: [
                _HeroBanner(
                  totalRecipes: insights['totalRecipes'] as int,
                  favorites: insights['markedFavoriteCount'] as int,
                  recentlyCooked: insights['recentlyCookedCount'] as int,
                  withImages: insights['withImagesCount'] as int,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                _SectionHeader(title: context.l10n.statsRecipeCollection),
                _RecipeBreakdown(
                  personal: insights['personalRecipes'] as int,
                  collaborative: insights['collaborativeRecipes'] as int,
                  highRated: insights['highRatedCount'] as int,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
                _SectionHeader(title: context.l10n.statsMealTypes),
                _MealTypeChart(entries: vm.getMostUsedMealTypes()),
                const SizedBox(height: AppDimensions.spacingXl),
                _SectionHeader(title: context.l10n.statsPopularTags),
                _TopTags(entries: vm.getMostUsedTags()),
                const SizedBox(height: AppDimensions.spacingXl),
                _SectionHeader(title: context.l10n.statsCookingActivity),
                _CookingSummary(
                  totalCooks: insights['totalCooks'] as int,
                  mealTypes: insights['mealTypes'] as int,
                  tags: insights['tags'] as int,
                ),
                const SizedBox(height: AppDimensions.spacingXl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int totalRecipes;
  final int favorites;
  final int recentlyCooked;
  final int withImages;

  const _HeroBanner({
    required this.totalRecipes,
    required this.favorites,
    required this.recentlyCooked,
    required this.withImages,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      color: cs.primary,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.menu_book,
                  value: totalRecipes,
                  label: context.l10n.statsTotalRecipes,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite,
                  value: favorites,
                  label: context.l10n.statsFavorites,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department,
                  value: recentlyCooked,
                  label: context.l10n.statsRecentlyCooked,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: _StatCard(
                  icon: Icons.camera_alt,
                  value: withImages,
                  label: context.l10n.statsWithImages,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: cs.surface, size: AppDimensions.iconSizeM),
        const SizedBox(height: AppDimensions.spacingXs),
        Text(
          '$value',
          style: AppTextStyles.headlineBold.copyWith(color: cs.surface),
        ),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: cs.surface.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.sectionLabel,
      ),
    );
  }
}

class _RecipeBreakdown extends StatelessWidget {
  final int personal;
  final int collaborative;
  final int highRated;

  const _RecipeBreakdown({
    required this.personal,
    required this.collaborative,
    required this.highRated,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Column(
        children: [
          _StatRow(
            label: context.l10n.statsPersonalRecipes,
            value: personal,
          ),
          _StatRow(
            label: context.l10n.statsCollaborativeRecipes,
            value: collaborative,
          ),
          _StatRow(
            label: context.l10n.statsHighRated,
            value: highRated,
          ),
        ],
      ),
    );
  }
}

class _MealTypeChart extends StatelessWidget {
  final List<MapEntry<String, int>> entries;

  const _MealTypeChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final top = entries.take(6).toList();

    if (top.isEmpty) {
      return StateWidget.empty(title: context.l10n.statsNoMealTypes);
    }

    final maxValue = top.first.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barMaxWidth = constraints.maxWidth * 0.6;

          return Column(
            children: top.map((entry) {
              final barWidth =
                  maxValue > 0 ? (entry.value / maxValue) * barMaxWidth : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spacingXs,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: constraints.maxWidth * 0.25,
                      child: Text(
                        entry.key,
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Container(
                      width: barWidth,
                      height: AppDimensions.spacingMd + AppDimensions.spacingXs,
                      color: cs.primary.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Text(
                      '${entry.value}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _TopTags extends StatelessWidget {
  final List<MapEntry<String, int>> entries;

  const _TopTags({required this.entries});

  @override
  Widget build(BuildContext context) {
    final top = entries.take(8).toList();

    if (top.isEmpty) {
      return StateWidget.empty(title: context.l10n.statsNoTags);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Column(
        children: List.generate(top.length, (i) {
          return _StatRow(
            label: '${i + 1}. ${top[i].key}',
            value: top[i].value,
          );
        }),
      ),
    );
  }
}

class _CookingSummary extends StatelessWidget {
  final int totalCooks;
  final int mealTypes;
  final int tags;

  const _CookingSummary({
    required this.totalCooks,
    required this.mealTypes,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Column(
        children: [
          _StatRow(
            label: context.l10n.statsTotalCooks,
            value: totalCooks,
          ),
          _StatRow(
            label: context.l10n.statsDistinctMealTypes,
            value: mealTypes,
          ),
          _StatRow(
            label: context.l10n.statsDistinctTags,
            value: tags,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Text(
            '$value',
            style: AppTextStyles.titleMedium.copyWith(
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
