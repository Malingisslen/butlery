import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/views/more/more_area_scaffold.dart';
import 'package:butlery/views/settings/collection_stats/completeness_distribution.dart';
import 'package:butlery/views/settings/collection_stats/meal_type_bar.dart';
import 'package:butlery/views/settings/collection_stats/stat_tiles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
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
    final l10n = context.l10n;
    final vm = context.watch<RecipeQueryViewModel>();
    final insights = vm.recipeInsights;
    final mealTypes = vm.getMostUsedMealTypes().take(6).toList();
    final tags = vm.getMostUsedTags().take(8).toList();
    final incompleteRecipes = vm.getIncompleteRecipes();

    return MoreAreaScaffold(
      title: l10n.moreCollectionStats,
      header: StatTiles(
        totalRecipes: insights.totalRecipes,
        favorites: insights.favoriteCount,
        recentlyCooked: insights.recentlyCookedCount,
        withImages: insights.withImagesCount,
      ),
      sections: [
        ButleryListSection(
          title: l10n.statsRecipeCollection,
          rows: [
            ButleryListRow.info(
              label: l10n.statsPersonalRecipes,
              value: '${insights.personalRecipes}',
              strongValue: true,
            ),
            ButleryListRow.info(
              label: l10n.statsCollaborativeRecipes,
              value: '${insights.collaborativeRecipes}',
              strongValue: true,
            ),
            ButleryListRow.info(
              label: l10n.statsHighRated,
              value: '${insights.highRatedCount}',
              strongValue: true,
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.statsMealTypes,
          rows: [
            if (mealTypes.isEmpty)
              StateWidget.empty(title: l10n.statsNoMealTypes)
            else
              for (var i = 0; i < mealTypes.length; i++)
                MealTypeBar(
                  label: mealTypes[i].key,
                  value: mealTypes[i].value,
                  maxValue: mealTypes.first.value,
                  rank: i,
                  ranks: mealTypes.length,
                ),
          ],
        ),
        ButleryListSection(
          title: l10n.statsPopularTags,
          rows: [
            if (tags.isEmpty)
              StateWidget.empty(title: l10n.statsNoTags)
            else
              for (var i = 0; i < tags.length; i++)
                ButleryListRow.info(
                  label: '${i + 1}. ${tags[i].key}',
                  value: '${tags[i].value}',
                  strongValue: true,
                ),
          ],
        ),
        ButleryListSection(
          title: l10n.statsCookingActivity,
          rows: [
            ButleryListRow.info(
              label: l10n.statsTotalCooks,
              value: '${insights.totalCooks}',
            ),
            ButleryListRow.info(
              label: l10n.statsDistinctMealTypes,
              value: '${insights.mealTypes}',
            ),
            ButleryListRow.info(
              label: l10n.statsDistinctTags,
              value: '${insights.tags}',
            ),
          ],
        ),
        ButleryListSection(
          title: l10n.statsCompleteness,
          rows: [
            ButleryListRow.info(
              label: l10n.statsWithoutPhoto,
              value: '${insights.withoutPhotoCount}',
            ),
            ButleryListRow.info(
              label: l10n.statsWithoutTime,
              value: '${insights.withoutTimeCount}',
            ),
            ButleryListRow.info(
              label: l10n.statsIncomplete,
              value: '${insights.incompleteCount}',
            ),
            CompletenessDistribution(
              distribution: insights.completenessDistribution,
            ),
          ],
        ),
        if (incompleteRecipes.isEmpty)
          StateWidget.empty(title: l10n.statsAllComplete)
        else
          ButleryListSection(
            title: l10n.statsIncomplete,
            rows: [
              for (final recipe in incompleteRecipes)
                ButleryListRow(
                  key: ValueKey('stats-incomplete-${recipe.id}'),
                  label: recipe.title,
                  onTap: () => Navigator.pushNamed(
                    context,
                    Routes.editRecipe,
                    arguments: recipe,
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: AppDimensions.space24),
          child: TintedNote(
            child: Text(
              l10n.statsCountedNote(insights.totalRecipes),
              style: TintedNote.textStyle(context),
            ),
          ),
        ),
      ],
    );
  }
}
