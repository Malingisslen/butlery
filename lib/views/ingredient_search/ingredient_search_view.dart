/// Full-screen ingredient-set search: select ingredients → see ranked recipes.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/ingredient_search_viewmodel.dart';
import 'package:butlery/views/ingredient_search/ingredient_chip_input.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/content_card.dart';
import 'package:butlery/widgets/common/state_widget.dart';

class IngredientSearchView extends StatefulWidget {
  const IngredientSearchView({super.key});

  @override
  State<IngredientSearchView> createState() => _IngredientSearchViewState();
}

class _IngredientSearchViewState extends State<IngredientSearchView> {
  late final IngredientSearchViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<IngredientSearchViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<IngredientSearchViewModel>.value(
      value: _vm,
      child: const _IngredientSearchContent(),
    );
  }
}

class _IngredientSearchContent extends StatelessWidget {
  const _IngredientSearchContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IngredientSearchViewModel>();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AdaptiveAppBar(title: l10n.ingredientSearchTitle),
      bottomNavigationBar: ButleryBottomNavigation(
        currentIndex: 0,
        items: ButleryAdaptiveNavigation.getNavigationItems(context),
        onTap: (index) {
          final items = ButleryAdaptiveNavigation.getNavigationItems(context);
          Navigator.pushNamed(context, items[index].route);
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppDimensions.responsiveMaxContentWidth(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.spacingMd),

                // Input + chips
                IngredientChipInput(
                  selectedIngredients: vm.selectedIngredients,
                  autocompleteResults: vm.autocompleteResults,
                  onSearchChanged: vm.searchIngredient,
                  onIngredientSelected: vm.addIngredient,
                  onIngredientRemoved: vm.removeIngredient,
                ),

                const SizedBox(height: AppDimensions.spacingLg),

                // Search button
                ActionButtons.primaryButton(
                  context,
                  label: l10n.ingredientSearchButton,
                  onPressed: vm.selectedIngredients.isEmpty
                      ? null
                      : vm.performSearch,
                ),

                const SizedBox(height: AppDimensions.spacingLg),

                // Results area
                Expanded(child: _buildResults(context, vm)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, IngredientSearchViewModel vm) {
    final l10n = context.l10n;

    if (vm.isLoading) {
      return StateWidget.loading();
    }

    if (vm.error != null) {
      return StateWidget.error(
        message: vm.error!,
        onAction: vm.performSearch,
        actionLabel: l10n.ingredientSearchButton,
      );
    }

    if (!vm.hasSearched) {
      return StateWidget.empty(
        title: l10n.ingredientSearchEmpty,
        icon: Icons.search,
      );
    }

    if (vm.matchResults.isEmpty) {
      return StateWidget.empty(
        title: l10n.ingredientSearchNoResults,
        icon: Icons.no_meals_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ingredientSearchResultCount(vm.matchResults.length),
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Expanded(
          child: ListView.builder(
            itemCount: vm.matchResults.length,
            itemBuilder: (context, index) =>
                _buildResultItem(context, vm, vm.matchResults[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    BuildContext context,
    IngredientSearchViewModel vm,
    IngredientMatchResult result,
  ) {
    final l10n = context.l10n;

    // "Saknas: grädde, vitlök"
    String? missingText;
    if (result.missingIngredientIds.isNotEmpty) {
      final names = result.missingIngredientIds
          .map((id) => vm.ingredientName(id))
          .toList();
      missingText = l10n.ingredientMissing(names.join(', '));
    }

    return Column(
      key: ValueKey(result.recipe.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContentCard(
          item: result.recipe,
          type: ContentCardType.recipe,
          style: ContentCardStyle.detailed,
          matchPercent: result.matchPercent,
          subtitle: l10n.ingredientMatchCount(
            result.matchedCount,
            result.totalCount,
          ),
          onTap: () => Navigator.pushNamed(
            context,
            Routes.recipeDetail,
            arguments: result.recipe,
          ),
        ),
        if (missingText != null || result.recipe.isCollaborative)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppDimensions.spacingMd,
              bottom: AppDimensions.spacingSm,
            ),
            child: Row(
              children: [
                if (result.recipe.isCollaborative)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppDimensions.spacingSm,
                    ),
                    child: Text(
                      l10n.ingredientSearchSharedBadge,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (missingText != null)
                  Expanded(
                    child: Text(
                      missingText,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
