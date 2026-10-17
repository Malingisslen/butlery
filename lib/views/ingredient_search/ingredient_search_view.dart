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
import 'package:butlery/views/ingredient_search/ingredient_match_row.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
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

    return ButleryPage.undersida(
      title: l10n.ingredientSearchHeading,
      body: Column(
        children: [
          LayoutComponents.offlineIndicator(),
          Expanded(child: _searchBody(context, vm)),
        ],
      ),
    );
  }

  Widget _searchBody(BuildContext context, IngredientSearchViewModel vm) {
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: AppDimensions.responsiveMaxContentWidth(context),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimensions.space16),

              // Input + chips
              IngredientChipInput(
                selectedIngredients: vm.selectedIngredients,
                autocompleteResults: vm.autocompleteResults,
                onSearchChanged: vm.searchIngredient,
                onIngredientSelected: vm.addIngredient,
                onIngredientRemoved: vm.removeIngredient,
              ),

              const SizedBox(height: AppDimensions.space24),

              // Search button
              FormButton(
                expand: true,
                label: l10n.ingredientSearchButton,
                onPressed: vm.selectedIngredients.isEmpty
                    ? null
                    : vm.performSearch,
              ),

              const SizedBox(height: AppDimensions.space24),

              // Results area
              Expanded(child: _buildResults(context, vm)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, IngredientSearchViewModel vm) {
    final l10n = context.l10n;

    if (vm.isLoading) {
      // The plate line says what it does (produktregler.md:163).
      return StateWidget.loading(message: l10n.loadingIngredientSearch);
    }

    if (vm.error != null) {
      // What happened, what was kept, what you can do
      // (content-style-guide.md:89-94): the chosen ingredients stay.
      return StateWidget.error(
        message: vm.error!,
        preserved: l10n.ingredientSearchSelectionKept,
        onAction: vm.performSearch,
        actionLabel: l10n.ingredientSearchAgain,
      );
    }

    if (!vm.hasSearched) {
      return StateWidget.empty(
        title: l10n.ingredientSearchEmpty,
        icon: ButleryIcons.search,
      );
    }

    if (vm.matchResults.isEmpty) {
      return StateWidget.empty(
        title: l10n.ingredientSearchNoResults,
        subtitle: l10n.ingredientSearchNoResultsHint,
        icon: ButleryIcons.searchOff,
        actionLabel: l10n.commonClearAll,
        onAction: vm.clearIngredients,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.ingredientSearchResultCount(vm.matchResults.length),
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.space8),
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
    return IngredientMatchRow(
      key: ValueKey(result.recipe.id),
      recipe: result.recipe,
      matchPercent: result.matchPercent,
      matchedCount: result.matchedCount,
      totalCount: result.totalCount,
      missingNames: [
        for (final id in result.missingIngredientIds) vm.ingredientName(id),
      ],
      onTap: () => Navigator.pushNamed(
        context,
        Routes.recipeDetail,
        arguments: result.recipe,
      ),
    );
  }
}
