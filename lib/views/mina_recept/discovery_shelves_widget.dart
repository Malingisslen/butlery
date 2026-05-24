/// Discovery-shelves widget extracted from `mina_recept_view.dart` per
/// BUT-441. Renders the seasonal hero (BUT-409) plus dormant-recipes and
/// forgotten-favorites shelves. Hero is hidden when fewer than 2 user
/// recipes match the curated month.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/services/seasonal/seasonal_hero_service.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/widgets/home/seasonal_hero_header.dart';
import 'package:butlery/widgets/recipe/recipe_shelf.dart';

class MinaReceptDiscoveryShelves extends StatelessWidget {
  const MinaReceptDiscoveryShelves({
    super.key,
    required this.queryVm,
    required this.seasonalMonthFuture,
    required this.seasonalHeroService,
  });

  final RecipeQueryViewModel queryVm;
  final Future<SeasonalMonth?> seasonalMonthFuture;
  final SeasonalHeroService seasonalHeroService;

  void _navigateToRecipe(BuildContext context, Recipe recipe) {
    Navigator.pushNamed(context, Routes.recipeDetail, arguments: recipe);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<SeasonalMonth?>(
          future: seasonalMonthFuture,
          builder: (_, snap) {
            final month = snap.data;
            if (month == null) return const SizedBox.shrink();
            final matches = seasonalHeroService.matchUserRecipes(
              month,
              queryVm.personalRecipes,
            );
            if (matches.length < 2) return const SizedBox.shrink();
            return SeasonalHeroHeader(
              month: month,
              matchCount: matches.length,
              onTap: () =>
                  queryVm.applySeasonalFilter(ingredients: month.ingredients),
            );
          },
        ),
        RecipeShelf(
          title: context.l10n.dormantRecipesTitle,
          recipes: queryVm.getDormantRecipes(),
          onRecipeTap: (recipe) => _navigateToRecipe(context, recipe),
        ),
        RecipeShelf(
          title: context.l10n.seasonalForgottenFavorites,
          recipes: queryVm.getForgottenFavorites(),
          onRecipeTap: (recipe) => _navigateToRecipe(context, recipe),
        ),
      ],
    );
  }
}
