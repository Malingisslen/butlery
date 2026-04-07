import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/theme/app_colors.dart';

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
                _SectionHeader(title: context.l10n.statsCompleteness),
                _CompletenessSection(
                  withoutPhoto: insights['withoutPhotoCount'] as int,
                  withoutTime: insights['withoutTimeCount'] as int,
                  incompleteCount: insights['incompleteCount'] as int,
                  distribution:
                      insights['completenessDistribution'] as Map<String, int>,
                  incompleteRecipes: vm.getIncompleteRecipes(),
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
    final l10n = context.l10n;
    Widget card(IconData icon, int value, String label) => Expanded(
          child: Column(children: [
            Icon(icon, color: cs.surface, size: AppDimensions.iconSizeM),
            const SizedBox(height: AppDimensions.spacingXs),
            Text('$value',
                style: AppTextStyles.headlineBold.copyWith(color: cs.surface)),
            Text(label,
                style: AppTextStyles.labelSmall
                    .copyWith(color: cs.surface.withValues(alpha: 0.8)),
                textAlign: TextAlign.center),
          ]),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingLg),
      color: cs.primary,
      child: Column(children: [
        Row(children: [
          card(Icons.menu_book, totalRecipes, l10n.statsTotalRecipes),
          const SizedBox(width: AppDimensions.spacingMd),
          card(Icons.favorite, favorites, l10n.statsFavorites),
        ]),
        const SizedBox(height: AppDimensions.spacingMd),
        Row(children: [
          card(Icons.local_fire_department, recentlyCooked,
              l10n.statsRecentlyCooked),
          const SizedBox(width: AppDimensions.spacingMd),
          card(Icons.camera_alt, withImages, l10n.statsWithImages),
        ]),
      ]),
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

class _CompletenessSection extends StatelessWidget {
  final int withoutPhoto;
  final int withoutTime;
  final int incompleteCount;
  final Map<String, int> distribution;
  final List<Recipe> incompleteRecipes;

  const _CompletenessSection({
    required this.withoutPhoto,
    required this.withoutTime,
    required this.incompleteCount,
    required this.distribution,
    required this.incompleteRecipes,
  });

  static const _segmentDefs = [
    ('0-25%', AppColors.error),
    ('25-50%', AppColors.warning),
    ('50-75%', AppColors.primaryContainer),
    ('75-100%', AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow(label: l10n.statsWithoutPhoto, value: withoutPhoto),
          _StatRow(label: l10n.statsWithoutTime, value: withoutTime),
          _StatRow(label: l10n.statsIncomplete, value: incompleteCount),
          const SizedBox(height: AppDimensions.spacingMd),
          _buildDistributionBar(),
          const SizedBox(height: AppDimensions.spacingMd),
          if (incompleteRecipes.isEmpty)
            StateWidget.empty(title: l10n.statsAllComplete)
          else
            _buildQuickFixChips(cs),
        ],
      ),
    );
  }

  Widget _buildDistributionBar() {
    final total = distribution.values.fold<int>(0, (sum, v) => sum + v);
    if (total == 0) return const SizedBox.shrink();
    final segments =
        _segmentDefs.map((d) => (d.$1, distribution[d.$1] ?? 0, d.$2)).toList();
    return Column(children: [
      SizedBox(
        height: AppDimensions.spacingMd + AppDimensions.spacingXs,
        child: Row(children: [
          for (final (_, count, color) in segments)
            if (count > 0)
              Expanded(
                  flex: count,
                  child:
                      ColoredBox(color: color, child: const SizedBox.expand())),
        ]),
      ),
      const SizedBox(height: AppDimensions.spacingXs),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final (label, count, color) in segments)
            Text('$label: $count',
                style: AppTextStyles.labelSmall.copyWith(color: color)),
        ],
      ),
    ]);
  }

  Widget _buildQuickFixChips(ColorScheme cs) {
    return SizedBox(
      height: AppDimensions.spacingXl + AppDimensions.spacingSm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: incompleteRecipes.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppDimensions.spacingSm),
        itemBuilder: (context, index) {
          final recipe = incompleteRecipes[index];
          return ActionChip(
            label: Text(recipe.title,
                style: AppTextStyles.labelSmall.copyWith(color: cs.onSurface)),
            backgroundColor: cs.errorContainer,
            side: BorderSide.none,
            shape: const RoundedRectangleBorder(),
            onPressed: () => Navigator.pushNamed(context, Routes.redigeraRecept,
                arguments: recipe),
          );
        },
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
